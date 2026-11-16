# 参与贡献

[English](CONTRIBUTING.en.md) · [项目首页](README.md)

## 暂不接受外部 Pull Request

本仓库暂不接受外部 Pull Request。请通过 [Issue](https://github.com/Windpicker-owo/Purrcept-Go/issues)
反馈问题或建议。维护者及其代理的内部改动遵守 AGENTS.md，后续工作直接在同步后的 main 上进行。

## 开发环境与边界

使用 Flutter 3.50 / Dart 3.14、JDK 17+、Android SDK 36，最低 Android 11。
主体运行在 Purrcept Engine；手机只持有设备连接、聊天缓存和明确授权的安卓能力。
当前源码在 app/lib/purrcept 与 app/android/app/src/purrcept。未使用的 DSH 源码、
模型、运行时、SDK、网站和测试图片已清理，历史实现仍可从 Git 查看。

提交标题和正文使用中文。只暂存明确路径，不提交运行数据、配对邀请、令牌、
签名私钥或 APK。保留 LICENSE、ASSETS.md、THIRD_PARTY_NOTICES.md 中的来源和许可。

## 修改与验证

协议行为同时核对 Engine。文案改 app/lib/purrcept/l10n 的中英文 ARB，再运行
flutter gen-l10n；Token 改 design/purrcept-cel.tokens.json，再运行生成器。
不要直接修改生成结果。行为变更更新契约和必要测试，文档与注释必须匹配实现。

```sh
python tooling/export_cel.py --check
python -m unittest discover -s tooling -p test_phone_eval.py
cd app
flutter pub get
flutter gen-l10n
flutter analyze --no-fatal-infos
flutter test
flutter build apk --debug --target-platform android-arm64
cd android
./gradlew :app:testDebugUnitTest --console=plain
```

CI 使用合成数据，不操控手机或真实账号。真机权限、后台恢复和操作效果须另行授权
验证，桌面测试不能替代；未执行的检查注明原因。覆盖安装需保持签名一致，签名
冲突时保留已有应用和数据，先核对证书。正式分发前配置自己的发布签名。

报告问题时说明版本、Android 版本、连接步骤、错误提示和可重复的操作。隐私与
安全问题按 [SECURITY.md](SECURITY.md) 私密报告。
