import '../../../../core/models/models.dart';
import '../models/models.dart';

/// 转换服务接口，提供 Markdown 和节点之间的转换功能
abstract class ConverterService {
  /// 将 Markdown 内容转换为节点列表
  /// 
  /// [markdown] - Markdown 内容
  /// [rule] - 转换规则，定义如何拆分 Markdown
  /// [filename] - 可选的文件名，用于识别来源
  /// 
  /// 返回转换后的节点列表
  Future<List<Node>> markdownToNodes({
    required String markdown,
    required ConversionRule rule,
    String? filename,
  });

  /// 将节点列表转换为 Markdown 内容
  /// 
  /// [nodes] - 要转换的节点列表
  /// [rule] - 合并规则，定义如何将多个节点合并为单个 Markdown 文档
  /// 
  /// 返回生成的 Markdown 字符串
  Future<String> nodesToMarkdown({
    required List<Node> nodes,
    required MergeRule rule,
  });

  /// 从文件读取 Markdown 并转换为节点列表
  /// 
  /// [filePath] - Markdown 文件路径
  /// [rule] - 转换规则，定义如何拆分 Markdown
  /// 
  /// 返回转换后的节点列表
  Future<List<Node>> fileToNodes({
    required String filePath,
    required ConversionRule rule,
  });

  /// 将节点列表转换为 Markdown 并写入文件
  /// 
  /// [nodes] - 要转换的节点列表
  /// [filePath] - 输出文件路径
  /// [rule] - 合并规则，定义如何将多个节点合并为单个 Markdown 文档
  Future<void> nodesToFile({
    required List<Node> nodes,
    required String filePath,
    required MergeRule rule,
  });

  /// 批量转换目录中的 Markdown 文件
  /// 
  /// [inputPath] - 输入目录路径
  /// [outputPath] - 输出目录路径
  /// [config] - 转换配置
  /// [onProgress] - 进度回调函数，参数为当前进度和总任务数
  /// 
  /// 返回转换结果，包含成功和失败的统计信息
  Future<ConversionResult> convertDirectory({
    required String inputPath,
    required String outputPath,
    required ConversionConfig config,
    Function(int, int)? onProgress,
  });

  /// 使用 AI 智能拆分 Markdown 内容为节点
  /// 
  /// [markdown] - 要拆分的 Markdown 内容
  /// 
  /// 返回智能拆分后的节点列表
  Future<List<Node>> smartSplit({required String markdown});

  /// 验证转换结果
  /// 
  /// [markdown] - 原始 Markdown 内容
  /// [nodes] - 转换后的节点列表
  /// 
  /// 返回验证结果，包含警告和建议
  Future<ConversionValidation> validateConversion({
    required String markdown,
    required List<Node> nodes,
  });
}
