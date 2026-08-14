import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/di.dart';

/// ServiceCollection 的 Bloc 扩展。
extension ServiceCollectionBlocExt on ServiceCollection {
  /// 注册 Bloc 工厂并暴露为 widget provider（BlocProvider.value）。
  ///
  /// **销毁归属：DI**——注册时挂 onDispose（close），插件卸载时由容器关闭；
  /// widget 树（BlocProvider.value）不关闭，避免重复关闭。
  void addBloc<T extends BlocBase>(
    T Function(ServiceProvider sp) factory, {
    String? owner,
  }) {
    addSingleton<T>(
      factory,
      owner: owner,
      isNotifier: true,
      isBloc: true,
      onDispose: (b) => (b as BlocBase).close(),
      providerFactory: (sp) => BlocProvider<T>.value(value: sp.get<T>()),
    );
  }
}
