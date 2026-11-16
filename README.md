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
- 从 Engine 读取主体名字；主脑接手、真实思考和真实行动分别呈现，消息状态可展开最近执行回执。
- 首次引导、系统深色、大字体、减少动效，以及由真实状态驱动的 Purrcept 白猫。

这是一版开发实现。连续观察、聊天图片与语音、桌宠和主脑已读
回执尚未接入；真实 Android 权限、后台和操作效果仍需测试手机验收。

## 连接电脑

电脑端操作在 **Engine WebUI → 设备 → 连接安卓手机** 完成。

1. 首次未启用 Phone 时，展开「设置手机连接」，选择电脑地址和端口，预览并保存。
2. 正常重启 Engine 使新增插件或监听配置生效；原配置会备份，已有证书会保留。
3. 点击「显示配对二维码」，手机按首次引导扫码、核对电脑，再配对连接。
4. 邀请过期可在 WebUI 直接刷新，无需重启 Engine。已配对手机可以直接连接。

Go 只承担手机端扫码与连接，无需电脑端 Go 程序或手动输入 JSON。详见同级
[Engine 接入说明](../purrcept_engine/docs/phone.md)。扫码不依赖 Google Play；聊天
无需无障碍或设备操控，配对也不自动授予操控权限。

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
```

当前活跃 Dart 入口为 `app/lib/purrcept/`，Android 源集为
`app/android/app/src/purrcept/`。已移除未使用的 DSH 参考源码、运行时、市场、分享服务、模型和旧界面测试图。
需要查看上游实现时请使用 Git 历史；许可证与来源声明继续保留。

## 来源与许可证

本项目是 [ccch1mneyyy/dsh-Go](https://github.com/ccch1mneyyy/dsh-Go) 的修改版，
原作者为 [ccch1mneyyy](https://github.com/ccch1mneyyy)。Purrcept 改动包括
远程设备协议、原生服务、聊天入口和 Engine 接入。保留原 AGPL-3.0 及第三方
声明，见 [LICENSE](LICENSE) 与 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
Purrcept 应用使用自己的名称和图标，不使用 DSH 品牌或吉祥物。旧素材的授权
范围仍见 [ASSETS.md](ASSETS.md)。
