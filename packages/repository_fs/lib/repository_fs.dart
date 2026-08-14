/// 文件系统仓库实现包
///
/// 提供基于文件系统的 `NodeRepository` 和 `GraphRepository` 实现。
/// 节点存储为 Markdown 文件（带 YAML frontmatter），图存储为 JSON 文件。
///
/// 要切换后端，替换此包中的实现并更新 app 包中的依赖注入即可。
library;

export 'graph_repository_fs.dart';
export 'node_repository_fs.dart';
