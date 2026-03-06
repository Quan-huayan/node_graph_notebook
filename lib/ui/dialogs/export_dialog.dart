import 'package:flutter/material.dart';
import 'package:node_graph_notebook/core/models/models.dart';
import 'package:node_graph_notebook/core/services/export_service.dart';
import '../../utils/files.dart';

/// 导出对话框
class ExportDialog extends StatefulWidget {
  const ExportDialog({
    super.key,
    required this.graph,
    required this.nodes,
  });

  final Graph graph;
  final List<Node> nodes;

  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> {
  _ExportDialogState();

  ExportFormat _selectedFormat = ExportFormat.json;
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Export Graph'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Format:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<ExportFormat>(
            initialValue: _selectedFormat,
            items: ExportFormat.values.map((format) {
              return DropdownMenuItem(
                value: format,
                child: Text(_getFormatLabel(format)),
              );
            }).toList(),
            onChanged: (format) {
              setState(() {
                _selectedFormat = format!;
              });
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Graph: ${widget.graph.name}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            'Nodes: ${widget.nodes.length}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isExporting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isExporting ? null : _export,
          child: _isExporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Export'),
        ),
      ],
    );
  }

  String _getFormatLabel(ExportFormat format) {
    switch (format) {
      case ExportFormat.json:
        return 'JSON (Full Data)';
      case ExportFormat.markdown:
        return 'Markdown (Document)';
      case ExportFormat.image:
        return 'Image (PNG)';
      case ExportFormat.pdf:
        return 'PDF Document';
    }
  }

  Future<void> _export() async {
    setState(() {
      _isExporting = true;
    });

    final exportService = ExportService();

    try {
      final file = await exportService.exportGraph(
        graph: widget.graph,
        nodes: widget.nodes,
        format: _selectedFormat,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported to: ${file.path}'),
            action: SnackBarAction(
              label: 'Open',
              onPressed: () async {
                try {
                  await openFile(file.path);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to open file: $e')),
                    );
                  }
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }
}
