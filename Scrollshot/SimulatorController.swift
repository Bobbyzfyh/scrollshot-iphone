#if targetEnvironment(simulator)
import SwiftUI

/// ScreenCaptureKit has no iOS Simulator module. This UI-only adapter never claims
/// to capture a screen. ImageTools / StitchService / the C core are the real app code.
@MainActor
final class CaptureController: NSObject, ObservableObject {
    enum Phase: Equatable { case ready, choosing, armed, capturing, processing, review }
    @Published private(set) var phase: Phase = .ready
    @Published private(set) var count = 0
    @Published private(set) var result: StitchResult?
    @Published private(set) var sourcePreview: UIImage?
    @Published private(set) var previewFrameSize = CGSize.zero
    @Published private(set) var notice: String? = "模拟器仅用于界面与图片算法验证。屏幕采集需要 iPhone 真机。"
    @Published private(set) var failure: String?
    @Published private(set) var frameCount = 0
    @Published private(set) var saving = false
    @Published var crop = CropSettings()
    @Published var firstFrame = 0
    @Published var lastFrame = 0
    var busy: Bool { false }
    var canGenerate: Bool { false }
    func begin() async { failure = "请在 iPhone 真机上测试屏幕采集。模拟器不提供该接口。" }
    func finish(note: String? = nil) async {}
    func generate() async {}
    func saveToPhotos() async {}
    func clear() { failure = nil }
    func updateSourcePreview() {}
    func invalidateResult() {}
    func resignActive() {}
    func enteredBackground() {}
    func enteringForeground() {}
}
#endif
