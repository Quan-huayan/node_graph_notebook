/// plugon 核心：类型化扩展点系统（纯 Dart）。
///
/// 通用扩展点机制，不占用 "Hook" 术语——Flowing UI 的 Hook 体系
/// 在此之上构建（Hook 即对某个 ExtensionPoint 的贡献）。
library;

export 'extensions/exceptions.dart';
export 'extensions/extension_contribution.dart';
export 'extensions/extension_point.dart';
export 'extensions/extension_registry.dart';
