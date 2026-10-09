import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SHUO Android startup does not depend on an unconfigured FirebaseApp', () {
    final native = File(
      'android/common/src/main/java/com/follow/clash/common/GlobalState.kt',
    ).readAsStringSync();
    expect(native, isNot(contains('FirebaseApp.initializeApp')));
    expect(native, isNot(contains('FirebaseCrashlytics.getInstance')));
    expect(native, contains('fun setCrashlytics(enable: Boolean) = Unit'));
    expect(native, contains('fun didCrashOnPreviousExecution(): Boolean = false'));

    final gradle = File('android/common/build.gradle.kts').readAsStringSync();
    expect(gradle, isNot(contains('libs.firebase')));
    // Keep the OS-native crash recovery path available on Android 11+.
    expect(native, contains('getHistoricalProcessExitReasons'));
  });
}
