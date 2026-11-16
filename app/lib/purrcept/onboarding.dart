/// First-run education follows native pairing facts and durable progress, without granting permissions.
/// The host owns camera review and pairing; this surface only requests explicit, reversible steps.
library;

import 'package:flutter/material.dart';

import 'device.dart';
import 'experience.dart';
import 'l10n/app_localizations.dart';
import 'mascot.dart';
import 'mobile_theme.dart';
import 'tokens.dart';
import 'press_feedback.dart';

/// Paired users finish optional permission education; an existing pairing without progress skips it.
class PhoneSetup extends StatelessWidget {
  const PhoneSetup({super.key, required this.device, required this.pairing});
  final DeviceController device;
  final Widget pairing;

  @override
  Widget build(BuildContext context) {
    final text = PhoneL10n.of(context);
    final colors = PhoneColors.of(context);
    // Credentials constrain navigation: a paired phone must never enter the scan page again.
    final step = device.paired ? 3 : device.setupStep.clamp(0, 2);
    final title = switch (step) {
      0 => text.setupWelcome,
      1 => text.setupComputer,
      2 => text.pairTitle,
      _ => text.setupChoices,
    };
    final body = switch (step) {
      0 => text.setupWelcomeBody,
      1 => text.setupComputerBody,
      2 => text.pairDescription,
      _ => text.setupChoicesBody,
    };
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: MobileTokens.contentMax),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(Cel.space * 1.5),
                child: AnimatedSwitcher(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : MobileTokens.effects,
                  child: Column(
                    key: ValueKey(step),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          if (step > 0 && step < 3)
                            IconButton(
                              tooltip: text.setupBack,
                              onPressed: device.busy
                                  ? null
                                  : () => device.invoke('onboarding', {
                                      'step': step - 1,
                                    }),
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                          Expanded(
                            child: Text(
                              text.setupProgress(step + 1, 4),
                              style: TextStyle(color: colors.muted),
                            ),
                          ),
                          ...List.generate(
                            4,
                            (index) => Container(
                              margin: const EdgeInsets.only(
                                left: Cel.space / 4,
                              ),
                              width: Cel.space / 2,
                              height: Cel.space / 2,
                              decoration: BoxDecoration(
                                color: index <= step
                                    ? colors.brand
                                    : colors.muted,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: Cel.space * 1.5),
                      if (device.busy) ...[
                        const LinearProgressIndicator(),
                        const SizedBox(height: Cel.space),
                      ],
                      if (step == 0) ...[
                        Container(
                          decoration: BoxDecoration(
                            color: colors.hero,
                            borderRadius: BorderRadius.circular(
                              MobileTokens.heroRadius,
                            ),
                          ),
                          padding: const EdgeInsets.all(Cel.space),
                          child: const Center(
                            child: CompanionMascot(
                              phase: CompanionPhase.ready,
                              hero: true,
                            ),
                          ),
                        ),
                        const SizedBox(height: Cel.space * 1.5),
                      ],
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: Cel.space),
                      Text(
                        body,
                        style: TextStyle(
                          color: colors.muted,
                          height: MobileTokens.lineHeight,
                        ),
                      ),
                      const SizedBox(height: Cel.space * 1.5),
                      if (step == 1) ...[
                        _SetupPanel(
                          icon: Icons.computer_rounded,
                          title: 'Purrcept Engine → Purrcept Go',
                          body: text.setupComputerSteps,
                        ),
                        const SizedBox(height: Cel.space),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: Text(text.setupComputerHelp),
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: Cel.space),
                              child: Text(text.setupComputerTrouble),
                            ),
                          ],
                        ),
                        const SizedBox(height: Cel.space),
                      ],
                      if (step == 2) pairing,
                      if (step == 3) ...[
                        _SetupPanel(
                          icon: Icons.notifications_none_rounded,
                          title: text.setupNotifications,
                          body: text.setupNotificationsBody,
                          child:
                              device.snapshot['notifications_enabled'] == true
                              ? Text(
                                  text.setupNotificationsReady,
                                  style: TextStyle(color: colors.active),
                                )
                              : OutlinedButton(
                                  onPressed: device.busy
                                      ? null
                                      : () => device.invoke('notifications'),
                                  child: Text(text.setupEnableNotifications),
                                ),
                        ),
                        const SizedBox(height: Cel.space),
                        _SetupPanel(
                          icon: Icons.touch_app_outlined,
                          title: text.setupControl,
                          body: text.setupControlBody,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              OutlinedButton(
                                onPressed: device.busy
                                    ? null
                                    : () => device.invoke('accessibility'),
                                child: Text(
                                  device.snapshot['accessibility'] == true
                                      ? text.enabled
                                      : text.setupOpenAccessibility,
                                ),
                              ),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(text.allowControl),
                                value:
                                    device.snapshot['control_allowed'] == true,
                                onChanged: device.busy
                                    ? null
                                    : (allowed) => device.invoke('control', {
                                        'allowed': allowed,
                                      }),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: Cel.space),
                        if (!device.online)
                          OutlinedButton(
                            onPressed: device.busy
                                ? null
                                : () => device.invoke('online'),
                            child: Text(text.reconnect),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (step != 2)
              Padding(
                padding: const EdgeInsets.all(Cel.space * 1.5),
                child: SizedBox(
                  width: double.infinity,
                  child: PressFeedback(
                    enabled: !device.busy,
                    child: FilledButton(
                      onPressed: device.busy
                          ? null
                          : () => device.invoke('onboarding', {
                              'step': step == 3 ? 4 : step + 1,
                            }),
                      child: Text(switch (step) {
                        0 => text.setupBegin,
                        1 => text.setupHaveQr,
                        _ => text.setupStartChat,
                      }),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Group explanation and its explicit action; decoration never implies permission was granted.
class _SetupPanel extends StatelessWidget {
  const _SetupPanel({
    required this.icon,
    required this.title,
    required this.body,
    this.child,
  });
  final IconData icon;
  final String title;
  final String body;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Material(
    color: PhoneColors.of(context).surface,
    borderRadius: BorderRadius.circular(MobileTokens.panelRadius),
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.all(Cel.space),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: PhoneColors.of(context).brand,
            size: MobileTokens.titleSize,
          ),
          const SizedBox(height: Cel.space / 2),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: Cel.space / 2),
          Text(
            body,
            style: TextStyle(
              color: PhoneColors.of(context).muted,
              height: MobileTokens.lineHeight,
            ),
          ),
          if (child != null) ...[const SizedBox(height: Cel.space), child!],
        ],
      ),
    ),
  );
}
