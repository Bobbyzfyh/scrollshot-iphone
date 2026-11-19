import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Foundation

enum ImageTools {
    static let grayWidth = 64

    static func gray(_ image: CGImage) throws -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: grayWidth * image.height)
        let success = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: grayWidth, height: image.height,
                                          bitsPerComponent: 8, bytesPerRow: grayWidth,
                                          space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(grayWidth), height: CGFloat(image.height)))
            return true
        }
        guard success else { throw ScrollshotError.message("无法读取屏幕图像。") }
        return pixels
    }

    static func encodeJPEG(_ image: CGImage) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw ScrollshotError.message("无法缓冲屏幕图片。")
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.96] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw ScrollshotError.message("屏幕图片处理失败。") }
        return data as Data
    }

    static func decode(_ data: Data) throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary) else {
            throw ScrollshotError.message("无法解码屏幕图片。")
        }
        return image
    }

    static func thumbnail(_ url: URL, maximum: Int = 1800) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maximum,
            kCGImageSourceCreateThumbnailWithTransform: true
        ] as CFDictionary)
    }

    static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw ScrollshotError.message("无法创建长图文件。")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw ScrollshotError.message("长图写入失败。") }
        try FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: url.path)
    }
}
