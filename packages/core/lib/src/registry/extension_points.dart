/// 扩展点定义（04 §1.1：注册归 plugon，查询侧归我们）。
///
/// Concept 与 CommandHandler 作为 plugon 扩展点贡献——
/// owner 清理自动随插件卸载（removeOwner）；活跃性由插件状态
/// 派生（setPluginActive，禁用即停用）。
library;

import 'package:core_data/core_data.dart';
import 'package:plugon/plugon.dart';

import '../command/command.dart';

/// Concept 贡献扩展点（findFor 的匹配源）。
const ExtensionPoint<Concept> conceptPoint = ExtensionPoint<Concept>(
  'concept',
  name: 'Concept',
  description: 'Node 归属判定（结构匹配）的代码层 schema 贡献',
);

/// CommandHandler 贡献扩展点（dispatch 的路由源）。
const ExtensionPoint<CommandHandler> commandHandlerPoint =
    ExtensionPoint<CommandHandler>(
      'command-handler',
      name: 'CommandHandler',
      description: '写命令处理器贡献（纯 DTO → Handler）',
    );
