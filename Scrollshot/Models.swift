import Foundation

struct CapturedFrame: Sendable {
    let jpeg: Data
    let gray: [UInt8]
    let width: Int
    let height: Int
    let time: Double
    var memoryBytes: Int { jpeg.count + gray.count }
}

struct CaptureArchive: Sendable {
    let frames: [CapturedFrame]
    let stopReason: String?
}

struct CropSettings: Equatable, Sendable {
    var top = 0
    var bottom = 0
    func validated(height: Int) throws -> CropSettings {
        guard top >= 0, bottom >= 0, top + bottom <= Int(Double(height) * 0.65),
              height - top - bottom >= 32 else {
            throw ScrollshotError.message("顶部与底部合计最多裁掉 65%，请保留滚动内容。")
        }
        return self
    }
}

struct StitchPiece: Sendable {
    let frame: Int
    let sourceY: Int
    let height: Int
}

struct StitchResult: Sendable {
    let files: [URL]
    let width: Int
    let height: Int
    let joined: Int
    let skippedDuplicates: Int
}

enum ScrollshotError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self { case .message(let text): return text }
    }
}
