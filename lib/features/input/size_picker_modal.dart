import 'package:flutter/material.dart';

import '../../shared/theme.dart';

enum _SizeTier { k1, k2, k4 }

extension on _SizeTier {
  String get label => switch (this) { _SizeTier.k1 => '1K', _SizeTier.k2 => '2K', _SizeTier.k4 => '4K' };
}

class _Ratio {
  const _Ratio(this.label, this.w, this.h);
  final String label;
  final int w;
  final int h;
}

const _ratios = [
  _Ratio('1:1', 1, 1),
  _Ratio('3:2', 3, 2),
  _Ratio('2:3', 2, 3),
  _Ratio('16:9', 16, 9),
  _Ratio('9:16', 9, 16),
  _Ratio('4:3', 4, 3),
  _Ratio('3:4', 3, 4),
  _Ratio('21:9', 21, 9),
];

const _presets = <_SizeTier, Map<String, (int, int)>>{
  _SizeTier.k1: {
    '1:1': (1024, 1024),
    '3:2': (1536, 1024),
    '2:3': (1024, 1536),
    '16:9': (1280, 720),
    '9:16': (720, 1280),
    '4:3': (1024, 768),
    '3:4': (768, 1024),
    '21:9': (1280, 544),
  },
  _SizeTier.k2: {
    '1:1': (2048, 2048),
    '3:2': (2160, 1440),
    '2:3': (1440, 2160),
    '16:9': (2560, 1440),
    '9:16': (1440, 2560),
    '4:3': (2048, 1536),
    '3:4': (1536, 2048),
    '21:9': (2560, 1088),
  },
  _SizeTier.k4: {
    '1:1': (2880, 2880),
    '3:2': (3456, 2304),
    '2:3': (2304, 3456),
    '16:9': (3840, 2160),
    '9:16': (2160, 3840),
    '4:3': (3200, 2400),
    '3:4': (2400, 3200),
    '21:9': (3840, 1600),
  },
};

enum _Mode { auto, ratio, custom }

Future<(int, int)?> showSizePickerModal(
  BuildContext context, {
  required int currentWidth,
  required int currentHeight,
}) {
  return showModalBottomSheet<(int, int)>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SizePickerSheet(
      currentWidth: currentWidth,
      currentHeight: currentHeight,
    ),
  );
}

class _SizePickerSheet extends StatefulWidget {
  const _SizePickerSheet({
    required this.currentWidth,
    required this.currentHeight,
  });

  final int currentWidth;
  final int currentHeight;

  @override
  State<_SizePickerSheet> createState() => _SizePickerSheetState();
}

class _SizePickerSheetState extends State<_SizePickerSheet> {
  _Mode _mode = _Mode.auto;
  _SizeTier _tier = _SizeTier.k1;
  String _ratio = '1:1';
  late final TextEditingController _wCtrl;
  late final TextEditingController _hCtrl;

  @override
  void initState() {
    super.initState();
    _wCtrl = TextEditingController(
      text: widget.currentWidth > 0 ? widget.currentWidth.toString() : '1024',
    );
    _hCtrl = TextEditingController(
      text: widget.currentHeight > 0 ? widget.currentHeight.toString() : '1024',
    );
    _inferFromCurrent();
  }

  void _inferFromCurrent() {
    if (widget.currentWidth == 0 || widget.currentHeight == 0) {
      _mode = _Mode.auto;
      return;
    }
    for (final tier in _SizeTier.values) {
      final map = _presets[tier]!;
      for (final entry in map.entries) {
        if (entry.value.$1 == widget.currentWidth &&
            entry.value.$2 == widget.currentHeight) {
          _mode = _Mode.ratio;
          _tier = tier;
          _ratio = entry.key;
          return;
        }
      }
    }
    _mode = _Mode.custom;
  }

  @override
  void dispose() {
    _wCtrl.dispose();
    _hCtrl.dispose();
    super.dispose();
  }

  (int, int) get _computedSize {
    if (_mode == _Mode.auto) return (0, 0);
    if (_mode == _Mode.custom) {
      final w = int.tryParse(_wCtrl.text.trim()) ?? 1024;
      final h = int.tryParse(_hCtrl.text.trim()) ?? 1024;
      return (w > 0 ? w : 1024, h > 0 ? h : 1024);
    }
    return _presets[_tier]![_ratio] ?? (1024, 1024);
  }

