import 'package:fl_clash/features/smart_select/smart_select_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SHUO edition feature version is explicit', () {
    expect(smartSelectEditionLabel, contains('SHUO'));
    expect(smartSelectEditionLabel, contains('v1.0.2'));
    expect(smartSelectFeatureVersion, '1.0.0');
    expect(smartSelectFeatureBuild, 10000);
  });
  test('minimum supported feature versions compare numerically', () {
    expect(compareSmartFeatureVersions('1.0.0', '1.0.1'), lessThan(0));
    expect(compareSmartFeatureVersions('1.10.0', '1.9.9'), greaterThan(0));
    expect(compareSmartFeatureVersions('1.0.0', '1.0.0'), 0);
  });
}
