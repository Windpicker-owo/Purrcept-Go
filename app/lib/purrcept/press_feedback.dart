/// Physical touch feedback belongs to the gesture, independently of network work or agent progress.
library;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'tokens.dart';

/// Wrap an existing button without taking its tap, keyboard, focus or accessibility semantics.
class PressFeedback extends StatefulWidget {
  const PressFeedback({super.key, required this.child, required this.enabled});
  final Widget child;
  final bool enabled;
  @override
  State<PressFeedback> createState() => _PressFeedbackState();
}

class _PressFeedbackState extends State<PressFeedback>
    with SingleTickerProviderStateMixin {
  late final spring = AnimationController.unbounded(vsync: this, value: 1);

  /// A release, cancellation or disabled button returns to rest; no timer can advance business state.
  void press(bool held) {
    if (MediaQuery.disableAnimationsOf(context)) {
      spring.stop();
      spring.value = 1;
      return;
    }
    if (held && !widget.enabled) return;
    spring.animateWith(
      SpringSimulation(
        SpringDescription(
          mass: MobileTokens.springMass,
          stiffness: MobileTokens.springStiffness,
          damping: MobileTokens.springDamping,
        ),
        spring.value,
        held ? MobileTokens.pressScale : 1,
        spring.velocity,
      ),
    );
  }

  @override
  void didUpdateWidget(PressFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A request becoming busy releases the held pose through the same spring, rather than snapping.
    if (oldWidget.enabled && !widget.enabled) press(false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      spring.stop();
      spring.value = 1;
    }
  }

  @override
  void dispose() {
    spring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => press(true),
    onPointerUp: (_) => press(false),
    onPointerCancel: (_) => press(false),
    child: AnimatedBuilder(
      animation: spring,
      child: widget.child,
      builder: (context, child) =>
          Transform.scale(scale: spring.value, child: child),
    ),
  );
}