  @override
  Widget build(BuildContext context) {
    final size = _computedSize;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHandle(),
            const SizedBox(height: 12),
            _buildHeader(),
            const SizedBox(height: 16),
            _buildModeTabs(),
            const SizedBox(height: 16),
            if (_mode == _Mode.auto) _buildAutoContent(),
            if (_mode == _Mode.ratio) _buildRatioContent(),
            if (_mode == _Mode.custom) _buildCustomContent(),
            const SizedBox(height: 16),
            _buildPreview(size),
            const SizedBox(height: 16),
            _buildActions(size),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Text(
          '设置图像尺寸',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        Text(
          '当前 ${widget.currentWidth}×${widget.currentHeight}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppThemeTokens.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildModeTabs() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppThemeTokens.surfaceSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _tabButton('自动', _mode == _Mode.auto, () {
            setState(() => _mode = _Mode.auto);
          }),
          _tabButton('按比例', _mode == _Mode.ratio, () {
            setState(() => _mode = _Mode.ratio);
          }),
          _tabButton('自定义', _mode == _Mode.custom, () {
            setState(() => _mode = _Mode.custom);
          }),
        ],
      ),
    );
  }

  Widget _tabButton(String text, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: active
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4)]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? AppThemeTokens.textPrimary : AppThemeTokens.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAutoContent() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(Icons.auto_awesome_rounded, size: 40, color: AppThemeTokens.primary.withValues(alpha: 0.6)),
          const SizedBox(height: 12),
          Text(
            '由模型自动决定尺寸',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '不传递尺寸参数，由模型根据内容自行选择',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppThemeTokens.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatioContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '基准分辨率',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppThemeTokens.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: _SizeTier.values.map((t) {
            final active = _tier == t;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: t != _SizeTier.k4 ? 8 : 0,
                ),
                child: _chipButton(t.label, active, () {
                  setState(() => _tier = t);
                }),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Text(
          '图像比例',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppThemeTokens.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        _buildRatioGrid(),
      ],
    );
  }

  Widget _buildRatioGrid() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _ratios.map((r) {
        final active = _ratio == r.label;
        return _ratioChip(r, active);
      }).toList(),
    );
  }

  Widget _ratioChip(_Ratio r, bool active) {
    final isHorizontal = r.w > r.h;
    final isSquare = r.w == r.h;
    final boxW = isHorizontal || isSquare ? 18.0 : 18.0 * r.w / r.h;
    final boxH = !isHorizontal || isSquare ? 18.0 : 18.0 * r.h / r.w;

    return GestureDetector(
      onTap: () => setState(() => _ratio = r.label),
      child: Container(
        width: 72,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppThemeTokens.primary.withValues(alpha: 0.08) : AppThemeTokens.surfaceSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? AppThemeTokens.primary : AppThemeTokens.border.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Center(
                child: Container(
                  width: boxW,
                  height: boxH,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: active ? AppThemeTokens.primary : AppThemeTokens.textSecondary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              r.label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: active ? AppThemeTokens.primary : AppThemeTokens.textPrimary,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomContent() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _wCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '宽度',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Icon(Icons.close_rounded, size: 16, color: Colors.grey),
        ),
        Expanded(
          child: TextField(
            controller: _hCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '高度',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
      ],
    );
  }

  Widget _buildPreview((int, int) size) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppThemeTokens.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '将使用',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppThemeTokens.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            size.$1 == 0 ? '自动' : '${size.$1} × ${size.$2}',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions((int, int) size) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('取消'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(size),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('确定'),
          ),
        ),
      ],
    );
  }

  Widget _chipButton(String text, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppThemeTokens.primary.withValues(alpha: 0.08) : AppThemeTokens.surfaceSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? AppThemeTokens.primary : AppThemeTokens.border.withValues(alpha: 0.5),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: active ? AppThemeTokens.primary : AppThemeTokens.textPrimary,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
