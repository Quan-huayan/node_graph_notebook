import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import '../graph/adjacency_list.dart';
import '../models/models.dart';
import '../utils/logger.dart';
import '../utils/yaml_utils.dart';
import 'exceptions.dart';

/// Logger for FileSystemNodeRepository
const _log = AppLogger('FileSystemNodeRepository');

/// 节点仓库接口
///
/// 负责节点数据的持久化和检索操作
abstract class NodeRepository {
  /// 保存节点到存储
  ///
  /// [node]: 要保存的节点对象
  Future<void> save(Node node);

  /// 根据ID加载节点
  ///
  /// [nodeId]: 节点的唯一标识符
  ///
  /// 返回: 加载的节点，如果不存在则返回null
  Future<Node?> load(String nodeId);

  /// 删除指定ID的节点
  ///
  /// [nodeId]: 要删除的节点ID
  Future<void> delete(String nodeId);

  /// 批量保存多个节点
  ///
  /// [nodes]: 要保存的节点列表
  Future<void> saveAll(List<Node> nodes);

  /// 批量加载多个节点
  ///
  /// [nodeIds]: 要加载的节点ID列表
  ///
  /// 返回: 加载的节点列表，不存在的节点会被忽略
  Future<List<Node>> loadAll(List<String> nodeIds);

  /// 查询所有节点
  ///
  /// 返回: 所有节点的列表
  Future<List<Node>> queryAll();

  /// 根据条件搜索节点
  ///
  /// [title]: 标题搜索关键词
  /// [content]: 内容搜索关键词
  /// [tags]: 标签过滤
  /// [startDate]: 开始日期过滤
  /// [endDate]: 结束日期过滤
  ///
  /// 返回: 符合条件的节点列表
  Future<List<Node>> search({
    String? title,
    String? content,
    List<String>? tags,
    DateTime? startDate,
    DateTime? endDate,
  });

  /// 获取节点文件路径
  ///
  /// [nodeId]: 节点ID
  ///
  /// 返回: 节点对应的文件路径
  String getNodeFilePath(String nodeId);

  /// 获取元数据索引
  ///
  /// 返回: 元数据索引对象
  Future<MetadataIndex> getMetadataIndex();

  /// 更新节点的元数据索引
  ///
  /// [node]: 要更新索引的节点
  Future<void> updateIndex(Node node);
}

/// 文件系统节点仓库实现
class FileSystemNodeRepository implements NodeRepository {
  /// 创建文件系统节点仓库
  ///
  /// [nodesDir]: 节点文件存储目录，默认为 'data/nodes'
  /// [useAdjacencyList]: 是否使用邻接表优化图查询，默认为true
  FileSystemNodeRepository({
    String nodesDir = 'data/nodes',
    bool useAdjacencyList = true,
  })  : _nodesDir = nodesDir,
        _useAdjacencyList = useAdjacencyList {
    if (_useAdjacencyList) {
      _adjacencyList = AdjacencyList(storageDir: path.join(nodesDir, '../graph'));
    }
  }

  final String _nodesDir;
  final bool _useAdjacencyList;

  /// 邻接表（用于优化图查询）
  AdjacencyList? _adjacencyList;

  /// 获取邻接表
  ///
  /// 如果邻接表未初始化，返回null
  AdjacencyList? get adjacencyList => _adjacencyList;

  /// 初始化节点存储目录
  ///
  /// 创建必要的目录结构并验证写入权限
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

