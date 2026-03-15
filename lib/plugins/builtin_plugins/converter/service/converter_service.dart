import '../../../../core/models/models.dart';
import '../models/models.dart';

/// 转换服务接口
abstract class ConverterService {
  /// Markdown → 节点
  Future<List<Node>> markdownToNodes({
    required String markdown,
    required ConversionRule rule,
    String? filename,
  });

  /// 节点 → Markdown
  Future<String> nodesToMarkdown({
    required List<Node> nodes,
    required MergeRule rule,
  });

  /// 文件 → 节点
  Future<List<Node>> fileToNodes({
    required String filePath,
    required ConversionRule rule,
  });

  /// 节点 → 文件
  Future<void> nodesToFile({
    required List<Node> nodes,
    required String filePath,
    required MergeRule rule,
  });

  /// 批量转换目录
  Future<ConversionResult> convertDirectory({
    required String inputPath,
    required String outputPath,
    required ConversionConfig config,
    Function(int, int)? onProgress,
  });

  /// 智能拆分（AI）
  Future<List<Node>> smartSplit({
    required String markdown,
  });

  /// 验证转换
  Future<ConversionValidation> validateConversion({
    required String markdown,
    required List<Node> nodes,
  });
}