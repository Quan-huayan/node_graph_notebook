import 'dart:io';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';
import '../core/models/models.dart';
import '../core/repositories/repositories.dart';
import '../ai/ai_service.dart';
import 'models/models.dart';
import 'converter_service.dart';

/// 转换服务实现
class ConverterServiceImpl implements ConverterService {
  ConverterServiceImpl(
    this._nodeRepository, [
    AIService? aiService,
  ]) : _aiService = aiService;

  final NodeRepository _nodeRepository;
  final AIService? _aiService;
  final Uuid _uuid = const Uuid();

  @override
  Future<List<Node>> markdownToNodes({
    required String markdown,
    required ConversionRule rule,
    String? filename,
  }) async {
    final nodes = <Node>[];

    switch (rule.splitStrategy) {
      case SplitStrategy.heading:
        nodes.addAll(_splitByHeading(markdown, rule.headingRule!));
        break;
      case SplitStrategy.separator:
        nodes.addAll(_splitBySeparator(markdown, rule.separatorRule!));
        break;
      case SplitStrategy.aiSmart:
        final aiNodes = await smartSplit(markdown: markdown);
        nodes.addAll(aiNodes);
        break;
      case SplitStrategy.customRegex:
        nodes.addAll(_splitByCustomRegex(markdown, rule.customRule!));
        break;
    }

    // 提取连接
    if (rule.extractConnections) {
      _extractConnections(nodes);
    }

    // 提取标签
    if (rule.extractTags) {
      _extractTags(nodes);
    }

    // 解析 Frontmatter
    if (rule.parseFrontmatter) {
      _parseFrontmatter(nodes);
    }

    return nodes;
  }

  @override
  Future<String> nodesToMarkdown({
    required List<Node> nodes,
    required MergeRule rule,
  }) async {
    final buffer = StringBuffer();

    switch (rule.strategy) {
      case MergeStrategy.hierarchy:
        buffer.writeln(_mergeHierarchy(nodes, rule.hierarchyRule!));
        break;
      case MergeStrategy.sequence:
        buffer.writeln(_mergeSequence(nodes, rule.sequenceRule!));
        break;
      case MergeStrategy.custom:
        buffer.writeln(_mergeCustom(nodes, rule.customRule!));
        break;
    }

    return buffer.toString();
  }

