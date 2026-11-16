/// Presentation semantics for authenticated Engine facts; elapsed time never advances a stage.
library;

/// Connection and subject activity are separate, including an explicit unavailable-state mode.
enum CompanionPhase {
  offline,
  connecting,
  synchronizing,
  unavailable,
  starting,
  closing,
  stopped,
  failed,
  ready,
  receiving,
  processing,
  thinking,
  acting,
}

/// A frame of live work. Native code discards it on disconnect and caches the public name separately.
class SubjectExperience {
  const SubjectExperience({
    required this.phase,
    this.name,
    this.turnId,
    this.callPath,
    this.startedAt,
    this.observedInputs = const <String>{},
  });
  final CompanionPhase phase;
  final String? name;
  final String? turnId;
  final String? callPath;
  final DateTime? startedAt;

  /// Inputs explicitly covered by the latest report. A live exact turn provides independent evidence.
  final Set<String> observedInputs;

  /// Derive visible activity only from an online connection's most recent authoritative snapshot.
  factory SubjectExperience.fromSnapshot(Map<String, dynamic> snapshot) {
    final name = snapshot['subject_name'] as String?;
    if (snapshot['phase'] != 'online') {
      final waiting =
          snapshot['phase'] == 'connecting' ||
          snapshot['phase'] == 'reconnecting';
      return SubjectExperience(
        phase: waiting ? CompanionPhase.connecting : CompanionPhase.offline,
        name: name,
      );
    }
    final raw = snapshot['engine_state'];
    if (raw is! Map) {
      return SubjectExperience(
        phase: snapshot['engine_state_supported'] == true
            ? CompanionPhase.synchronizing
            : CompanionPhase.unavailable,
        name: name,
      );
    }
    final activity = raw['activity'];
    final work = activity is Map ? activity : const <String, Object?>{};
    final inputs = raw['messages'];
    final waiting =
        inputs is List &&
        inputs.any(
          (item) =>
              item is Map &&
              item['stage'] != 'processed' &&
              item['stage'] != 'failed',
        );
    final phase = switch (raw['host_phase']) {
      'new' || 'starting' => CompanionPhase.starting,
      'closing' => CompanionPhase.closing,
      'closed' => CompanionPhase.stopped,
      'failed' => CompanionPhase.failed,
      'running' => switch (work['phase']) {
        'idle' => waiting ? CompanionPhase.receiving : CompanionPhase.ready,
        'processing' => CompanionPhase.processing,
        'thinking' => CompanionPhase.thinking,
        'acting' => CompanionPhase.acting,
        _ => CompanionPhase.synchronizing,
      },
      _ => CompanionPhase.unavailable,
    };
    final since = work['started_at'];
    return SubjectExperience(
      phase: phase,
      name: name,
      observedInputs: inputs is List
          ? {
              for (final item in inputs)
                if (item is Map && item['input_id'] is String)
                  item['input_id'] as String,
            }
          : const <String>{},
      turnId: work['turn_id'] as String?,
      callPath: work['call_path'] as String?,
      startedAt: since is num
          ? DateTime.fromMillisecondsSinceEpoch(
              (since * 1000).round(),
              isUtc: true,
            )
          : null,
    );
  }

  /// Animation is reserved for work which has a current server-side owner.
  bool get working =>
      phase == CompanionPhase.processing ||
      phase == CompanionPhase.thinking ||
      phase == CompanionPhase.acting;
}

/// Per-message labels distinguish delivery, attention, processing and completion without claiming a reply.
enum MessagePhase {
  saved,
  delivered,
  waiting,
  claimed,
  thinking,
  acting,
  finished,
  recorded,
  failed,
  stale,
  unavailable,
}

/// Join a message's durable facts with live work only through its exact turn identity.
MessagePhase messagePhase(
  Map<String, dynamic> message,
  SubjectExperience experience,
) {
  if (message['delivery_state'] == 'pending') return MessagePhase.saved;
  final raw = message['processing'];
  if (raw is! Map) return MessagePhase.delivered;
  if (raw['stage'] == 'failed') return MessagePhase.failed;
  if (raw['stage'] == 'processed') {
    return raw['reason'] == 'subject.sleeping.recorded'
        ? MessagePhase.recorded
        : MessagePhase.finished;
  }
  if (experience.phase == CompanionPhase.offline ||
      experience.phase == CompanionPhase.connecting) {
    return MessagePhase.stale;
  }
  // A still-active exact turn is independent evidence, even when an older message falls
  // outside the bounded input report. Elapsed time and a different turn prove nothing.
  if (raw['turn_id'] != null &&
      raw['turn_id'] == experience.turnId &&
      experience.working) {
    if (experience.phase == CompanionPhase.thinking) {
      return MessagePhase.thinking;
    }
    if (experience.phase == CompanionPhase.acting) return MessagePhase.acting;
    return MessagePhase.claimed;
  }
  final liveReport =
      experience.phase == CompanionPhase.ready ||
      experience.phase == CompanionPhase.receiving ||
      experience.working;
  if (!liveReport || !experience.observedInputs.contains(raw['input_id'])) {
    return MessagePhase.unavailable;
  }
  if (raw['stage'] == 'claimed' || raw['stage'] == 'processing') {
    return MessagePhase.claimed;
  }
  return MessagePhase.waiting;
}
