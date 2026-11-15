/// Verifies UI admission, durable-state projections and recovery hints through the native boundary.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purrcept_go/purrcept/app.dart';
import 'package:purrcept_go/purrcept/device.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, Object?> snapshot;
  late List<MethodCall> calls;
  setUp(() {
    snapshot = {
      'paired': true,
      'phase': 'offline',
      'messages': <Object?>[],
      'control_allowed': false,
    };
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('purrcept/device/events'),
          (call) async => null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DeviceController.channel, (call) async {
          calls.add(call);
          if (call.method == 'snapshot') return jsonEncode(snapshot);
          return '{}';
        });
  });

  testWidgets(
    'offline messages use the native durable queue and clear only after admission',
    (tester) async {
      await tester.pumpWidget(const PurrceptApp());
      await tester.pumpAndSettle();
      expect(find.text('Offline'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();
      final sends = calls.where((call) => call.method == 'send').toList();
      expect(sends.length, 1);
      expect(sends.single.arguments, {'text': 'Hello'});
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(calls.any((call) => call.method == 'control'), isFalse);
    },
  );

  testWidgets('a failed local enqueue preserves the draft', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DeviceController.channel, (call) async {
          if (call.method == 'snapshot') return jsonEncode(snapshot);
          throw PlatformException(code: 'storage_unavailable');
        });
    await tester.pumpWidget(const PurrceptApp());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Keep this');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Keep this',
    );
    expect(find.textContaining('Phone storage is unavailable'), findsOneWidget);
  });

  testWidgets(
    'accepted messages stay visible until the synced projection arrives',
    (tester) async {
      snapshot['messages'] = [
        {
          'message_id': 'm1',
          'text': 'Hello',
          'direction': 'incoming',
          'delivery_state': 'accepted',
        },
      ];
      await tester.pumpWidget(const PurrceptApp());
      await tester.pumpAndSettle();
      expect(find.text('Hello'), findsOneWidget);
      expect(find.text('Engine accepted · awaiting sync'), findsOneWidget);

      snapshot['messages'] = [
        {
          'message_id': 'm1',
          'text': 'Hello',
          'direction': 'incoming',
          'delivery_state': 'synced',
        },
        {
          'message_id': 'm2',
          'text': 'Hi there',
          'direction': 'outgoing',
          'delivery_state': 'synced',
        },
      ];
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Hello'), findsOneWidget);
      expect(find.text('Accepted by Engine'), findsOneWidget);
      expect(find.text('Synced to this phone'), findsOneWidget);
      expect(find.text('Engine accepted · awaiting sync'), findsNothing);
    },
  );

  testWidgets('device online can be turned off while reconnecting', (
    tester,
  ) async {
    snapshot['phase'] = 'reconnecting';
    snapshot['online_wanted'] = true;
    await tester.pumpWidget(const PurrceptApp());
    await tester.pumpAndSettle();
    expect(find.text('Reconnecting'), findsOneWidget);
    expect(find.text('Reconnect now'), findsOneWidget);
    await tester.tap(find.text('Device'));
    await tester.pumpAndSettle();
    final onlineSwitch = find.widgetWithText(SwitchListTile, 'Device online');
    expect(tester.widget<SwitchListTile>(onlineSwitch).value, isTrue);
    await tester.tap(onlineSwitch);
    await tester.pumpAndSettle();
    expect(calls.where((call) => call.method == 'offline').length, 1);
  });

  testWidgets('a local failure survives a later successful snapshot refresh', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DeviceController.channel, (call) async {
          if (call.method == 'snapshot') return jsonEncode(snapshot);
          throw PlatformException(code: 'storage_unavailable');
        });
    final controller = DeviceController();
    await controller.refresh();
    expect(await controller.invoke('send', {'text': 'Keep this'}), isFalse);
    await controller.refresh();
    expect(controller.error, 'storage_unavailable');
    controller.dispose();
  });

  testWidgets('chat opens at the newest messages', (tester) async {
    snapshot['phase'] = 'online';
    snapshot['messages'] = List.generate(
      60,
      (index) => {
        'message_id': 'm$index',
        'text': 'Message $index',
        'direction': 'incoming',
        'delivery_state': 'synced',
      },
    );
    await tester.pumpWidget(const PurrceptApp());
    await tester.pumpAndSettle();
    expect(find.text('Message 59'), findsOneWidget);
    expect(find.text('Message 0'), findsNothing);
  });

  testWidgets(
    'Chinese chat shows admission without claiming agent read status',
    (tester) async {
      tester.binding.platformDispatcher.localesTestValue = const [Locale('zh')];
      addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
      snapshot['messages'] = [
        {
          'message_id': 'm1',
          'text': '你好',
          'direction': 'incoming',
          'delivery_state': 'accepted',
        },
      ];
      await tester.pumpWidget(const PurrceptApp());
      await tester.pumpAndSettle();
      expect(find.text('你好'), findsOneWidget);
      expect(find.text('Engine 已接管 · 等待同步'), findsOneWidget);
      expect(find.textContaining('已读'), findsNothing);
    },
  );

  String fakeInvitation() => jsonEncode({
    'v': 1,
    'url': 'https://192.0.2.1:8766',
    'certificate_sha256': 'ab' * 32,
    'invitation': 'fake_invitation_for_test_only',
    'expires_at': 2000000000,
  });

  testWidgets(
    'scanning reviews the computer before pairing and connecting without control',
    (tester) async {
      snapshot = {'paired': false, 'phase': 'offline', 'messages': <Object?>[]};
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(DeviceController.channel, (call) async {
            calls.add(call);
            if (call.method == 'snapshot') return jsonEncode(snapshot);
            if (call.method == 'scan') return fakeInvitation();
            if (call.method == 'pair') snapshot['paired'] = true;
            return '{}';
          });
      await tester.pumpWidget(const PurrceptApp());
      await tester.pumpAndSettle();
      expect(find.text('Connect your Purrcept'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('Scan to pair'));
      await tester.pumpAndSettle();
      expect(
        find.text('Connect this phone to https://192.0.2.1:8766?'),
        findsOneWidget,
      );
      expect(
        calls.any((call) => call.method == 'pair' || call.method == 'online'),
        isFalse,
      );
      await tester.tap(find.text('Pair and connect'));
      await tester.pumpAndSettle();
      expect(calls.where((call) => call.method == 'pair').length, 1);
      expect(calls.where((call) => call.method == 'online').length, 1);
      expect(
        calls.any(
          (call) => call.method == 'control' || call.method == 'accessibility',
        ),
        isFalse,
      );
    },
  );

  testWidgets('cancelling computer review performs no pairing or connection', (
    tester,
  ) async {
    snapshot['paired'] = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DeviceController.channel, (call) async {
          calls.add(call);
          if (call.method == 'snapshot') return jsonEncode(snapshot);
          if (call.method == 'scan') return fakeInvitation();
          return '{}';
        });
    await tester.pumpWidget(const PurrceptApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scan to pair'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(
      calls.any((call) => call.method == 'pair' || call.method == 'online'),
      isFalse,
    );
  });

  testWidgets('cancelled and unrelated scans never contact Engine', (
    tester,
  ) async {
    snapshot['paired'] = false;
    String? scanned;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DeviceController.channel, (call) async {
          calls.add(call);
          if (call.method == 'snapshot') return jsonEncode(snapshot);
          if (call.method == 'scan') return scanned;
          return '{}';
        });
    await tester.pumpWidget(const PurrceptApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scan to pair'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    scanned = 'https://unrelated.example/';
    await tester.tap(find.text('Scan to pair'));
    await tester.pumpAndSettle();
    expect(find.textContaining('This invitation is invalid'), findsOneWidget);
    expect(
      calls.any((call) => call.method == 'pair' || call.method == 'online'),
      isFalse,
    );
  });

  testWidgets('rejected pairing does not start the online service', (
    tester,
  ) async {
    snapshot['paired'] = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(DeviceController.channel, (call) async {
          calls.add(call);
          if (call.method == 'snapshot') return jsonEncode(snapshot);
          if (call.method == 'scan') return fakeInvitation();
          throw PlatformException(code: 'pairing_rejected_403');
        });
    await tester.pumpWidget(const PurrceptApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scan to pair'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pair and connect'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Pairing was rejected'), findsOneWidget);
    expect(calls.any((call) => call.method == 'online'), isFalse);
  });

  testWidgets(
    'manual invitation remains available without opening the camera',
    (tester) async {
      snapshot['paired'] = false;
      await tester.pumpWidget(const PurrceptApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Other option: paste an invitation'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), fakeInvitation());
      await tester.ensureVisible(find.text('Pair device'));
      await tester.tap(find.text('Pair device'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        calls.any((call) => call.method == 'scan' || call.method == 'pair'),
        isFalse,
      );
    },
  );
}
