import 'dart:io';

import 'package:fl_clash/common/constant.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native Android plugins and Flutter use identical channel names', () {
    expect(packageName, 'com.shuowang.flclash.custom');

    final components = File(
      'android/common/src/main/java/com/follow/clash/common/Components.kt',
    ).readAsStringSync();
    expect(
      components,
      contains('FLUTTER_CHANNEL_NAMESPACE = "$packageName"'),
    );
    for (final plugin in ['AppPlugin', 'ServicePlugin', 'TilePlugin']) {
      final native = File(
        'android/app/src/main/kotlin/com/follow/clash/plugins/$plugin.kt',
      ).readAsStringSync();
      expect(
        native,
        contains(r'${Components.FLUTTER_CHANNEL_NAMESPACE}/'),
        reason: '$plugin must register its MethodChannel under the Dart namespace',
      );
      expect(
        native,
        isNot(contains(r'${Components.PACKAGE_NAME}/')),
        reason: '$plugin must not use Kotlin class package as a channel name',
      );
    }
  });

  test('all three Dart platform plugins use SHUO packageName', () {
    for (final plugin in ['app', 'service', 'tile']) {
      final dart = File('lib/plugins/$plugin.dart').readAsStringSync();
      expect(dart, contains(r'$packageName/'));
    }
  });
}
