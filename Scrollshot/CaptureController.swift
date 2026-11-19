#if !targetEnvironment(simulator)
import SwiftUI
import Photos
@preconcurrency import ScreenCaptureKit

@MainActor
final class CaptureController: NSObject, ObservableObject {
    enum Phase: Equatable { case ready, choosing, armed, capturing, processing, review }
    @Published private(set) var phase: Phase = .ready
    @Published private(set) var count = 0
    @Published private(set) var result: StitchResult?
    @Published private(set) var sourcePreview: UIImage?
    @Published private(set) var previewFrameSize = CGSize.zero
    @Published private(set) var notice: String?
    @Published private(set) var failure: String?
    @Published private(set) var frameCount = 0
    @Published private(set) var saving = false
    @Published var crop = CropSettings()
    @Published var firstFrame = 0
    @Published var lastFrame = 0

    private let collector = FrameCollector()
    private lazy var picker = SCContentSharingPicker.shared
    private var delegate: CaptureDelegate!
    private var stream: SCStream?
    private var archive = CaptureArchive(frames: [], stopReason: nil)
    private var operation = UUID()
    private var background = false
    private var hasLeftApp = false
    private var timeout: Task<Void, Never>?
    private let exportRoot = FileManager.default.temporaryDirectory.appendingPathComponent("ScrollshotExports", isDirectory: true)

    var busy: Bool { saving || [.choosing, .armed, .capturing, .processing].contains(phase) }
    var canGenerate: Bool { !busy && frameCount > 0 }

    override init() {
        super.init()
        delegate = CaptureDelegate(owner: self)
        collector.onCount = { [weak self] count in Task { @MainActor in self?.count = count } }
        collector.onLimit = { [weak self] text in Task { @MainActor in await self?.finish(note: text) } }
        // Only our own export directory is removed; no user-selected files are touched.
        try? FileManager.default.removeItem(at: exportRoot)
    }

    func begin() async {
        guard !busy else { return }
        #if targetEnvironment(simulator)
        failure = "跨 App 屏幕采集需要 iPhone 真机；模拟器可用于界面和拼接测试。"
        return
        #else
        clear()
        operation = UUID(); hasLeftApp = false
        phase = .choosing
        await collector.reset()
        var configuration = SCContentSharingPickerConfiguration()
        configuration.showsMicrophoneControl = false
        configuration.showsCameraControl = false
        picker.defaultConfiguration = configuration
        picker.add(delegate); picker.isActive = true
        picker.present()
        #endif
    }

