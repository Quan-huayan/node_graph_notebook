import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import '../models/models.dart';
import 'exceptions.dart';

/// 节点仓库接口
abstract class NodeRepository {
  /// 保存节点
  Future<void> save(Node node);

  /// 加载节点
  Future<Node?> load(String nodeId);

  /// 删除节点
  Future<void> delete(String nodeId);

  /// 批量保存
  Future<void> saveAll(List<Node> nodes);

  /// 批量加载
  Future<List<Node>> loadAll(List<String> nodeIds);

  /// 查询所有节点
  Future<List<Node>> queryAll();

  /// 搜索
  Future<List<Node>> search({
    String? title,
    String? content,
    List<String>? tags,
    DateTime? startDate,
    DateTime? endDate,
  });

  /// 获取节点文件路径
  String getNodeFilePath(String nodeId);

  /// 获取元数据索引
  Future<MetadataIndex> getMetadataIndex();

  /// 更新索引
  Future<void> updateIndex(Node node);
}

/// 文件系统节点仓库实现
class FileSystemNodeRepository implements NodeRepository {
  FileSystemNodeRepository({String nodesDir = 'data/nodes'})
      : _nodesDir = nodesDir;

  final String _nodesDir;

  /// 初始化目录
  Future<void> init() async {
    final dir = Directory(_nodesDir);
    if (!dir.existsSync()) {
      try {
        await dir.create(recursive: true);
      } catch (e) {
        throw RepositoryException('Failed to create nodes directory: $e');
      }
    }

    // 验证目录可写
    try {
      final testFile = File(path.join(_nodesDir, '.write_test'));
      await testFile.writeAsString('test');
      await testFile.delete();
    } catch (e) {
      throw RepositoryException('Nodes directory is not writable: $e');
    }
  }

  @override
  Future<void> save(Node node) async {
    final file = File(getNodeFilePath(node.id));
    final content = _generateNodeMarkdown(node);
    await file.writeAsString(content);
    await updateIndex(node);
  }

  @override
  Future<Node?> load(String nodeId) async {
    final file = File(getNodeFilePath(nodeId));
    if (!file.existsSync()) return null;

    try {
      final content = await file.readAsString();
      return _parseNodeMarkdown(content, nodeId);
    } catch (e) {
      throw RepositoryException('Failed to load node $nodeId: $e');
    }
  }

  @override
  Future<void> delete(String nodeId) async {
    final file = File(getNodeFilePath(nodeId));
    if (file.existsSync()) {
      await file.delete();
    }
  }

  @override
  Future<void> saveAll(List<Node> nodes) async {
    debugPrint('=== saveAll ===');
    for (final node in nodes) {
      debugPrint('Saving node: ${node.title} with ${node.references.length} references');
      await save(node);
    }
    debugPrint('saveAll completed');
  }

  @override
  Future<List<Node>> loadAll(List<String> nodeIds) async {
    final nodes = <Node>[];
    for (final nodeId in nodeIds) {
      final node = await load(nodeId);
      if (node != null) {
        nodes.add(node);
      }
    }
    return nodes;
  }

