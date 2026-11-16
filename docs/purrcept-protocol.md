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

## 信封与富媒体协商

```json
{"v":1,"type":"hello","id":"frame-id","reply_to":null,"connection_id":null,"payload":{"through":0}}
```

服务端 welcome 分配本次 `connection_id` 并返回 `server_time` 与 `features`
（如 `["engine_state", "rich_chat"]`）。之后每帧必须带该连接身份。帧 `id`
只关联应答；`message_id` 和 `command_id` 才是业务身份。

| 类型 | payload |
|---|---|
| `chat.submit` | 必选 `message_id,text,occurred_at`（带时区）；当 `welcome.features` 含 `rich_chat` 时可选携带 `kind`（`text/sticker/voice/image`）、`sticker_id`、`media_id`、`media_type`、`duration_ms`、`waveform`、`reply_to_id` |
| `chat.accepted` | `message_id,input_id,duplicate`，仅表示正式接管 |
| `sync.event` | `seq,type=chat.message,message_id,direction,text`，入站含 `input_id` 与 `occurred_at`；存在贴纸/语音/图片/引用时同步携带对应富媒体元数据 |
| `sync.ack` | `through`，手机已落盘的连续前缀 |
| `device.state` | `control_allowed,accessibility`，只反映本机事实 |
| `device.command` | `command_id,control_session_id,operation,arguments,expires_at` |
| `device.result` | `command_id,state,data,error?`，state 为 confirmed/failed/unknown |
| `command.query` | `command_id`，只允许返回旧记录，缺失报告 unknown |
| `error` | `code`，业务拒绝不伪装成功 |

当服务端未在 `welcome.features` 中宣告 `rich_chat` 时，手机自动在网络层将
`chat.submit` 裁剪为严格的 `{message_id, text, occurred_at}` 三字段以保证旧版
向后兼容，同时在手机侧路记录（`rich:<message_id>`）保留本地图片、贴纸、录音文件与引用展示。

## HTTP 媒体与语音

`GET /phone/v1/state` 读取当前状态；`GET /phone/v1/chat?after=0` 返回至多
100条事件。`POST /phone/v1/media` 接收至多 8 MiB 的完整图片（JPEG/PNG/WEBP/GIF）
或语音音频（自动校验并归一化为 16 kHz 单声道 PCM16 WAV），验证实际内容后返回
`{media_id, media_type, duration_ms?}`。`GET /phone/v1/media/{media_id}` 仅允许
读取本设备归属的媒体及 Bot 当前公开头像，不允许浏览 Bot 贴纸库。

已协商 `rich_chat` 的附件必须先上传成功，再将返回的媒体身份持久保存并提交
`chat.submit`。上传被拒或本地文件丢失时，原待发消息保留，不能提交纯文本替代。
手机分别显示 `media_upload_failed`、`media_missing`；连接恢复或明确点击
「重试附件传输」时沿用原 `message_id` 再尝试一次。

同步事件与游标仍先同事务提交。下载失败显示 `media_download_failed`，已提交的
消息本身保存待下载媒体身份；重连或手动重试会扫描这些消息，补齐缺失的本地文件。
只有完整下载并写入后才发布 `local_path`，不通过回退游标或重复接收事件来重试。
`waveform` 在网络中为至多 64 项的 JSON 数组，每项必须是 0..100 的整数。

## 用户收藏与 Bot 贴纸库

APP 的「我的收藏」是手机用户的私人收藏，保存在 Room 的 `favorite_sticker` 行和
应用本地图片目录中。添加、重命名及删除不访问 Engine，可以离线完成。发送收藏时
通过普通聊天附件上传取得媒体身份；本地贴纸 ID 不授予访问 Bot 库的资格。
删除只移除收藏关系，待发消息和历史仍使用的图片保留。12 款内置图案仍是客户端资产。

Bot 的 `me.stickers` 库由 Engine 保存，QQ 与手机的 Bot 发言共用该库；向手机发送
使用 `me.phone.chat.send(sticker_id=...)`。协议不提供手机浏览、添加或删除 Bot 收藏的
HTTP 接口，也不推送 Bot 目录。用户收藏不自动进入 Bot 库。

## Bot 头像同步

`me.phone.chat.set_avatar(media_id=...)` 使用宿主已经读取或接管的真实图片设置 Bot
在 APP 中的头像；传 `None` 或省略参数恢复默认。PNG、JPEG、WebP、GIF 必须有效，
不超过 8 MiB 与 3200 万像素。设置在 Engine 同库提交，返回 `delivery_state=queued`
表示待同步，不证明手机已显示；不要求在线或开启操控会话。

`engine.state.avatar` 为 `null` 表示 Bot 从未设置；否则为
`{media_id,media_type,revision}`。明确恢复默认时前两项为 `null`，版本仍递增。
每次显式设置递增版本，同图重设也能覆盖手机上随后修改的头像。
客户端通过认证媒体接口下载图片，完整写入后同事务提交 profile 与已应用版本；
失败保留旧头像与版本，重连、后续状态更新或手动重试附件时重新下载。
只允许认证手机下载 Bot 当前公开头像和已授权的聊天附件，不能猜摘要读取其他媒体。
用户头像与昵称仍由手机本地拥有，不混入 `chat.submit`，不改变主脑身份认证。

## 手机聊天状态

`chat.accepted` 和 `sync.event` 没有到达先后保证。手机将接管回执单独保存，
不删除原待发项；直到对应入站同步事件与游标同事务提交后才移除。已接管但
未同步的消息在重连时仍可提交原始 `message_id`、正文和 `occurred_at`，由
Engine 去重。本地路径（`local_path`）与引用预览文案严禁混入 `chat.submit`。

本地快照的 `delivery_state=pending` 表示手机已保存、尚无接管证明；
`accepted` 表示 Engine 已正式接管、手机尚未提交同步事件；`synced` 表示
事件已落盘。入站已同步消息显示 Engine 已接管，出站显示已同步到本机。

## 结构快照与操作

`screen` 返回 `frame_id` 和有界可见树的 `element_id`。新 `screen` 会替换旧
快照；截图不会替换。`tap`、`input_text` 和 `swipe` 执行前重读并比对当前
树；窗口切换、当前窗口滚动、中断或已接受的界面操作也会撤销快照。失败仍使用
`stale_frame` 并附 `data.stale_reason`，调用方不得原样自动重试旧命令。

## 主体名字与真实进度

`welcome.payload.features` 包含 `engine_state` 时，服务端独立发送
`engine.state`（含 `subject_name`、`avatar`、`host_phase`、`activity` 与最近 24 条本设备
入站消息处置阶段）。手机断线立即清除实时活动，仅保留已验证的主体公开名字与已确认历史处置。
