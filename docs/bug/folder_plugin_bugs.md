# Folder Plugin Bug Report

## Bug 1: Missing Import for `SidebarNodeListHook` (Critical)

**File:** [folder_plugin.dart:71](file:///d:/Projects/node_graph_notebook/lib/plugins/folder/folder_plugin.dart#L71)

**Severity:** Critical - Compilation Error

**Description:**
`SidebarNodeListHook` is referenced in `registerHooks()` but never imported. This will cause a compilation error.

**Problematic Code:**
```dart
@override
List<HookFactory> registerHooks() => [
    FolderSidebarTabHook.new,
    SidebarNodeListHook.new,  // <-- Not imported!
];
```

**Expected Fix:**
Add the missing import statement:
```dart
import '../sidebarNode/ui/sidebar_hook_renderer_simple.dart';
// or wherever SidebarNodeListHook is defined
```

---

## Bug 2: `firstWhere` Without `orElse` - Runtime Exception (Critical)

**Files:**
- [folder_item.dart:184-188](file:///d:/Projects/node_graph_notebook/lib/plugins/folder/ui/folder_item.dart#L184-L188)
- [folder_tree_view.dart:296-297](file:///d:/Projects/node_graph_notebook/lib/plugins/folder/ui/folder_tree_view.dart#L296-L297)

**Severity:** Critical - Runtime Exception

**Description:**
Using `firstWhere` without `orElse` will throw `StateError: No element` if the node is not found in the list. The subsequent check `draggedNode.id.isNotEmpty` is useless because the exception is thrown before this line executes.

**Problematic Code (folder_item.dart):**
```dart
final draggedNode = widget.allNodes.firstWhere(
  (n) => n.id == draggedNodeId,
);
if (draggedNode.id.isNotEmpty) {
  await _addToFolder(draggedNode, widget.folder);
}
```

**Problematic Code (folder_tree_view.dart):**
```dart
final draggedNode = allNodes.firstWhere((n) => n.id == draggedNodeId);
if (draggedNode.id.isNotEmpty) {
  await _addToFolder(draggedNode, folder);
}
```

**Expected Fix:**
```dart
final draggedNode = widget.allNodes.firstWhere(
  (n) => n.id == draggedNodeId,
  orElse: () => Node.empty(), // or return a sentinel node
);
if (draggedNode.id.isNotEmpty) {
  await _addToFolder(draggedNode, widget.folder);
}
```

Or use `firstWhereOrNull` from collection package.

---

## Bug 3: Duplicate Extension Definition (Critical)

**Files:**
- [folder_tree_view.dart:890-896](file:///d:/Projects/node_graph_notebook/lib/plugins/folder/ui/folder_tree_view.dart#L890-L896)
- [node_item.dart:161-167](file:///d:/Projects/node_graph_notebook/lib/plugins/folder/ui/node_item.dart#L161-L167)

**Severity:** Critical - Compilation Error (when both files imported)

**Description:**
The `NodeExtension` extension on `Node` is defined in both files with identical implementation. This will cause a compile-time error "The name 'NodeExtension' is already defined" when both files are imported together.

**Problematic Code (both files):**
```dart
extension NodeExtension on Node {
  bool get isFolder => metadata['isFolder'] == true ||
        (metadata['isFolder'] is bool && metadata['isFolder'] as bool);
}
```

**Expected Fix:**
Move the extension to a shared file (e.g., `node_extensions.dart`) and import it in both files, or keep it in only one file and import that file where needed.

---

## Bug 4: Redundant Condition in `isFolder` Getter (Minor)

**Files:**
- [folder_tree_view.dart:894-895](file:///d:/Projects/node_graph_notebook/lib/plugins/folder/ui/folder_tree_view.dart#L894-L895)
- [node_item.dart:165-166](file:///d:/Projects/node_graph_notebook/lib/plugins/folder/ui/node_item.dart#L165-L166)

**Severity:** Minor - Logic Issue

**Description:**
The second condition in the `isFolder` getter is redundant. If `metadata['isFolder']` is `true`, the first condition already returns `true`. The second condition would only be true if the value is `true`, which is already covered.

**Problematic Code:**
```dart
bool get isFolder => metadata['isFolder'] == true ||
      (metadata['isFolder'] is bool && metadata['isFolder'] as bool);
```

**Expected Fix:**
```dart
bool get isFolder => metadata['isFolder'] == true;
```

---

## Bug 5: Potential Null Callback in `FolderSidebarTabHook` (Medium)

**File:** [folder_sidebar_tab_hook.dart:38](file:///d:/Projects/node_graph_notebook/lib/plugins/folder/folder_sidebar_tab_hook.dart#L38)

**Severity:** Medium - Potential Null Reference

**Description:**
The `onNodeSelected` callback retrieved from context could be null, but it's passed to `FolderTreeView` which may expect a valid callback.

**Problematic Code:**
```dart
final onNodeSelected = context.get<Function(String?)>('onNodeSelected');
```

**Expected Fix:**
Add null check or provide a default empty callback:
```dart
final onNodeSelected = context.get<Function(String?)>('onNodeSelected') ?? ((_) {});
```

---

## Summary

| Bug # | Severity | File | Issue |
|-------|----------|------|-------|
| 1 | Critical | folder_plugin.dart | Missing import for SidebarNodeListHook |
| 2 | Critical | folder_item.dart, folder_tree_view.dart | firstWhere without orElse throws StateError |
| 3 | Critical | folder_tree_view.dart, node_item.dart | Duplicate extension definition |
| 4 | Minor | folder_tree_view.dart, node_item.dart | Redundant condition in isFolder |
| 5 | Medium | folder_sidebar_tab_hook.dart | Potential null callback |
