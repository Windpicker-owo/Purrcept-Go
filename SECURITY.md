# 安全问题报告

[English](SECURITY.en.md)

不要在公开 Issue 或评论中提交密钥、配对邀请、设备令牌、真实聊天或完整诊断包。

## 私密报告

优先使用本仓库的 [Security Advisories](https://github.com/Windpicker-owo/Purrcept-Go/security/advisories)
私密表单；若没有该入口，先开一个只询问私密联系方式的 Issue，不附漏洞细节。
本文件不会自动启用 GitHub 私密报告功能。

说明版本、Android 版本、实际与预期行为、复现条件和影响范围。使用合成数据，
保留稳定错误码，避免真实凭据、截图正文或可访问私人设备的地址。凭据已泄漏时
先撤销相应服务权限。

## 范围与边界

当前范围为 Purrcept 安卓界面、原生 HTTPS/WSS、证书固定、Keystore 凭据、Room
持久缓存、无障碍读屏与明确授权的安卓操作。Engine 问题同时说明对应 Engine 版本。
旧 DSH 运行时、分享站点和 SDK 已移除，不属于当前应用。

测试真实手机或账号前取得所有者授权，不绕过 FLAG_SECURE、密码框或系统权限。
返回成功、手势回调和最终业务效果分别核对；未知结果不能自动重做。诊断信息
公开前人工检查，自动脱敏不能替代审阅。
