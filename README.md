# Purrcept Go

[English](README.en.md) · [架构](docs/purrcept-architecture.md) · [通信协议](docs/purrcept-protocol.md)

Purrcept Engine 的安卓手机设备与聊天入口。**主体运行在电脑，手机不运行
Purrcept 或模型。** 用户消息成为主体刺激，主体通过显式聊天能力回应或主动
发言；授权后，主脑也可以显式连接手机、读取界面和执行基础操作。

## 当前实现

- 手机与电脑通过证书固定的 HTTPS/WSS 配对和连接。
- 文字聊天先落盘再发送；断线补送按稳定身份去重。
- Kotlin 前台服务持有网络和 Room，Flutter 只呈现已提交状态。
- 操作会话与聊天独立；断线和本地停止撤销操控资格。
- 界面结构、截图、元素点击、文字输入、滑动、应用启动和系统按键。
- 命令执行前记录意图；未知结果不自动重做。
- 聊天区分手机已保存、Engine 已接管和已同步；离线消息自动补送，接管回执先到时气泡不会消失。

这是一版开发实现。连续观察、聊天图片与语音、桌宠和主脑已读
回执尚未接入；真实 Android 权限、后台和操作效果仍需测试手机验收。

## 连接电脑

电脑使用同级 `purrcept_engine` 的 `phone` extra，按
[`docs/phone.md`](../purrcept_engine/docs/phone.md) 创建 TLS 身份并配置 Phone
插件。启动 Engine 并开启 Phone 配对后，在本仓库根目录运行：

```powershell
uv run tooling/pair_phone.py
```

电脑浏览器会打开本机二维码窗口。手机点击“扫码配对”，确认电脑地址和
证书指纹，再点击“配对并连接”，无需手动输入 JSON。相机只在扫码时申请
权限；取消扫描或取消确认不会配对。扫码不依赖 Google Play 服务。
仅聊天无需开启无障碍或设备操控，配对也不会自动授予这些权限。

工具默认读取同级 `purrcept_engine/.purrcept/phone-invitation.json`，自定义
位置使用 `--invitation <路径>`。邀请有效120秒，过期需重新开启 Engine 的
配对窗口；二维码页面会跟随文件更新并撤下已过期或已消费的邀请。工具只读
现有邀请，不启动或修改 Engine。保持工具运行，结束时按 Ctrl+C。
无法扫码时，可展开手机的“其他方式：粘贴邀请”，使用剪贴板或粘贴原邀请。

## 构建和验证

使用 Flutter 3.50.0 / Dart 3.14，JDK 17+，Android SDK 36。最低 Android 11。
构建不需要 Ubuntu、PRoot、Node、DSH 运行时或上游服务凭据。

```powershell
cd app
flutter pub get
flutter analyze --no-fatal-infos
flutter test test/purrcept
flutter build apk --debug --target-platform android-arm64
cd android
.\gradlew.bat :app:testDebugUnitTest --console=plain
```

调试产物是 `app/build/app/outputs/flutter-apk/app-debug.apk`，仅用于开发。
Flutter 3.50 的标准本地化生成器仍引用已弃用的 SDK 本地化类，分析器会报告
相关 info；检查保留这些提示，错误和警告仍使验证失败。
正式分发需要配置自己的发布签名。不要卸载已有应用来解决签名冲突。

元素操作会在执行前重新比对界面。无变化的内容通知不会清除快照；窗口
切换、滚动和已接受的操作会撤销快照，下一步需重新读取 `screen`。
本地 JVM 测试覆盖快照替换、撤销和变化拒绝；真机效果仍需安装新包复测。

视觉 Token 固定自 Purrcept Design，更新输入后执行：

```powershell
python tooling/export_cel.py
python tooling/export_cel.py --check
uv run --with qrcode==8.2 python -m unittest discover -s tooling -p test_pair_phone.py -v
```

当前活跃 Dart 入口为 `app/lib/purrcept/`，Android 源集为
`app/android/app/src/purrcept/`。旧 DSH 源码保留作移植参考，已移出新应用
依赖和构建源集；旧运行时、市场、分享和统计服务不会随新应用启用。

## 来源与许可证

本项目是 [ccch1mneyyy/dsh-Go](https://github.com/ccch1mneyyy/dsh-Go) 的修改版，
原作者为 [ccch1mneyyy](https://github.com/ccch1mneyyy)。Purrcept 改动包括
远程设备协议、原生服务、聊天入口和 Engine 接入。保留原 AGPL-3.0 及第三方
声明，见 [LICENSE](LICENSE) 与 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
Purrcept 应用使用自己的名称和图标，不使用 DSH 品牌或吉祥物。旧素材的授权
范围仍见 [ASSETS.md](ASSETS.md)。
