/// Render real phone-sized layouts with synthetic Engine facts, including reduced motion and large type.
/// Optional PURRCEPT_PREVIEW_FONT supplies a local CJK font for human inspection, never for production.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purrcept_go/purrcept/app.dart';
import 'package:purrcept_go/purrcept/device.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fontPath = Platform.environment['PURRCEPT_PREVIEW_FONT'];
    if (fontPath == null) return;
    final font = FontLoader('Roboto')
      ..addFont(File(fontPath).readAsBytes().then(ByteData.sublistView));
    await font.load();
    final icons = Platform.environment['PURRCEPT_PREVIEW_ICONS'];
    if (icons != null) {
      await (FontLoader(
        'MaterialIcons',
      )..addFont(File(icons).readAsBytes().then(ByteData.sublistView))).load();
    }
  });

  for (final mode in [
    'thinking-light',
    'personal-stickers',
    'acting-dark',
    'large-type',
    'offline',
    'welcome',
    'computer-setup',
    'scan-setup',
    'permissions',
  ]) {
    testWidgets('mobile layout and real status: $mode', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.binding.platformDispatcher.localesTestValue = const [Locale('zh')];
      tester.binding.platformDispatcher.platformBrightnessTestValue =
          mode == 'acting-dark' ? Brightness.dark : Brightness.light;
      tester.binding.platformDispatcher.textScaleFactorTestValue =
          mode == 'large-type' ? 2 : 1;
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.binding.platformDispatcher.clearLocalesTestValue();
        tester.binding.platformDispatcher.clearPlatformBrightnessTestValue();
        tester.binding.platformDispatcher.clearTextScaleFactorTestValue();
        tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue();
      });
      final snapshot = <String, Object?>{
        'paired': true,
        'phase': mode == 'offline' ? 'offline' : 'online',
        'online_wanted': mode != 'offline',
        'subject_name': '小白',
        'engine_state_supported': true,
        'engine_state': {
          'host_phase': 'running',
          'activity': {
            'phase': mode == 'acting-dark' ? 'acting' : 'thinking',
            'turn_id': 'turn',
            'call_path': mode == 'acting-dark' ? 'me.phone.screen' : null,
          },
          'messages': [],
        },
        'messages': [
          {
            'message_id': 'm1',
            'text': '今天想用手机和你聊聊。',
            'direction': 'incoming',
            'delivery_state': 'synced',
            'processing': {'stage': 'processed'},
          },
          {
            'message_id': 'm2',
            'text': '我在，慢慢说。',
            'direction': 'outgoing',
            'delivery_state': 'synced',
          },
          {
            'message_id': 'm3',
            'text': '可以帮我看看手机上的页面吗？',
            'direction': 'incoming',
            'delivery_state': 'synced',
            'processing': {'stage': 'processing', 'turn_id': 'turn'},
          },
        ],
      };
      final setupStep = switch (mode) {
        'welcome' => 0,
        'computer-setup' => 1,
        'scan-setup' => 2,
        'permissions' => 3,
        _ => 4,
      };
      if (setupStep < 4) {
        snapshot['paired'] = setupStep == 3;
        snapshot['setup_step'] = setupStep;
      }
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('purrcept/device/events'),
        (_) async => null,
      );
      messenger.setMockMethodCallHandler(
        DeviceController.channel,
        (call) async => call.method == 'snapshot' ? jsonEncode(snapshot) : '{}',
      );
      const key = ValueKey('preview');
      await tester.pumpWidget(
        const RepaintBoundary(key: key, child: PurrceptApp()),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (setupStep == 4) expect(find.text('小白'), findsWidgets);
      expect(
        find.text('本轮正在思考'),
        setupStep < 4 || mode == 'offline' || mode == 'acting-dark'
            ? findsNothing
            : findsOneWidget,
      );
      if (mode == 'personal-stickers') {
        await tester.tap(find.byTooltip('表情贴纸'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('我的收藏 (0)'));
        await tester.pumpAndSettle();
        final composer = find.byKey(const ValueKey('chat-composer'));
        expect(tester.getSize(composer).width, greaterThan(280));
        expect(tester.getSize(composer).height, lessThan(80));
        expect(tester.takeException(), isNull);
      }
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(key),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/purrcept-previews/$mode.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
