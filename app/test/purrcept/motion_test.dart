/// Observe real rendered motion and touch behavior under synthetic, fixed activity facts.
/// Advancing the test clock must change the pose, never invent a new Engine stage.
library;

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purrcept_go/purrcept/activity.dart';
import 'package:purrcept_go/purrcept/experience.dart';
import 'package:purrcept_go/purrcept/l10n/app_localizations.dart';
import 'package:purrcept_go/purrcept/mobile_theme.dart';
import 'package:purrcept_go/purrcept/press_feedback.dart';

Widget _scene(Widget child, {bool reduced = false}) => MaterialApp(
  theme: phoneTheme(Brightness.light),
  localizationsDelegates: PhoneL10n.localizationsDelegates,
  supportedLocales: PhoneL10n.supportedLocales,
  builder: (context, page) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
    child: page!,
  ),
  home: Scaffold(body: Center(child: child)),
);

Future<Uint8List> _pixels(WidgetTester tester, Key key) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  final data = await tester.runAsync(() async {
    final image = await boundary.toImage();
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      return bytes!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  });
  return data!;
}

void main() {
  testWidgets(
    'work moves without advancing its stage and rests when its owner ends',
    (tester) async {
      const key = ValueKey('presence');
      Widget presence(CompanionPhase phase) => _scene(
        RepaintBoundary(
          key: key,
          child: CompanionPresence(
            experience: SubjectExperience(phase: phase),
            hero: true,
          ),
        ),
      );
      try {
        await tester.pumpWidget(presence(CompanionPhase.thinking));
        await tester.pump(const Duration(milliseconds: 400));
        final first = await _pixels(tester, key);
        await tester.pump(const Duration(milliseconds: 600));
        final moving = await _pixels(tester, key);
        expect(listEquals(first, moving), isFalse);
        expect(find.text('Thinking'), findsOneWidget);
        expect(find.text('Taking action'), findsNothing);

        await tester.pumpWidget(presence(CompanionPhase.ready));
        await tester.pump(const Duration(milliseconds: 400));
        final rest = await _pixels(tester, key);
        await tester.pump(const Duration(milliseconds: 900));
        expect(listEquals(rest, await _pixels(tester, key)), isTrue);
        expect(find.text('Here with you'), findsOneWidget);
      } finally {
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets(
    'reduced motion keeps a working pose static and its stage explicit',
    (tester) async {
      const key = ValueKey('reduced-presence');
      await tester.pumpWidget(
        _scene(
          const RepaintBoundary(
            key: key,
            child: CompanionPresence(
              experience: SubjectExperience(phase: CompanionPhase.acting),
              hero: true,
            ),
          ),
          reduced: true,
        ),
      );
      await tester.pumpAndSettle();
      final first = await _pixels(tester, key);
      await tester.pump(const Duration(seconds: 3));
      expect(listEquals(first, await _pixels(tester, key)), isTrue);
      expect(find.text('Taking action'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'press feedback follows touch, while cancellation invokes no action',
    (tester) async {
      const key = ValueKey('button');
      var calls = 0;
      await tester.pumpWidget(
        _scene(
          PressFeedback(
            enabled: true,
            child: FilledButton(
              key: key,
              onPressed: () => calls++,
              child: const Text('Continue'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final original = tester.getRect(find.byKey(key));
      final press = await tester.startGesture(original.center);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getRect(find.byKey(key)).width, lessThan(original.width));
      expect(calls, 0);
      await press.up();
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(
        tester.getRect(find.byKey(key)).width,
        closeTo(original.width, .5),
      );

      final cancelled = await tester.startGesture(original.center);
      await tester.pump(const Duration(milliseconds: 100));
      await cancelled.cancel();
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(
        tester.getRect(find.byKey(key)).width,
        closeTo(original.width, .5),
      );
    },
  );
  testWidgets('busy feedback releases through the spring instead of snapping', (
    tester,
  ) async {
    const key = ValueKey('busy-button');
    var enabled = true;
    await tester.pumpWidget(
      _scene(
        StatefulBuilder(
          builder: (context, update) => PressFeedback(
            enabled: enabled,
            child: FilledButton(
              key: key,
              onPressed: enabled ? () => update(() => enabled = false) : null,
              child: const Text('Continue'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final original = tester.getRect(find.byKey(key));
    final press = await tester.startGesture(original.center);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getRect(find.byKey(key)).width, lessThan(original.width));
    await press.up();
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byKey(key)).onPressed, isNull);
    expect(tester.getRect(find.byKey(key)).width, lessThan(original.width));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(key)).width, closeTo(original.width, .5));
  });
}
