import XCTest
@testable import FinderRightKit

final class FileOperationsTests: XCTestCase {
    var root: URL!
    var operations: FileOperations!
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("FinderRightTests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        operations = FileOperations(stateDirectory: root.appendingPathComponent("state"))
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }
    func file(_ name: String, _ content: String = "original") throws -> URL {
        let url = root.appendingPathComponent(name)
        try Data(content.utf8).write(to: url)
        return url
    }
    func directory(_ name: String) throws -> URL {
        let url = root.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func testConsecutiveCutsNeverMoveOrDeleteOriginals() throws {
        let a = try file("A.txt"), b = try file("B.txt")
        try operations.cut([a]); try operations.cut([b])
        XCTAssertEqual(try String(contentsOf: a), "original")
        XCTAssertEqual(try String(contentsOf: b), "original")
        let destination = try directory("destination")
        let result = try operations.paste(into: destination)
        XCTAssertTrue(result.succeeded)
        XCTAssertTrue(FileManager.default.fileExists(atPath: a.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: b.path))
        XCTAssertEqual(try String(contentsOf: destination.appendingPathComponent("B.txt")), "original")
    }

    func testCancellationKeepsSourceAndPersistsAcrossRestart() throws {
        let a = try file("A.txt")
        try operations.cut([a])
        let restarted = FileOperations(stateDirectory: operations.stateDirectory)
        XCTAssertEqual(restarted.pendingCuts, [a])
        try restarted.cancelCut()
        XCTAssertTrue(operations.pendingCuts.isEmpty)
        XCTAssertEqual(try String(contentsOf: a), "original")
    }

    func testPasteDoesNotOverwriteAndRetainsFailedSources() throws {
        let a = try file("A.txt", "new"), b = try file("B.txt")
        let dest = try directory("destination")
        try Data("existing".utf8).write(to: dest.appendingPathComponent("A.txt"))
        try operations.cut([a, b])
        try FileManager.default.removeItem(at: b)
        let result = try operations.paste(into: dest)
        XCTAssertEqual(result.completed.count, 1)
        XCTAssertEqual(result.failures.count, 1)
        XCTAssertEqual(operations.pendingCuts, [b])
        XCTAssertEqual(try String(contentsOf: dest.appendingPathComponent("A.txt")), "existing")
        XCTAssertEqual(try String(contentsOf: dest.appendingPathComponent("A 2.txt")), "new")
    }

    func testLegacyStagingIsPreservedAndRecoverable() throws {
        let staging = try directory("state/staging")
        let old = staging.appendingPathComponent("old.txt")
        try Data("legacy".utf8).write(to: old)
        try JSONEncoder().encode([old.path]).write(to: operations.queueURL)
        let next = try file("next.txt")
        XCTAssertThrowsError(try operations.cut([next]))
        XCTAssertThrowsError(try operations.cancelCut())
        XCTAssertEqual(try String(contentsOf: old), "legacy")
        let dest = try directory("recovered")
        XCTAssertTrue(try operations.paste(into: dest).succeeded)
        XCTAssertEqual(try String(contentsOf: dest.appendingPathComponent("old.txt")), "legacy")
        try operations.cut([next])
        XCTAssertTrue(FileManager.default.fileExists(atPath: next.path))
    }

    func testDirectoryCannotBeMovedIntoDescendantOrSymlinkToDescendant() throws {
        let parent = try directory("parent"), child = try directory("parent/child")
        let alias = root.appendingPathComponent("alias")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: child)
        XCTAssertFalse(operations.transfer([parent], into: alias, move: true).succeeded)
        XCTAssertTrue(FileManager.default.fileExists(atPath: child.path))
    }

    func testRenameValidatesWholeBatchBeforeMutation() throws {
        let a = try file("A.txt"), b = try file("B.txt"), occupied = try file("occupied.txt", "keep")
        XCTAssertThrowsError(try operations.rename([a, b], names: ["first.txt", occupied.lastPathComponent]))
        XCTAssertTrue(FileManager.default.fileExists(atPath: a.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: b.path))
        XCTAssertEqual(try String(contentsOf: occupied), "keep")
        XCTAssertThrowsError(try operations.rename([a, b], names: ["same.txt", "SAME.txt"]))
        let renamed = try operations.rename([a, b], names: ["photo-001.txt", "photo-002.txt"])
        XCTAssertEqual(renamed.map(\.lastPathComponent), ["photo-001.txt", "photo-002.txt"])
    }

