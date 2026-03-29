/// Node template system for plugin integration.
///
/// This module defines the Node template system, allowing plugins to
/// register Node templates that can be instantiated by the UILayoutService.
///
/// ## Key Concepts
///
/// - **NodeTemplate**: Factory function + metadata for creating Nodes
/// - **NodeFactory**: Function that creates Node instances
/// - **NodeTemplateRegistry**: Central registry for all Node templates
///
/// ## Architecture
///
/// ```
/// Plugin registers NodeTemplate
///     ↓
/// NodeTemplateRegistry stores template
///     ↓
/// UILayoutService creates Node from template
///     ↓
/// Node attached to Hook
/// ```
///
/// ## Usage
///
/// ```dart
/// // In plugin:
/// final template = NodeTemplate(
///   id: 'com.example.myPlugin.textNode',
///   name: 'Text Node',
///   factory: ({required id, required title, content}) {
///     return Node(
///       id: id,
///       title: title,
///       content: content,
///     );
///   },
///   defaultHookId: 'sidebar',
///   defaultPosition: LocalPosition.sequential(index: 0),
/// );
///
/// layoutService.registerNodeTemplate(template);
///
/// // Create Node from template:
/// final node = await layoutService.createNodeFromTemplate(
///   templateId: 'com.example.myPlugin.textNode',
///   title: 'My Note',
///   content: 'Hello World',
/// );
/// ```
library;

import 'package:flutter/material.dart';

import '../models/node.dart' show Node;
import 'coordinate_system.dart';

/// Factory function for creating Node instances.
///
/// [id] is the unique ID for the Node (required).
/// [title] is the Node's title (required).
/// [content] is the Node's content (optional).
/// Additional parameters can be passed via [params] map.
typedef NodeFactory = Node Function({
  required String id,
  required String title,
  String? content,
  Map<String, dynamic>? params,
});

/// Template for creating Nodes.
///
/// Contains a factory function and metadata for Node creation.
/// Plugins register NodeTemplates to allow UILayoutService to
/// create Node instances.
///
/// ## Example
///
/// ```dart
/// final template = NodeTemplate(
///   id: 'com.example.textNode',
///   name: 'Text Node',
///   description: 'A simple text note node',
///   category: 'text',
///   factory: ({required id, required title, content, params}) {
///     return Node(
///       id: id,
///       title: title,
///       content: content ?? '',
///       metadata: params?['metadata'],
///     );
///   },
///   defaultHookId: 'sidebar',
///   defaultPosition: LocalPosition.sequential(index: 0),
///   icon: Icons.note,
/// );
/// ```
class NodeTemplate {
  /// Creates a Node template.
  ///
  /// [id] is the unique template ID (e.g., 'com.plugin.nodeType').
  /// [name] is the human-readable name.
  /// [factory] is the function that creates Node instances.
  /// [description] is optional description.
  /// [category] is optional category for grouping templates.
  /// [defaultHookId] is the default Hook where Nodes are attached.
  /// [defaultPosition] is the default position for new Nodes.
  /// [defaultSize] is the default size for Nodes.
  /// [icon] is the icon for UI display (Flutter IconData).
  /// [metadata] is optional additional metadata.
  /// [params] is optional default parameters for factory.
  const NodeTemplate({
    required this.id,
    required this.name,
    required this.factory,
    this.description,
    this.category,
    this.defaultHookId,
    this.defaultPosition,
    this.defaultSize,
    this.icon,
    this.metadata,
    this.params,
  });

  /// Unique template ID (e.g., 'com.plugin.nodeType').
  final String id;

  /// Human-readable name.
  final String name;

  /// Factory function for creating Nodes.
  final NodeFactory factory;

  /// Optional description.
  final String? description;

  /// Optional category for grouping.
  final String? category;

  /// Default Hook ID where Nodes are attached.
  final String? defaultHookId;

  /// Default position for new Nodes.
  final LocalPosition? defaultPosition;

  /// Default size for Nodes.
  final Size? defaultSize;

  /// Icon for UI display.
  final IconData? icon;

  /// Optional additional metadata.
  final Map<String, dynamic>? metadata;

  /// Default parameters for factory function.
  final Map<String, dynamic>? params;

