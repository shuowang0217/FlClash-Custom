import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Deliberately does not use a generated Riverpod provider. This makes the
/// feature self-contained and keeps the upstream generated files unchanged.
final smartSelectProvider = NotifierProvider<SmartSelectController, SmartSelectState>(
  SmartSelectController.new,
);

class SmartSpeed {
  const SmartSpeed({required this.name, required this.megabytesPerSecond,
    required this.bytes, required this.delayMs, this.error});
  final String name;
  final double megabytesPerSecond;
  final int bytes;
  final int delayMs;
  final String? error;
  bool get valid => error == null && megabytesPerSecond > 0;
}

class SmartEvent {
  const SmartEvent(this.at, this.kind, this.message);
  final DateTime at;
  final String kind;
  final String message;

  Map<String, dynamic> toJson() => {
    'at': at.toIso8601String(), 'kind': kind, 'message': message,
  };
  factory SmartEvent.fromJson(Map<String, dynamic> json) => SmartEvent(
    DateTime.parse(json['at'] as String),
    json['kind'] as String,
    json['message'] as String,
  );
}

class SmartSelectState {
  const SmartSelectState({
    this.enabled = true,
    this.aiMode = false,
    this.country = 'JP',
    this.manualHold = false,
    this.activeConnectionProtection = true,
    this.wifiOnlyOnAndroid = true,
    this.intervalMinutes = 10,
    this.switchThreshold = 20,
    this.perNodeMb = 2,
    this.perRoundMb = 50,
    this.dailyMb = 500,
    this.testing = false,
    this.progress = 0,
    this.progressTotal = 0,
    this.status = '尚未开启智能优选',
    this.lastTest,
    this.scores = const [],
    this.events = const [],
    this.lastRoundBytes = 0,
    this.todayBytes = 0,
    this.today = '',
  });

  final bool enabled;
  final bool aiMode;
  final String country;
  final bool manualHold;
  final bool activeConnectionProtection;
  final bool wifiOnlyOnAndroid;
  final int intervalMinutes;
  final int switchThreshold;
  final int perNodeMb;
  final int perRoundMb;
  final int dailyMb;
  final bool testing;
  final int progress;
  final int progressTotal;
  final String status;
  final DateTime? lastTest;
  final List<SmartSpeed> scores;
  final List<SmartEvent> events;
  final int lastRoundBytes;
  final int todayBytes;
  final String today;

  SmartSelectState copyWith({
    bool? enabled, bool? aiMode, String? country, bool? manualHold,
    bool? activeConnectionProtection, bool? wifiOnlyOnAndroid,
    int? intervalMinutes, int? switchThreshold, int? perNodeMb,
    int? perRoundMb, int? dailyMb, bool? testing, int? progress,
    int? progressTotal, String? status, DateTime? lastTest,
    List<SmartSpeed>? scores, List<SmartEvent>? events,
    int? lastRoundBytes, int? todayBytes, String? today,
  }) => SmartSelectState(
    enabled: enabled ?? this.enabled,
    aiMode: aiMode ?? this.aiMode,
    country: country ?? this.country,
    manualHold: manualHold ?? this.manualHold,
    activeConnectionProtection: activeConnectionProtection ?? this.activeConnectionProtection,
    wifiOnlyOnAndroid: wifiOnlyOnAndroid ?? this.wifiOnlyOnAndroid,
    intervalMinutes: intervalMinutes ?? this.intervalMinutes,
    switchThreshold: switchThreshold ?? this.switchThreshold,
    perNodeMb: perNodeMb ?? this.perNodeMb,
    perRoundMb: perRoundMb ?? this.perRoundMb,
    dailyMb: dailyMb ?? this.dailyMb,
    testing: testing ?? this.testing,
    progress: progress ?? this.progress,
    progressTotal: progressTotal ?? this.progressTotal,
    status: status ?? this.status,
    lastTest: lastTest ?? this.lastTest,
    scores: scores ?? this.scores,
    events: events ?? this.events,
    lastRoundBytes: lastRoundBytes ?? this.lastRoundBytes,
    todayBytes: todayBytes ?? this.todayBytes,
    today: today ?? this.today,
  );
}

const smartCountries = <String, String>{
  'HK': '🇭🇰 香港', 'JP': '🇯🇵 日本', 'SG': '🇸🇬 新加坡',
  'TW': '🇹🇼 台湾', 'US': '🇺🇸 美国', 'KR': '🇰🇷 韩国',
  'DE': '🇩🇪 德国', 'GB': '🇬🇧 英国',
};

