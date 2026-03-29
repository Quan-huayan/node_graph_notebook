import 'package:flutter/material.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/node.dart';
import '../../../core/ui_layout/coordinate_system.dart';
import '../../../core/ui_layout/node_template.dart';

/// Folder node template
///
/// Provides a factory function for creating folder nodes with the correct metadata
class FolderNodeTemplate {
  /// Gets the folder node template
  static NodeTemplate get template => NodeTemplate(
        id: 'folder_plugin.folder',
        name: 'Folder',
        description: 'A folder for organizing notes',
        category: 'folder',
        factory: ({required id, required title, content, params}) => Node(
            id: id,
            title: title,
            content: content ?? 'A folder to organize your notes',
            references: const {},
            position: Offset.zero, // Will be managed by UILayoutService in Phase 6
            size: const Size(200, 80),
            viewMode: NodeViewMode.compact,
            color: null,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            metadata: {
              'isFolder': true,
              ...?params?['metadata'],
            },
          ),
        defaultHookId: 'sidebar.bottom',
        defaultPosition: LocalPosition.sequential(index: 0),
        icon: Icons.folder,
      );
}
