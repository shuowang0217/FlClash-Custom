import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'smart_select_controller.dart';


/// The side sheet is itself a modal route. Inline options avoid opening
/// another popup route behind the sheet on certain Windows window sizes.
/// Kept public to make the real selection behavior widget-testable.
class SmartInlinePicker<T> extends StatefulWidget {
  const SmartInlinePicker({
    super.key,
    required this.title,
    required this.value,
    required this.options,
    required this.onSelected,
  });

  final String title;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onSelected;

  @override
  State<SmartInlinePicker<T>> createState() => _SmartInlinePickerState<T>();
}

class _SmartInlinePickerState<T> extends State<SmartInlinePicker<T>> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.options[widget.value] ?? widget.value.toString();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton(
            onPressed: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title, style: Theme.of(context).textTheme.labelMedium),
                        const SizedBox(height: 4),
                        Text(selected, style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            Card(
              child: Column(
                children: [
                  for (final entry in widget.options.entries)
                    ListTile(
                      dense: true,
                      title: Text(entry.value),
                      selected: widget.value == entry.key,
                      trailing: widget.value == entry.key
                          ? const Icon(Icons.check_circle)
                          : null,
                      onTap: () {
                        widget.onSelected(entry.key);
                        setState(() => _isExpanded = false);
                      },
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Put this immediately above the original proxy-group tabs. No original
/// proxy card, search, group selection or delay-test control is replaced.
class SmartSelectStatusCard extends ConsumerWidget {
  const SmartSelectStatusCard({super.key});

  void _open(BuildContext context, WidgetRef ref) {
    if (ref.read(isMobileViewProvider)) {
      showSheet(
        context: context,
        props: const SheetProps(isScrollControlled: true),
        builder: (_) => const SmartSelectPanel(),
      );
    } else {
      showExtend(context, builder: (_) => const SmartSelectPanel());
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(smartSelectProvider);
    final profile = ref.watch(currentProfileProvider);
    final group = profile?.currentGroupName ?? '未选择';
    final groups = ref.watch(groupsProvider);
    final selected = profile?.selectedMap[group] ?? groups.getGroup(group)?.now ?? '';
    final speeds = s.scores.where((x) => x.name == selected && x.valid);
    final speed = speeds.isEmpty ? null : speeds.first.megabytesPerSecond;
    final colorScheme = Theme.of(context).colorScheme;
    final text = !s.enabled ? '关闭' : s.manualHold ? '手动保持' : s.testing ? '测速中' : '运行中';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Card(
        elevation: 0,
        color: colorScheme.surfaceContainerHigh,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Chip(avatar: Icon(s.manualHold ? Icons.pause_circle_outline : Icons.auto_awesome,
                size: 17), label: Text('智能优选 · $text')),
              Chip(avatar: const Icon(Icons.public, size: 17),
                label: Text('AI ${s.aiMode ? "开启 · ${smartCountries[s.country] ?? s.country}" : "关闭"}')),
              OutlinedButton.icon(
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('智能优选设置'),
                onPressed: () => _open(context, ref),
              ),
            ]),
            const SizedBox(height: 8),
            Text('当前代理组：$group', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text('当前节点：${selected.isEmpty ? "未选择" : selected}',
              maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Wrap(spacing: 16, runSpacing: 6, children: [
              Text('下载速度：${speed == null ? "--" : speed.toStringAsFixed(1)} MB/s'),
              Text('检测时间：${s.lastTest == null ? "--" : _time(s.lastTest!)}'),
            ]),
            const SizedBox(height: 5),
            Row(children: [
              Expanded(child: Text(s.status,
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall)),
              if (s.testing) const SizedBox(width: 9),
              if (s.testing) const SizedBox.square(dimension: 15,
                child: CircularProgressIndicator(strokeWidth: 2)),
            ]),
            if (s.manualHold && s.enabled)
              Align(alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => ref.read(smartSelectProvider.notifier).resume(),
                  icon: const Icon(Icons.play_arrow), label: const Text('恢复自动优选'))),
          ]),
        ),
      ),
    );
  }
}

String _time(DateTime dt) =>
    '${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

/// Shared widget: showExtend on desktop, adaptive full-height sheet on mobile.
class SmartSelectPanel extends ConsumerStatefulWidget {
  const SmartSelectPanel({super.key});
  @override
  ConsumerState<SmartSelectPanel> createState() => _SmartSelectPanelState();
}

class _SmartSelectPanelState extends ConsumerState<SmartSelectPanel> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(smartSelectProvider);
    final action = ref.read(smartSelectProvider.notifier);
    final profile = ref.watch(currentProfileProvider);
    final groupName = profile?.currentGroupName ?? '未选择';
    final screenWidth = MediaQuery.sizeOf(context).width;
    return SizedBox(
      width: screenWidth < 440 ? screenWidth : 410,
      child: Scaffold(
        appBar: AppBar(title: const Text('智能优选'),
          actions: [IconButton(icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).maybePop())]),
        body: Column(children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 0, label: Text('优选设置')),
                ButtonSegment(value: 1, label: Text('测速排行')),
                ButtonSegment(value: 2, label: Text('切换历史')),
              ],
              selected: {_index}, onSelectionChanged: (v) => setState(() => _index = v.first),
            )),
          Expanded(child: switch (_index) {
            0 => _settings(s, action, groupName),
            1 => _ranking(s, action, groupName),
            _ => _history(s),
          }),
        ]),
      ),
    );
  }

  Widget _settings(SmartSelectState s, SmartSelectController action, String group) {
    final isAndroid = Theme.of(context).platform == TargetPlatform.android;
    return ListView(padding: const EdgeInsets.fromLTRB(14, 12, 14, 36), children: [
      SwitchListTile(title: const Text('启用智能优选'),
        subtitle: const Text('定时测速并自动选择更快节点'),
        value: s.enabled, onChanged: (v) => action.configure(enabled: v)),
      SwitchListTile(title: const Text('AI 模式'),
        subtitle: const Text('开启后仅测所选的一个国家/地区，并立即测速'),
        value: s.aiMode, onChanged: (v) => action.configure(aiMode: v)),
      if (s.aiMode) SmartInlinePicker<String>(
        title: '固定国家 / 地区',
        value: s.country,
        options: smartCountries,
        onSelected: (country) => action.configure(country: country),
      ),
      ListTile(title: const Text('当前监控代理组'), subtitle: Text(group),
        trailing: const Icon(Icons.sync_alt),
        isThreeLine: false),
      const Divider(),
      const ListTile(title: Text('真实下载测速'),
        subtitle: Text('采用内核绑定单节点的下载测速，不以延迟代替速度')),
      SmartInlinePicker<int>(
        title: '测速周期',
        value: s.intervalMinutes,
        options: const {5: '5 分钟', 10: '10 分钟', 30: '30 分钟', 60: '60 分钟'},
        onSelected: (minutes) => action.configure(intervalMinutes: minutes),
      ),
      ListTile(title: Text('自动切换阈值 ${s.switchThreshold}%'),
        subtitle: Slider(min: 5, max: 50, divisions: 9, value: s.switchThreshold.toDouble(),
          onChanged: (v) => action.configure(switchThreshold: v.round()))),
      const Divider(),
      const ListTile(title: Text('测速流量限制')),
      _choice('单节点上限', s.perNodeMb, [1,2,5], (x)=>action.configure(perNodeMb:x)),
      _choice('单轮总上限', s.perRoundMb, [20,50,100], (x)=>action.configure(perRoundMb:x)),
      _choice('每日总上限', s.dailyMb, [200,500,1000], (x)=>action.configure(dailyMb:x)),
      ListTile(title: const Text('已使用测速流量'),
        subtitle: Text('本轮 ${(s.lastRoundBytes/1048576).toStringAsFixed(1)} MB · '
          '今日 ${(s.todayBytes/1048576).toStringAsFixed(1)} / ${s.dailyMb} MB')),
      if (isAndroid) SwitchListTile(title: const Text('仅在 Wi-Fi 下测速'),
        value: s.wifiOnlyOnAndroid,
        onChanged: (v) => action.configure(wifiOnlyOnAndroid:v)),
      const Divider(),
      SwitchListTile(title: const Text('活跃连接保护'),
        subtitle: const Text('重要连接仍在传输时暂缓自动切换'),
        value: s.activeConnectionProtection,
        onChanged:(v)=>action.configure(activeConnectionProtection:v)),
      ListTile(title: const Text('手动切换保护'),
        subtitle: Text(s.manualHold ? '已暂停，直到手动恢复' : '手动连接后暂停自动切换')),
      if (s.manualHold) FilledButton.icon(
        onPressed: action.resume, icon: const Icon(Icons.play_arrow),
        label: const Text('恢复自动优选')),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: s.enabled && !s.testing ? () => action.testNow() : null,
        icon: const Icon(Icons.speed), label: const Text('立即测速')),
      if (s.testing) Padding(padding: const EdgeInsets.all(10), child: Column(children: [
        LinearProgressIndicator(value: s.progressTotal == 0 ? null : s.progress/s.progressTotal),
        Text('正在测试 ${s.progress}/${s.progressTotal} 个节点'),
      ])),
      const SizedBox(height: 8),
      Text(s.status, style: Theme.of(context).textTheme.bodySmall),
    ]);
  }

  Widget _choice(String name, int current, List<int> values, void Function(int) change) {
    return SmartInlinePicker<int>(
      title: name,
      value: current,
      options: {for (final value in values) value: '$value MB'},
      onSelected: change,
    );
  }

  Widget _ranking(SmartSelectState s, SmartSelectController action, String group) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('代理组：$group · ${s.aiMode ? smartCountries[s.country] : '全部地区'}'),
      Text('检测时间：${s.lastTest == null ? '未检测' : _time(s.lastTest!)}'),
      const SizedBox(height: 8),
      if (s.scores.isEmpty) const ListTile(title: Text('暂无测速结果')),
      for (final (index, item) in s.scores.indexed)
        Card(child: Padding(padding: const EdgeInsets.all(10), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${index+1}. ${item.name}', maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          Text(item.valid
            ? '${item.megabytesPerSecond.toStringAsFixed(1)} MB/s · ${item.delayMs} ms'
            : '失败：${item.error ?? '无有效速度'}'),
          const SizedBox(height: 6),
          LinearProgressIndicator(value: item.valid
            ? (item.megabytesPerSecond / (s.scores.first.megabytesPerSecond == 0
              ? 1 : s.scores.first.megabytesPerSecond)).clamp(0.0,1.0) : 0),
          Align(alignment: Alignment.centerRight, child: TextButton.icon(
            onPressed: item.valid ? () => action.connectManually(item.name) : null,
            icon: const Icon(Icons.login), label: const Text('立即连接'))),
        ]))),
      const SizedBox(height: 8),
      FilledButton.icon(
        onPressed: s.enabled && !s.testing ? () => action.testNow() : null,
        icon: const Icon(Icons.refresh), label: const Text('重新测速')),
    ]);
  }

  Widget _history(SmartSelectState s) {
    return ListView(padding: const EdgeInsets.all(12), children: [
      const ListTile(title: Text('切换历史'), subtitle: Text('保留最近 30 天、最多 200 条')),
      if (s.events.isEmpty) const ListTile(title: Text('暂无记录')),
      for (final e in s.events)
        Card(child: ListTile(
          leading: Icon(switch (e.kind) {
            'switch' => Icons.swap_horiz,
            'hold' => Icons.pan_tool_outlined,
            _ => Icons.play_circle_outline,
          }),
          title: Text(e.message),
          subtitle: Text('${e.kind} · ${_time(e.at)}'),
        )),
    ]);
  }
}
