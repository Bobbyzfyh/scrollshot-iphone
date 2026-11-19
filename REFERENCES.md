# 原生接口与安装依据

核实日期：2026-11-19。

- [Apple：Capturing screen content on iOS](https://developer.apple.com/documentation/screencapturekit/capturing-screen-content-on-ios)：iOS 27+、系统选择器、全屏采集、后台 `screen-capture` 模式、原始图片回调。
- [Apple 官方示例下载](https://docs-assets.developer.apple.com/published/91f0562d72a9/CapturingScreenContentInIOS.zip)：对照 Swift 委托签名与 `com.apple.developer.screen-recording` entitlement。原始下载留在本地忽略目录 `reference/`，不包含于交付源码包。
  - 系统选择器与委托调用方式参考该示例，保留其许可于 `APPLE-SAMPLE-LICENSE.txt`。没有包含其视频录制、摄像头或音频实现。
- [ScreenCaptureKit](https://developer.apple.com/documentation/screencapturekit)：开始前必须经用户授权；不需要旧式广播扩展。
- [SCContentSharingPickerObserver](https://developer.apple.com/documentation/screencapturekit/sccontentsharingpickerobserver)：选择、取消、错误处理。
- [videoOrientation](https://developer.apple.com/documentation/screencapturekit/scstreamframeinfo/videoorientation)：图片方向遵循 `CGImagePropertyOrientation`。
- [Apple：Developer account overview](https://developer.apple.com/help/account/basics/about-your-developer-account)：免费 Personal Team 描述文件 7 天期限，能力存在限制。
- [Apple：Supported capabilities](https://developer.apple.com/help/account/reference/supported-capabilities-ios)：签名能力依会员类型变化，需真实 Team 验证本项目的采集权限。
- [Apple：Required-reason API](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)：时间间隔计时使用 `35F9.1`，不发送到设备外。
- [GitHub：Xcode 27 runner](https://github.blog/changelog/2026-10-15-xcode-27-runner-image-generally-available/)：已提供 `xcode-27` runner 标签。
- [GitHub：Actions billing](https://docs.github.com/en/actions/concepts/billing-and-usage)：标准公共仓库 runner 与私有仓库额度的差异。

拼接核心为第一版已有自研实现的 C 移植，没有引入 `bikerr/stitching` 的 Python/OpenCV 代码或依赖。
