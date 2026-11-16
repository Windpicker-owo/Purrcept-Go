// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class PhoneL10nZh extends PhoneL10n {
  PhoneL10nZh([String locale = 'zh']) : super(locale);

  @override
  String get online => '在线';

  @override
  String get offline => '离线';

  @override
  String get connectionError => '连接需要处理';

  @override
  String get chat => '聊天';

  @override
  String get device => '设备';

  @override
  String get pairTitle => '连接你的 Purrcept';

  @override
  String get pairDescription => '在电脑打开手机配对二维码，用手机扫描即可连接。主体始终运行在你的电脑上。';

  @override
  String get scanPair => '扫码配对';

  @override
  String get scanning => '扫码窗口已经打开。';

  @override
  String get scanDescription => '相机仅用于读取邀请。确认电脑后会自动连接，设备操控仍保持关闭。';

  @override
  String get manualPairing => '其他方式：粘贴邀请';

  @override
  String get pasteInvitation => '粘贴邀请';

  @override
  String get confirmPairing => '确认你的电脑';

  @override
  String get pairAndConnect => '配对并连接';

  @override
  String confirmHost(String host) {
    return '将此手机连接到 $host？';
  }

  @override
  String get verifyComputer => '请仅扫描自己电脑上显示的二维码，也可核对下方证书指纹与电脑端是否一致。';

  @override
  String get certificateFingerprint => '证书指纹';

  @override
  String get openSourceLicenses => '开源许可';

  @override
  String get cameraPermissionError => '相机权限未开启。可到系统设置允许访问相机，或使用粘贴邀请方式。';

  @override
  String get invitation => '配对邀请';

  @override
  String get pair => '配对手机';

  @override
  String get connect => '连接';

  @override
  String get offlineHint => '连接 Engine 后会同步消息。';

  @override
  String get emptyChat => '从这里，继续你们的对话。';

  @override
  String get you => '你';

  @override
  String get pending => '已保存在手机 · 等待 Engine 接管';

  @override
  String get messageHint => '一个念头、一个问题，或说说今天…';

  @override
  String get send => '发送';

  @override
  String get connecting => '连接中';

  @override
  String get reconnecting => '重连中';

  @override
  String get reconnect => '立即重连';

  @override
  String get connectingHint => '正在连接 Engine，已保存的消息会自动同步。';

  @override
  String get acceptedPending => 'Engine 已接管 · 等待同步';

  @override
  String get engineAccepted => 'Engine 已接管';

  @override
  String get receivedOnPhone => '已同步到本机';

  @override
  String get networkError => '连接已中断，已保存的消息会在重连后补送。';

  @override
  String get authenticationError => 'Engine 拒绝了当前配对，请先在电脑检查配对状态，再重新配对。';

  @override
  String get protocolError => '手机与 Engine 通信异常，请检查两端版本后重新连接。';

  @override
  String get invitationError => '邀请内容无效，请粘贴 Engine 生成的完整邀请。';

  @override
  String get messageTooLarge => '消息过长，请缩短后重新发送；输入框中的草稿已保留。';

  @override
  String get invalidMessage => '请输入非空且未超过长度限制的消息。';

  @override
  String get storageError => '手机存储暂时不可用，请释放空间后重试；未保存的草稿会留在输入框中。';

  @override
  String get serviceError => '手机服务暂时不可用，请返回应用后重试。';

  @override
  String get notPairedError => '请先将手机与 Engine 配对。';

  @override
  String get forgetFirstError => '连接另一个 Engine 前，请先解除当前配对。';

  @override
  String get disconnectFirstError => '更换配对前，请先关闭设备在线。';

  @override
  String get pairingRejected => '配对被拒绝或邀请已过期，请在电脑生成新邀请后重试。';

  @override
  String requestFailed(String code) {
    return '请求失败（$code），请检查设备状态后重试。';
  }

  @override
  String get host => '你的 Engine';

  @override
  String get stayOnline => '设备在线';

  @override
  String get onlineDescription => '通过可见常驻通知保持连接。';

  @override
  String get allowControl => '允许设备操控';

  @override
  String get controlDescription => '主脑必须显式连接后才能读取和操作屏幕。关闭后立即停止操控。';

  @override
  String get accessibility => '无障碍服务';

  @override
  String get enabled => '已启用';

  @override
  String get disabled => '尚未启用';

  @override
  String get controlSession => '主脑操作会话';

  @override
  String get connected => '已连接';

  @override
  String get notConnected => '未连接';

  @override
  String get forget => '解除本机配对';

  @override
  String get forgetDescription => '移除手机凭据和本机消息缓存，Engine 历史保留。再次配对前还需在电脑端撤销旧配对。';

  @override
  String get cancel => '取消';

  @override
  String get about =>
      'Purrcept Go · Purrcept Engine 的安卓设备应用。基于 ccch1mneyyy 的 dsh-Go 修改。源码：github.com/Windpicker-owo/Purrcept-Go · AGPL-3.0。';

  @override
  String get companionFallback => '你的伙伴';

  @override
  String get activityReady => '在这里，随时可以聊';

  @override
  String get activityReceiving => '消息已送达电脑';

  @override
  String get activityProcessing => '正在接手当前输入';

  @override
  String get activityThinking => '正在思考';

  @override
  String get activityActing => '正在行动';

  @override
  String get activityOffline => '连接暂时断开';

  @override
  String get activityConnecting => '正在寻找你的 Engine';

  @override
  String get activitySynchronizing => '正在同步当前状态';

  @override
  String get activityUnavailable => '已连接 · 暂无活动状态';

  @override
  String get activityStarting => 'Engine 正在准备';

  @override
  String get detailReady => '说点什么，或先去忙你的事。';

  @override
  String get detailReceiving => '已经记入收件箱，等待主脑接入一轮思考。';

  @override
  String get detailProcessing => '一轮处理已经开始，思考与行动进展会在这里更新。';

  @override
  String get detailThinking => '主脑正在思考。你可以继续发消息，不必等候。';

  @override
  String get detailActing => '动作正在执行，完成或失败都会以实际结果为准。';

  @override
  String get detailOffline => '手机保存的消息会在重连后补送；此时无法确认主脑的实时活动。';

  @override
  String get detailConnecting => '正在恢复连接，已保存的消息会留在这里。';

  @override
  String get detailSynchronizing => '网络已连上，正在等待电脑传来真实状态。';

  @override
  String get detailUnavailable => '当前电脑端暂未提供活动进度。你可以继续聊天，更新电脑端后即可查看。';

  @override
  String get detailStarting => '电脑正在准备主体。消息接收和开始思考是不同阶段。';

  @override
  String get messageWaiting => '已记入收件箱 · 等待主脑接手';

  @override
  String get messageClaimed => '已进入一轮处理';

  @override
  String get messageThinking => '本轮正在思考';

  @override
  String get messageActing => '本轮正在执行动作';

  @override
  String get messageFinished => '本轮处理已结束';

  @override
  String get messageRecorded => '休息期间已记下';

  @override
  String get messageFailed => '本轮未能正常完成';

  @override
  String get messageStale => '已接管 · 重连后同步进度';

  @override
  String get activityDetails => '这个状态意味着什么';

  @override
  String get statusNotReply => '处理结束不一定会产生回复。动作与消息只会在实际发生后展示。';

  @override
  String get actionPhone => '正在使用手机';

  @override
  String get actionComputer => '正在使用电脑';

  @override
  String get actionNotebook => '正在整理笔记';

  @override
  String get actionBrowser => '正在查找资料';

  @override
  String get actionMessage => '正在发来消息';

  @override
  String get conversationHint => '一个念头、一个问题，或说说今天…';

  @override
  String get setupWelcome => '把陪伴带在身边';

  @override
  String get setupWelcomeBody => '主体仍住在电脑里。手机是随时聊天的窗口，也能在你允许时，成为可以行动的一双手。';

  @override
  String get setupBegin => '开始连接';

  @override
  String get setupComputer => '先准备好电脑';

  @override
  String get setupComputerBody => '主体仍在电脑运行。让手机和电脑连接同一个 Wi-Fi，或使用你已配置好的私人网络。';

  @override
  String get setupComputerSteps =>
      '在电脑打开 Engine 的 WebUI，进入「设备 → 连接安卓手机」。首次使用可在「设置手机连接」中选择电脑地址，预览并保存，再正常重启 Engine。点击「显示配对二维码」，然后回到手机扫码。';

  @override
  String get setupComputerHelp => '电脑没有出现二维码？';

  @override
  String get setupComputerTrouble =>
      '在 WebUI 设备页点击「显示配对二维码」。邀请过期可直接刷新，无需重启 Engine。若提示 Phone 未启用，先在同一页面保存设置并正常重启；若提示已经配对，手机可直接连接。';

  @override
  String get setupHaveQr => '电脑二维码已准备好';

  @override
  String get setupBack => '上一步';

  @override
  String get setupChoices => '按你的习惯来';

  @override
  String get setupChoicesBody => '配对已保存，现在就可以聊天。下面的权限都可以稍后在「设备」中调整。';

  @override
  String get setupNotifications => '不错过新消息';

  @override
  String get setupNotificationsBody => '允许通知后，使用其他应用时也能看到新消息。不开启也可以聊天。';

  @override
  String get setupEnableNotifications => '开启消息通知';

  @override
  String get setupNotificationsReady => '消息通知已开启';

  @override
  String get setupControl => '让主体操作这部手机';

  @override
  String get setupControlBody =>
      '读取屏幕和点击滑动需要两步：在安卓无障碍设置中启用 Purrcept Go，再打开「允许设备操控」。主体仍需主动建立操作会话。聊天不需要这些权限。';

  @override
  String get setupOpenAccessibility => '打开无障碍设置';

  @override
  String get setupStartChat => '进入聊天';

  @override
  String get setupRetry => '重试';

  @override
  String setupProgress(int current, int total) {
    return '第 $current / $total 步';
  }

  @override
  String get activityClosing => 'Engine 正在收尾';

  @override
  String get activityStopped => 'Engine 已停止';

  @override
  String get activityFailed => 'Engine 需要检查';

  @override
  String get detailClosing => '电脑正在关闭主体，已经开始的行动可能仍在收尾。';

  @override
  String get detailStopped => '请在电脑启动 Engine。手机已保存的消息仍会保留。';

  @override
  String get detailFailed => '请检查电脑上的 Engine。手机无法从故障状态推断当前思考或行动。';

  @override
  String get messageDetails => '这条消息的进度';

  @override
  String get messageDetailsHint => '点击消息下方的状态，可以查看最近观察到的进度。';

  @override
  String get recentAction => '最近关联的行动';

  @override
  String get receiptConfirmed => '执行回执已确认';

  @override
  String get receiptFailed => '执行失败';

  @override
  String get receiptUnknown => '执行结果未知';

  @override
  String get receiptStarted => '已派发，尚未观察到结果';

  @override
  String get noAssociatedAction => '本次观察没有提供与这条消息关联的行动。';

  @override
  String get receiptExplanation =>
      '这里显示最近一次已记录的调用，并非完整行动历史。回执已确认也不代表手机上的应用已完成其业务操作。';

  @override
  String get messageProgressUnavailable => '已接管 · 当前进度未提供';

  @override
  String get messageProgressUnavailableDetail =>
      '电脑这次未提供这条消息的最新进度。已确认的处理结果会保留；缺少最新记录时，手机不会猜测她仍在处理还是已经结束。';

  @override
  String get actionNamePhone => '手机操作';

  @override
  String get actionNameComputer => '电脑操作';

  @override
  String get actionNameNotebook => '笔记整理';

  @override
  String get actionNameBrowser => '网页操作';

  @override
  String get actionNameMessage => '消息发送';

  @override
  String get actionNameOther => '行动';

  @override
  String get pairingNetworkError =>
      '还未连上电脑，配对没有完成。请检查电脑地址、手机 WLAN 联网权限或代理设置，然后刷新二维码重试。';

  @override
  String get networkTimeoutError => '连接电脑超时。请检查手机与电脑的 Wi-Fi、代理或网络隔离设置。';

  @override
  String get computerUnreachableError =>
      '无法连接电脑上的 Phone 服务。请检查 Engine 是否运行、配对地址和端口是否正确。';

  @override
  String get computerNotFoundError => '找不到配对地址中的电脑，请在 Engine WebUI 检查电脑地址。';

  @override
  String get networkPermissionError =>
      '系统阻止了 App 联网，请在手机的应用联网权限中允许 Purrcept Go 使用 WLAN。';

  @override
  String get certificateDateError =>
      '证书时间校验失败。请检查手机和电脑的日期时间；若时间正确，请检查电脑证书是否过期。';

  @override
  String get certificateMismatchError =>
      '电脑证书与二维码不匹配。请在 Engine WebUI 刷新二维码并重新扫描。';

  @override
  String get tlsConnectionError =>
      '与电脑的 TLS 安全连接失败。请检查手机或网络代理设置，并核对手机与电脑的日期时间。';

  @override
  String get copyConnectionError => '复制连接错误详情';
}
