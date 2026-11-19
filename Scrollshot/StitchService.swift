import CoreGraphics
import Foundation

enum StitchService {
    static let maximumPixels = 64_000_000
    static let pagePixels = 8_000_000

    static func suggestedCrop(_ frames: [CapturedFrame]) -> CropSettings? {
        guard let first = frames.first, frames.count >= 3 else { return nil }
        let count = min(8, frames.count)
        var samples: [UInt8] = []
        for i in 0..<count {
            let index = i * (frames.count - 1) / (count - 1)
            guard frames[index].height == first.height, frames[index].width == first.width,
                  frames[index].gray.count == ImageTools.grayWidth * first.height else { return nil }
            samples.append(contentsOf: frames[index].gray)
        }
        let insets = samples.withUnsafeBufferPointer {
            ss_detect_insets($0.baseAddress, Int32(count), Int32(ImageTools.grayWidth), Int32(first.height))
        }
        guard insets.valid != 0 else { return nil }
        return CropSettings(top: Int(insets.top), bottom: Int(insets.bottom))
    }

    private static func croppedGray(_ frame: CapturedFrame, _ crop: CropSettings) -> [UInt8] {
        let width = ImageTools.grayWidth
        return Array(frame.gray[(crop.top * width)..<((frame.height - crop.bottom) * width)])
    }

    /// A failed join never becomes a guessed placement or a silently truncated result.
    static func plan(_ frames: [CapturedFrame], crop: CropSettings) throws -> (pieces: [StitchPiece], joined: Int, duplicates: Int) {
        guard let first = frames.first else { throw ScrollshotError.message("还没有采集到画面，请切到微信后再慢慢滚动。") }
        guard frames.allSatisfy({ $0.width == first.width && $0.height == first.height && $0.gray.count == ImageTools.grayWidth * first.height }),
              first.width > 0, first.height >= 32, first.height <= 8192 else {
            throw ScrollshotError.message("采集到的图像数据或尺寸无效。")
        }
        _ = try crop.validated(height: first.height)
        let height = first.height - crop.top - crop.bottom
        var pieces = [StitchPiece(frame: 0, sourceY: crop.top, height: height)]
        var previous = croppedGray(first, crop), pendingSince: Double?
        var duplicates = 0, joined = 1, total = height
        for index in frames.indices.dropFirst() {
            let frame = frames[index]
            guard frame.width == first.width, frame.height == first.height else {
                throw ScrollshotError.message("屏幕尺寸不一致，请重新采集。")
            }
            let current = croppedGray(frame, crop)
            let match = previous.withUnsafeBufferPointer { a in current.withUnsafeBufferPointer { b in
                ss_match(a.baseAddress, b.baseAddress, Int32(ImageTools.grayWidth), Int32(height))
            } }
            if match.valid == 0 {
                if pendingSince == nil { pendingSince = frame.time }
                if frame.time - (pendingSince ?? frame.time) <= 1.25 { continue }
                throw ScrollshotError.message("第 \(index + 1) 个画面无法可靠接上。请检查上下裁剪，或去掉切换 App 的过渡画面；重新采集时慢慢滚动，保持相邻内容有重叠。")
            }
            pendingSince = nil
            if match.duplicate != 0 { duplicates += 1; continue }
            let added = height - Int(match.overlap)
            total += added
            guard total * first.width <= maximumPixels else {
                throw ScrollshotError.message("长图超过本次 6400 万像素上限，请缩短选取范围或分段采集。")
            }
            pieces.append(StitchPiece(frame: index, sourceY: crop.top + Int(match.overlap), height: added))
            previous = current; joined += 1
        }
        if pendingSince != nil {
            throw ScrollshotError.message("末尾画面没有接上，尚未导出。请缩短末尾范围，去掉结束采集时的系统界面，或调整裁剪后重新生成。")
        }
        return (pieces, joined, duplicates)
    }

    static func render(_ frames: [CapturedFrame], crop: CropSettings, directory: URL) throws -> StitchResult {
        let plan = try plan(frames, crop: crop)
        guard let first = frames.first else { throw ScrollshotError.message("没有可生成的画面。") }
        let width = first.width, totalHeight = plan.pieces.reduce(0) { $0 + $1.height }
        let pageHeight = min(10_000, pagePixels / width)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var excluded = URLResourceValues(); excluded.isExcludedFromBackup = true
        var folder = directory; try folder.setResourceValues(excluded)
        var files: [URL] = []
        do {
            var pageStart = 0
            while pageStart < totalHeight {
                try autoreleasepool {
                    let height = min(pageHeight, totalHeight - pageStart)
                    guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                                  bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
                        throw ScrollshotError.message("可用内存不足，请缩短截图范围。")
                    }
                    context.interpolationQuality = .none
                    var pieceStart = 0
                    for piece in plan.pieces {
                        let start = max(pageStart, pieceStart), end = min(pageStart + height, pieceStart + piece.height)
                        if end > start {
                            try autoreleasepool {
                                let image = try ImageTools.decode(frames[piece.frame].jpeg)
                                let sourceY = piece.sourceY + start - pieceStart
                                guard let strip = image.cropping(to: CGRect(x: 0, y: CGFloat(sourceY), width: CGFloat(width), height: CGFloat(end - start))) else {
                                    throw ScrollshotError.message("拼接区域超出图像范围。")
                                }
                                // A bitmap CGContext uses a bottom-left origin. Keep every output row at 1:1 scale.
                                context.draw(strip, in: CGRect(x: 0, y: CGFloat(height - (start - pageStart) - (end - start)), width: CGFloat(width), height: CGFloat(end - start)))
                            }
                        }
                        pieceStart += piece.height
                    }
                    guard let image = context.makeImage() else { throw ScrollshotError.message("无法生成长图。") }
                    let url = directory.appendingPathComponent(String(format: "长截图-%02d.png", files.count + 1))
                    try ImageTools.writePNG(image, to: url); files.append(url)
                    pageStart += height
                }
            }
            return StitchResult(files: files, width: width, height: totalHeight, joined: plan.joined, skippedDuplicates: plan.duplicates)
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
    }
}
