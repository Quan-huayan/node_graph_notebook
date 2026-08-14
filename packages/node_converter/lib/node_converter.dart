/// node_converter —— 导入导出插件（M7，01 拍板 #37）。
///
/// ExportCommand（节点 → JSON 文件，结构保真往返）/ ImportCommand
/// （JSON 文件 → 节点）——纯 DTO + Handler（03 §四），写路径。
/// JSON 往返保真：id/title/content/references/metadata/createdAt/updatedAt。
library;

export 'converter_plugin.dart';
export 'src/converter_commands.dart';
export 'src/converter_dialog.dart';
export 'src/converter_handlers.dart';