  /// Creates a copy of this template with some fields replaced.
  NodeTemplate copyWith({
    String? id,
    String? name,
    NodeFactory? factory,
    String? description,
    String? category,
    String? defaultHookId,
    LocalPosition? defaultPosition,
    Size? defaultSize,
    IconData? icon,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? params,
  }) => NodeTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      factory: factory ?? this.factory,
      description: description ?? this.description,
      category: category ?? this.category,
      defaultHookId: defaultHookId ?? this.defaultHookId,
      defaultPosition: defaultPosition ?? this.defaultPosition,
      defaultSize: defaultSize ?? this.defaultSize,
      icon: icon ?? this.icon,
      metadata: metadata ?? this.metadata,
      params: params ?? this.params,
    );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is NodeTemplate && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'NodeTemplate(id: $id, name: $name, category: $category)';
}

/// Registry for Node templates.
///
/// Central repository where plugins register their Node templates.
/// UILayoutService uses this registry to create Node instances.
///
/// ## Usage
///
/// ```dart
/// final registry = NodeTemplateRegistry();
///
/// // Register template
/// registry.register(textNodeTemplate);
///
/// // Get template
/// final template = registry.get('com.example.textNode');
///
/// // List templates by category
/// final textTemplates = registry.getByCategory('text');
///
/// // Create Node from template
/// final node = await registry.createNode(
///   templateId: 'com.example.textNode',
///   id: 'node-123',
///   title: 'My Note',
///   content: 'Hello',
/// );
/// ```
class NodeTemplateRegistry {
  /// Creates a Node template registry.
  NodeTemplateRegistry();

  /// Registered templates by ID.
  final Map<String, NodeTemplate> _templates = {};

  /// Templates indexed by category.
  final Map<String, List<NodeTemplate>> _templatesByCategory = {};

  /// Registers a Node template.
  ///
  /// [template] is the template to register.
  ///
  /// Throws [StateError] if a template with the same ID already exists.
  void register(NodeTemplate template) {
    if (_templates.containsKey(template.id)) {
      throw StateError('Template already registered: ${template.id}');
    }

    _templates[template.id] = template;

    // Index by category
    if (template.category != null) {
      _templatesByCategory.putIfAbsent(template.category!, () => []);
      _templatesByCategory[template.category]!.add(template);
    }
  }

  /// Unregisters a Node template.
  ///
  /// [templateId] is the ID of the template to unregister.
  ///
  /// Returns the removed template, or null if not found.
  NodeTemplate? unregister(String templateId) {
    final template = _templates.remove(templateId);

    if (template != null && template.category != null) {
      _templatesByCategory[template.category]?.remove(template);
    }

    return template;
  }

  /// Gets a template by ID.
  ///
  /// [templateId] is the template ID.
  ///
  /// Returns the template, or null if not found.
  NodeTemplate? get(String templateId) => _templates[templateId];

  /// Checks if a template is registered.
  ///
  /// [templateId] is the template ID.
  bool has(String templateId) => _templates.containsKey(templateId);

  /// Gets all registered templates.
  ///
  /// Returns an unmodifiable list of all templates.
  List<NodeTemplate> getAll() => _templates.values.toList();

  /// Gets templates by category.
  ///
  /// [category] is the category to filter by.
  ///
  /// Returns a list of templates in the category, or empty list if none found.
  List<NodeTemplate> getByCategory(String category) => List.unmodifiable(_templatesByCategory[category] ?? []);

  /// Gets all template categories.
  ///
  /// Returns a list of unique category names.
  List<String> getCategories() => _templatesByCategory.keys.toList();

  /// Creates a Node from a template.
  ///
  /// [templateId] is the ID of the template to use.
  /// [id] is the unique ID for the new Node.
  /// [title] is the Node's title.
  /// [content] is optional Node content.
  /// [params] are optional additional parameters for the factory.
  ///
  /// Throws [ArgumentError] if template not found.
  Node createNode({
    required String templateId,
    required String id,
    required String title,
    String? content,
    Map<String, dynamic>? params,
  }) {
    final template = _templates[templateId];
    if (template == null) {
      throw ArgumentError('Template not found: $templateId');
    }

    // Merge default params with provided params
    final mergedParams = <String, dynamic>{
      ...?template.params,
      ...?params,
    };

    return template.factory(
      id: id,
      title: title,
      content: content,
      params: mergedParams,
    );
  }

  /// Clears all registered templates.
  ///
  /// Useful for testing or plugin unloading.
  void clear() {
    _templates.clear();
    _templatesByCategory.clear();
  }

  /// Gets the total number of registered templates.
  int get count => _templates.length;

  @override
  String toString() =>
      'NodeTemplateRegistry(templates: ${_templates.length}, categories: ${_templatesByCategory.length})';
}
