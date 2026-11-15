# Purrcept Phone v1

固定协议主版本 `v=1`。HTTPS 处理一次性配对、状态、分页和媒体；WSS 处理
聊天、同步及设备调用。身份错误、版本错误和超过64 KiB的帧均拒绝。

## 配对与认证

本地邀请为 `{v,url,certificate_sha256,invitation,expires_at}`。客户端以
`POST /phone/v1/pair` 提交 `{invitation,name}`，获得一次性响应中的
`{v,device_id,token}`。其他 HTTP 和 WebSocket 升级请求均带
`Authorization: Bearer ...`。令牌不放进 URL，不允许 HTTP 或跟随重定向。

二维码直接编码原邀请 JSON，不创建另一套配对协议。电脑展示工具只读该
文件；手机扫码后先校验结构并确认电脑，再走原 POST 配对。粘贴邀请使用
相同流程。手机本地时钟不决定邀请是否失效，最终由 Engine 核验。

## 信封

```json
{"v":1,"type":"hello","id":"frame-id","reply_to":null,"connection_id":null,"payload":{"through":0}}
```

服务端 welcome 分配本次 connection_id 并返回 server_time。之后每帧必须
带该连接身份。帧 id 只关联应答；message_id 和 command_id 才是业务身份。
服务端验证客户端恢复游标不超过本设备已有事件。

| 类型 | payload |
|---|---|
| `chat.submit` | `message_id,text,occurred_at`，发生时间必须带时区 |
| `chat.accepted` | `message_id,input_id,duplicate`，仅表示正式接管 |
| `sync.event` | `seq,type=chat.message,message_id,direction,text`，入站还含 input_id 和发生时间 |
| `sync.ack` | `through`，手机已落盘的连续前缀 |
| `device.state` | `control_allowed,accessibility`，只反映本机事实 |
| `device.command` | `command_id,control_session_id,operation,arguments,expires_at` |
| `device.result` | `command_id,state,data,error?`，state 为 confirmed/failed/unknown |
| `command.query` | `command_id`，只允许返回旧记录，缺失报告 unknown |
| `error` | `code`，业务拒绝不伪装成功 |

`direction=incoming` 表示用户发给 Engine；`outgoing` 表示主体向手机表达。
出站消息身份使用实际 call_id。事件按持久 seq 升序分页；设备归属过滤后
全局 seq 可能存在间隙，不能按整数差推断丢失消息。

命令不进入聊天补送流。expires_at 是服务端 Unix 秒，客户端以握手偏移
核验预算；不跨设备传递 asyncio 单调时钟。操作会话因断线、重启或本地
撤销失效。重连后旧命令只能查询；任何 unknown 都不能自动重新执行。

## HTTP

`GET /phone/v1/state` 读取当前状态；`GET /phone/v1/chat?after=0` 返回至多
100条事件。`POST /phone/v1/media` 接收至多8 MiB的完整 JPEG/PNG，验证实际
格式和尺寸后返回 media_id。`GET /phone/v1/media/{media_id}` 仅允许取本
设备上传的媒体。截图结果 data 包含 media_id、media_type、captured_at。

当前没有聊天附件、已读、语音或旧 DSH 协议兼容。

## 手机聊天状态

`chat.accepted` 和 `sync.event` 没有到达先后保证。手机将接管回执单独保存，
不删除原待发项；直到对应入站同步事件与游标同事务提交后才移除。已接管但
未同步的消息在重连时仍可提交原始 message_id、正文和 occurred_at，由
Engine 去重。展示字段、接管回执不能混入严格的 `chat.submit` 请求。

本地快照的 `delivery_state=pending` 表示手机已保存、尚无接管证明；
`accepted` 表示 Engine 已正式接管、手机尚未提交同步事件；`synced` 表示
事件已落盘。入站已同步消息显示 Engine 已接管，出站显示已同步到本机。
这些状态均不代表主脑已读或已经作答，协议尚无已读回执。

本地 `online_wanted` 表示用户希望设备在线，与 `phase=connecting/online/
reconnecting/offline` 的网络事实分开。重连期间可以关闭设备在线，终止
后续自动尝试；手动重连会取消尚未开始的重试定时器，不创建第二条连接。

## 结构快照与操作

`screen` 返回 `frame_id` 和有界可见树的 `element_id`。新 screen 会替换旧
快照；截图不会替换。`tap`、`input_text` 和 `swipe` 执行前重读并比对当前
树；窗口切换、当前窗口滚动、中断或已接受的界面操作也会撤销快照。
内容事件本身不撤销，实际树发生变化才拒绝。失败仍使用 `stale_frame`，
调用方应重新读取 screen，根据新元素决定操作，不能原样自动重试旧命令。
本地比对覆盖已遍历树，不能为截断部分或 Android 渲染提供原子性保证。
`stale_frame` 回执的 `data.stale_reason` 区分 `frame_missing`、
`frame_replaced`、`tree_changed`、`window_changed`、`window_scrolled`、
`operation_accepted`、`service_interrupted` 和 `service_stopped`；只记录
失效原因，不附带界面正文。这些诊断不改变失败状态或允许自动重试。
