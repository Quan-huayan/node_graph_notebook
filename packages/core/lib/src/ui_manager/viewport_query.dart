/// ViewportQuery —— 视口内节点查询抽象（架构 §5.1 时序的查询侧）。
///
/// 空间索引（QuadTree，旧资产带走）由 appframe 实现——M3.5 接入；
/// core 只依赖本抽象（测试与 Lua 可用简单实现）。
library;

import 'value_rect.dart';

/// 视口内节点查询。
abstract class ViewportQuery {
  /// 返回视口内（含边界）的全部 nodeId。
  ///
  /// 10⁶ 背书：空间索引查询，与全库规模无关（架构 §7 帧预算）。
  Iterable<String> queryNodes(ValueRect viewport);
}
