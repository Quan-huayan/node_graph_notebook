/// node_editor —— Markdown 编辑器插件（M7 修正，Hook 承载 UI）。
///
/// NoteConcept（普通笔记归属）+ EditorHook（kind = 'open' 渲染编辑器
/// 视图——点击笔记 = 渲染其 Hook）；保存 = 写路径（SaveNoteCommand →
/// Handler 落盘 → 写后通知，03 §四）。插件自带命令（plugins 互相不依赖，
/// 04 §三 约束 3）。
library;

export 'editor_plugin.dart';
export 'src/editor_concept.dart';
export 'src/markdown_editor_view.dart';
export 'src/note_card_view.dart';
export 'src/note_row_view.dart';
export 'src/save_note.dart';
