/// Guards the difference between admitted input, active thought, action and completed processing.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:purrcept_go/purrcept/experience.dart';

void main() {
  Map<String, dynamic> snapshot(String phase) => {
    'phase': 'online',
    'subject_name': '小白',
    'engine_state_supported': true,
    'engine_state': {
      'host_phase': 'running',
      'activity': {'phase': phase, 'turn_id': 'turn'},
      'messages': phase == 'idle'
          ? <Object?>[]
          : [
              {'input_id': 'input', 'stage': 'processing'},
            ],
    },
  };

  test('network connection alone is never presented as thinking', () {
    final unsupported = SubjectExperience.fromSnapshot({'phase': 'online'});
    expect(unsupported.phase, CompanionPhase.unavailable);
    final waiting = SubjectExperience.fromSnapshot({
      'phase': 'online',
      'engine_state_supported': true,
    });
    expect(waiting.phase, CompanionPhase.synchronizing);
  });

  test('host shutdown and failure never masquerade as startup or thought', () {
    final expected = {
      'starting': CompanionPhase.starting,
      'closing': CompanionPhase.closing,
      'closed': CompanionPhase.stopped,
      'failed': CompanionPhase.failed,
      'unknown': CompanionPhase.unavailable,
    };
    for (final entry in expected.entries) {
      final value = snapshot('thinking');
      (value['engine_state'] as Map)['host_phase'] = entry.key;
      final experience = SubjectExperience.fromSnapshot(value);
      expect(experience.phase, entry.value);
      expect(experience.working, isFalse);
    }
  });

  test('queued stimulus is receiving rather than a fake model request', () {
    final value = snapshot('idle');
    (value['engine_state'] as Map)['messages'] = [
      {'input_id': 'input', 'stage': 'foreground'},
    ];
    final experience = SubjectExperience.fromSnapshot(value);
    expect(experience.phase, CompanionPhase.receiving);
    expect(
      messagePhase({
        'delivery_state': 'synced',
        'processing': {'input_id': 'input', 'stage': 'foreground'},
      }, experience),
      MessagePhase.waiting,
    );
  });

  test('only an exact turn association joins a message to current thought or action', () {
    final message = <String, dynamic>{
      'delivery_state': 'synced',
      'processing': {
        'input_id': 'input',
        'stage': 'processing',
        'turn_id': 'turn',
      },
    };
    expect(
      messagePhase(
        message,
        SubjectExperience.fromSnapshot(snapshot('thinking')),
      ),
      MessagePhase.thinking,
    );
    expect(
      messagePhase(message, SubjectExperience.fromSnapshot(snapshot('acting'))),
      MessagePhase.acting,
    );
    message['processing'] = {
      'input_id': 'input',
      'stage': 'processing',
      'turn_id': 'another-turn',
    };
    expect(
      messagePhase(
        message,
        SubjectExperience.fromSnapshot(snapshot('thinking')),
      ),
      MessagePhase.claimed,
    );
  });

  test('an unfinished cached message outside the report never claims current progress', () {
    final message = <String, dynamic>{
      'delivery_state': 'synced',
      'processing': {
        'input_id': 'older-input',
        'stage': 'processing',
        'turn_id': 'old-turn',
      },
    };
    final experience = SubjectExperience.fromSnapshot(snapshot('idle'));
    expect(messagePhase(message, experience), MessagePhase.unavailable);
    message['processing'] = {
      'input_id': 'older-input',
      'stage': 'processed',
      'reason': 'succeeded',
    };
    expect(messagePhase(message, experience), MessagePhase.finished);
  });

  test(
    'a current exact turn remains valid beyond the recent message window',
    () {
      final value = snapshot('acting');
      (value['engine_state'] as Map)['messages'] = <Object?>[];
      final message = <String, dynamic>{
        'delivery_state': 'synced',
        'processing': {
          'input_id': 'older-input',
          'stage': 'processing',
          'turn_id': 'turn',
        },
      };
      expect(
        messagePhase(message, SubjectExperience.fromSnapshot(value)),
        MessagePhase.acting,
      );
      final unsupported = SubjectExperience.fromSnapshot({'phase': 'online'});
      expect(messagePhase(message, unsupported), MessagePhase.unavailable);
    },
  );

  test('disconnect invalidates even a cached thinking state while retaining the name', () {
    final value = snapshot('thinking')..['phase'] = 'offline';
    final experience = SubjectExperience.fromSnapshot(value);
    expect(experience.working, isFalse);
    expect(experience.name, '小白');
    expect(
      messagePhase({
        'delivery_state': 'synced',
        'processing': {'stage': 'processing'},
      }, experience),
      MessagePhase.stale,
    );
  });

  test(
    'recorded rest, failed processing and a finished turn stay distinct',
    () {
      final experience = SubjectExperience.fromSnapshot(snapshot('idle'));
      expect(
        messagePhase({
          'delivery_state': 'synced',
          'processing': {
            'stage': 'processed',
            'reason': 'subject.sleeping.recorded',
          },
        }, experience),
        MessagePhase.recorded,
      );
      expect(
        messagePhase({
          'delivery_state': 'synced',
          'processing': {'stage': 'processed', 'reason': 'succeeded'},
        }, experience),
        MessagePhase.finished,
      );
      expect(
        messagePhase({
          'delivery_state': 'synced',
          'processing': {'stage': 'failed'},
        }, experience),
        MessagePhase.failed,
      );
    },
  );
}