    func start(with filter: SCContentFilter) async {
        guard phase == .choosing else { return }
        let request = operation
        // Change phase before awaiting so duplicate picker callbacks cannot start two streams.
        phase = .armed
        let configuration = SCStreamConfiguration()
        guard let screen = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first?.screen.bounds.size,
              screen.width > 0, screen.height > 0 else {
            deactivatePicker(); _ = await collector.finish()
            phase = .ready; failure = "无法取得 iPhone 屏幕尺寸，请回到 App 后重新开始。"
            return
        }
        configuration.width = 1080
        configuration.height = Int((1080 * max(screen.height, screen.width) / min(screen.height, screen.width)).rounded())
        configuration.capturesAudio = false
        // iOS does not expose the macOS pixel-format / queue / frame-interval controls.
        // The collector throttles raw screen callbacks; no microphone output is attached.
        do {
            let capture = SCStream(filter: filter, configuration: configuration, delegate: delegate)
            try capture.addStreamOutput(collector, type: .screen, sampleHandlerQueue: collector.queue)
            await collector.attach(capture)
            try await capture.startCapture()
            guard operation == request, phase == .armed else {
                try? await capture.stopCapture()
                return
            }
            stream = capture
            collector.background(background)
            if background { hasLeftApp = true; phase = .capturing }
            notice = "采集已开启。切到微信，停留约 2 秒后向下慢慢滚动。返回本 App 会自动结束。"
            timeout = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 95_000_000_000)
                guard !Task.isCancelled else { return }
                await self?.finish(note: "已达到本次时间上限，采集已结束。")
            }
        } catch {
            guard operation == request else { return }
            deactivatePicker()
            _ = await collector.finish()
            phase = .ready; failure = "无法开始屏幕采集：\(error.localizedDescription)"
        }
    }

    func pickerCancelled() async {
        guard phase == .choosing else { return }
        operation = UUID(); deactivatePicker(); _ = await collector.finish()
        phase = .ready; notice = "已取消，没有采集画面。"
    }

    func pickerFailed(_ error: Error) async {
        guard phase == .choosing else { return }
        operation = UUID(); deactivatePicker(); _ = await collector.finish()
        phase = .ready; failure = "系统采集面板无法打开：\(error.localizedDescription)"
    }

    func resignActive() { collector.background(false) }
    func enteredBackground() {
        background = true
        if phase == .armed || phase == .capturing {
            hasLeftApp = true
            if stream != nil { phase = .capturing; collector.background(true) }
        }
    }
    func enteringForeground() {
        background = false
        collector.background(false)
        if hasLeftApp && (phase == .armed || phase == .capturing) {
            Task { await finish() }
        }
    }

    func streamStopped(_ stopped: SCStream, error: Error) async {
        guard let stream, stream === stopped, phase == .armed || phase == .capturing else { return }
        await finish(note: "系统已停止屏幕采集。\(error.localizedDescription)")
    }

    func finish(note: String? = nil) async {
        guard phase == .armed || phase == .capturing else { return }
        phase = .processing; operation = UUID()
        timeout?.cancel(); timeout = nil
        collector.background(false)
        let existing = stream; stream = nil
        if let existing { try? await existing.stopCapture() }
        deactivatePicker()
        archive = await collector.finish()
        frameCount = archive.frames.count; firstFrame = 0; lastFrame = max(0, frameCount - 1)
        notice = note ?? archive.stopReason
        guard let first = archive.frames.first else {
            phase = .ready; failure = "没有采集到微信画面。确认授权后，请切到微信停留约 2 秒，再慢慢滚动。"
            return
        }
        updateSourcePreview()
        if let suggested = StitchService.suggestedCrop(archive.frames) {
            crop = suggested
            await generate()
        } else if archive.frames.count == 1 {
            crop = CropSettings(); await generate()
        } else {
            crop = CropSettings(top: Int(Double(first.height) * 0.12), bottom: Int(Double(first.height) * 0.10))
            phase = .review
            failure = "未能可靠识别固定栏。请把上、下边界移到可滚动的聊天内容内，再点“重新生成”。"
        }
    }

    private func deactivatePicker() {
        picker.isActive = false; picker.remove(delegate)
    }

    func updateSourcePreview() {
        guard archive.frames.indices.contains(firstFrame) else { return }
        let frame = archive.frames[firstFrame]
        sourcePreview = UIImage(data: frame.jpeg)
        previewFrameSize = CGSize(width: CGFloat(frame.width), height: CGFloat(frame.height))
    }

    func invalidateResult() {
        guard !busy else { return }
        if let result { for file in result.files { try? FileManager.default.removeItem(at: file) } }
        result = nil
    }

    func generate() async {
        guard !archive.frames.isEmpty, firstFrame >= 0, lastFrame >= firstFrame,
              lastFrame < archive.frames.count, phase != .choosing, phase != .armed, phase != .capturing else { return }
        // `finish` calls this while processing; UI calls are disabled until processing ends.
        let request = UUID(); operation = request
        if let result { for file in result.files { try? FileManager.default.removeItem(at: file) } }
        result = nil; failure = nil; phase = .processing
        let selected = Array(archive.frames[firstFrame...lastFrame]), settings = crop
        let directory = exportRoot.appendingPathComponent(request.uuidString, isDirectory: true)
        let outcome = await Task.detached(priority: .userInitiated) {
            Result { try StitchService.render(selected, crop: settings, directory: directory) }
        }.value
        guard operation == request else { try? FileManager.default.removeItem(at: directory); return }
        phase = .review
        switch outcome {
        case .success(let output): result = output
        case .failure(let error): failure = error.localizedDescription
        }
    }

    func saveToPhotos() async {
        guard let files = result?.files, !files.isEmpty, !saving else { return }
        saving = true; defer { saving = false }
        let permission = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard permission == .authorized || permission == .limited else {
            failure = "尚未允许添加到相册。你也可以用“分享／存到文件”保存长图。"; return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                for url in files {
                    let request = PHAssetCreationRequest.forAsset()
                    request.addResource(with: .photo, fileURL: url, options: nil)
                }
            }
            notice = "已保存 \(files.count) 张长图到相册。"
        } catch { failure = "保存失败：\(error.localizedDescription)" }
    }

    func clear() {
        guard !busy else { return }
        operation = UUID(); timeout?.cancel(); timeout = nil
        archive = CaptureArchive(frames: [], stopReason: nil)
        result = nil; sourcePreview = nil; previewFrameSize = .zero
        count = 0; frameCount = 0; firstFrame = 0; lastFrame = 0
        notice = nil; failure = nil; crop = CropSettings(); phase = .ready
        try? FileManager.default.removeItem(at: exportRoot)
    }
}

/// ScreenCaptureKit can call delegates on a non-main queue.
private final class CaptureDelegate: NSObject, SCContentSharingPickerObserver, SCStreamDelegate, @unchecked Sendable {
    weak var owner: CaptureController?
    init(owner: CaptureController) { self.owner = owner }
    func contentSharingPicker(_ picker: SCContentSharingPicker, didUpdateWith filter: SCContentFilter, for stream: SCStream?) {
        Task { @MainActor in await owner?.start(with: filter) }
    }
    func contentSharingPicker(_ picker: SCContentSharingPicker, didCancelFor stream: SCStream?) {
        Task { @MainActor in await owner?.pickerCancelled() }
    }
    func contentSharingPickerStartDidFailWithError(_ error: Error) {
        Task { @MainActor in await owner?.pickerFailed(error) }
    }
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor in await owner?.streamStopped(stream, error: error) }
    }
}
#endif