  @override
  Future<List<Node>> fileToNodes({
    required String filePath,
    required ConversionRule rule,
  }) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw ConverterException('File not found: $filePath');
    }

    final markdown = await file.readAsString();
    final filename = filePath.split(RegExp(r'[/\\]')).last;

    return markdownToNodes(
      markdown: markdown,
      rule: rule,
      filename: filename,
    );
  }

  @override
  Future<void> nodesToFile({
    required List<Node> nodes,
    required String filePath,
    required MergeRule rule,
  }) async {
    final markdown = await nodesToMarkdown(
      nodes: nodes,
      rule: rule,
    );

    final file = File(filePath);
    await file.writeAsString(markdown);
  }

  @override
  Future<ConversionResult> convertDirectory({
    required String inputPath,
    required String outputPath,
    required ConversionConfig config,
    Function(int, int)? onProgress,
  }) async {
    int successCount = 0;
    int failureCount = 0;
    final errors = <String>[];
    final createdNodeIds = <String>[];
    final startTime = DateTime.now();

    final inputDir = Directory(inputPath);
    if (!inputDir.existsSync()) {
      throw ConverterException('Input directory not found: $inputPath');
    }

    // 创建输出目录
    final outputDir = Directory(outputPath);
    if (!outputDir.existsSync()) {
      await outputDir.create(recursive: true);
    }

    // 递归处理所有 .md 文件
    final files = await _listMarkdownFiles(inputDir);
    final totalFiles = files.length;

    for (int i = 0; i < files.length; i++) {
      try {
        final nodes = await fileToNodes(
          filePath: files[i].path,
          rule: config.rule,
        );

        for (final node in nodes) {
          await _nodeRepository.save(node);
          createdNodeIds.add(node.id);
        }

        successCount++;
        onProgress?.call(i + 1, totalFiles);
      } catch (e) {
        failureCount++;
        errors.add('${files[i].path}: $e');
      }
    }

    final duration = DateTime.now().difference(startTime);

    return ConversionResult(
      successCount: successCount,
      failureCount: failureCount,
      errors: errors,
      duration: duration,
      createdNodeIds: createdNodeIds,
    );
  }

  @override
  Future<List<Node>> smartSplit({
    required String markdown,
  }) async {
    if (_aiService == null) {
      // 如果没有 AI 服务，使用简单的按标题拆分
      return _splitByHeading(markdown, const HeadingSplitRule(level: 2));
    }

    try {
      // 使用 AI 分析文档结构并返回拆分建议
      final prompt = '''请分析以下 Markdown 文档，将其智能拆分成多个主题节点。

要求：
1. 每个节点应该是一个独立的主题
2. 节点之间应该有逻辑关联
3. 返回 JSON 格式，包含节点列表，每个节点有 title 和 content
4. 标题应该简洁明了，能够概括节点内容

文档内容：
$markdown

请返回 JSON 格式：
{
  "nodes": [
    {"title": "节点标题", "content": "节点内容"},
    ...
  ]
}''';

      final response = await _aiService.generateNode(
        prompt: prompt,
        type: NodeType.content,
      );

      // 解析 AI 响应
      final nodes = <Node>[];
      final content = response.content ?? '';

      // 尝试从响应中提取 JSON
      final jsonMatch = RegExp(r'\{[\s\S]*\}', multiLine: true).firstMatch(content);
      if (jsonMatch != null) {
        try {
          final jsonStr = jsonMatch.group(0)!;
          final jsonData = jsonDecode(jsonStr) as Map<String, dynamic>;
          final nodesList = jsonData['nodes'] as List<dynamic>?;

          if (nodesList != null) {
            for (final nodeData in nodesList) {
              final nodeMap = nodeData as Map<String, dynamic>;
              nodes.add(_createNode(
                nodeMap['title'] as String? ?? 'Untitled',
                nodeMap['content'] as String? ?? '',
                false,
              ));
            }
          }
        } catch (e) {
          // JSON 解析失败，回退到简单拆分
        }
      }

      // 如果 AI 拆分失败或没有结果，使用简单拆分
      if (nodes.isEmpty) {
        return _splitByHeading(markdown, const HeadingSplitRule(level: 2));
      }

      return nodes;
    } catch (e) {
      // AI 调用失败，回退到简单拆分
      return _splitByHeading(markdown, const HeadingSplitRule(level: 2));
    }
  }

  @override
  Future<ConversionValidation> validateConversion({
    required String markdown,
    required List<Node> nodes,
  }) async {
    final warnings = <String>[];
    final suggestions = <String>[];

    // 检查是否有空标题
    for (final node in nodes) {
      if (node.title.trim().isEmpty) {
        warnings.add('Node ${node.id} has empty title');
      }
    }

    // 检查是否有未连接的节点
    final connectedIds = <String>{};
    for (final node in nodes) {
      connectedIds.addAll(node.references.keys);
    }

    for (final node in nodes) {
      if (!connectedIds.contains(node.id)) {
        suggestions.add('Node "${node.title}" is not connected to any other node');
      }
    }

    return ConversionValidation(
      isValid: true,
      warnings: warnings,
      suggestions: suggestions,
    );
  }

  /// 按标题拆分
  List<Node> _splitByHeading(String markdown, HeadingSplitRule rule) {
    final nodes = <Node>[];
    final lines = markdown.split('\n');

    String? currentTitle;
    final List<String> currentContent = [];

    for (final line in lines) {
      // 检查是否是标题
      final headingMatch = RegExp(r'^(#{1,6})\s+(.+)$').firstMatch(line);
      if (headingMatch != null) {
        final level = headingMatch.group(1)!.length;
        final title = headingMatch.group(2)!;

        // 保存之前的节点
        if (currentTitle != null &&
            (currentContent.isNotEmpty || rule.keepOriginalHeading)) {
          nodes.add(_createNode(
            currentTitle,
            currentContent.join('\n'),
            rule.keepOriginalHeading,
          ));
        }

        // 检查是否是目标级别的标题
        if (level == rule.level ||
            (rule.minContentLength == null || level <= rule.level)) {
          currentTitle = title;
          currentContent.clear();

          if (rule.keepOriginalHeading) {
            currentContent.add(line);
          }
        } else if (currentTitle != null) {
          // 子标题，添加到内容
          currentContent.add(line);
        }
      } else if (currentTitle != null) {
        currentContent.add(line);
      }
    }

    // 保存最后一个节点
    if (currentTitle != null) {
      nodes.add(_createNode(
        currentTitle,
        currentContent.join('\n'),
        rule.keepOriginalHeading,
      ));
    }

    return nodes;
  }

  /// 按分隔符拆分
  List<Node> _splitBySeparator(String markdown, SeparatorSplitRule rule) {
    final nodes = <Node>[];
    final parts = markdown.split(RegExp(rule.pattern));

    for (int i = 0; i < parts.length; i++) {
      final content = parts[i].trim();
      if (content.isNotEmpty) {
        // 从第一行提取标题
        final lines = content.split('\n');
        final title = lines.first.replaceAll(RegExp(r'^#+\s+'), '').trim();

        nodes.add(_createNode(
          title.isEmpty ? 'Section ${i + 1}' : title,
          content,
          false,
        ));
      }
    }

    return nodes;
  }

  /// 按自定义正则拆分
  List<Node> _splitByCustomRegex(String markdown, CustomRegexRule rule) {
    final nodes = <Node>[];
    final parts = markdown.split(RegExp(rule.pattern));

    for (int i = 0; i < parts.length; i++) {
      final content = parts[i].trim();
      if (content.isNotEmpty) {
        nodes.add(_createNode(
          'Section ${i + 1}',
          content,
          false,
        ));
      }
    }

    return nodes;
  }

  /// 层级合并
  String _mergeHierarchy(List<Node> nodes, HierarchyMergeRule rule) {
    final buffer = StringBuffer();

    // 添加目录
    if (rule.addToc) {
      buffer.writeln('# Table of Contents\n');
      for (final node in nodes) {
        final indent = '  ' * (node.references.length);
        buffer.writeln('$indent- [${node.title}](#${_slugify(node.title)})');
      }
      buffer.writeln();
    }

    // 合并节点内容
    for (final node in nodes) {
      if (rule.headingLevels) {
        final level = (node.references.length + 1).clamp(1, 6);
        buffer.writeln('${'#' * level} ${node.title}');
      } else {
        buffer.writeln(node.title);
      }
      buffer.writeln();
      buffer.writeln(node.content ?? '');
      buffer.writeln();
      buffer.writeln(rule.separator);
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// 顺序合并
  String _mergeSequence(List<Node> nodes, SequenceMergeRule rule) {
    final buffer = StringBuffer();

    // 排序
    final sortedNodes = List<Node>.from(nodes);
    if (rule.sortBy == SortBy.createdAt) {
      sortedNodes.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    } else if (rule.sortBy == SortBy.updatedAt) {
      sortedNodes.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    } else if (rule.sortBy == SortBy.title) {
      sortedNodes.sort((a, b) => a.title.compareTo(b.title));
    }

    // 合并
    for (final node in sortedNodes) {
      buffer.writeln('# ${node.title}');
      buffer.writeln();

      if (rule.addMetadata) {
        buffer.writeln('*Created: ${node.createdAt}*');
        buffer.writeln('*Updated: ${node.updatedAt}*');
        buffer.writeln();
      }

      buffer.writeln(node.content ?? '');
      buffer.writeln();
      buffer.writeln(rule.separator);
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// 自定义合并
  String _mergeCustom(List<Node> nodes, CustomMergeRule rule) {
    String result = rule.template;

    for (final node in nodes) {
      result = result.replaceAll('{title}', node.title);
      result = result.replaceAll('{content}', node.content ?? '');
      result = result.replaceAll(
        '{created_at}',
        node.createdAt.toIso8601String(),
      );
      result = result.replaceAll(
        '{updated_at}',
        node.updatedAt.toIso8601String(),
      );

      final tags = node.metadata['tags'] as List<dynamic>? ?? [];
      result = result.replaceAll('{tags}', tags.join(', '));
    }

    return result;
  }

  /// 提取连接
  void _extractConnections(List<Node> nodes) {
    final titleToId = <String, String>{};
    for (final node in nodes) {
      titleToId[node.title.toLowerCase()] = node.id;
    }

    for (final node in nodes) {
      final content = node.content ?? '';
      final links = _extractWikiLinks(content);

      for (final link in links) {
        final targetId = titleToId[link.toLowerCase()];
        if (targetId != null && targetId != node.id) {
          node.references[targetId] = NodeReference(
            nodeId: targetId,
            type: ReferenceType.mentions,
            role: 'wiki_link',
          );
        }
      }
    }
  }

  /// 提取标签
  void _extractTags(List<Node> nodes) {
    for (final node in nodes) {
      final content = node.content ?? '';
      final tags = _extractTagsFromContent(content);

      if (tags.isNotEmpty) {
        node.metadata['tags'] = tags;
      }
    }
  }

  /// 解析 Frontmatter
  void _parseFrontmatter(List<Node> nodes) {
    for (final node in nodes) {
      final content = node.content ?? '';
      if (!content.startsWith('---')) continue;

      final end = content.indexOf('---', 3);
      if (end == -1) continue;

      final frontmatter = content.substring(3, end);
      final metadata = _parseYamlFrontmatter(frontmatter);

      // 将解析的元数据合并到节点的 metadata 中
      if (metadata.isNotEmpty) {
        for (final entry in metadata.entries) {
          node.metadata[entry.key] = entry.value;
        }
      }
    }
  }

  /// 简单的 YAML frontmatter 解析器
  Map<String, dynamic> _parseYamlFrontmatter(String yaml) {
    final metadata = <String, dynamic>{};
    final lines = yaml.split('\n');

    String? currentKey;
    List<String> listValues = [];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;

      // 处理键值对
      final keyValueMatch = RegExp(r'^([^:]+):\s*(.*)$').firstMatch(trimmed);
      if (keyValueMatch != null) {
        // 保存之前的键
        if (currentKey != null && listValues.isNotEmpty) {
          metadata[currentKey] = listValues;
          listValues = [];
        }

        currentKey = keyValueMatch.group(1)!.trim();
        final value = keyValueMatch.group(2)!.trim();

        // 如果值不为空，直接设置
        if (value.isNotEmpty && !value.startsWith('-')) {
          metadata[currentKey] = _parseYamlValue(value);
        }
      }
      // 处理列表项
      else if (trimmed.startsWith('-') && currentKey != null) {
        final item = trimmed.substring(1).trim();
        if (item.isNotEmpty) {
          listValues.add(_parseYamlValue(item).toString());
        }
      }
    }

    // 保存最后一个列表
    if (currentKey != null && listValues.isNotEmpty) {
      metadata[currentKey] = listValues;
    }

    return metadata;
  }

  /// 解析 YAML 值
  dynamic _parseYamlValue(String value) {
    // 布尔值
    if (value == 'true') return true;
    if (value == 'false') return false;

    // 数字
    final parsedNum = num.tryParse(value);
    if (parsedNum != null) return parsedNum;

    // 带引号的字符串
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
      return value.substring(1, value.length - 1);
    }

    // 数组格式 [a, b, c]
    if (value.startsWith('[') && value.endsWith(']')) {
      final items = value.substring(1, value.length - 1).split(',');
      return items.map((e) => e.trim()).toList();
    }

    // 默认返回字符串
    return value;
  }

  List<String> _extractWikiLinks(String content) {
    final pattern = RegExp(r'\[\[([^\]]+)\]\]');
    final matches = pattern.allMatches(content);
    return matches.map((m) => m.group(1)!).toList();
  }

  List<String> _extractTagsFromContent(String content) {
    final tags = <String>[];
    final pattern = RegExp(r'#([a-zA-Z0-9_\u4e00-\u9fa5]+)');
    final matches = pattern.allMatches(content);

    for (final match in matches) {
      final tag = match.group(1)!;
      if (!tags.contains(tag)) {
        tags.add(tag);
      }
    }

    return tags;
  }

  Node _createNode(String title, String content, bool keepHeading) {
    final now = DateTime.now();
    return Node(
      id: _uuid.v4(),
      type: NodeType.content,
      title: title,
      content: content,
      references: {},
      position: const Offset(100, 100),
      size: const Size(300, 400),
      viewMode: NodeViewMode.titleWithPreview,
      createdAt: now,
      updatedAt: now,
      metadata: {},
    );
  }

  String _slugify(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'[\s]+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
  }

  Future<List<File>> _listMarkdownFiles(Directory dir) async {
    final files = <File>[];
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.md')) {
        files.add(entity);
      }
    }
    return files;
  }
}
