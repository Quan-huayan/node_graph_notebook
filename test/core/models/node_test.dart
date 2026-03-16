import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/models/enums.dart';
import 'package:node_graph_notebook/core/models/node.dart';
import 'package:node_graph_notebook/core/models/node_reference.dart';

void main() {
  group('Node', () {
    late Node node;
    late NodeReference reference;
    late DateTime now;

    setUp(() {
      now = DateTime.now();
      reference = const NodeReference(
        nodeId: 'ref_1',
        properties: {'type': 'test_type'},
      );
      node = Node(
        id: 'node_1',
        title: 'Test Node',
        content: 'Test content',
        references: {'ref_1': reference},
        position: const Offset(100, 200),
        size: const Size(200, 100),
        viewMode: NodeViewMode.fullContent,
        color: '#FF0000',
        createdAt: now,
        updatedAt: now,
        metadata: {'key': 'value'},
      );
    });

    test('should create a Node instance with correct properties', () {
      expect(node.id, 'node_1');
      expect(node.title, 'Test Node');
      expect(node.content, 'Test content');
      expect(node.references.length, 1);
      expect(node.references['ref_1'], reference);
      expect(node.position, const Offset(100, 200));
      expect(node.size, const Size(200, 100));
      expect(node.viewMode, NodeViewMode.fullContent);
      expect(node.color, '#FF0000');
      expect(node.createdAt, now);
      expect(node.updatedAt, now);
      expect(node.metadata, {'key': 'value'});
    });

    test('should return correct referencedNodeIds', () {
      expect(node.referencedNodeIds, ['ref_1']);
    });

    test('should return correct references by type', () {
      final result = node.getReferencesByType('test_type');
      expect(result.length, 1);
      expect(result[0], reference);

      final emptyResult = node.getReferencesByType('non_existent');
      expect(emptyResult, isEmpty);
    });

    test('should check if node is a folder', () {
      expect(node.isFolder, false);

      final folderNode = node.copyWith(metadata: {'isFolder': true});
      expect(folderNode.isFolder, true);
    });

    test('should add a reference', () {
      const newReference = NodeReference(
        nodeId: 'ref_2',
        properties: {'type': 'new_type'},
      );
      final updatedNode = node.addReference('ref_2', newReference);

      expect(updatedNode.references.length, 2);
      expect(updatedNode.references['ref_2'], newReference);
    });

    test('should remove a reference', () {
      final updatedNode = node.removeReference('ref_1');
      expect(updatedNode.references.length, 0);
    });

    test('should update timestamp', () {
      final updatedNode = node.updateTimestamp();
      expect(updatedNode.updatedAt.isAfter(now) || updatedNode.updatedAt.isAtSameMomentAs(now), true);
    });

    test('should copy with updated fields', () {
      const newPosition = Offset(300, 400);
      final updatedNode = node.copyWith(
        title: 'Updated Title',
        position: newPosition,
      );

      expect(updatedNode.title, 'Updated Title');
      expect(updatedNode.position, newPosition);
      expect(updatedNode.id, node.id); // Should remain the same
    });

    test('should have correct equality check', () {
      final sameNode = Node(
        id: 'node_1',
        title: 'Test Node',
        content: 'Test content',
        references: {'ref_1': reference},
        position: const Offset(100, 200),
        size: const Size(200, 100),
        viewMode: NodeViewMode.fullContent,
        color: '#FF0000',
        createdAt: now,
        updatedAt: now,
        metadata: {'key': 'value'},
      );

      final differentNode = node.copyWith(id: 'node_2');

      expect(node == sameNode, true);
      expect(node == differentNode, false);
    });

    test('should have correct hashCode', () {
      expect(node.hashCode, 'node_1'.hashCode);
    });

    test('should have correct toString', () {
      expect(node.toString(), 'Node(id: node_1, title: Test Node, refs: 1)');
    });
  });
}
