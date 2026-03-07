import 'package:flutter/material.dart';
import '../../core/models/models.dart';

/// 转换预览面板
class ConvertPreviewPanel extends StatelessWidget {
  const ConvertPreviewPanel({
    super.key,
    required this.isDirectory,
    required this.previewNodes,
    required this.previewMarkdown,
    required this.isPreviewing,
  });

  final bool isDirectory; // false = MD → Nodes, true = Nodes → MD
  final List<Node> previewNodes;
  final String previewMarkdown;
  final bool isPreviewing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isDirectory) ...[
            // MD → Nodes 模式
            if (previewNodes.isEmpty && !isPreviewing)
              _buildEmptyStateNodes(context)
            else if (isPreviewing)
              const Center(child: CircularProgressIndicator())
            else
              _buildNodesPreview(context),
          ] else ...[
            // Nodes → MD 模式
            if (previewMarkdown.isEmpty && !isPreviewing)
              _buildEmptyStateMarkdown(context)
            else if (isPreviewing)
              const Center(child: CircularProgressIndicator())
            else
              _buildMarkdownPreview(),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyStateNodes(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.preview,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Preview will appear here',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a source and click "Preview" to see the conversion results',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateMarkdown(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Markdown preview will appear here',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildNodesPreview(BuildContext context) {
    return Expanded(
      child: ListView.builder(
        itemCount: previewNodes.length,
        itemBuilder: (ctx, i) {
          final node = previewNodes[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(
                node.isConcept ? Icons.category : Icons.note,
                color: node.isConcept ? Colors.orange : null,
              ),
              title: Text(node.title),
              subtitle: Text(
                '${node.content?.length ?? 0} characters, ${node.references.length} references',
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMarkdownPreview() {
    return Expanded(
      child: SingleChildScrollView(
        child: SelectableText(previewMarkdown),
      ),
    );
  }
}
