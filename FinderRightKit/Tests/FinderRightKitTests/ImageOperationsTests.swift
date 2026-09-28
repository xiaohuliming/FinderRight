import XCTest
import ImageIO
import UniformTypeIdentifiers
import PDFKit
@testable import FinderRightKit

final class ImageOperationsTests: XCTestCase {
    var root: URL!
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("FinderRightImageTests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }
    func fixture(_ name: String = "source.png", frames: Int = 1) throws -> URL {
        let context = CGContext(data: nil, width: 200, height: 100, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 0.5))
        context.fill(CGRect(x: 0, y: 0, width: 200, height: 100))
        let file = root.appendingPathComponent(name)
        let type = frames > 1 ? UTType.gif : UTType.png
        let output = CGImageDestinationCreateWithURL(file as CFURL, type.identifier as CFString, frames, nil)!
        for _ in 0..<frames { CGImageDestinationAddImage(output, context.makeImage()!, nil) }
        XCTAssertTrue(CGImageDestinationFinalize(output))
        return file
    }
    func testConversionKeepsSourceAndUsesIndependentOutput() throws {
        let source = try fixture()
        let before = try Data(contentsOf: source)
        for format in ImageOperations.Format.allCases {
            let output = try ImageOperations.convert(source, format: format)
            XCTAssertNotEqual(output, source)
            let image = CGImageSourceCreateWithURL(output as CFURL, nil)!
            XCTAssertEqual(CGImageSourceGetType(image) as String?, format.type.identifier)
        }
        XCTAssertEqual(try Data(contentsOf: source), before)
    }
    func testJPEGTransparencyUsesWhiteBackground() throws {
        let output = try ImageOperations.convert(fixture(), format: .jpeg)
        let source = CGImageSourceCreateWithURL(output as CFURL, nil)!
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
        let context = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        let bytes = context.data!.assumingMemoryBound(to: UInt8.self)
        XCTAssertGreaterThan(bytes[0], 120)
        XCTAssertGreaterThan(bytes[1], 140)
        XCTAssertGreaterThan(bytes[2], 180)
    }
    func testResizePreservesAspectRatioAndDoesNotUpscale() throws {
        let source = try fixture()
        let output = try ImageOperations.convert(source, format: .png, maxPixel: 80)
        let image = CGImageSourceCreateWithURL(output as CFURL, nil)!
        let properties = CGImageSourceCopyPropertiesAtIndex(image, 0, nil) as! [CFString: Any]
        XCTAssertEqual(properties[kCGImagePropertyPixelWidth] as? Int, 80)
        XCTAssertEqual(properties[kCGImagePropertyPixelHeight] as? Int, 40)
        XCTAssertThrowsError(try ImageOperations.convert(source, format: .png, maxPixel: 0))
        let larger = try ImageOperations.convert(source, format: .png, maxPixel: 1000)
        let largerImage = CGImageSourceCreateWithURL(larger as CFURL, nil)!
        let largerProperties = CGImageSourceCopyPropertiesAtIndex(largerImage, 0, nil) as! [CFString: Any]
        XCTAssertEqual(largerProperties[kCGImagePropertyPixelWidth] as? Int, 200)
    }
    func testAnimationIsRejectedRatherThanSilentlyFlattened() throws {
        XCTAssertThrowsError(try ImageOperations.convert(fixture("animation.gif", frames: 2), format: .png))
    }
    func testImagesAndPDFMergePreserveAllPages() throws {
        let first = try fixture("01.png"), second = try fixture("02.png")
        let pdf = try ImageOperations.makePDF([second, first])
        XCTAssertEqual(PDFDocument(url: pdf)?.pageCount, 2)
        let merged = try ImageOperations.makePDF([pdf, first])
        XCTAssertEqual(PDFDocument(url: merged)?.pageCount, 3)
        XCTAssertNotEqual(pdf, merged)
    }
}
