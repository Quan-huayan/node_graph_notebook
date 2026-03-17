import 'package:flutter/painting.dart';
import '../../../../core/execution/cpu_task.dart';

/// 文本布局计算任务
///
/// 在后台 isolate 中计算文本布局度量
/// 避免阻塞 UI 线程
class TextLayoutTask extends CPUTask<TextLayoutResult> {
  /// 创建文本布局计算任务
  TextLayoutTask({
    required this.text,
    required this.fontSize,
    this.maxWidth,
    this.fontWeight = FontWeight.normal,
    this.textAlign = TextAlign.left,
  });

  /// 文本内容
  final String text;
  /// 字体大小
  final double fontSize;
  /// 最大宽度
  final double? maxWidth;
  /// 字体权重
  final FontWeight fontWeight;
  /// 文本对齐方式
  final TextAlign textAlign;

  @override
  String get name => 'TextLayout("$text")';

  @override
  String get taskType => 'TextLayout';

  @override
  Map<String, dynamic> serialize() => {
      'taskType': taskType,
      'taskName': name,
      'text': text,
      'fontSize': fontSize,
      'maxWidth': maxWidth,
      'fontWeight': fontWeight.value,
      'textAlign': textAlign.index,
    };

  @override
  Future<TextLayoutResult> execute() async {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: textAlign,
    );

    // 计算布局
    final maxWidthValue = maxWidth;
    if (maxWidthValue != null) {
      painter.layout(maxWidth: maxWidthValue);
    } else {
      painter.layout();
    }

    return TextLayoutResult(
      width: painter.width,
      height: painter.height,
      didExceedMaxWidth: maxWidthValue != null && painter.width > maxWidthValue,
      lineCount: painter.computeLineMetrics(),
    );
  }
}

/// 文本布局计算结果
class TextLayoutResult {
  /// 创建文本布局计算结果
  const TextLayoutResult({
    required this.width,
    required this.height,
    this.didExceedMaxWidth = false,
    this.lineCount = const [],
  });

  /// 文本宽度
  final double width;
  /// 文本高度
  final double height;
  /// 是否超出最大宽度
  final bool didExceedMaxWidth;
  /// 行度量
  final List<LineMetrics> lineCount;
}

/// 序列化的文本布局任务（用于 isolate 内部）
class TextLayoutTaskSerialized extends CPUTask<Map<String, dynamic>> {
  /// 创建序列化的文本布局任务
  ///
  /// ### 参数
  /// - `_data` - 包含任务数据的 Map
  TextLayoutTaskSerialized(this._data);

  final Map<String, dynamic> _data;

  @override
  String get name => _data['taskName'] as String;

  @override
  String get taskType => 'TextLayout';

  @override
  Map<String, dynamic> serialize() => _data;

  @override
  Future<Map<String, dynamic>> execute() async {
    // 在 isolate 中执行文本布局计算
    // 注意：这里不能使用 TextPainter（依赖 Flutter），所以使用简化计算

    final text = _data['text'] as String;
    final fontSize = _data['fontSize'] as double;
    final maxWidth = _data['maxWidth'] as double?;

    // 简化的文本尺寸估算
    final avgCharWidth = fontSize * 0.6;
    final estimatedWidth = text.length * avgCharWidth;
    final finalWidth = maxWidth != null && estimatedWidth > maxWidth
        ? maxWidth
        : estimatedWidth;

    // 估算行数
    final lineCount = maxWidth != null
        ? (estimatedWidth / maxWidth).ceil().clamp(1, 100)
        : 1;

    final height = lineCount * fontSize * 1.2;

    return {
      'width': finalWidth,
      'height': height,
      'didExceedMaxWidth': maxWidth != null && estimatedWidth > maxWidth,
      'lineCount': <Map<String, dynamic>>[],
    };
  }
}