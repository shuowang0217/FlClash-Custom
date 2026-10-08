import 'package:fl_clash/features/smart_select/smart_select_controller.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AI single-country matching', () {
    test('Japanese nodes match both Chinese and emoji markers', () {
      expect(smartCountryMatches('🇯🇵 日本高速01', 'JP'), isTrue);
      expect(smartCountryMatches('JP-Tokyo-02', 'JP'), isTrue);
      expect(smartCountryMatches('Hong Kong-HK01', 'JP'), isFalse);
    });

    test('country abbreviations require word boundaries', () {
      expect(smartCountryMatches('US-Los Angeles', 'US'), isTrue);
      expect(smartCountryMatches('Russia', 'US'), isFalse);
      expect(smartCountryMatches('Singapore SG', 'SG'), isTrue);
    });

    test('unknown regions never silently count as Japanese', () {
      expect(smartCountryMatches('节点 01 CMCU', 'JP'), isFalse);
      expect(smartCountryMatches('新加坡高速', 'JP'), isFalse);
    });
  });

  group('download speed decoding', () {
    test('counts Go measured response bytes per microsecond', () {
      final reading = parseSmartMeasurement('JP1', const ProbeResult(
        statusCode: 200, delay: 88, body: '2097152,100000',
      ));
      expect(reading.valid, isTrue);
      expect(reading.bytes, 2097152);
      expect(reading.megabytesPerSecond, closeTo(20.97, 0.01));
      expect(reading.delayMs, 88);
    });

    test('rejects too-short samples and unpatched cores', () {
      final tooShort = parseSmartMeasurement('JP1', const ProbeResult(
        statusCode: 200, delay: 55, body: '100,50',
      ));
      expect(tooShort.valid, isFalse);
      final unpatched = parseSmartMeasurement('JP1', const ProbeResult(
        statusCode: 200, delay: 55, body: 'binary body',
      ));
      expect(unpatched.valid, isFalse);
    });

    test('does not mistake HTTP errors for valid speed', () {
      final result = parseSmartMeasurement('JP1', const ProbeResult(
        statusCode: 503, delay: 0, body: '2097152,100000',
        error: 'failed', message: 'unavailable',
      ));
      expect(result.valid, isFalse);
      expect(result.bytes, 2097152);
    });
  });
}
