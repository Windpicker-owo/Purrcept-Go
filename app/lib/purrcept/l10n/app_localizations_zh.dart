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
  String get emptyChat => '和 Purrcept 说句话。她也可以在这里主动找你。';

  @override
  String get you => '你';

  @override
  String get pending => '已保存在手机 · 等待 Engine 接管';

  @override
  String get messageHint => '发消息给 Purrcept';

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
}
