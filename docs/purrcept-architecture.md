# Purrcept Go 架构

主体只在电脑的 Purrcept Engine 中运行。手机是聊天入口和显式授权的设备执行端。
本仓库继承 dsh-Go 的 Flutter/Android 工程，未接入的上游源码已清理；旧实现
可从 Git 历史查阅。当前应用不包含 DSH 运行时或上游在线服务。

## 活跃入口

| 位置 | 所有权 |
|---|---|
| `app/lib/main.dart`、`app/lib/purrcept/` | Flutter 页面、本地状态投影和中英文文案 |
| `app/android/app/src/purrcept/` | Kotlin 服务、Room 缓存、Keystore 凭据和 Android 执行 |
| `app/android/app/src/main/AndroidManifest.xml` | 标准 Flutter/Android 入口清单 |
| `app/android/app/build.gradle.kts` | 只打包 Purrcept 源集，Android 11+ |
| `design/purrcept-cel.tokens.json` | 来自 purrcept_design 的固定 Token 输入 |
| `tooling/export_cel.py` | 生成 Flutter Token 映射 |
| `app/test/purrcept/` | 当前应用交互测试 |

原有 `app/lib/` 其他目录、原生 `src/main/` 业务源码和旧界面测试已移除。
Flutter 仍在 `src/main/java/io/flutter/plugins` 生成插件注册器，该生成路径
保留在构建源集中。当前应用没有 DSH 产品模式。

## 资源生命周期

DeviceService 的单线程执行器拥有 Room 和唯一 OkHttp WSS。CommandLane 独占
有界 Android 等待与图片上传，期间状态查询、聊天收发和撤销仍由原线程推进。
命令先落盘再跨线程派发，一次只接收一个 Android 操作；重叠调用明确报告
`device_busy`，不在等待队列中暗中积压。完成回到状态线程落盘，再发送真实回执。
重连后的旧命令查询若仍在同一次 Android 等待中，会在真实回执落盘后回答；
查询不提前固化临时 unknown，也不重新派发。关闭时先撤销资格，等待已接受工作
归还后再关闭 Room。Activity 绑定服务，
页面只通过 `purrcept/device` 发本地请求，通过事件通道得知需要刷新；事件
不携带权威聊天正文，UI 总是查询已提交缓存。用户开启设备在线后服务显示
前台通知，强制停止后不承诺继续在线。进程重启不恢复操控授权。
只读 snapshot 不发送变更通知，避免事件与查询互相触发无限刷新。

配对时通过本地邀请同时固定主机和完整证书 SHA-256。长期凭据用 Keystore
加密后保存，不进入 Flutter。网络断开即撤销 control_session；自动重连
只恢复消息同步。手机本地停止操控先清除易变操作资格，再排队通知电脑。

配对默认由本机相机扫描。MainActivity 以 Activity Result 契约借用独立扫码
Activity，只返回邀请文字，不保存相机图片。Flutter 对扫码或粘贴结果做有界
结构校验并展示目标电脑，用户确认后才调用原生配对；成功后自动开启在线。
原生仍负责 HTTPS 固定证书校验和凭据持久化，扫码不能绕过信任边界。
电脑端配对由 Engine WebUI 直接借用当前 Phone 监听器。Go 不提供电脑端
配对程序或邀请文件观察器；普通查询不续期，明确点击才生成新的两分钟窗口。

聊天由 ChatJournal 保存 message_id 再发送，重试沿用正文和发生时间。
chat.accepted 只另存接管回执，不能删除待发正文或移动同步游标；否则同步
事件迟到时气泡会消失。接收消息、删除对应待发项与回执、推进游标在 Room
同事务提交后才发确认。事件先于接管回执到达时，忽略迟到回执，不复活待发项。
界面状态区分手机已保存、Engine 已接管等待同步、已同步；均不证明主脑已读。
EngineExperience 持有本连接的有限实时状态，断线立即清空，只单独保留公开名字。
ChatJournal 按确切 input_id 缓存处置版本和最近一次行动摘要，只有确切 turn_id
才能将单条气泡与实时思考或行动关联。详见通信协议的 engine.state 契约。

首次引导进度由 Room 元数据保存；配对成功进入可跳过的通知与无障碍说明，
不因配对或开启在线自动申请通知、不自动授权操控。已存在配对且没有引导元数据
的用户直接进入聊天。忘记配对同时清除引导与名字。
命令先写 running 再调用 Android；
旧 running 在进程恢复时转为 unknown，不得再次执行。命令查询只回记录。

截图和手势通过无障碍服务实施。元素身份属于某次界面快照；窗口切换、
当前窗口滚动、中断和已接受的界面操作会撤销快照。普通内容通知不直接
撤销，执行前在主线程重读有界可见树，比对窗口、节点路径、完整内容摘要、
控件身份、状态和几何，再使用本次读取的节点。无障碍节点不跨调用缓存。
比对失败返回 stale_frame，必须重新读取 screen 并决定下一步，不自动重做。
截断快照只能校验已遍历的部分；Android 树读取与应用渲染也不是原子事务，
不能把本地校验视为系统级原子操作保证。截图通过 HTTPS 上传，WebSocket
只传媒体身份；截图不会更新结构快照。

协议与 Engine 配置见同级 `purrcept_engine/docs/phone.md` 和本仓库
`docs/purrcept-protocol.md`。

## 本轮尚未接入

连续观察、聊天附件与语音、桌宠、主脑主观已读回执，以及 Shizuku、
ADB 和后台虚拟显示。旧实现仅是后续移植参考，不应直接恢复其 DSH 通信。

## 电脑端设置与配对

设置与二维码统一位于 Engine WebUI 的设备页。设置只编辑 CLI 的当前配置，
先预览再保存并备份；插件和监听配置在正常重启后生效。二维码从运行中 Phone
插件的独立本机配对端口取得，过期可以直接刷新，不再依赖 Go 的工具或 Tk 窗口。
