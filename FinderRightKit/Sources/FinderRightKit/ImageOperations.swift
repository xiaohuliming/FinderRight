import Foundation
import ImageIO
import UniformTypeIdentifiers
import PDFKit
import AppKit

public enum ImageOperations {
    public enum Format: String, CaseIterable {
        case png, jpeg, heic, tiff
        public var type: UTType {
            switch self {
            case .png: return .png
            case .jpeg: return .jpeg
            case .heic: return .heic
            case .tiff: return .tiff
            }
        }
        public var fileExtension: String { self == .jpeg ? "jpg" : rawValue }
    }

    public static func supports(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .image)
    }

    public static func convert(_ sourceURL: URL, format: Format, maxPixel: Int? = nil, quality: Double = 0.9) throws -> URL {
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil) else {
            throw FileOperationError("无法读取图片：\(sourceURL.lastPathComponent)")
        }
        guard CGImageSourceGetCount(source) == 1 else {
            throw FileOperationError("动画或多页图片暂不转换，以免丢失帧。")
        }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
        let width = properties[kCGImagePropertyPixelWidth] as? Int ?? 0
        let height = properties[kCGImagePropertyPixelHeight] as? Int ?? 0
        guard width > 0, height > 0, width <= 100_000, height <= 100_000, width * height <= 100_000_000 else {
            throw FileOperationError("图片尺寸无效或超过一亿像素。")
        }
        let limit = min(maxPixel ?? max(width, height), max(width, height))
        guard limit > 0 else { throw FileOperationError("图片尺寸必须大于零。") }
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: limit
        ] as CFDictionary) else { throw FileOperationError("无法解码图片。") }
        let label = maxPixel == nil ? " 转换" : " \(limit)px"
        let name = sourceURL.deletingPathExtension().lastPathComponent + label + "." + format.fileExtension
        let output = FileOperations.uniqueURL(named: name, in: sourceURL.deletingLastPathComponent())
        guard let destination = CGImageDestinationCreateWithURL(output as CFURL, format.type.identifier as CFString, 1, nil) else {
            throw FileOperationError("此系统不支持输出 \(format.rawValue.uppercased())。")
        }
        var outputImage = image
        if format == .jpeg {
            guard let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
                throw FileOperationError("无法创建 JPEG 图片。")
            }
            context.setFillColor(CGColor(gray: 1, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: image.width, height: image.height))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            guard let flattened = context.makeImage() else { throw FileOperationError("无法转换 JPEG 图片。") }
            outputImage = flattened
        }
        CGImageDestinationAddImage(destination, outputImage, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            try? FileManager.default.removeItem(at: output)
            throw FileOperationError("图片写入失败。")
        }
        return output
    }

    public static func makePDF(_ urls: [URL]) throws -> URL {
        guard let first = urls.first else { throw FileOperationError("请先选择图片或 PDF。") }
        let document = PDFDocument()
        for url in urls.sorted(by: { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }) {
            if url.pathExtension.lowercased() == "pdf" {
                guard let input = PDFDocument(url: url), !input.isLocked, input.pageCount > 0 else {
                    throw FileOperationError("无法读取 PDF：\(url.lastPathComponent)")
                }
                for index in 0..<input.pageCount {
                    guard let page = input.page(at: index)?.copy() as? PDFPage else { throw FileOperationError("无法读取 PDF 页面。") }
                    document.insert(page, at: document.pageCount)
                }
            } else {
                guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), CGImageSourceGetCount(source) == 1,
                      let image = NSImage(contentsOf: url), let page = PDFPage(image: image) else {
                    throw FileOperationError("仅支持单帧图片：\(url.lastPathComponent)")
                }
                document.insert(page, at: document.pageCount)
            }
        }
        let output = FileOperations.uniqueURL(named: "合并文档.pdf", in: first.deletingLastPathComponent())
        guard document.write(to: output) else { throw FileOperationError("PDF 写入失败。") }
        return output
    }
}
