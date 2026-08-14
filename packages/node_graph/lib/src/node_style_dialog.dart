/// NodeStyleDialog —— 节点样式对话框（M7.3，判据② 外观直写）。
///
/// 编辑颜色（12 色板 + 默认）/ 尺寸（宽高，可空 = 默认）/ 形态
/// （卡片 / 圆圈）→ 返回 [NodeStyle]；全缺省 = 恢复默认。写路径由
/// 调用方执行（uiStateStore.set/remove，不发结构事件）。
library;

import 'package:appframe/appframe.dart';
import 'package:flutter/material.dart';

/// 样式对话框。
///
/// [initial] 当前样式（null = 默认）；返回新的样式（含空字段 = 恢复默认）。
class NodeStyleDialog extends StatefulWidget {
  /// 注入 i18n 与当前样式。
  const NodeStyleDialog({super.key, required this.i18n, this.initial});

  /// 国际化服务。
  final I18nService i18n;

  /// 当前样式（null = 全默认）。
  final NodeStyle? initial;

  @override
  State<NodeStyleDialog> createState() => _NodeStyleDialogState();
}

class _NodeStyleDialogState extends State<NodeStyleDialog> {
  /// 12 色板（含默认底色，选中高亮）。
  static const List<Color> _palette = <Color>[
    Color(0xFFEF5350), // red 400
    Color(0xFFEC407A), // pink 400
    Color(0xFFAB47BC), // purple 400
    Color(0xFF7E57C2), // deep purple 400
    Color(0xFF5C6BC0), // indigo 400
    Color(0xFF42A5F5), // blue 400
    Color(0xFF26C6DA), // cyan 400
    Color(0xFF26A69A), // teal 400
    Color(0xFF66BB6A), // green 400
    Color(0xFFFFA726), // orange 400
    Color(0xFFFF7043), // deep orange 400
    Color(0xFF8D6E63), // brown 400
  ];

  late String? _color;
  late TextEditingController _widthController;
  late TextEditingController _heightController;
  late NodeCardMode _mode;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _color = initial?.color;
    _widthController = TextEditingController(
      text: initial?.width?.toStringAsFixed(0) ?? '',
    );
    _heightController = TextEditingController(
      text: initial?.height?.toStringAsFixed(0) ?? '',
    );
    _mode = initial?.mode ?? NodeCardMode.card;
  }

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  /// 输入 → 样式（非法/空 → null 字段）。
  NodeStyle _collect() {
    final width = double.tryParse(_widthController.text);
    final height = double.tryParse(_heightController.text);
    return NodeStyle(
      color: _color,
      width: (width == null || width <= 0) ? null : width,
      height: (height == null || height <= 0) ? null : height,
      mode: _mode == NodeCardMode.card ? null : NodeCardMode.circle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = widget.i18n;
    return AlertDialog(
      title: Text(i18n.t('node.style')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 颜色：12 色板 + 默认。
            Text(
              i18n.t('style.color'),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final color in _palette)
                  _swatch(color, selected: _color == _hex(color)),
                _defaultSwatch(selected: _color == null),
              ],
            ),
            const SizedBox(height: 16),
            // 尺寸：宽 / 高（空 = 默认）。
            Text(
              i18n.t('style.width') + ' / ' + i18n.t('style.height'),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _widthController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: i18n.t('style.width'),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _heightController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: i18n.t('style.height'),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 形态：卡片 / 圆圈。
            Text(
              i18n.t('style.mode'),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            SegmentedButton<NodeCardMode>(
              segments: <ButtonSegment<NodeCardMode>>[
                ButtonSegment<NodeCardMode>(
                  value: NodeCardMode.card,
                  label: Text(i18n.t('style.card')),
                  icon: const Icon(Icons.crop_square),
                ),
                ButtonSegment<NodeCardMode>(
                  value: NodeCardMode.circle,
                  label: Text(i18n.t('style.circle')),
                  icon: const Icon(Icons.circle_outlined),
                ),
              ],
              selected: <NodeCardMode>{_mode},
              onSelectionChanged: (selection) =>
                  setState(() => _mode = selection.first),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, const NodeStyle()),
          child: Text(i18n.t('style.reset')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(i18n.t('dialog.cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _collect()),
          child: Text(i18n.t('dialog.save')),
        ),
      ],
    );
  }

  /// 色块（选中描边）。
  Widget _swatch(Color color, {required bool selected}) => InkWell(
    onTap: () => setState(() => _color = _hex(color)),
    borderRadius: BorderRadius.circular(8),
    child: Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outlineVariant,
          width: selected ? 3 : 1,
        ),
      ),
    ),
  );

  /// 默认色块（不选任何颜色）。
  Widget _defaultSwatch({required bool selected}) => InkWell(
    onTap: () => setState(() => _color = null),
    borderRadius: BorderRadius.circular(8),
    child: Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outlineVariant,
          width: selected ? 3 : 1,
        ),
      ),
      child: const Icon(Icons.block, size: 16),
    ),
  );

  /// Color → '#RRGGBB'。
  static String _hex(Color color) {
    final rgb = (color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return '#$rgb';
  }
}
