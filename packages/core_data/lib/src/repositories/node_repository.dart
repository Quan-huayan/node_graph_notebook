import '../models/models.dart';
import 'metadata_index.dart';

/// 节点仓库抽象接口
///
/// 定义节点数据的持久化和检索操作规范。
/// 具体实现（如文件系统、图数据库等）应在外部包中提供。
///
/// 所有写操作应通过命令总线执行，读操作应通过查询总线执行。
/// 插件不应直接依赖此接口，而应使用 CQRS 总线。
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

  /// 初始化仓库（可选操作）
  ///
  /// 如果仓库实现需要初始化（如创建默认数据、重建索引等），可以覆写此方法
  /// 默认实现为空操作，以保证向后兼容
  Future<void> init() async {}
}
