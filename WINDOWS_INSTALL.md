# Windows 安装说明（待签名能力验证）

本工程的 IPA 尚未获得可在 iPhone 上安装的苹果开发签名。点开 IPA 文件不会自动安装。当前也没有 App Store / TestFlight 分发。

下面是可尝试的免费个人签名路线，不代表本项目的屏幕采集 entitlement 已通过免费账号验证。

## 准备条件

- Windows 电脑、iPhone 数据线、解锁的 iPhone。
- 一个你自己控制的 Apple 账号；账号及密码只在官方安装工具的本机界面输入，不要发到聊天或上传 GitHub。
- [AltStore 官方 Windows 安装说明](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows)。从该页面获取 AltServer 和它所要求的 Apple 驱动组件，不使用搜索广告中的仿冒安装器。
- 本工程构建得到的 `Scrollshot-unsigned.ipa`。

## 尝试安装

1. 依据 AltStore 官方指南安装 AltServer 及相应 Apple 组件。
2. 用数据线连接 iPhone，解锁后在手机上确认“信任这台电脑”。
3. 在 Windows 的 AltServer 菜单选择安装 AltStore 到这部 iPhone。账号验证需你自己在本机完成。
4. 在手机按系统要求信任自己的开发者账号，并开启“设置 → 隐私与安全性 → 开发者模式”。
5. 将 IPA 放进 iPhone 的“文件”，在 AltStore 的 My Apps 页用加号选取 IPA，尝试用自己的账号签名安装。

AltStore 是安装工具。安装成功后主屏幕会出现独立的“长截图”App，日常拼图不需要打开网页、Scriptable 或 AltStore。

## 如果出现权限或安装错误

此项目所需的 Screen Recording entitlement 必须在苹果签发的描述文件中获准。若提示 entitlement、provisioning profile 或 Team 不支持等错误，请保留完整错误文字以便判断。**不能通过删掉必要 entitlement 就宣称功能可用，也不需要购买来历不明的证书。**

即使安装成功，首次跨 App 采集、微信滚动拼接、方向及相册保存仍需在你的 iPhone 上验证。

## 离线与有效期

- 有效签名期间，屏幕图片在 iPhone 本地处理，无需网站或联网上传。
- 苹果免费 Personal Team 一般采用 7 天有效期，需要定期经电脑续签，过期后 App 不能继续打开。
- 安装和续签需要连接苹果服务；“离线拼图”不意味着免费签名永久有效。

依据：[AltStore Windows 指南](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows)、[Apple Personal Team 限制](https://developer.apple.com/help/account/basics/about-your-developer-account)、[Apple 签名与权限说明](https://developer.apple.com/documentation/technotes/tn3125-inside-code-signing-provisioning-profiles)。
