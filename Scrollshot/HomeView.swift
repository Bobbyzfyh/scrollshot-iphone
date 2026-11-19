import SwiftUI
import QuickLook

struct HomeView: View {
    @ObservedObject var model: CaptureController
    @State private var showShare = false
    @State private var previewFile: PreviewFile?
    @State private var showCrop = false
    @State private var confirmClear = false
    private let blue = Color(red: .12, green: .30, blue: .83)
    private let paper = Color(red: .97, green: .97, blue: .94)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Label("本地处理 · 无视频文件", systemImage: "iphone.gen3")
                            .font(.caption.weight(.semibold)).foregroundStyle(blue)
                        Spacer()
                        Text("原生版 2.0").font(.caption).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "rectangle.portrait.and.arrow.down")
                            .font(.system(size: 40, weight: .light)).foregroundStyle(blue)
                        Text("滚动之后，\n就是一张长图。").font(.system(size: 33, weight: .bold, design: .rounded))
                        Text("确认屏幕采集，去微信慢慢滚动。\n回到这里，自动结束并拼接。")
                            .foregroundStyle(.secondary).lineSpacing(5)
                    }.padding(.vertical, 8)

                    statusCard
                    if let text = model.failure {
                        Label(text, systemImage: "exclamationmark.circle")
                            .font(.callout).foregroundStyle(.orange).padding()
                            .background(Color.orange.opacity(.08), in: RoundedRectangle(cornerRadius: 16))
                    }
                    if let text = model.notice { Text(text).font(.callout).foregroundStyle(.secondary) }

                    if let output = model.result {
                        resultView(output)
                    }
                    if model.frameCount > 0 {
                        DisclosureGroup("调整上下裁剪与起止画面", isExpanded: $showCrop) {
                            cropEditor.padding(.top, 14)
                        }.tint(blue)
                    }
                    if !model.busy {
                        Button {
                            if model.frameCount > 0 { confirmClear = true }
                            else { Task { await model.begin() } }
                        } label: {
                            Label(model.frameCount > 0 ? "开始下一次长截图" : "开始长截图", systemImage: "plus.viewfinder")
                                .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 10)
                        }.buttonStyle(.borderedProminent).tint(blue)
                        if model.frameCount > 0 {
                            Button("清除本次画面与临时长图", role: .destructive) { model.clear() }
                                .font(.footnote).frame(maxWidth: .infinity)
                        }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Label("怎么滚动更容易接上", systemImage: "hand.draw") .font(.subheadline.weight(.semibold))
                        Text("保持竖屏，只向一个方向慢慢滚动。每次移动不超过半屏，等待文字稳定。不要切换聊天或弹出键盘。")
                            .font(.footnote).foregroundStyle(.secondary)
                        Text("只采集屏幕图片，不采集声音，不连接服务器。采集期间可能包含通知内容，请先开启勿扰模式。")
                            .font(.footnote).foregroundStyle(.secondary)
                    }.padding().background(.white.opacity(.75), in: RoundedRectangle(cornerRadius: 18))
                }.padding(22)
            }
            .background(paper)
            .navigationTitle("长截图").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showShare) {
                if let output = model.result { ShareSheet(files: output.files) }
            }
            .sheet(item: $previewFile) { file in ImagePreview(url: file.url) }
            .confirmationDialog("开始下一次会清除本次临时画面。已保存到相册的长图会保留。", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("清除并开始", role: .destructive) { Task { await model.begin() } }
            }
            .onChange(of: model.failure) { _, error in if error != nil && model.frameCount > 0 { showCrop = true } }
            .onChange(of: model.crop) { _, _ in model.invalidateResult() }
            .onChange(of: model.firstFrame) { _, _ in model.invalidateResult(); model.updateSourcePreview() }
            .onChange(of: model.lastFrame) { _, _ in model.invalidateResult() }
        }
    }

    private var statusCard: some View {
        HStack(alignment: .top, spacing: 14) {
            if model.busy { ProgressView().tint(blue) }
            else { Image(systemName: model.result == nil ? "checkmark.shield" : "checkmark.circle.fill").foregroundStyle(blue) }
            VStack(alignment: .leading, spacing: 6) {
                Text(statusTitle).font(.headline)
                Text(statusDetail).font(.footnote).foregroundStyle(.secondary)
                if model.phase == .armed || model.phase == .capturing {
                    Button("结束采集并生成") { Task { await model.finish() } }.font(.subheadline.weight(.semibold))
                }
            }
            Spacer(minLength: 0)
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 18))
    }

    private var statusTitle: String {
        switch model.phase {
        case .ready: return "准备好后，开始采集"
        case .choosing: return "请在系统界面确认采集"
        case .armed: return "现在切到微信"
        case .capturing: return "正在收集滚动画面"
        case .processing: return "正在对齐并生成长图"
        case .review: return model.result == nil ? "检查滚动区域" : "长图已生成"
        }
    }
    private var statusDetail: String {
        switch model.phase {
        case .ready: return "免费功能，无需注册。保存时才申请添加到相册。"
        case .choosing: return "选择整个屏幕；系统采集提示会保留。"
        case .armed, .capturing: return "已收集 \(model.count) 个不同画面。回到本 App 自动结束。"
        case .processing: return "图像只在这部 iPhone 上处理。"
        case .review: return "\(model.frameCount) 个画面。导出前请检查文字和接缝。"
        }
    }

    private func resultView(_ output: StitchResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("\(output.width) × \(output.height) 像素 · \(output.files.count) 张").font(.subheadline.weight(.semibold))
            if output.files.count > 1 { Text("长图较长，已按顺序分成多张，保存时会一起导出。").font(.footnote).foregroundStyle(.secondary) }
            ForEach(output.files, id: \.self) { url in
                Button { previewFile = PreviewFile(url: url) } label: { OutputThumbnail(url: url) }
                    .buttonStyle(.plain)
            }
            Button { Task { await model.saveToPhotos() } } label: {
                Label(model.saving ? "正在保存…" : "保存到相册", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }.buttonStyle(.borderedProminent).tint(blue).disabled(model.saving)
            Button { showShare = true } label: {
                Label("分享／存到文件", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
            }.buttonStyle(.bordered).disabled(model.saving)
        }
    }

    private var cropEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("只保留会滚动的聊天内容，让固定顶栏、输入框和底部横条完全落在灰色区域内。")
                .font(.footnote).foregroundStyle(.secondary)
            if let image = model.sourcePreview {
                GeometryReader { proxy in
                    let height = proxy.size.height
                    let top = height * Double(model.crop.top) / max(1, model.previewFrameSize.height)
                    let bottom = height * Double(model.crop.bottom) / max(1, model.previewFrameSize.height)
                    ZStack(alignment: .top) {
                        Image(uiImage: image).resizable().scaledToFit()
                        VStack(spacing: 0) {
                            Color.black.opacity(.5).frame(height: top)
                            Rectangle().fill(blue).frame(height: 2)
                            Spacer(minLength: 0)
                            Rectangle().fill(blue).frame(height: 2)
                            Color.black.opacity(.5).frame(height: bottom)
                        }
                    }
                }
                .aspectRatio(model.previewFrameSize.width / max(1, model.previewFrameSize.height), contentMode: .fit)
                .frame(maxHeight: 440).frame(maxWidth: .infinity)
                .clipped().clipShape(RoundedRectangle(cornerRadius: 12))
            }
            cropSlider("顶部", value: $model.crop.top, other: model.crop.bottom)
            cropSlider("底部", value: $model.crop.bottom, other: model.crop.top)
            if model.frameCount > 1 {
                Stepper("起始画面：\(model.firstFrame + 1) / \(model.frameCount)", value: $model.firstFrame, in: 0...max(0, model.lastFrame))
                Stepper("结束画面：\(model.lastFrame + 1) / \(model.frameCount)", value: $model.lastFrame, in: model.firstFrame...max(model.firstFrame, model.frameCount - 1))
                Text("切换 App 或停止时出现过渡界面，可缩短起止范围再试。").font(.footnote).foregroundStyle(.secondary)
            }
            Button("重新生成") { Task { await model.generate() } }
                .buttonStyle(.borderedProminent).tint(blue).disabled(!model.canGenerate)
        }.disabled(model.busy)
    }

    private func cropSlider(_ name: String, value: Binding<Int>, other: Int) -> some View {
        let maximum = max(0, Int(model.previewFrameSize.height * .65) - other)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(name)：\(value.wrappedValue) 像素").font(.subheadline)
                Spacer()
                Button { value.wrappedValue = max(0, value.wrappedValue - 1) } label: { Image(systemName: "minus.circle") }
                Button { value.wrappedValue = min(maximum, value.wrappedValue + 1) } label: { Image(systemName: "plus.circle") }
            }.buttonStyle(.plain)
            Slider(value: Binding(get: { Double(value.wrappedValue) }, set: { value.wrappedValue = Int($0.rounded()) }), in: 0...Double(max(1, maximum)), step: 1)
                .tint(blue)
        }
    }
}

private struct OutputThumbnail: View {
    let url: URL
    @State private var image: UIImage?
    var body: some View {
        VStack(spacing: 8) {
            if let image { Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 430) }
            else { ProgressView().frame(height: 90) }
            Text("轻点查看完整长图").font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity).padding(10)
            .background(.white, in: RoundedRectangle(cornerRadius: 14))
            .task(id: url) {
                let cgImage = await Task.detached { ImageTools.thumbnail(url) }.value
                if let cgImage { image = UIImage(cgImage: cgImage) }
            }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let files: [URL]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: files, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

private struct ImagePreview: UIViewControllerRepresentable {
    let url: URL
    func makeCoordinator() -> Coordinator { Coordinator(url: url) }
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController(); controller.dataSource = context.coordinator; return controller
    }
    func updateUIViewController(_ controller: QLPreviewController, context: Context) {}
    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem { url as NSURL }
    }
}

private struct PreviewFile: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}
