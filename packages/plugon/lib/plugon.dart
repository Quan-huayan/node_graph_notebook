/// plugon 核心桶（纯 Dart，零 Flutter 依赖）。
///
/// 依赖管理基础设施：.NET 风格 DI + 类型化扩展点 + 插件生命周期。
/// Flutter 集成（Provider/Bloc 适配）请导入 `package:plugon/plugon_flutter.dart`。
library;

export 'core/di.dart';
export 'core/extensions.dart';
export 'core/plugin.dart';
