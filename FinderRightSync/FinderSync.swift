import Cocoa
import FinderSync
import FinderRightKit

final class FinderSync: FIFinderSync {
    private var nextTag = 1
    private var requests: [Int: (String, [String: AnyJSON])] = [:]

    override init() {
        super.init()
        updateDirectories()
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(updateDirectories), name: NSWorkspace.didMountNotification, object: nil)
        center.addObserver(self, selector: #selector(updateDirectories), name: NSWorkspace.didUnmountNotification, object: nil)
    }

    @objc private func updateDirectories() {
        let home = IPCBridge.rootDirectory.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        var directories: Set<URL> = [home]
        directories.formUnion(FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: nil, options: [.skipHiddenVolumes]) ?? [])
        FIFinderSyncController.default().directoryURLs = directories
    }

    private func L(_ key: String) -> String { NSLocalizedString(key, comment: "Finder menu") }
    private func menuItem(_ title: String, action: String, payload: [String: AnyJSON], symbol: String? = nil, enabled: Bool = true) -> NSMenuItem {
        let shortcutId: String
        switch action {
        case "compressZip": shortcutId = "shortcut.compress"
        case "toggleHiddenFiles": shortcutId = "shortcut.toggleHidden"
        case "cutFiles": shortcutId = "shortcut.cut"
        case "pasteFiles": shortcutId = "shortcut.paste"
        default: shortcutId = "shortcut." + action
        }
        let shortcut = SharedConfig.shared.shortcut(forActionId: shortcutId)
        let item = NSMenuItem(title: L(title), action: #selector(performAction(_:)), keyEquivalent: shortcut?.key ?? "")
        item.target = self; item.tag = nextTag; item.isEnabled = enabled
        if let shortcut { item.keyEquivalentModifierMask = NSEvent.ModifierFlags(rawValue: UInt(shortcut.modifiers)) }
        if let symbol { item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
        requests[nextTag] = (action, payload)
        nextTag += 1
        return item
    }

    private func submenu(_ title: String, items: [NSMenuItem], symbol: String? = nil) -> NSMenuItem {
        let root = NSMenuItem(title: L(title), action: nil, keyEquivalent: "")
        let menu = NSMenu(title: L(title)); menu.autoenablesItems = false
        items.forEach { menu.addItem($0) }; root.submenu = menu
        if let symbol { root.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
        return root
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        SharedConfig.shared.reload()
        // Retain recent tags because Finder serializes menu items into another process.
        if requests.count > 10_000 { requests = requests.filter { $0.key > nextTag - 5_000 } }
        let config = SharedConfig.shared
        let controller = FIFinderSyncController.default()
        let selected = controller.selectedItemURLs() ?? []
        let directory = controller.targetedURL() ?? selected.first?.deletingLastPathComponent()
        let paths: [String: AnyJSON] = ["paths": .stringArray(selected.map(\.path))]
        let hasSelection = !selected.isEmpty
        let isBackground = menuKind == .contextualMenuForContainer || !hasSelection
        let pending = FileOperations(stateDirectory: IPCBridge.rootDirectory).pendingCuts
        var groups: [MenuGroup: [NSMenuItem]] = [:]
        func enabled(_ id: String) -> Bool { config.isActionEnabled(id) }
        func add(_ group: MenuGroup, _ item: NSMenuItem) { groups[group, default: []].append(item) }

        if let directory, isBackground {
            if enabled(MenuFeatureCatalog.newFile) {
                let templates = TemplateCatalog.builtIn + config.customFileTemplates
                add(.create, submenu("新建文件", items: templates.map { template in
                    menuItem(template.name + " (." + template.fileExtension + ")", action: "createFile", payload: [
                        "directory": .string(directory.path), "ext": .string(template.fileExtension), "content": .string(template.content)
                    ])
                }, symbol: "doc.badge.plus"))
            }
            if enabled(MenuFeatureCatalog.newFolder) { add(.create, menuItem("新建文件夹…", action: "createFolder", payload: ["directory": .string(directory.path)], symbol: "folder.badge.plus")) }
        }
        if hasSelection {
            for (feature, title, action, symbol) in [
                (MenuFeatureCatalog.copyPath, "复制路径", "copyPath", "doc.on.doc"),
                (MenuFeatureCatalog.copyNames, "复制文件名", "copyNames", "textformat"),
                (MenuFeatureCatalog.copyFileURLs, "复制文件链接", "copyFileURLs", "link"),
                (MenuFeatureCatalog.checksum, "复制 SHA-256", "copySHA256", "number")
            ] where enabled(feature) {
                if action != "copySHA256" || selected.allSatisfy({ (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }) {
                    add(.copy, menuItem(title, action: action, payload: paths, symbol: symbol))
                }
            }
            if enabled(MenuFeatureCatalog.cut) { add(.files, menuItem("剪切", action: "cutFiles", payload: paths, symbol: "scissors")) }
            if enabled(MenuFeatureCatalog.transfer) {
                for (title, action) in [("复制到", "copyTo"), ("移动到", "moveTo")] {
                    var items = [menuItem("选择文件夹…", action: action, payload: paths)]
                    for favorite in config.favoriteFolders {
                        var payload = paths; payload["destination"] = .string(favorite)
                        let item = menuItem(URL(fileURLWithPath: favorite).lastPathComponent, action: action, payload: payload)
                        item.toolTip = favorite; items.append(item)
                    }
                    add(.files, submenu(title, items: items, symbol: "folder"))
                }
            }
            if enabled(MenuFeatureCatalog.duplicate) { add(.files, menuItem("创建副本", action: "duplicate", payload: paths, symbol: "plus.square.on.square")) }
            if enabled(MenuFeatureCatalog.rename) { add(.files, menuItem("批量重命名…", action: "batchRename", payload: paths, symbol: "pencil")) }
            if enabled(MenuFeatureCatalog.compress) {
                add(.files, submenu("压缩", items: [menuItem("压缩为 ZIP", action: "compressZip", payload: paths), menuItem("压缩为 TAR.GZ", action: "compressTarGz", payload: paths)], symbol: "archivebox"))
            }
            if enabled(MenuFeatureCatalog.decompress), selected.allSatisfy(ArchiveOperations.supports) {
                add(.files, menuItem("安全解压", action: "decompress", payload: paths, symbol: "archivebox.fill"))
            }
        }
        if enabled(MenuFeatureCatalog.paste), let directory {
            add(.files, menuItem("粘贴", action: "pasteFiles", payload: ["destination": .string(directory.path)], symbol: "doc.on.clipboard", enabled: !pending.isEmpty))
            if !pending.isEmpty { add(.files, menuItem("取消剪切", action: "cancelCut", payload: [:])) }
        }
        if enabled(MenuFeatureCatalog.openTerminal), let directory {
            let firstDirectory = selected.first.flatMap { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true ? $0 : nil }
            add(.tools, menuItem("打开终端", action: "openTerminal", payload: ["directory": .string((firstDirectory ?? directory).path), "bundleId": .string(config.preferredTerminal)], symbol: "terminal"))
        }
        if enabled(MenuFeatureCatalog.openEditor), hasSelection {
            let editors = EditorCatalog.all.filter { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0.id) != nil }
            if !editors.isEmpty {
                add(.tools, submenu("打开编辑器", items: editors.map { editor in
                    var payload = paths; payload["bundleId"] = .string(editor.id)
                    return menuItem(editor.name, action: "openWithApp", payload: payload)
                }, symbol: "curlybraces"))
            }
        }
        if enabled(MenuFeatureCatalog.toggleHidden) { add(.tools, menuItem("切换隐藏文件", action: "toggleHiddenFiles", payload: [:], symbol: "eye")) }
        if enabled(MenuFeatureCatalog.favorites), !config.favoriteFolders.isEmpty {
            add(.tools, submenu("常用目录", items: config.favoriteFolders.map { path in
                let item = menuItem(URL(fileURLWithPath: path).lastPathComponent, action: "openFolder", payload: ["directory": .string(path)])
                item.toolTip = path; return item
            }, symbol: "star"))
        }
        if enabled(MenuFeatureCatalog.images), hasSelection, selected.allSatisfy(ImageOperations.supports) {
            add(.media, submenu("转换图片", items: ImageOperations.Format.allCases.map { format in
                var payload = paths; payload["format"] = .string(format.rawValue)
                return menuItem(format.rawValue.uppercased(), action: "imageConvert", payload: payload)
            }, symbol: "photo"))
            add(.media, submenu("缩放图片", items: [640, 1280, 1920, 2560].map { size in
                var payload = paths; payload["maxPixel"] = .int(size); payload["format"] = .string("png")
                return menuItem("最长边 \(size) px", action: "imageResize", payload: payload)
            }))
            add(.media, menuItem("压缩为 JPEG 副本", action: "imageCompress", payload: paths))
        }
        if enabled(MenuFeatureCatalog.pdf), hasSelection, selected.allSatisfy({ ImageOperations.supports($0) || $0.pathExtension.lowercased() == "pdf" }) {
            add(.media, menuItem("合并为 PDF", action: "makePDF", payload: paths, symbol: "doc.richtext"))
        }
        let menu = NSMenu(title: "FinderRight"); menu.autoenablesItems = false
        for group in MenuGroup.allCases {
            guard let items = groups[group], !items.isEmpty else { continue }
            if config.groupedMenus { menu.addItem(submenu(group.rawValue, items: items)) }
            else { if !menu.items.isEmpty { menu.addItem(.separator()) }; items.forEach { menu.addItem($0) } }
        }
        return menu
    }

    @objc private func performAction(_ sender: NSMenuItem) {
        guard let (action, payload) = requests[sender.tag] else { return }
        IPCClient.shared.send(action: action, payload: payload)
    }
}