/// Match known country markers rather than guessing from an arbitrary substring
/// ("us" must never match "Russia", for example).
bool smartCountryMatches(String name, String country) {
  final patterns = <String, RegExp>{
    'HK': RegExp(r'🇭🇰|香港|Hong\s*Kong|(?:^|[^A-Za-z])HK(?:$|[^A-Za-z])', caseSensitive: false),
    'JP': RegExp(r'🇯🇵|日本|Japan|Tokyo|Osaka|(?:^|[^A-Za-z])JP(?:$|[^A-Za-z])', caseSensitive: false),
    'SG': RegExp(r'🇸🇬|新加坡|Singapore|(?:^|[^A-Za-z])SG(?:$|[^A-Za-z])', caseSensitive: false),
    'TW': RegExp(r'🇹🇼|台湾|臺灣|Taiwan|(?:^|[^A-Za-z])TW(?:$|[^A-Za-z])', caseSensitive: false),
    'US': RegExp(r'🇺🇸|美国|美國|United\s*States|America|(?:^|[^A-Za-z])US(?:$|[^A-Za-z])', caseSensitive: false),
    'KR': RegExp(r'🇰🇷|韩国|韓國|Korea|Seoul|(?:^|[^A-Za-z])KR(?:$|[^A-Za-z])', caseSensitive: false),
    'DE': RegExp(r'🇩🇪|德国|德國|Germany|Frankfurt|(?:^|[^A-Za-z])DE(?:$|[^A-Za-z])', caseSensitive: false),
    'GB': RegExp(r'🇬🇧|英国|英國|Britain|London|(?:^|[^A-Za-z])(?:GB|UK)(?:$|[^A-Za-z])', caseSensitive: false),
  };
  return patterns[country]?.hasMatch(name) ?? false;
}

/// Native Go's custom probe path returns bytes,microseconds. This is genuine
/// response BODY throughput, not delay/TTFB or a traffic-counter estimate.
SmartSpeed parseSmartMeasurement(String name, ProbeResult? response) {
  if (response == null) {
    return SmartSpeed(name: name, megabytesPerSecond: 0, bytes: 0,
      delayMs: 0, error: '测速请求失败');
  }
  final parts = response.body.split(',');
  if (parts.length != 2) {
    return SmartSpeed(name: name, megabytesPerSecond: 0, bytes: 0,
      delayMs: response.delay,
      error: response.message ?? '内核尚未集成下载测速补丁');
  }
  final bytes = int.tryParse(parts[0]);
  final micros = int.tryParse(parts[1]);
  if (response.error != null || response.statusCode != 200 ||
      bytes == null || micros == null || bytes < 32768 || micros <= 0) {
    return SmartSpeed(name: name, megabytesPerSecond: 0, bytes: bytes ?? 0,
      delayMs: response.delay, error: response.message ?? '测速样本不足');
  }
  return SmartSpeed(name: name, megabytesPerSecond: bytes / micros,
    bytes: bytes, delayMs: response.delay);
}

class SmartSelectController extends Notifier<SmartSelectState> {
  static const _prefKey = 'flclash_custom_smart_select_v1';
  static const _mb = 1024 * 1024;
  Timer? _timer;
  int _generation = 0;
  bool _busy = false;
  bool _forceRegionAfterBusy = false;
  Future<void>? _restoring;
  bool _ready = false;

