import '../models/models.dart';

/// 图仓库抽象接口
///
/// 定义图数据的持久化和检索操作规范。
/// 具体实现（如文件系统、图数据库等）应在外部包中提供。
///
/// 所有写操作应通过命令总线执行，读操作应通过查询总线执行。
/// 插件不应直接依赖此接口，而应使用 CQRS 总线。
abstract class GraphRepository {
  /// 保存图到存储
  ///
  /// [graph]: 要保存的图对象
  Future<void> save(Graph graph);

  /// 根据ID加载图
  ///
  /// [graphId]: 图的唯一标识符
  ///
  /// 返回: 加载的图，如果不存在则返回null
  Future<Graph?> load(String graphId);

  /// 删除指定ID的图
  ///
  /// [graphId]: 要删除的图ID
  Future<void> delete(String graphId);

  /// 获取所有图
  ///
  /// 返回: 所有图的列表
  Future<List<Graph>> getAll();

  /// 获取当前活动的图
  ///
  /// 返回: 当前图，如果不存在则返回null
  Future<Graph?> getCurrent();

  /// 设置当前活动的图
  ///
  /// [graphId]: 要设置为当前图的ID
  Future<void> setCurrent(String graphId);

  /// 导出图到文件
  ///
  /// [graphId]: 要导出的图ID
  /// [filePath]: 导出文件的路径
  Future<void> export(String graphId, String filePath);

  /// 从文件导入图
  ///
  /// [filePath]: 要导入的文件路径
  ///
  /// 返回: 导入的图对象
  Future<Graph> import(String filePath);

  // === 邻接表相关方法 ===

  /// 获取节点的出边邻居
  ///
  /// [nodeId]: 节点ID
  /// 返回: 该节点引用的所有节点ID集合
  Set<String> getOutgoingNeighbors(String nodeId);

  /// 获取节点的入边邻居
  ///
  /// [nodeId]: 节点ID
  /// 返回: 所有引用该节点的节点ID集合
  Set<String> getIncomingNeighbors(String nodeId);

  /// 获取节点的所有邻居
  ///
  /// [nodeId]: 节点ID
  /// 返回: 该节点的所有邻居（出边+入边）ID集合
  Set<String> getAllNeighbors(String nodeId);

  /// 获取节点的度数
  ///
  /// [nodeId]: 节点ID
  /// 返回: (入度, 出度)
  (int inDegree, int outDegree) getNodeDegree(String nodeId);

  /// 添加边
  ///
  /// [fromId]: 源节点ID
  /// [toId]: 目标节点ID
  void addEdge(String fromId, String toId);

  /// 删除边
  ///
  /// [fromId]: 源节点ID
  /// [toId]: 目标节点ID
  void removeEdge(String fromId, String toId);

  /// 移除节点的所有边
  ///
  /// [nodeId]: 节点ID
  void removeNodeEdges(String nodeId);

  /// 重建邻接表
  ///
  /// 从节点列表重建邻接表索引
  /// [nodes]: 节点列表
  void rebuildAdjacencyList(List<Node> nodes);

  /// 持久化邻接表
  Future<void> saveAdjacencyList();

  /// 初始化仓库（可选操作）
  ///
  /// 如果仓库实现需要初始化（如创建默认图、重建邻接表等），可以覆写此方法
  /// 默认实现为空操作，以保证向后兼容
  Future<void> init() async {}
}
