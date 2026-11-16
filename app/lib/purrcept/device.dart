/// Typed UI projections of the native service. Events invalidate this cache; they never carry credentials.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'experience.dart';

/// Owns one native-state subscription for a page; credentials, media files and message admission stay native.
class DeviceController extends ChangeNotifier {
  static const channel = MethodChannel('purrcept/device');
  static const events = EventChannel('purrcept/device/events');
  StreamSubscription<Object?>? _subscription;
  Map<String, dynamic> snapshot = {};
  String? _requestError;

  /// Native exception class names only; the next user request clears this temporary diagnostic.
  String? requestDiagnostics;
  String? _serviceError;
  bool busy = false;
  bool loaded = false;
  bool _disposed = false;
  bool _refreshing = false;
  bool _refreshAgain = false;

  /// Subscribe before the first query so an intervening native commit cannot be missed.
  void start() {
    _subscription = events.receiveBroadcastStream().listen(
      (_) => refresh(),
      onError: (Object event) {
        _serviceError = 'service_unavailable';
        if (!_disposed) notifyListeners();
      },
    );
    unawaited(refresh());
  }

  bool get paired => snapshot['paired'] == true;

  /// Setup progress is stored by the native service; existing pairings bypass first-run education.
  int get setupStep => snapshot['setup_step'] as int? ?? (paired ? 4 : 0);
  bool get online => snapshot['phase'] == 'online';

  /// The user's online intent stays true while the transport is connecting or retrying.
  bool get onlineWanted => snapshot['online_wanted'] == true;

  /// Native transport phase is independent of permission and agent control-session state.
  String get phase => snapshot['phase'] as String? ?? 'offline';

  /// Current work and identity come from the paired Engine, independently of device control.
  SubjectExperience get experience => SubjectExperience.fromSnapshot(snapshot);

  /// Local display preferences, including the Bot avatar last applied from Engine.
  Map<String, dynamic> get profile {
    final raw = snapshot['profile'];
    return raw is Map ? Map<String, dynamic>.from(raw) : const {};
  }

  String? get userAvatar => _nonBlank(profile['user_avatar']);
  String? get botAvatar => _nonBlank(profile['bot_avatar']);
  String? get userName => _nonBlank(profile['user_name']);

  /// User-imported custom image stickers stored on this phone.
  List<Map<String, dynamic>> get customStickers =>
      (snapshot['custom_stickers'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .toList();

  /// Live voice recording and playback state from native MediaLab.
  Map<String, dynamic> get voiceState {
    final raw = snapshot['voice_state'];
    return raw is Map ? Map<String, dynamic>.from(raw) : const {};
  }

  bool get isRecordingVoice => voiceState['recording'] == true;
  int get recordingStartedAtMs =>
      (voiceState['started_at_ms'] as num?)?.toInt() ?? 0;
  int get recordingLevel => (voiceState['level'] as num?)?.toInt() ?? 0;
  String? get playingMessageId => _nonBlank(voiceState['playing_id']);
  int get playingPositionMs =>
      (voiceState['position_ms'] as num?)?.toInt() ?? 0;
  int get playingDurationMs =>
      (voiceState['duration_ms'] as num?)?.toInt() ?? 0;

  /// Local failures remain visible across network refreshes until another user request starts.
  String? get error =>
      _requestError ?? _serviceError ?? snapshot['error'] as String?;
  List<Map<String, dynamic>> get messages =>
      (snapshot['messages'] as List<dynamic>? ?? [])
          .map((entry) => Map<String, dynamic>.from(entry as Map))
          .toList();

  static String? _nonBlank(Object? raw) {
    if (raw is! String) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Open the native camera on explicit request. Cancellation returns no invitation or network work.
  Future<String?> scanInvitation() async {
    busy = true;
    _requestError = null;
    requestDiagnostics = null;
    notifyListeners();
    try {
      return await channel.invokeMethod<String>('scan');
    } on PlatformException catch (failure) {
      _requestError = failure.code;
      return null;
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Launch Android's system image picker for avatars, custom stickers, or chat photos.
  Future<Map<String, dynamic>?> pickImage(String purpose) async {
    _requestError = null;
    requestDiagnostics = null;
    notifyListeners();
    try {
      final raw = await channel.invokeMethod<String>('pick_image', {
        'purpose': purpose,
      });
      if (raw == null || raw.isEmpty) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } on PlatformException catch (failure) {
      _requestError = failure.code;
      return null;
    } finally {
      if (!_disposed) notifyListeners();
    }
  }

  /// Invoke a fast media/voice control method and parse its JSON response without toggling global busy.
  Future<Map<String, dynamic>?> invokeMedia(
    String method, [
    Map<String, Object?> arguments = const {},
  ]) async {
    _requestError = null;
    requestDiagnostics = null;
    try {
      final raw = await channel.invokeMethod<String>(method, arguments);
      await refresh();
      if (raw == null || raw.isEmpty) return const {};
      return jsonDecode(raw) as Map<String, dynamic>;
    } on PlatformException catch (failure) {
      _requestError = failure.code;
      if (!_disposed) notifyListeners();
      return null;
    }
  }

  /// Coalesce invalidations without dropping a commit that arrives while a query is in flight.
  Future<void> refresh() async {
    if (_refreshing) {
      _refreshAgain = true;
      return;
    }
    _refreshing = true;
    try {
      do {
        _refreshAgain = false;
        final raw = await channel.invokeMethod<String>('snapshot');
        if (raw != null && !_disposed) {
          snapshot = jsonDecode(raw) as Map<String, dynamic>;
          loaded = true;
          _serviceError = null;
          notifyListeners();
        }
      } while (_refreshAgain && !_disposed);
    } on PlatformException catch (failure) {
      if (failure.code != 'not_ready') _serviceError = failure.code;
      if (!_disposed) notifyListeners();
    } finally {
      _refreshing = false;
    }
  }

  /// Success confirms the native request, including local enqueue; it does not imply network delivery.
  Future<bool> invoke(
    String method, [
    Map<String, Object?> arguments = const {},
  ]) async {
    busy = true;
    _requestError = null;
    requestDiagnostics = null;
    notifyListeners();
    try {
      await channel.invokeMethod<Object?>(method, arguments);
      await refresh();
      return true;
    } on PlatformException catch (failure) {
      _requestError = failure.code;
      requestDiagnostics = failure.details is String
          ? failure.details as String
          : null;
      return false;
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
