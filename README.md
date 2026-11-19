# 长截图 · iPhone 原生版 2.0

为 iPhone / iOS 27+ 准备的 SwiftUI 原生工程。确认系统屏幕采集后，切到微信手动向下滚动，返回长截图 App，结束采集并在本机生成 PNG。

**Xcode 27.1 的 iPhone / arm64 目标已编译通过。当前工程尚未在 iPhone 真机测试，也未取得可在手机上安装的苹果开发签名。** Windows、Ubuntu 和 Mac 已运行共享 C 拼接核心测试，iOS 图片适配与渲染测试另见验证记录。

第一版网站与 Scriptable 离线版均保留在原目录。

## 设计的使用流程

1. 打开原生 App，点“开始长截图”。
2. 在 iOS 系统界面确认采集整个屏幕。系统提示与采集指示会保留。
3. 切到微信，停留约 2 秒，再缓慢向下滚动。相邻画面保留超过半屏重叠。
4. 回到长截图 App，自动停止采集、识别固定栏并拼接。也可通过系统采集界面停止后返回 App。
5. 检查预览、上下裁剪和文字接缝，再点“保存到相册”，或“分享／存到文件”。

如果无法自动识别固定栏，会显示完整屏幕预览和逐像素裁剪控件。固定顶栏、输入框、底部横条要全部排除；起止画面选择用于去掉切换 App 时的过渡界面。没有可靠接缝时不会导出猜测的结果。

## 实现范围

- 单个原生 App，iPhone 专用，最低 iOS 27.0；无需网页或 Scriptable 容器。
- 使用 ScreenCaptureKit 的系统内容选择器及 `.screen` 图片回调，不添加视频录制输出。
- 不调用摄像头或麦克风；不采集声音。
- 默认输出宽度 1080 像素，最多约每秒 5 张不同屏幕图片，采集时仅保留 JPEG 图片和匹配缩略数据于内存。
- 进入后台后等待 1.2 秒，减少切换 App 动画干扰；进入本 App 前台立即关闭接收并结束。
- 最多 320 个不同画面 / 96 MiB 图片与灰度缓存 / 约 90 秒，先达到哪个上限就停止，并保留提示。
- 单次结果最多 6400 万像素；每张 PNG 控制在 800 万像素 / 10000 像素高以内，较长结果按序分图。
- PNG 临时文件仅写入 App 自己的临时目录，开启文件保护、排除备份；清除、本次重新生成或下次启动时删除相应临时输出。
- 只有点击保存才请求“添加到相册”，不要求读取整个相册。不上传图片；项目不包含网络请求、分析 SDK 或远程依赖。

采集范围由系统授权决定，期间可能包含通知或其他 App 画面。建议先开勿扰，保持同一个竖屏聊天页面，不反向滚动，不弹出键盘。旋转、受保护内容、非常快速滚动和后台运行行为仍需真机验证。

## 只有 Windows，如何继续

Windows 不能运行 Xcode。经你授权，源码已上传公开仓库 [Bobbyzfyh/scrollshot-iphone](https://github.com/Bobbyzfyh/scrollshot-iphone)，云端构建使用免费的公开仓库标准 `xcode-27` runner。只上传了代码、图标与说明，没有上传聊天画面、Apple 凭据或证书。

`.github/workflows/ios-build.yml` 只手动触发，不自动发布。产物名含 `UNSIGNED`，仅带本地 ad-hoc 签名以保留屏幕采集权限声明；它没有苹果开发证书签名或有效描述文件，**不能直接安装**。App 使用 `com.apple.developer.screen-recording` 权限，该权限能否由你的账号签发必须验证，不能承诺免费个人签名一定支持。

GitHub 公共仓库上的标准 runner 可免费使用；当前仓库采用该方式，不使用 `xlarge`。

普通免费 Personal Team 的开发描述文件通常在 7 天后过期，需要重新签名安装；它不能提供永久有效的免费安装。请不要购买第三方企业证书来解决本工程的验证问题。

后续 Windows 安装路线见 [WINDOWS_INSTALL.md](WINDOWS_INSTALL.md)。AltStore 只负责安装与续签，App 实际运行不依赖网页或 Scriptable。签名有效期内，图像处理可断网使用；免费签名续期仍需电脑与网络。

## 有可用 Mac 时

需要含 iOS 27 SDK 的 Xcode，以及 iOS 27+ 真机。

1. 打开 `Scrollshot.xcodeproj`。
2. 选择 `Scrollshot` target，在 Signing & Capabilities 中选择自己的 Team，把 Bundle Identifier 改为自己唯一的标识。
3. 保留 Screen Recording entitlement 和 `screen-capture` 后台模式。
4. 连接并信任 iPhone，按系统要求开启开发者模式，再在 Xcode 选择真机运行。
5. 如果 Xcode 提示 Team 不支持屏幕采集权限，需要先解决苹果签名能力；删掉 entitlement 并不能证明采集功能正常。

无签名的编译检查：

```sh
bash scripts/verify-apple.sh
```

运行图像适配与渲染测试时，先 `xcrun simctl list devices available`，选择 iOS 27 模拟器 UUID：

```sh
IOS_SIMULATOR_ID=你的模拟器UUID bash scripts/verify-apple.sh
```

生成仅供后续签名的无签名包：

```sh
bash scripts/build-unsigned.sh
```

## 在 Windows 验证已共享到 App 的算法

使用现有 GCC 与 Python，无需第三方库：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/test-core.ps1
```

工程文件可通过 `python scripts/make-project.py` 重建。图标已生成，重建图标脚本需要 Pillow；编译 App 不需要 Python 或 Pillow。

模拟器没有 ScreenCaptureKit；项目只在模拟器使用明确标注的界面适配层，不模拟采集成功。图像测试运行与真机相同的 `ImageTools`、`StitchService` 和 C 核心。更多边界见 [VALIDATION.md](VALIDATION.md)，官方依据见 [REFERENCES.md](REFERENCES.md)。
