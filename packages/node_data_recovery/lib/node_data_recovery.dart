/// node_data_recovery —— 数据恢复插件（M7，01 拍板 #35）。
///
/// 备份 / 校验 / 修复命令（纯 DTO + Handler，03 §四）：
/// - 备份 = 复制 sidecar 存储到 data/backups/<时间戳>
/// - 校验 = sidecar JSON 可解析性 + 引用完整性（引用目标存在）
/// - 修复 = 删除损坏 sidecar（恢复为可编辑空节点，架构 §8）
/// 启动失败恢复路径：宿主调用方按需触发（架构 §4 失败行为）。
library;

export 'recovery_plugin.dart';
export 'src/recovery_commands.dart';
export 'src/recovery_handlers.dart';