    func testTemplateCannotEscapeTargetDirectory() throws {
        XCTAssertThrowsError(try operations.createFile(named: "../escape.txt", content: "", in: root))
        let output = try operations.createFile(named: "中文.txt", content: "你好", in: root)
        XCTAssertEqual(try String(contentsOf: output), "你好")
        let second = try operations.createFile(named: "中文.txt", content: "second", in: root)
        XCTAssertNotEqual(output, second)
        XCTAssertEqual(try String(contentsOf: output), "你好")
    }

    func testSHA256MatchesKnownDigest() throws {
        XCTAssertEqual(try FileOperations.sha256(of: file("hash.txt", "abc")), "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    func testArchiveRoundTripNeverOverwritesSiblings() throws {
        let source = try file("-中文 file.txt", "archived")
        let zip = try ArchiveOperations.compress([source])
        try Data("keep current".utf8).write(to: source)
        let first = try ArchiveOperations.extract(zip)
        let second = try ArchiveOperations.extract(zip)
        XCTAssertNotEqual(first, second)
        XCTAssertEqual(try String(contentsOf: source), "keep current")
        XCTAssertEqual(try String(contentsOf: first.appendingPathComponent(source.lastPathComponent)), "archived")
        let tar = try ArchiveOperations.compress([source], tarGz: true)
        XCTAssertTrue(FileManager.default.fileExists(atPath: try ArchiveOperations.extract(tar).appendingPathComponent(source.lastPathComponent).path))
    }

    func testUnsafeArchiveNamesAreRejected() throws {
        XCTAssertThrowsError(try ArchiveOperations.validateMembers("../outside.txt\n"))
        XCTAssertThrowsError(try ArchiveOperations.validateMembers("/tmp/outside.txt\n"))
        XCTAssertNoThrow(try ArchiveOperations.validateMembers("./folder/valid.txt\n"))
    }

    func testActualArchiveTraversalAndSymlinkEscapeCannotOverwriteOutsideFile() throws {
        func entry(_ name: String, type: UInt8 = 48, link: String = "", content: String = "") -> Data {
            var header = [UInt8](repeating: 0, count: 512)
            func put(_ text: String, _ offset: Int) {
                for (index, byte) in text.utf8.enumerated() { header[offset + index] = byte }
            }
            put(name, 0); put("0000644", 100); put("0000000", 108); put("0000000", 116)
            put(String(format: "%011o", content.utf8.count), 124); put("00000000000", 136)
            put("        ", 148); header[156] = type; put(link, 157); put("ustar", 257); put("00", 263)
            let sum = header.reduce(0) { $0 + Int($1) }
            put(String(format: "%06o", sum), 148); header[154] = 0; header[155] = 32
            var data = Data(header); data.append(Data(content.utf8))
            if content.utf8.count % 512 != 0 { data.append(Data(repeating: 0, count: 512 - content.utf8.count % 512)) }
            return data
        }
        let protected = try file("outside.txt", "must survive")
        let traversal = root.appendingPathComponent("traversal.tar")
        var bad = entry("../outside.txt", content: "overwrite")
        bad.append(Data(repeating: 0, count: 1024)); try bad.write(to: traversal)
        XCTAssertThrowsError(try ArchiveOperations.extract(traversal))
        XCTAssertEqual(try String(contentsOf: protected), "must survive")
        let symlink = root.appendingPathComponent("symlink.tar")
        var linked = entry("escape", type: 50, link: "..")
        linked.append(entry("escape/outside.txt", content: "overwrite"))
        linked.append(Data(repeating: 0, count: 1024)); try linked.write(to: symlink)
        XCTAssertThrowsError(try ArchiveOperations.extract(symlink))
        XCTAssertEqual(try String(contentsOf: protected), "must survive")
    }

    func testRenamePlanPreservesExtensions() throws {
        let urls = [root.appendingPathComponent("你好.md"), root.appendingPathComponent("world.txt")]
        XCTAssertEqual(RenamePlan.names(for: urls, mode: .affix, first: "pre-", second: "-end"), ["pre-你好-end.md", "pre-world-end.txt"])
        XCTAssertEqual(RenamePlan.names(for: urls, mode: .sequence, first: "file-", second: "", start: 9), ["file-009.md", "file-010.txt"])
    }
}
