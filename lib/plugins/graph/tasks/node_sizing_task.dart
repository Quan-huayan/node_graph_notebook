import '../../../../core/execution/cpu_task.dart';
import '../../../../core/models/enums.dart';
import '../../../../core/models/node.dart';

/// 节点尺寸计算任务
///
/// 在后台 isolate 中计算节点尺寸
/// 根据节点类型和 viewMode 确定合适的尺寸
class NodeSizingTask extends CPUTask<NodeSizeResult> {
  /// 创建节点尺寸计算任务
  NodeSizingTask({
    required this.node,
    this.fontSize = 14.0,
    this.padding = 16.0,
  });

  /// 节点数据
  final Node node;
  /// 字体大小
  final double fontSize;
  /// 内边距
  final double padding;

  @override
  String get name => 'NodeSizing(${node.id})';

  @override
  String get taskType => 'NodeSizing';

  @override
  Map<String, dynamic> serialize() => {
      'taskType': taskType,
      'taskName': name,
      'isFolder': node.isFolder,
      'viewMode': node.viewMode.name,
      'title': node.title,
      'content': node.content ?? '',
      'fontSize': fontSize,
      'padding': padding,
    };

  @override
  Future<NodeSizeResult> execute() async {
    // 文件夹节点使用稍大的尺寸
    if (node.isFolder) {
      return const NodeSizeResult(
        width: 200,
        height: 80,
        isFolder: true,
      );
    }

    // 根据 viewMode 计算尺寸
    switch (node.viewMode) {
      case NodeViewMode.titleOnly:
        // 仅标题模式：根据标题长度动态计算
        final titleWidth = _calculateTextWidth(node.title, fontSize);
        final width = (titleWidth + padding * 2).clamp(150.0, 300.0);
        return NodeSizeResult(
          width: width,
          height: 40,
          viewMode: node.viewMode,
        );

      case NodeViewMode.compact:
        // 紧凑模式：固定尺寸正方形
        return const NodeSizeResult(
          width: 80,
          height: 80,
          viewMode: NodeViewMode.compact,
        );

      case NodeViewMode.titleWithPreview:
        // 标题+预览模式
        final titleWidth = _calculateTextWidth(node.title, fontSize);
        final content = node.content ?? '';
        final previewContent = content.length > 50 ? '${content.substring(0, 50)}...' : content;
        final contentWidth = _calculateTextWidth(previewContent, fontSize * 0.9);
        final width = [titleWidth, contentWidth].reduce((a, b) => a > b ? a : b);
        return NodeSizeResult(
          width: (width + padding * 2).clamp(200.0, 300.0),
          height: 120,
          viewMode: NodeViewMode.titleWithPreview,
        );

      case NodeViewMode.fullContent:
        // 完整内容模式
        final titleWidth = _calculateTextWidth(node.title, fontSize);
        final content = node.content ?? '';
        final contentWidth = _calculateTextWidth(content, fontSize * 0.9);
        final width = [titleWidth, contentWidth].reduce((a, b) => a > b ? a : b);
        // 根据内容长度估算高度
        final lineCount = (content.length / 40).ceil().clamp(3, 15);
        final height = 40.0 + lineCount * (fontSize * 1.5);
        return NodeSizeResult(
          width: (width + padding * 2).clamp(300.0, 500.0),
          height: height.clamp(200.0, 500.0),
          viewMode: NodeViewMode.fullContent,
        );
    }
  }

  /// 简化的文本宽度计算（估算）
  double _calculateTextWidth(String text, double fontSize) {
    // 简单估算：英文字符约为字体大小的 0.6 倍，中文字符约为字体大小
    final chineseChars = text.replaceAll(RegExp(r'[^\u4e00-\u9fa5]'), '');
    final otherCharCount = text.length - chineseChars.length;
    return chineseChars.length * fontSize + otherCharCount * fontSize * 0.6;
  }
}

/// 节点尺寸计算结果
class NodeSizeResult {
  /// 创建节点尺寸计算结果
  const NodeSizeResult({
    required this.width,
    required this.height,
    this.isFolder = false,
    this.viewMode,
  });

  /// 节点宽度
  final double width;
  /// 节点高度
  final double height;
  /// 是否为文件夹节点
  final bool isFolder;
  /// 节点视图模式
  final NodeViewMode? viewMode;
}

/// 序列化的节点尺寸任务（用于 isolate 内部）
class NodeSizingTaskSerialized extends CPUTask<Map<String, dynamic>> {
  /// 创建序列化的节点尺寸任务
  ///
  /// ### 参数
  /// - `_data` - 包含任务数据的 Map
  NodeSizingTaskSerialized(this._data);

  final Map<String, dynamic> _data;

  @override
  String get name => _data['taskName'] as String;

  @override
  String get taskType => 'NodeSizing';

  @override
  Map<String, dynamic> serialize() => _data;

  @override
  Future<Map<String, dynamic>> execute() async {
    final isFolder = _data['isFolder'] as bool? ?? false;
    final viewMode = _data['viewMode'] as String?;
    final title = _data['title'] as String;
    final content = _data['content'] as String? ?? '';
    final fontSize = _data['fontSize'] as double;

    // 简化的节点尺寸计算
    double width;
    double height;

    if (isFolder) {
      // 文件夹节点
      width = 120;
      height = 80;
    } else {
      // 普通节点尺寸根据视图模式计算
      switch (viewMode) {
        case 'titleOnly':
          width = title.length * fontSize * 0.6;
          height = fontSize * 1.5;
          break;
        case 'compact':
          width = 80;
          height = 80;
          break;
        case 'titleWithPreview':
          width = 200;
          height = 120;
          break;
        case 'fullContent':
        default:
          // 根据内容长度计算尺寸
          final contentLines = content.split('\n').length;
          final contentWidth = content.length > 100 ? 300 : 200;
          width = contentWidth.toDouble();
          height = (200 + contentLines * 20).toDouble();
          break;
      }
    }

    return {
      'width': width,
      'height': height,
      'isFolder': isFolder,
      'viewMode': viewMode,
    };
  }
}
