/// First-run navigation survives page recreation and requests permissions only after explicit taps.
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
      'paired': false,
      'phase': 'offline',
      'setup_step': 0,
      'messages': <Object?>[],
    };
    calls = [];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('purrcept/device/events'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(DeviceController.channel, (call) async {
      calls.add(call);
      if (call.method == 'snapshot') return jsonEncode(snapshot);
      if (call.method == 'onboarding') {
        snapshot['setup_step'] = (call.arguments as Map)['step'];
      }
      return '{}';
    });
  });

  testWidgets(
    'fresh setup resumes and has no implicit device or permission action',
    (tester) async {
      await tester.pumpWidget(const PurrceptApp());
      await tester.pumpAndSettle();
      expect(find.text('Bring your companion along'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      await tester.ensureVisible(find.text('Let’s connect'));
      await tester.tap(find.text('Let’s connect'));
      await tester.pumpAndSettle();
      expect(snapshot['setup_step'], 1);
      expect(find.text('First, your computer'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(const PurrceptApp());
      await tester.pumpAndSettle();
      expect(find.text('First, your computer'), findsOneWidget);
      await tester.ensureVisible(find.text('The QR code is ready'));
      await tester.tap(find.text('The QR code is ready'));
      await tester.pumpAndSettle();
      expect(snapshot['setup_step'], 2);
      expect(find.text('Scan to pair'), findsOneWidget);
      expect(
        calls.where(
          (call) => !{'snapshot', 'onboarding'}.contains(call.method),
        ),
        isEmpty,
      );
    },
  );

  testWidgets(
    'optional permissions do not block chat or silently grant control',
    (tester) async {
      snapshot.addAll({
        'paired': true,
        'setup_step': 3,
        'notifications_enabled': false,
      });
      await tester.pumpWidget(const PurrceptApp());
      await tester.pumpAndSettle();
      expect(find.text('Make it yours'), findsOneWidget);
      expect(calls.any((call) => call.method == 'notifications'), isFalse);
      await tester.ensureVisible(find.text('Allow message notifications'));
      await tester.tap(find.text('Allow message notifications'));
      await tester.pumpAndSettle();
      expect(calls.where((call) => call.method == 'notifications').length, 1);
      await tester.ensureVisible(find.text('Start chatting'));
      await tester.tap(find.text('Start chatting'));
      await tester.pumpAndSettle();
      expect(snapshot['setup_step'], 4);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(
        calls.any((call) => {'control', 'accessibility'}.contains(call.method)),
        isFalse,
      );
    },
  );

  for (var step = 0; step < 4; step++) {
    testWidgets('setup step $step supports a narrow screen and large text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      tester.binding.platformDispatcher.textScaleFactorTestValue = 2;
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.binding.platformDispatcher.clearTextScaleFactorTestValue();
        tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue();
      });
      snapshot.addAll({'paired': step == 3, 'setup_step': step});
      await tester.pumpWidget(const PurrceptApp());
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -1800),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
