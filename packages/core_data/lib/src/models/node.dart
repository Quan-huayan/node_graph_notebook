/// Node —— 数据层实体（00 §2.1）：纯数据，无行为。
///
/// 逻辑身份 + 结构关系 + 内容引用。**不含任何 UI 信息**
/// （00 不变量 4.3-5）；**不感知文件**（00 §3.4：物理文件是存储实现的
/// 序列化形态，逻辑层接口不暴露任何物理概念）。
///
/// 附加内容（图片/代码/3D/二进制）不是 Node 字段——附件是
/// asset 类 Concept 的实例，被主节点以 references 引用（02 §1.1）。
abstract class Node {
  /// 逻辑身份（uuid），稳定；文件路径只是别名（00 §3.4）。
  String get id;

  /// 标题（UI 呈现的主文本）。
  String get title;

  /// 文本内容（markdown 等主内容），可为空。
  String? get content;

  /// 有序引用集合：slot → targetId，仅 targetId（00 §2.2 Ln 定义 / 01 A 域）。
  /// 边只是恰好引用了一组低层 Node 的 Node——references 即结构。
  Map<String, String> get references;

  /// 纯数据元信息，不含任何 UI 信息（00 不变量 4.1）。
  /// 无 instanceOf——归属判定靠结构匹配（00 删除清单）。
  Map<String, dynamic> get metadata;

  /// 创建时间（存储实现写入）。
  DateTime get createdAt;

  /// 最后修改时间（存储实现写入）。
  DateTime get updatedAt;

  /// 不可变复制（references / metadata 整体替换，不做深拷贝）。
  Node copyWith({
    String? title,
    String? content,
    Map<String, String>? references,
    Map<String, dynamic>? metadata,
  });
}