    // 初始化邻接表
    if (_useAdjacencyList && _adjacencyList != null) {
      await _adjacencyList!.init();

      // 如果邻接表为空，从现有节点构建
      if (_adjacencyList!.nodeCount == 0) {
        final nodes = await queryAll();
        _adjacencyList!.buildFromNodes(nodes);
        await _adjacencyList!.save();
      }
    }
  }

  @override
  Future<void> save(Node node) async {
    final file = File(getNodeFilePath(node.id));
    final content = _generateNodeMarkdown(node);
    await file.writeAsString(content);
    await updateIndex(node);

    // 更新邻接表
    if (_useAdjacencyList && _adjacencyList != null) {
      // 移除旧的关系
      _adjacencyList!.removeNode(node.id);

      // 添加新的关系
      for (final referencedId in node.references.keys) {
        _adjacencyList!.addEdge(node.id, referencedId);
      }

      // 异步保存邻接表
      _adjacencyList!.save();
    }
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

    // 从邻接表中移除节点
    if (_useAdjacencyList && _adjacencyList != null) {
      _adjacencyList!.removeNode(nodeId);
      await _adjacencyList!.save();
    }
  }

  @override
  Future<void> saveAll(List<Node> nodes) async {
    _log.debug('=== saveAll ===');
    for (final node in nodes) {
      _log.debug(
        'Saving node: ${node.title} with ${node.references.length} references',
      );
      await save(node);
    }
    _log.debug('saveAll completed');
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
    final corruptedFiles = <String>[];

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
            _log.warning('Failed to load node file ${entity.path}: $e');
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
        _log.warning('Failed to cleanup index: $e');
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
        final titleMatch =
            title != null &&
            n.title.toLowerCase().contains(title.toLowerCase());
        final contentMatch =
            content != null &&
            (n.content?.toLowerCase().contains(content.toLowerCase()) ?? false);
        return titleMatch || contentMatch;
      }).toList();
    }

    if (tags != null && tags.isNotEmpty) {
      results = results.where((n) {
        final nodeTags = n.metadata['tags'] as List<Object>? ?? [];
        return tags.any(nodeTags.contains);
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
  String getNodeFilePath(String nodeId) => path.join(_nodesDir, '$nodeId.md');

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
      _log.warning('Index file corrupted, rebuilding: $e');
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
    final buffer = StringBuffer()

    // Frontmatter
    ..writeln('---')
    ..writeln('id: ${node.id}')
    ..writeln('title: "${node.title}"')
    ..writeln('created_at: ${node.createdAt.toIso8601String()}')
    ..writeln('updated_at: ${node.updatedAt.toIso8601String()}')

    // 序列化位置
    ..writeln('position:')
    ..writeln('  dx: ${node.position.dx}')
    ..writeln('  dy: ${node.position.dy}')

    // 序列化尺寸
    ..writeln('size:')
    ..writeln('  width: ${node.size.width}')
    ..writeln('  height: ${node.size.height}');

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
        buffer..writeln('  ${entry.key}:')
        ..writeln('    type: ${ref.type}');
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
            buffer.writeln(
              '      ${metaEntry.key}: ${_formatYamlValue(metaEntry.value)}',
            );
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
  ///
  /// [markdown] Markdown 文件内容
  /// [nodeId] 节点 ID（用于回退）
  ///
  /// 返回解析后的 Node 对象
  Node _parseNodeMarkdown(String markdown, String nodeId) {
    final lines = markdown.split('\n');

    // 解析 Frontmatter
    final frontmatterData = _parseFrontmatter(lines);
    final frontmatter = frontmatterData.$1;
    final frontmatterEnd = frontmatterData.$2;

    // 解析内容和标题
    final contentData = _parseContentAndTitle(lines, frontmatter, frontmatterEnd);
    final title = contentData.$1;
    final content = contentData.$2;

    // 解析引用
    final references = _parseReferences(frontmatter);

    return Node(
      id: _parseStringValue(frontmatter['id']) ?? nodeId,
      title: title ?? 'Untitled',
      content: content,
      references: references,
      position: _parseOffset(frontmatter['position'] as Map<String, dynamic>?),
      size: _parseSize(frontmatter['size'] as Map<String, dynamic>?),
      viewMode:
          NodeViewMode.values.firstOrNull ?? NodeViewMode.titleWithPreview,
      color: _parseStringValue(frontmatter['color']),
      createdAt: _parseDateTime(frontmatter['created_at']),
      updatedAt: _parseDateTime(frontmatter['updated_at']),
      metadata: frontmatter['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  /// 解析 Markdown Frontmatter
  ///
  /// [lines] Markdown 文件的行列表
  ///
  /// 返回一个元组：(frontmatter Map, frontmatter 结束行索引)
  (Map<String, dynamic>, int) _parseFrontmatter(List<String> lines) {
    var frontmatter = <String, dynamic>{};
    var frontmatterEnd = 0;

    if (lines.isNotEmpty && lines[0] == '---') {
      final frontmatterLines = <String>[];
      for (var i = 1; i < lines.length; i++) {
        if (lines[i] == '---') {
          frontmatterEnd = i + 1;
          break;
        }
        frontmatterLines.add(lines[i]);
      }
      frontmatter = _parseYamlMap(frontmatterLines.join('\n'));
    }

    return (frontmatter, frontmatterEnd);
  }

  /// 解析内容和标题
  ///
  /// [lines] Markdown 文件的行列表
  /// [frontmatter] Frontmatter 元数据
  /// [frontmatterEnd] Frontmatter 结束行索引
  ///
  /// 返回一个元组：(title, content)
  (String?, String) _parseContentAndTitle(
    List<String> lines,
    Map<String, dynamic> frontmatter,
    int frontmatterEnd,
  ) {
    final contentLines = lines.skip(frontmatterEnd).toList();
    var title = _parseStringValue(frontmatter['title']);
    var content = '';

    // Skip leading empty/whitespace lines after frontmatter
    var contentStartOffset = 0;
    while (contentStartOffset < contentLines.length &&
        contentLines[contentStartOffset].trim().isEmpty) {
      contentStartOffset++;
    }
    final trimmedContentLines = contentLines.skip(contentStartOffset).toList();

    if (trimmedContentLines.isNotEmpty) {
      // 只查找一级标题（单个 # 号）
      var contentStartIndex = 0;
      for (var i = 0; i < trimmedContentLines.length; i++) {
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
        content = trimmedContentLines
            .skip(contentStartIndex)
            .join('\n')
            .trimRight();
      }
    }

    return (title, content);
  }

  /// 解析节点引用
  ///
  /// [frontmatter] Frontmatter 元数据
  ///
  /// 返回节点 ID 到 NodeReference 的映射
  Map<String, NodeReference> _parseReferences(Map<String, dynamic> frontmatter) {
    final references = <String, NodeReference>{};

    if (!frontmatter.containsKey('references')) {
      return references;
    }

    (frontmatter['references'] as Map<String, dynamic>).forEach((key, value) {
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

      references[key] = NodeReference(nodeId: key, properties: properties);
    });

    return references;
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
      if (value.contains(' ') ||
          value.contains(':') ||
          value.contains('{') ||
          value.contains(',')) {
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

  /// 解析 YAML 字符串为 Map
  ///
  /// 使用 YamlUtils 进行解析，支持嵌套对象和列表
  Map<String, dynamic> _parseYamlMap(String yaml) => YamlUtils.parse(yaml);

  Map<String, dynamic> _parseJson(String json) => jsonDecode(json) as Map<String, dynamic>;

  String _stringifyJson(Map<String, dynamic> json) => jsonEncode(json);

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
      _log.info(
        'Cleaned up index: removed ${nodes.length - validNodes.length} invalid entries',
      );
    } catch (e) {
      // 如果清理失败，尝试删除索引文件，让它重新构建
      try {
        await indexFile.delete();
        _log.info('Deleted corrupted index file');
      } catch (e2) {
        _log.warning('Failed to delete corrupted index: $e2');
      }
    }
  }
}
