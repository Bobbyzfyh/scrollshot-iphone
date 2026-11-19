import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import Scrollshot

final class ScrollshotTests: XCTestCase {
    private func noise(height: Int) -> [UInt8] {
        var state: UInt32 = 42
        return (0..<(64 * height)).map { _ in
            state = state &* 1664525 &+ 1013904223
            return UInt8(35 + state % 195)
        }
    }
    private func image(_ pixels: [UInt8], height: Int) throws -> CGImage {
        let provider = try XCTUnwrap(CGDataProvider(data: Data(pixels) as CFData))
        return try XCTUnwrap(CGImage(width: 64, height: height, bitsPerComponent: 8, bitsPerPixel: 8,
                                     bytesPerRow: 64, space: CGColorSpaceCreateDeviceGray(),
                                     bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                                     provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
    }
    private func frame(_ source: [UInt8], offset: Int, height: Int, time: Double) throws -> CapturedFrame {
        let pixels = Array(source[(offset * 64)..<((offset + height) * 64)])
        let cg = try image(pixels, height: height)
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, cg, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return CapturedFrame(jpeg: data as Data, gray: try ImageTools.gray(cg), width: 64, height: height, time: time)
    }

    func testGrayAdapterPreservesTopToBottomPixelOrder() throws {
        let pixels = noise(height: 400)
        let gray = try ImageTools.gray(image(pixels, height: 400))
        XCTAssertEqual(gray, pixels)
    }

    func testPlanAndRendererReconstructRowsWithoutFlipOrSeams() throws {
        let source = noise(height: 4400)
        let frames = try [0, 713, 1800, 2800].enumerated().map { index, offset in
            try frame(source, offset: offset, height: 1600, time: Double(index) * 0.25)
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let result = try StitchService.render(frames, crop: CropSettings(), directory: directory)
        XCTAssertEqual(result.height, 4400); XCTAssertEqual(result.files.count, 1)
        let output = try ImageTools.decode(Data(contentsOf: result.files[0]))
        let reconstructed = try ImageTools.gray(output)
        // Color conversion from device gray to RGB is allowed a one-level rounding difference.
        XCTAssertEqual(reconstructed.count, source.count)
        XCTAssertLessThanOrEqual(zip(reconstructed, source).map { abs(Int($0) - Int($1)) }.max() ?? 255, 1)
    }

    func testGapAndInvalidCropDoNotProduceExport() throws {
        let source = noise(height: 4000)
        let frames = try [0, 2000].enumerated().map { index, offset in
            try frame(source, offset: offset, height: 1600, time: Double(index))
        }
        XCTAssertThrowsError(try StitchService.plan(frames, crop: CropSettings()))
        XCTAssertThrowsError(try StitchService.plan(frames, crop: CropSettings(top: 900, bottom: 600)))
    }

    func testSplitPNGPagesKeepBoundaryRows() throws {
        let source = noise(height: 10700)
        let positions = Array(stride(from: 0, through: 9100, by: 700))
        let frames = try positions.enumerated().map { index, offset in
            try frame(source, offset: offset, height: 1600, time: Double(index) * 0.25)
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let result = try StitchService.render(frames, crop: CropSettings(), directory: directory)
        XCTAssertEqual(result.height, 10700); XCTAssertEqual(result.files.count, 2)
        var reconstructed: [UInt8] = []
        for url in result.files {
            reconstructed.append(contentsOf: try ImageTools.gray(ImageTools.decode(Data(contentsOf: url))))
        }
        XCTAssertEqual(reconstructed.count, source.count)
        XCTAssertLessThanOrEqual(zip(reconstructed, source).map { abs(Int($0) - Int($1)) }.max() ?? 255, 1)
    }

    func testBriefBadTransitionCanRecoverButUnmatchedTailFails() throws {
        let source = noise(height: 3000)
        let a = try frame(source, offset: 0, height: 1600, time: 0)
        let good = try frame(source, offset: 400, height: 1600, time: 0.5)
        let bad = CapturedFrame(jpeg: a.jpeg, gray: [UInt8](repeating: 0, count: a.gray.count), width: 64, height: 1600, time: 0.25)
        let result = try StitchService.plan([a, bad, good], crop: CropSettings())
        XCTAssertEqual(result.pieces.reduce(0) { $0 + $1.height }, 2000)
        XCTAssertThrowsError(try StitchService.plan([a, bad], crop: CropSettings()))
    }
}
