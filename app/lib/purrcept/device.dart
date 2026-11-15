/// Typed UI projections of the native service. Events invalidate this cache; they never carry credentials.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Owns one native-state subscription for a page; credentials and message admission stay native.
class DeviceController extends ChangeNotifier {
  static const channel = MethodChannel('purrcept/device');
  static const events = EventChannel('purrcept/device/events');
  StreamSubscription<Object?>? _subscription;
  Map<String, dynamic> snapshot = {};
  String? _requestError;
  String? _serviceError;
  bool busy = false;
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
  bool get online => snapshot['phase'] == 'online';

  /// The user's online intent stays true while the transport is connecting or retrying.
  bool get onlineWanted => snapshot['online_wanted'] == true;

  /// Native transport phase is independent of permission and agent control-session state.
  String get phase => snapshot['phase'] as String? ?? 'offline';

  /// Local failures remain visible across network refreshes until another user request starts.
  String? get error =>
      _requestError ?? _serviceError ?? snapshot['error'] as String?;
  List<Map<String, dynamic>> get messages =>
      (snapshot['messages'] as List<dynamic>? ?? [])
          .map((entry) => Map<String, dynamic>.from(entry as Map))
          .toList();

  /// Open the native camera on explicit request. Cancellation returns no invitation or network work.
  Future<String?> scanInvitation() async {
    busy = true;
    _requestError = null;
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
    notifyListeners();
    try {
      await channel.invokeMethod<Object?>(method, arguments);
      await refresh();
      return true;
    } on PlatformException catch (failure) {
      _requestError = failure.code;
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
