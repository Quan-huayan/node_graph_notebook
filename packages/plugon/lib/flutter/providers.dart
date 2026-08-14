import 'package:provider/single_child_widget.dart';

import '../core/di.dart';

/// 从 DI 容器生成 MultiProvider 用的 Provider 列表。
///
/// 只包含注册时附加了类型化 providerFactory 的描述符（addNotifier /
/// addValue / addFactory / addBloc 等 flutter 便捷方法）；纯 core 注册的
/// 服务不会出现在 widget 树中。
///
/// [activeOwners] 非空时，排除 owner 不在集合内的插件服务（宿主服务
/// owner 为 null，始终保留）。
List<SingleChildWidget> buildProviders(
  ServiceProvider provider, {
  Set<String>? activeOwners,
}) => provider.descriptors
    .where((d) => d.providerFactory != null)
    .where(
      (d) =>
          activeOwners == null ||
          d.owner == null ||
          activeOwners.contains(d.owner),
    )
    .map((d) => d.providerFactory!(provider) as SingleChildWidget)
    .toList();

/// 从 DI 容器生成 MultiBlocProvider 用的 BlocProvider 列表（仅 Bloc 服务）。
List<SingleChildWidget> buildBlocProviders(
  ServiceProvider provider, {
  Set<String>? activeOwners,
}) => provider.descriptors
    .where((d) => d.isBloc)
    .where(
      (d) =>
          activeOwners == null ||
          d.owner == null ||
          activeOwners.contains(d.owner),
    )
    .map((d) => d.providerFactory!(provider) as SingleChildWidget)
    .toList();
