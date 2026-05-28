import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../shared/theme.dart';

// --- Data models ---

enum _PresetCategory {
  general('通用比例', Icons.aspect_ratio_rounded),
  photo('照片', Icons.photo_camera_rounded),
  screen('屏幕/视频', Icons.tv_rounded),
  web('Web', Icons.monitor_rounded),
  mobile('移动设备', Icons.phone_iphone_rounded),
  print('打印', Icons.description_rounded),
  artwork('图稿与插画', Icons.brush_rounded);

  const _PresetCategory(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _SizeItem {
  const _SizeItem(this.name, this.w, this.h, {this.icon});
  final String name;
  final int w;
  final int h;
  final IconData? icon;
}

// --- Preset data (all values are multiples of 16, within gpt-image-2 constraints) ---

const _presetData = <_PresetCategory, List<_SizeItem>>{
  _PresetCategory.general: [
    _SizeItem('1:1 1K', 1024, 1024),
    _SizeItem('1:1 2K', 2048, 2048),
    _SizeItem('1:1 Max', 2880, 2880),
    _SizeItem('3:2', 1536, 1024),
    _SizeItem('3:2 2K', 2160, 1440),
    _SizeItem('3:2 4K', 3456, 2304),
    _SizeItem('2:3', 1024, 1536),
    _SizeItem('2:3 2K', 1440, 2160),
    _SizeItem('2:3 4K', 2304, 3456),
    _SizeItem('16:9', 1920, 1088),
    _SizeItem('16:9 2K', 2560, 1440),
    _SizeItem('16:9 4K', 3840, 2160),
    _SizeItem('9:16', 1088, 1920),
    _SizeItem('9:16 2K', 1440, 2560),
    _SizeItem('9:16 4K', 2160, 3840),
    _SizeItem('4:3', 1024, 768),
    _SizeItem('4:3 2K', 2048, 1536),
    _SizeItem('4:3 4K', 3200, 2400),
    _SizeItem('3:4', 768, 1024),
    _SizeItem('3:4 2K', 1536, 2048),
    _SizeItem('3:4 4K', 2400, 3200),
    _SizeItem('21:9', 1792, 768),
    _SizeItem('21:9 2K', 2688, 1152),
    _SizeItem('21:9 4K', 3840, 1648),
  ],
  _PresetCategory.photo: [
    _SizeItem('横向 3:2', 1536, 1024),
    _SizeItem('纵向 2:3', 1024, 1536),
    _SizeItem('横向 7:5', 1792, 1280),
    _SizeItem('纵向 5:7', 1280, 1792),
    _SizeItem('横向 10:8', 1280, 1024),
    _SizeItem('纵向 8:10', 1024, 1280),
    _SizeItem('横向 3:2 高清', 3456, 2304),
    _SizeItem('纵向 2:3 高清', 2304, 3456),
  ],
  _PresetCategory.screen: [
    _SizeItem('720p', 1280, 736),
    _SizeItem('1080p', 1920, 1088),
    _SizeItem('2K QHD', 2560, 1440),
    _SizeItem('4K UHD', 3840, 2160),
    _SizeItem('竖屏 9:16', 1088, 1920),
    _SizeItem('竖屏 2K', 1440, 2560),
    _SizeItem('竖屏 4K', 2160, 3840),
  ],
  _PresetCategory.web: [
    _SizeItem('1024×768', 1024, 768),
    _SizeItem('1280×800', 1280, 800),
    _SizeItem('1376×768', 1376, 768),
    _SizeItem('1440×896', 1440, 896),
    _SizeItem('1440×1024', 1440, 1024),
    _SizeItem('1920×1088', 1920, 1088),
    _SizeItem('2560×1440', 2560, 1440),
    _SizeItem('2560×1600', 2560, 1600),
    _SizeItem('2880×1808', 2880, 1808),
  ],
  _PresetCategory.mobile: [
    _SizeItem('iPhone 16 Pro Max', 1312, 2864, icon: Icons.phone_iphone),
    _SizeItem('iPhone 16 Pro', 1200, 2624, icon: Icons.phone_iphone),
    _SizeItem('iPhone 16', 1168, 2528, icon: Icons.phone_iphone),
    _SizeItem('iPhone SE', 752, 1328, icon: Icons.phone_iphone),
    _SizeItem('iPad Pro 12.9"', 2048, 2736, icon: Icons.tablet_mac),
    _SizeItem('iPad Pro 11"', 1664, 2384, icon: Icons.tablet_mac),
    _SizeItem('iPad Air', 1648, 2368, icon: Icons.tablet_mac),
    _SizeItem('Android 常见', 1088, 1920, icon: Icons.phone_android),
    _SizeItem('Android 大屏', 1440, 3200, icon: Icons.phone_android),
  ],
  _PresetCategory.print: [
    _SizeItem('名片', 1056, 608),
    _SizeItem('明信片 4×6"', 1200, 1808),
    _SizeItem('A6', 1248, 1744),
    _SizeItem('A5', 1744, 2480),
    _SizeItem('A4', 2480, 3504),
    _SizeItem('海报 18×24"', 2160, 2880),
  ],
  _PresetCategory.artwork: [
    _SizeItem('方形 1K', 1024, 1024),
    _SizeItem('方形 2K', 2048, 2048),
    _SizeItem('方形 Max', 2880, 2880),
    _SizeItem('Instagram 方形', 1088, 1088),
    _SizeItem('Instagram 竖版', 1088, 1360),
    _SizeItem('社交封面 3:1', 1584, 528),
    _SizeItem('横幅 2:1', 2048, 1024),
    _SizeItem('竖幅 1:2', 1024, 2048),
  ],
};

// --- Mode enum ---

enum _Mode { auto, preset, custom }

// --- Public API ---
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

// --- Sheet widget ---

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
  _PresetCategory _category = _PresetCategory.general;
  _SizeItem? _selectedItem;
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
    for (final cat in _PresetCategory.values) {
      for (final item in _presetData[cat]!) {
        if (item.w == widget.currentWidth && item.h == widget.currentHeight) {
          _mode = _Mode.preset;
          _category = cat;
          _selectedItem = item;
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
    if (_selectedItem != null) return (_selectedItem!.w, _selectedItem!.h);
    return (1024, 1024);
  }

  String? get _validationError {
    if (_mode != _Mode.custom) return null;
    final (w, h) = _computedSize;
    if (w % 16 != 0 || h % 16 != 0) return '宽高须为 16 的倍数';
    if (w > 3840 || h > 3840) return '单边最大 3840px';
    final pixels = w * h;
    if (pixels < 655360) return '总像素不能少于 655,360';
    if (pixels > 8294400) return '总像素不能超过 8,294,400';
    final ratio = w > h ? w / h : h / w;
    if (ratio > 3.0) return '长短边比例不能超过 3:1';
    return null;
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
            _buildHeader(size),
            const SizedBox(height: 16),
            _buildModeTabs(),
            const SizedBox(height: 16),
            if (_mode == _Mode.auto) _buildAutoContent(),
            if (_mode == _Mode.preset) _buildPresetContent(),
            if (_mode == _Mode.custom) _buildCustomContent(),
            const SizedBox(height: 20),
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

  Widget _buildHeader((int, int) size) {
    return Row(
      children: [
        Text(
          '设置图像尺寸',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppThemeTokens.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            size.$1 == 0 ? '自动' : '${size.$1}×${size.$2}',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppThemeTokens.primary,
              fontWeight: FontWeight.w700,
            ),
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
          _tabButton('预设', _mode == _Mode.preset, () {
            setState(() => _mode = _Mode.preset);
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

  Widget _buildPresetContent() {
    final items = _presetData[_category]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 36,
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
              },
            ),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _PresetCategory.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = _PresetCategory.values[index];
                final active = _category == cat;
                return _categoryChip(cat, active);
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final crossAxisCount = width > 500 ? 6 : width > 360 ? 5 : 4;
            final gridHeight = width > 400 ? 360.0 : 280.0;
            return SizedBox(
              height: gridHeight,
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: 1.05,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) => _presetTile(items[index]),
              ),
            );
          },
        ),
      ],
    );
  }
  Widget _categoryChip(_PresetCategory cat, bool active) {
    return GestureDetector(
      onTap: () => setState(() => _category = cat),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppThemeTokens.primary.withValues(alpha: 0.08) : AppThemeTokens.surfaceSoft,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: active ? AppThemeTokens.primary : AppThemeTokens.border.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(cat.icon, size: 14, color: active ? AppThemeTokens.primary : AppThemeTokens.textSecondary),
            const SizedBox(width: 4),
            Text(
              cat.label,
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

  Widget _presetTile(_SizeItem item) {
    final active = _selectedItem == item && _mode == _Mode.preset;
    final iconData = item.icon;
    final isHorizontal = item.w > item.h;
    final isSquare = item.w == item.h;
    final boxW = isHorizontal || isSquare ? 18.0 : 18.0 * item.w / item.h;
    final boxH = !isHorizontal || isSquare ? 18.0 : 18.0 * item.h / item.w;

    return GestureDetector(
      onTap: () => setState(() => _selectedItem = item),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        decoration: BoxDecoration(
          color: active ? AppThemeTokens.primary.withValues(alpha: 0.08) : AppThemeTokens.surfaceSoft,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? AppThemeTokens.primary : AppThemeTokens.border.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (iconData != null)
              Icon(iconData, size: 18, color: active ? AppThemeTokens.primary : AppThemeTokens.textSecondary)
            else
              SizedBox(
                width: 20,
                height: 20,
                child: Center(
                  child: Container(
                    width: boxW,
                    height: boxH,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(
                        color: active ? AppThemeTokens.primary : AppThemeTokens.textSecondary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 2),
            Text(
              item.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: active ? AppThemeTokens.primary : AppThemeTokens.textPrimary,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                fontSize: 11,
              ),
            ),
            Text(
              '${item.w}×${item.h}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppThemeTokens.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildCustomContent() {
    final error = _validationError;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
        ),
        const SizedBox(height: 8),
        if (error != null)
          Text(
            error,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.red.shade700,
              fontWeight: FontWeight.w600,
            ),
          )
        else
          Text(
            '宽高须为16的倍数 · 单边≤3840 · 总像素≤8,294,400 · 比例≤3:1',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppThemeTokens.textSecondary,
              fontSize: 11,
            ),
          ),
      ],
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
            onPressed: _validationError == null
                ? () => Navigator.of(context).pop(size)
                : null,
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
}

