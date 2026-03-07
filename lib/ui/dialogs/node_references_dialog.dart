import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/models/models.dart';
import '../../bloc/blocs.dart';

/// 显示引用信息
void showReferencesInfo(BuildContext context, Node node) {
  showDialog(
    context: context,
    builder: (ctx) => BlocBuilder<NodeBloc, NodeState>(
      builder: (ctx, nodeState) {
        return AlertDialog(
          title: Text('References: ${node.title}'),
          content: SizedBox(
            width: 400,
            child: node.references.isEmpty
                ? const Text('No references yet.')
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: node.references.entries.map((entry) {
                      final ref = entry.value;
                      final targetNode = nodeState.nodes.firstWhere(
                        (n) => n.id == entry.key,
                        orElse: () => ref as Node,
                      );

                      return ListTile(
                        leading: Icon(
                          targetNode.isConcept
                              ? Icons.category
                              : Icons.note,
                          size: 16,
                        ),
                        title: Text(entry.key),
                        subtitle: Text(getReferenceTypeLabel(ref.type)),
                        trailing: ref.role != null
                            ? Chip(
                                label: Text(ref.role!),
                                padding: EdgeInsets.zero,
                              )
                            : null,
                      );
                    }).toList(),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    ),
  );
}

/// 获取引用类型标签
String getReferenceTypeLabel(ReferenceType type) {
  switch (type) {
    case ReferenceType.mentions:
      return 'Mentions';
    case ReferenceType.contains:
      return 'Contains';
    case ReferenceType.dependsOn:
      return 'Depends On';
    case ReferenceType.causes:
      return 'Causes';
    case ReferenceType.partOf:
      return 'Part Of';
    case ReferenceType.relatesTo:
      return 'Related';
    case ReferenceType.references:
      return 'References';
    case ReferenceType.instanceOf:
      return 'Instance Of';
  }
}
