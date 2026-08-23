/// 文件夹内新建对话框（B3：Obsidian 文件夹内新建语义）。
///
/// 弹窗收集标题 + 内容 → 返回 `(title, content)`；null = 取消。
/// 创建写操作由调用方（FolderView）dispatch `CreateNodeInFolderCommand`。
library;

import 'package:appframe/appframe.dart';
import 'package:flutter/material.dart';

/// 打开文件夹内新建对话框。
///
/// 返回记录 (标题, 内容)；用户取消 → null。
Future<(String, String)?> showFolderCreateDialog(
  BuildContext context,
  I18nService i18n,
) =>
    showDialog<(String, String)>(
      context: context,
      builder: (context) => _FolderCreateDialog(i18n: i18n),
    );

/// 新建对话框（标题 + 内容，保存走调用方命令分发）。
class _FolderCreateDialog extends StatefulWidget {
  /// 构造。
  const _FolderCreateDialog({required this.i18n});

  /// 国际化服务（壳层文案）。
  final I18nService i18n;

  @override
  State<_FolderCreateDialog> createState() => _FolderCreateDialogState();
}

class _FolderCreateDialogState extends State<_FolderCreateDialog> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _content = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = widget.i18n;
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(i18n.t('folder.createTitle'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              autofocus: true,
              decoration: InputDecoration(
                labelText: i18n.t('dialog.title'),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _content,
              minLines: 3,
              maxLines: 6,
              decoration: InputDecoration(
                labelText: i18n.t('dialog.content'),
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () {
                  final title = _title.text.trim();
                  if (title.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(i18n.t('dialog.titleRequired')),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(context, (title, _content.text));
                },
                child: Text(i18n.t('dialog.save')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}