  @override
  Future<List<Node>> queryAll() async {
    final dir = Directory(_nodesDir);
    if (!dir.existsSync()) {
      // 目录不存在，尝试创建
      try {
        await dir.create(recursive: true);
        return [];
      } catch (e) {
        throw RepositoryException('Failed to create nodes directory: $e');
      }
    }

    final nodes = <Node>[];
    final List<String> corruptedFiles = [];

    try {
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.md')) {
          try {
            final nodeId = path.basenameWithoutExtension(entity.path);
            final node = await load(nodeId);
            if (node != null) {
              nodes.add(node);
            }
          } catch (e) {
            // 记录损坏的文件，但继续处理其他文件
            corruptedFiles.add(entity.path);
            debugPrint('Failed to load node file ${entity.path}: $e');
          }
        }
      }
    } catch (e) {
      throw RepositoryException('Failed to list nodes: $e');
    }

    // 清理损坏的索引（如果有）
    if (corruptedFiles.isNotEmpty) {
      try {
        await _cleanupIndex(nodes.map((n) => n.id).toSet());
      } catch (e) {
        debugPrint('Failed to cleanup index: $e');
      }
    }

    return nodes;
  }

  @override
  Future<List<Node>> search({
    String? title,
    String? content,
    List<String>? tags,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final allNodes = await queryAll();
    var results = allNodes;

    // Combine title and content search with OR logic
    if (title != null || content != null) {
      results = results.where((n) {
        final titleMatch = title != null &&
            n.title.toLowerCase().contains(title.toLowerCase());
        final contentMatch = content != null &&
            n.content?.toLowerCase().contains(content.toLowerCase()) == true;
        return titleMatch || contentMatch;
      }).toList();
    }

    if (tags != null && tags.isNotEmpty) {
      results = results.where((n) {
        final nodeTags = n.metadata['tags'] as List<Object>? ?? [];
        return tags.any((tag) => nodeTags.contains(tag));
      }).toList();
    }

    if (startDate != null) {
      results = results.where((n) => n.createdAt.isAfter(startDate)).toList();
    }

    if (endDate != null) {
      results = results.where((n) => n.createdAt.isBefore(endDate)).toList();
    }

    return results;
  }

  @override
  String getNodeFilePath(String nodeId) {
    return path.join(_nodesDir, '$nodeId.md');
  }

  @override
  Future<MetadataIndex> getMetadataIndex() async {
    final indexFile = File(path.join(_nodesDir, 'index.json'));
    if (!indexFile.existsSync()) {
      return MetadataIndex(nodes: [], lastUpdated: DateTime.now());
    }

    try {
      final json = await indexFile.readAsString();
      final data = _parseJson(json);
      return MetadataIndex(
        nodes: (data['nodes'] as List<dynamic>)
            .map((n) => NodeMetadata.fromJson(n as Map<String, dynamic>))
            .toList(),
        lastUpdated: DateTime.parse(data['last_updated'] as String),
      );
    } catch (e) {
      // 索引文件损坏，返回空索引并重新构建
      debugPrint('Index file corrupted, rebuilding: $e');
      return MetadataIndex(nodes: [], lastUpdated: DateTime.now());
    }
  }

  @override
  Future<void> updateIndex(Node node) async {
    final index = await getMetadataIndex();
    final metadata = NodeMetadata(
      id: node.id,
      title: node.title,
      position: PositionInfo(dx: node.position.dx, dy: node.position.dy),
      size: SizeInfo(width: node.size.width, height: node.size.height),
      filePath: getNodeFilePath(node.id),
      referencedNodeIds: node.referencedNodeIds,
      createdAt: node.createdAt,
      updatedAt: node.updatedAt,
    );

    // 移除旧条目
    index.nodes.removeWhere((n) => n.id == node.id);
    // 添加新条目
    index.nodes.add(metadata);

    // 保存索引
    final indexFile = File(path.join(_nodesDir, 'index.json'));
    final json = {
      'nodes': index.nodes.map((n) => n.toJson()).toList(),
      'last_updated': DateTime.now().toIso8601String(),
    };
    await indexFile.writeAsString(_stringifyJson(json));
  }

  /// 生成节点 Markdown 文件内容
  String _generateNodeMarkdown(Node node) {
    final buffer = StringBuffer();

    // Frontmatter
    buffer.writeln('---');
    buffer.writeln('id: ${node.id}');
    buffer.writeln('title: "${node.title}"');
    buffer.writeln('created_at: ${node.createdAt.toIso8601String()}');
    buffer.writeln('updated_at: ${node.updatedAt.toIso8601String()}');

    // 序列化位置
    buffer.writeln('position:');
    buffer.writeln('  dx: ${node.position.dx}');
    buffer.writeln('  dy: ${node.position.dy}');

    // 序列化尺寸
    buffer.writeln('size:');
    buffer.writeln('  width: ${node.size.width}');
    buffer.writeln('  height: ${node.size.height}');

    if (node.color != null) {
      buffer.writeln('color: "${node.color}"');
    }

    if (node.metadata.isNotEmpty) {
      buffer.writeln('metadata:');
      for (final entry in node.metadata.entries) {
        buffer.writeln('  ${entry.key}: ${_formatYamlValue(entry.value)}');
      }
    }

    if (node.references.isNotEmpty) {
      buffer.writeln('references:');
      for (final entry in node.references.entries) {
        final ref = entry.value;
        buffer.writeln('  ${entry.key}:');
        buffer.writeln('    type: ${ref.type}');
        if (ref.role != null) {
          buffer.writeln('    role: "${ref.role}"');
        }
        // 输出 properties 中的其他属性（除了 type 和 role）
        final otherProps = ref.properties.entries
            .where((e) => e.key != 'type' && e.key != 'role')
            .toList();
        if (otherProps.isNotEmpty) {
          buffer.writeln('    metadata:');
          for (final metaEntry in otherProps) {
            buffer.writeln('      ${metaEntry.key}: ${_formatYamlValue(metaEntry.value)}');
          }
        }
      }
    }

    buffer.writeln('---');

    // 不添加 # title，直接保存内容
    if (node.content != null && node.content!.isNotEmpty) {
      buffer.write(node.content);
    }

    return buffer.toString();
  }

  /// 解析节点 Markdown 文件
  Node _parseNodeMarkdown(String markdown, String nodeId) {
    final lines = markdown.split('\n');

    // 解析 Frontmatter
    Map<String, dynamic> frontmatter = {};
    int frontmatterEnd = 0;

    if (lines.isNotEmpty && lines[0] == '---') {
      final frontmatterLines = <String>[];
      for (int i = 1; i < lines.length; i++) {
        if (lines[i] == '---') {
          frontmatterEnd = i + 1;
          break;
        }
        frontmatterLines.add(lines[i]);
      }
      frontmatter = _parseYamlMap(frontmatterLines.join('\n'));
    }

    // 解析内容并提取第一个 # title（只提取一级标题）
    final contentLines = lines.skip(frontmatterEnd).toList();
    String? title = _parseStringValue(frontmatter['title']);
    String content = '';

    // Skip leading empty/whitespace lines after frontmatter
    int contentStartOffset = 0;
    while (contentStartOffset < contentLines.length &&
        contentLines[contentStartOffset].trim().isEmpty) {
      contentStartOffset++;
    }
    final trimmedContentLines = contentLines.skip(contentStartOffset).toList();

    if (trimmedContentLines.isNotEmpty) {
      // 只查找一级标题（单个 # 号）
      int contentStartIndex = 0;
      for (int i = 0; i < trimmedContentLines.length; i++) {
        final line = contentLines[i];
        final trimmed = line.trim();

        // 只匹配一级标题：行首是 # 且后面不是 #
        if (trimmed.startsWith('#') &&
            (trimmed.length == 1 || trimmed[1] != '#')) {
          // 找到一级标题，提取它
          final match = RegExp(r'^#\s+(.+)$').firstMatch(trimmed);
          if (match != null) {
            title = match.group(1)!.trim();
            contentStartIndex = i + 1;
            // 跳过标题后的空行
            while (contentStartIndex < trimmedContentLines.length &&
                   trimmedContentLines[contentStartIndex].trim().isEmpty) {
              contentStartIndex++;
            }
            break;
          }
        }
      }

      // 如果没有找到标题，使用整个内容
      if (contentStartIndex == 0) {
        content = trimmedContentLines.join('\n').trimRight();
      } else {
        content = trimmedContentLines.skip(contentStartIndex).join('\n').trimRight();
      }
    }

    // 解析引用
    final references = <String, NodeReference>{};
    if (frontmatter.containsKey('references')) {
      final refsMap = frontmatter['references'] as Map<String, dynamic>;
      refsMap.forEach((key, value) {
        final refData = value as Map<String, dynamic>;

        // 构建 properties Map
        final properties = <String, dynamic>{};

        // 解析 type（必需）
        properties['type'] = _parseStringValue(refData['type']) ?? 'relatesTo';

        // 解析 role（可选）
        final role = _parseStringValue(refData['role']);
        if (role != null) {
          properties['role'] = role;
        }

        // 合并 metadata 中的其他属性
        if (refData.containsKey('metadata')) {
          final metadata = refData['metadata'] as Map<String, dynamic>?;
          if (metadata != null) {
            properties.addAll(metadata);
          }
        }

        references[key] = NodeReference(
          nodeId: key,
          properties: properties,
        );
      });
    }

    return Node(
      id: _parseStringValue(frontmatter['id']) ?? nodeId,
      title: title ?? 'Untitled',
      content: content,
      references: references,
      position: _parseOffset(frontmatter['position'] as Map<String, dynamic>?),
      size: _parseSize(frontmatter['size'] as Map<String, dynamic>?),
      viewMode: NodeViewMode.values.firstOrNull ??
          NodeViewMode.titleWithPreview,
      color: _parseStringValue(frontmatter['color']),
      createdAt: _parseDateTime(frontmatter['created_at']),
      updatedAt: _parseDateTime(frontmatter['updated_at']),
      metadata: frontmatter['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  /// 安全地解析字符串值
  String? _parseStringValue(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    // 处理数字类型（如旧格式中的纯数字title）
    if (value is num) return value.toString();
    return value.toString();
  }

  /// 安全地解析日期时间值
  DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  Offset _parseOffset(Map<String, dynamic>? data) {
    if (data == null) return const Offset(100, 100);
    return Offset(
      (data['dx'] as num?)?.toDouble() ?? 100.0,
      (data['dy'] as num?)?.toDouble() ?? 100.0,
    );
  }

  Size _parseSize(Map<String, dynamic>? data) {
    if (data == null) return const Size(300, 400);
    return Size(
      (data['width'] as num?)?.toDouble() ?? 300.0,
      (data['height'] as num?)?.toDouble() ?? 400.0,
    );
  }

  /// 格式化 YAML 值
  String _formatYamlValue(dynamic value) {
    if (value == null) return 'null';
    if (value is bool) return value ? 'true' : 'false';
    if (value is num) return value.toString();
    if (value is String) {
      // 如果值包含空格或特殊字符，用引号包裹
      if (value.contains(' ') || value.contains(':') || value.contains('{') || value.contains(',')) {
        return '"$value"';
      }
      return value;
    }
    if (value is Map) {
      // Map类型需要在外部调用处处理嵌套，这里返回占位符
      // 注意：实际上这个方法不应该被Map类型调用，因为Map需要特殊处理
      return value.toString();
    }
    if (value is List) {
      // List类型也需要特殊处理
      return value.toString();
    }
    return value.toString();
  }

  Map<String, dynamic> _parseYamlMap(String yaml) {
    final result = <String, dynamic>{};
    final lines = yaml.split('\n');
    _parseYamlBlock(lines, 0, result);
    return result;
  }

  /// 递归解析 YAML 块
  /// 返回处理到的行索引
  int _parseYamlBlock(List<String> lines, int startIndex, Map<String, dynamic> output) {
    int i = startIndex;
    int? baseIndent;

    while (i < lines.length) {
      final line = lines[i];
      final trimmed = line.trim();

      // Skip empty lines and comments
      if (trimmed.isEmpty || trimmed.startsWith('#')) {
        i++;
        continue;
      }

      // Stop at frontmatter delimiter
      if (trimmed == '---') {
        break;
      }

      final indent = line.length - line.trimLeft().length;
      baseIndent ??= indent;

      // 如果缩进小于基础缩进，说明到了上一层
      if (indent < baseIndent) {
        break;
      }

      final match = RegExp(r'^([^:]+):\s*(.*)$').firstMatch(trimmed);

      if (match != null) {
        final key = match.group(1)!.trim();
        final valueStr = match.group(2)!.trim();

        if (valueStr.isEmpty) {
          // 可能是嵌套对象或列表，需要向前看
          i++;
          if (i >= lines.length) break;

          final nextLine = lines[i];
          if (nextLine.trim().startsWith('-')) {
            // 这是一个列表
            final list = <dynamic>[];
            while (i < lines.length) {
              if (lines[i].trim().isEmpty || lines[i].trim().startsWith('#')) {
                i++;
                continue;
              }
              final nextIndent = lines[i].length - lines[i].trimLeft().length;
              if (nextIndent <= baseIndent) break;

              final itemTrimmed = lines[i].trim();
              if (!itemTrimmed.startsWith('-')) break;

              final itemContent = itemTrimmed.substring(1).trim();
              final itemMatch = RegExp(r'^([^:]+):\s*(.*)$').firstMatch(itemContent);

              if (itemMatch != null) {
                // 列表项是对象
                final itemMap = <String, dynamic>{};
                final itemKey = itemMatch.group(1)!.trim();
                final itemValue = itemMatch.group(2)!.trim();
                itemMap[itemKey] = _parseYamlValue(itemValue);

                // 检查是否有更多属性
                i++;
                while (i < lines.length) {
                  if (lines[i].trim().isEmpty) {
                    i++;
                    continue;
                  }
                  final attrIndent = lines[i].length - lines[i].trimLeft().length;
                  if (attrIndent <= nextIndent) break;

                  final attrMatch = RegExp(r'^([^:]+):\s*(.*)$').firstMatch(lines[i].trim());
                  if (attrMatch != null) {
                    final attrKey = attrMatch.group(1)!.trim();
                    final attrValue = attrMatch.group(2)!.trim();
                    itemMap[attrKey] = _parseYamlValue(attrValue);
                  }
                  i++;
                }
                list.add(itemMap);
              } else {
                // 简单值
                list.add(_parseYamlValue(itemContent));
                i++;
              }
            }
            output[key] = list;
          } else {
            // 这是一个嵌套对象
            final nestedMap = <String, dynamic>{};
            i = _parseYamlBlock(lines, i, nestedMap);
            output[key] = nestedMap;
          }
        } else {
          // 简单值
          output[key] = _parseYamlValue(valueStr);
          i++;
        }
      } else {
        i++;
      }
    }

    return i;
  }

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

  Map<String, dynamic> _parseJson(String json) {
    return jsonDecode(json) as Map<String, dynamic>;
  }

  String _stringifyJson(Map<String, dynamic> json) {
    return jsonEncode(json);
  }

  /// 清理损坏的索引条目
  Future<void> _cleanupIndex(Set<String> validNodeIds) async {
    final indexFile = File(path.join(_nodesDir, 'index.json'));
    if (!indexFile.existsSync()) return;

    try {
      final json = await indexFile.readAsString();
      final data = _parseJson(json);
      final nodes = data['nodes'] as List<dynamic>;

      // 只保留有效的节点ID
      final validNodes = nodes.where((n) {
        final metadata = n as Map<String, dynamic>;
        final nodeId = metadata['id'] as String;
        return validNodeIds.contains(nodeId);
      }).toList();

      // 保存清理后的索引
      final cleanedIndex = {
        'nodes': validNodes,
        'last_updated': DateTime.now().toIso8601String(),
      };
      await indexFile.writeAsString(_stringifyJson(cleanedIndex));
      debugPrint('Cleaned up index: removed ${nodes.length - validNodes.length} invalid entries');
    } catch (e) {
      // 如果清理失败，尝试删除索引文件，让它重新构建
      try {
        await indexFile.delete();
        debugPrint('Deleted corrupted index file');
      } catch (e2) {
        debugPrint('Failed to delete corrupted index: $e2');
      }
    }
  }
}
