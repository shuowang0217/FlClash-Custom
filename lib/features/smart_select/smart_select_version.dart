/// Dedicated SHUO edition (not an upstream chen08209 build).
const smartSelectEditionLabel = 'FlClash SHUO Custom · v1.0.1';
const smartSelectFeatureVersion = '1.0.0';
const smartSelectFeatureBuild = 10000;
const smartSelectReleaseUrl =
    'https://github.com/shuowang0217/FlClash-Custom/releases/latest';
const smartSelectManifestUrl =
    'https://raw.githubusercontent.com/shuowang0217/FlClash-Custom/main/shuo-version.json';

int compareSmartFeatureVersions(String left, String right) {
  final a = left.split('.').map((v) => int.tryParse(v) ?? 0).toList();
  final b = right.split('.').map((v) => int.tryParse(v) ?? 0).toList();
  for (var i = 0; i < 3; i++) {
    final l = i < a.length ? a[i] : 0;
    final r = i < b.length ? b[i] : 0;
    if (l != r) return l.compareTo(r);
  }
  return 0;
}
