// The active Purrcept tests install their own platform fakes. Upstream tests are migration references.

import 'dart:async';
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Purrcept tests use only the active device app. Upstream tests remain migration references.
  await testMain();
}
