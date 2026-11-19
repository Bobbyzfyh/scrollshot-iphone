@preconcurrency import ScreenCaptureKit
import CoreMedia
import CoreImage
import ImageIO
import QuartzCore
import Foundation

/// Every mutable field is confined to `queue`, including the native capture gate.
final class FrameCollector: NSObject, SCStreamOutput, @unchecked Sendable {
    let queue = DispatchQueue(label: "local.scrollshot.frames", qos: .userInitiated)
    private let context = CIContext(options: [.cacheIntermediates: false])
    private var gate = SSCaptureGate()
    private var frames: [CapturedFrame] = []
    private var bytes = 0
    private var enabled = false
    private var ended = false
    private var reason: String?
    private var firstTime: Double?
    private var lastGray: [UInt8]?
    private var acceptedStream: SCStream?
    var onCount: (@Sendable (Int) -> Void)?
    var onLimit: (@Sendable (String) -> Void)?

    func reset() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async {
                self.frames.removeAll(); self.bytes = 0; self.reason = nil
                self.firstTime = nil; self.lastGray = nil; self.enabled = true; self.ended = false
                self.acceptedStream = nil
                ss_gate_reset(&self.gate)
                continuation.resume()
            }
        }
    }

    func attach(_ stream: SCStream) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async { self.acceptedStream = stream; continuation.resume() }
        }
    }

    func background(_ background: Bool) {
        queue.async { ss_gate_background(&self.gate, background ? 1 : 0, CACurrentMediaTime()) }
    }

    func finish() async -> CaptureArchive {
        await withCheckedContinuation { continuation in
            queue.async {
                self.enabled = false
                self.acceptedStream = nil
                ss_gate_background(&self.gate, 0, CACurrentMediaTime())
                let archive = CaptureArchive(frames: self.frames, stopReason: self.reason)
                self.frames.removeAll(); self.lastGray = nil; self.bytes = 0
                continuation.resume(returning: archive)
            }
        }
    }

    private func end(_ message: String) {
        guard !ended else { return }
        ended = true; enabled = false; reason = message
        onLimit?(message)
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard let acceptedStream, acceptedStream === stream,
              type == .screen, enabled, !ended, CMSampleBufferIsValid(sampleBuffer),
              ss_gate_accept(&gate, CACurrentMediaTime()) != 0 else { return }
        // Empty / suspended samples must not become black frames in the result.
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let rawStatus = attachments.first?[.status] as? Int,
              SCFrameStatus(rawValue: rawStatus) == .complete,
              let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        autoreleasepool {
            do {
                var input = CIImage(cvPixelBuffer: buffer)
                if let rawOrientation = attachments.first?[.videoOrientation] as? UInt32,
                   let orientation = CGImagePropertyOrientation(rawValue: rawOrientation) {
                    input = input.oriented(orientation)
                }
                guard input.extent.height > input.extent.width else {
                    end("目前只支持竖屏。已停止采集，请保持微信为竖屏后重试。")
                    return
                }
                guard let image = context.createCGImage(input, from: input.extent) else { return }
                if let previous = frames.first, previous.width != image.width || previous.height != image.height {
                    end("屏幕尺寸发生变化，已停止采集。请保持竖屏和相同的显示设置。")
                    return
                }
                let now = CACurrentMediaTime()
                if firstTime == nil { firstTime = now }
                if now - (firstTime ?? now) > 90 {
                    end("已达到本次 90 秒上限。已保留此前画面，请分段截取。")
                    return
                }
                let gray = try ImageTools.gray(image)
                if let lastGray, lastGray.count == gray.count {
                    var total = 0, changed = 0
                    for i in gray.indices {
                        let delta = abs(Int(gray[i]) - Int(lastGray[i]))
                        total += delta; if delta > 6 { changed += 1 }
                    }
                    if Double(total) / Double(gray.count) < 0.7 && Double(changed) / Double(gray.count) < 0.003 { return }
                }
                let jpeg = try ImageTools.encodeJPEG(image)
                let frame = CapturedFrame(jpeg: jpeg, gray: gray, width: image.width, height: image.height, time: now)
                guard ss_archive_can_add(bytes, Int32(frames.count), frame.memoryBytes) != 0 else {
                    end("已达到本次内存上限，采集已结束。已保留此前画面，请分段截取。")
                    return
                }
                frames.append(frame); bytes += frame.memoryBytes; lastGray = gray
                onCount?(frames.count)
            } catch { end(error.localizedDescription) }
        }
    }
}