  @override
  SmartSelectState build() {
    ref.onDispose(() { _timer?.cancel(); _generation++; });
    ref.listen(currentProfileProvider, (prev, next) {
      if (prev?.id != next?.id || prev?.currentGroupName != next?.currentGroupName) {
        _generation++;
        if (_ready && state.enabled) scheduleMicrotask(() => unawaited(testNow()));
      }
    });
    ref.listen(coreStatusProvider, (prev, next) {
      if (next != CoreStatus.connected) _generation++;
      if (next == CoreStatus.connected && _ready && state.enabled) {
        scheduleMicrotask(() => unawaited(testNow()));
      }
    });
    _restoring = _restore();
    return const SmartSelectState();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final text = prefs.getString(_prefKey);
      if (text != null) {
        final data = jsonDecode(text) as Map<String, dynamic>;
        state = state.copyWith(
          enabled: data['enabled'] == true,
          aiMode: data['aiMode'] == true,
          country: (data['country'] as String?) ?? 'JP',
          manualHold: data['manualHold'] == true,
          activeConnectionProtection: data['protect'] != false,
          wifiOnlyOnAndroid: data['wifi'] != false,
          intervalMinutes: (data['interval'] as int?) ?? 10,
          switchThreshold: (data['threshold'] as int?) ?? 20,
          perNodeMb: (data['perNode'] as int?) ?? 2,
          perRoundMb: (data['perRound'] as int?) ?? 50,
          dailyMb: (data['daily'] as int?) ?? 500,
          today: (data['today'] as String?) ?? '',
          todayBytes: (data['todayBytes'] as int?) ?? 0,
          events: ((data['events'] as List?) ?? []).whereType<Map>()
            .map((e) => SmartEvent.fromJson(Map<String, dynamic>.from(e))).toList(),
        );
      }
    } catch (_) {
      state = state.copyWith(status: '设置读取失败，使用安全默认值');
    } finally {
      _ready = true;
      _armTimer();
      if (state.enabled) unawaited(testNow());
    }
  }

  Future<void> _persist() async {
    if (!_ready) await _restoring;
    final s = state;
    final data = {
      'enabled': s.enabled, 'aiMode': s.aiMode, 'country': s.country,
      'manualHold': s.manualHold, 'protect': s.activeConnectionProtection,
      'wifi': s.wifiOnlyOnAndroid, 'interval': s.intervalMinutes,
      'threshold': s.switchThreshold, 'perNode': s.perNodeMb,
      'perRound': s.perRoundMb, 'daily': s.dailyMb,
      'today': s.today, 'todayBytes': s.todayBytes,
      'events': s.events.map((e) => e.toJson()).toList(),
    };
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, jsonEncode(data));
  }

  void _log(String kind, String message) {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final items = [SmartEvent(DateTime.now(), kind, message), ...state.events]
      .where((e) => e.at.isAfter(cutoff)).take(200).toList();
    state = state.copyWith(events: items);
    unawaited(_persist());
  }

  void _armTimer() {
    _timer?.cancel();
    if (!state.enabled) return;
    _timer = Timer.periodic(Duration(minutes: state.intervalMinutes), (_) {
      unawaited(testNow());
    });
  }

  void configure({bool? enabled, bool? aiMode, String? country,
    bool? activeConnectionProtection, bool? wifiOnlyOnAndroid,
    int? intervalMinutes, int? switchThreshold, int? perNodeMb,
    int? perRoundMb, int? dailyMb}) {
    final wasEnabled = state.enabled;
    final selectionChanged = (aiMode != null && aiMode != state.aiMode) ||
      (country != null && country != state.country);
    state = state.copyWith(
      enabled: enabled, aiMode: aiMode, country: country,
      activeConnectionProtection: activeConnectionProtection,
      wifiOnlyOnAndroid: wifiOnlyOnAndroid,
      intervalMinutes: intervalMinutes,
      switchThreshold: switchThreshold, perNodeMb: perNodeMb,
      perRoundMb: perRoundMb, dailyMb: dailyMb,
      status: enabled == false ? '智能优选已关闭' : null,
    );
    if (enabled == false) _generation++;
    if (enabled != null || intervalMinutes != null) _armTimer();
    unawaited(_persist());
    if (state.enabled && (!wasEnabled || selectionChanged)) {
      _generation++;
      unawaited(testNow(forceRegionPick: state.aiMode && selectionChanged));
    }
  }

  void manualSelection(String groupName) {
    if (!state.enabled) return;
    final activeGroup = ref.read(currentProfileProvider)?.currentGroupName;
    if (activeGroup != groupName) return;
    _generation++;
    state = state.copyWith(manualHold: true, status: '用户手动选节点，自动切换暂停');
    _log('hold', '$groupName：手动保持，直到恢复');
    unawaited(_persist());
  }

  void resume() {
    state = state.copyWith(manualHold: false, status: '已恢复自动优选');
    _log('resume', '用户恢复自动优选');
    unawaited(_persist());
    if (state.enabled) unawaited(testNow());
  }

  /// The group may contain nested strategy groups. Flatten only its children;
  /// never search outside the selected group. Skip virtual/direct items.
  List<String> _candidates(String groupName) {
    final groups = ref.read(groupsProvider);
    final seenGroups = <String>{};
    final names = <String>{};
    void walk(String name, int depth) {
      if (depth > 12 || !seenGroups.add(name)) return;
      final group = groups.getGroup(name);
      if (group == null) return;
      for (final p in group.all) {
        final child = groups.getGroup(p.name);
        if (child != null) {
          walk(child.name, depth + 1);
        } else if (!{'DIRECT', 'REJECT', 'PASS', 'COMPATIBLE', 'REJECT-DROP'}
            .contains(p.name.toUpperCase()) &&
            !RegExp(r'剩余流量|到期时间|套餐信息|流量重置').hasMatch(p.name)) {
          if (!state.aiMode || smartCountryMatches(p.name, state.country)) {
            names.add(p.name);
          }
        }
      }
    }
    walk(groupName, 0);
    return names.toList();
  }

  Future<void> testNow({bool forceRegionPick = false}) async {
    if (!_ready) { await _restoring; }
    if (!state.enabled) return;
    if (_busy) {
      // In-flight native requests cannot be cancelled, but their results are
      // invalidated. The requested rerun starts after this round finishes.
      _generation++;
      _forceRegionAfterBusy = _forceRegionAfterBusy || forceRegionPick;
      return;
    }
    final generation = ++_generation;
    final profile = ref.read(currentProfileProvider);
    final groupName = profile?.currentGroupName;
    if (groupName == null || groupName.isEmpty) {
      state = state.copyWith(status: '请先选择一个代理组');
      return;
    }
    if (ref.read(coreStatusProvider) != CoreStatus.connected) {
      state = state.copyWith(status: '代理内核未连接，等待启动');
      return;
    }
    final date = DateTime.now().toIso8601String().substring(0, 10);
    if (state.today != date) state = state.copyWith(today: date, todayBytes: 0);
    if (state.todayBytes >= state.dailyMb * _mb) {
      state = state.copyWith(status: '达到今日测速流量上限，保留当前节点');
      return;
    }
    // Explicit Wi-Fi protection on Android. A blocked automatic test never
    // bypasses the setting just because AI mode was enabled.
    if (state.wifiOnlyOnAndroid) {
      // Connectivity works on all supported platforms; on Windows mobile
      // carrier checking is irrelevant (mobile data rarely reports here).
      final List<ConnectivityResult> links;
      try {
        links = await Connectivity().checkConnectivity();
      } catch (_) {
        state = state.copyWith(status: '无法确认网络类型，已取消本轮测速');
        return;
      }
      if (Platform.isAndroid && !links.contains(ConnectivityResult.wifi) &&
          !links.contains(ConnectivityResult.ethernet)) {
        state = state.copyWith(status: '等待 Wi-Fi 后测速（可在设置中关闭限制）');
        return;
      }
    }
    if (generation != _generation || !state.enabled || _busy) return;
    final names = _candidates(groupName);
    if (names.isEmpty) {
      state = state.copyWith(status: state.aiMode ? '所选国家无可测节点，保持连接' : '当前代理组没有可测节点');
      return;
    }
    _busy = true;
    state = state.copyWith(testing: true, progress: 0,
      progressTotal: names.length, scores: [], status: '下载测速中');
    var roundBytes = 0;
    var accounted = false;
    final scores = <SmartSpeed>[];
    try {
      for (final name in names) {
        if (generation != _generation || !state.enabled) return;
        final available = math.min(state.perNodeMb * _mb,
          math.min(state.perRoundMb * _mb - roundBytes,
            state.dailyMb * _mb - state.todayBytes - roundBytes));
        if (available < 32768) {
          state = state.copyWith(status: '测速流量上限已用完，保留当前节点');
          break;
        }
        try {
          final url = 'https://speed.cloudflare.com/__down?bytes=$available';
          final response = await ref.read(coreHandlerProvider).probe(ProbeParams(
            url: url, proxyName: name, timeout: 12000, maxBody: available,
            headers: const {'X-FlClash-Measure-Download': '1'},
          ));
          final measured = parseSmartMeasurement(name, response);
          final result = measured.valid && measured.bytes < available * 0.8
              ? SmartSpeed(name: name, megabytesPerSecond: 0,
                  bytes: measured.bytes, delayMs: measured.delayMs,
                  error: '下载内容不足，未计入排名')
              : measured;
          scores.add(result);
          roundBytes += result.bytes;
        } catch (e) {
          scores.add(SmartSpeed(name: name, megabytesPerSecond: 0,
            bytes: 0, delayMs: 0, error: '$e'));
        }
        if (generation == _generation) {
          state = state.copyWith(progress: scores.length, scores: [...scores]);
        }
      }
      if (generation != _generation) return;
      final sorted = [...scores]..sort((a,b) => b.megabytesPerSecond.compareTo(a.megabytesPerSecond));
      final wasComplete = scores.length == names.length;
      state = state.copyWith(scores: sorted, lastTest: DateTime.now(),
        todayBytes: state.todayBytes + roundBytes, lastRoundBytes: roundBytes,
        status: wasComplete ? '本轮测速完成' : '流量限制：本轮测速不完整');
      accounted = true;
      unawaited(_persist());
      // Never switch on partial or failed measurements.
      if (wasComplete) {
        await _considerSwitch(groupName, sorted, generation,
          forceRegionPick: forceRegionPick);
      }
    } finally {
      // A cancelled/invalidation round still used download traffic. Never
      // allow repeated AI toggles to reset daily accounting.
      if (!accounted && roundBytes > 0) {
        state = state.copyWith(todayBytes: state.todayBytes + roundBytes,
          lastRoundBytes: roundBytes);
        unawaited(_persist());
      }
      _busy = false;
      state = state.copyWith(testing: false);
      if (generation != _generation && state.enabled) {
        final force = _forceRegionAfterBusy;
        _forceRegionAfterBusy = false;
        scheduleMicrotask(() => unawaited(testNow(forceRegionPick: force)));
      }
    }
  }

  Future<void> _considerSwitch(String groupName, List<SmartSpeed> scores,
    int generation, {required bool forceRegionPick}) async {
    if (generation != _generation || state.manualHold) {
      if (state.manualHold) state = state.copyWith(status: '测速完成 · 手动保持中');
      return;
    }
    final best = scores.where((s) => s.valid).firstOrNull;
    if (best == null) {
      state = state.copyWith(status: '没有有效测速结果，保持当前节点');
      return;
    }
    final group = ref.read(groupsProvider).getGroup(groupName);
    if (group == null) return;
    final currentName = ref.read(currentProfileProvider)?.selectedMap[groupName] ?? group.now ?? '';
    if (currentName == best.name) return;
    final currentSpeed = scores.where((s)=>s.name==currentName && s.valid).firstOrNull?.megabytesPerSecond ?? 0;
    final isOtherCountry = state.aiMode && !smartCountryMatches(currentName, state.country);
    final isInitialRegionPick = state.aiMode && (forceRegionPick || isOtherCountry);
    if (!isInitialRegionPick && (currentSpeed <= 0 ||
        best.megabytesPerSecond < currentSpeed * (1 + state.switchThreshold / 100))) {
      state = state.copyWith(status: '提升未达 ${state.switchThreshold}% 或当前节点测速无效，保持连接');
      return;
    }
    if (state.activeConnectionProtection) {
      try {
        final connections = await ref.read(coreHandlerProvider).getConnections();
        if (connections.any((c) => (c.downloadSpeed ?? 0) > 128 * 1024 ||
          (c.uploadSpeed ?? 0) > 128 * 1024)) {
          state = state.copyWith(status: '检测到活跃连接，暂缓切换');
          return;
        }
      } catch (_) {
        // When protection is enabled, failure to inspect connections must fail closed.
        state = state.copyWith(status: '无法读取活跃连接，暂缓切换');
        return;
      }
    }
    if (generation != _generation || state.manualHold) return;
    // Core supports select and some computed groups; when a group cannot be
    // picked, leave it to the native fallback/url-test strategy rather than
    // claiming a successful switch.
    try {
      final result = await ref.read(coreHandlerProvider).changeProxy(
        ChangeProxyParams(groupName: groupName, proxyName: best.name));
      if (result.message.isNotEmpty) {
        state = state.copyWith(status: '此策略组不支持直接切换：${result.message}');
        return;
      }
      ref.read(profilesActionProvider.notifier).updateCurrentSelectedMap(groupName, best.name);
      if (result.changed) {
        if (ref.read(appSettingProvider).closeConnections) {
          await ref.read(coreHandlerProvider).closeConnections();
        } else {
          await ref.read(coreHandlerProvider).resetConnections();
        }
      }
      state = state.copyWith(status: '已优选 ${best.name} · ${best.megabytesPerSecond.toStringAsFixed(1)} MB/s');
      _log('switch', '$groupName：$currentName → ${best.name}；${isInitialRegionPick ? "AI 国家首次优选" : "速度提升达到阈值"}');
    } catch (e) {
      state = state.copyWith(status: '节点切换失败：$e');
    }
  }

  /// Explicit connect from the ranking is user intent, not an automatic pick.
  Future<void> connectManually(String name) async {
    final group = ref.read(currentProfileProvider)?.currentGroupName;
    if (group == null) return;
    try {
      final result = await ref.read(coreHandlerProvider).changeProxy(
        ChangeProxyParams(groupName: group, proxyName: name));
      if (result.message.isNotEmpty) {
        state = state.copyWith(status: '手动连接失败：${result.message}');
        return;
      }
      ref.read(profilesActionProvider.notifier).updateCurrentSelectedMap(group, name);
      manualSelection(group);
      if (result.changed) {
        if (ref.read(appSettingProvider).closeConnections) {
          await ref.read(coreHandlerProvider).closeConnections();
        } else {
          await ref.read(coreHandlerProvider).resetConnections();
        }
      }
    } catch (e) {
      state = state.copyWith(status: '手动连接失败：$e');
    }
  }
}
