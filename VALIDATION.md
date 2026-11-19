# 验证记录

日期：2026-11-19。当前环境：Windows，缺少 Xcode / Apple SDK。

## 已运行

- 直接编译 App 中实际使用的 `Core/SSMatcher.c`，不是另写算法模拟。
- GCC C11 / `-O2 -Wall -Wextra -Werror` 编译通过。
- 在现有 Ubuntu GCC 上运行同一组 26 个案例，AddressSanitizer / UndefinedBehaviorSanitizer / 内存泄漏检测均通过。
- 26 个原生核心案例通过：多种滚动距离精确对齐、轻度噪声、重复画面、空白静止画面、无关画面拒绝、反向滚动拒绝、重复纹理歧义拒绝、微信式稀疏文字、连续多帧逐行重建、固定 120px 顶栏与 180px 底栏识别及裁剪后拼接、非法尺寸、采集等待与前后台门控、帧数和内存边界及溢出保护。
- 工程结构检查覆盖对象引用、全部源码入工程、资源存在、iPhone/iOS 27 配置、plist、采集后台模式、权限及隐私声明、没有视频写入/WebView/网络路径。

## 已编写，待 Apple 环境运行

`tests/ScrollshotTests.swift`：

1. CGImage → 灰度适配是否保留顶到底行顺序。
2. 整个 Swift 规划器与 PNG 渲染是否还原连续行、没有翻转或接缝错位。
3. 缺少重叠、非法裁剪必须拒绝导出。
4. 短暂坏画面可以恢复；无法接上的末尾必须提示错误。

## 尚未验证，不能视为已完成

- Xcode 编译、链接、Apple SDK 可用性及 Swift 诊断。
- 上述 4 个 iOS XCTest。
- iPhone 17 Pro Max / iOS 27.2.1 的系统采集授权与后台回调。
- 系统终止、返回 App 时的真实时序，以及 App 切换动画是否完全排除。
- 实际微信页面的自动固定区域识别和文字接缝。
- 真机方向信息、色彩、可读性、PNG 预览、相册保存与分享。
- 内存、温度与长时间采集；内存上限统计不包含系统额外缓冲和渲染上下文。
- 免费 Personal Team 是否可签发 Screen Recording entitlement，以及可执行的 Windows 签名安装路线。
- GitHub 云构建和 IPA 产物。

不会把 Windows 算法通过写成“手机 App 已可用”。
