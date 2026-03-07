import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/models/models.dart';
import '../../test_helpers.dart';

void main() {
  group('Connection', () {
    late Connection testConnection;

    setUp(() {
      testConnection = const Connection(
        id: 'node1_node2',
        fromNodeId: 'node1',
        toNodeId: 'node2',
        referenceType: ReferenceType.relatesTo,
        role: 'connected',
        color: '#FF0000',
        lineStyle: LineStyle.solid,
        thickness: 2.0,
      );
    });

    test('should create connection with all fields', () {
      expect(testConnection.id, 'node1_node2');
      expect(testConnection.fromNodeId, 'node1');
      expect(testConnection.toNodeId, 'node2');
      expect(testConnection.referenceType, ReferenceType.relatesTo);
      expect(testConnection.role, 'connected');
      expect(testConnection.color, '#FF0000');
      expect(testConnection.lineStyle, LineStyle.solid);
      expect(testConnection.thickness, 2.0);
    });

    test('should create connection with minimal fields', () {
      const minimalConnection = Connection(
        id: 'node1_node2',
        fromNodeId: 'node1',
        toNodeId: 'node2',
        referenceType: ReferenceType.dependsOn,
        lineStyle: LineStyle.dashed,
        thickness: 1.5,
      );

      expect(minimalConnection.fromNodeId, 'node1');
      expect(minimalConnection.toNodeId, 'node2');
      expect(minimalConnection.referenceType, ReferenceType.dependsOn);
      expect(minimalConnection.role, null);
      expect(minimalConnection.color, null);
    });

    test('should calculate connections from nodes', () {
      final node1 = NodeTestHelpers.test(id: 'node1', title: 'Node 1', content: 'Content 1');

      final node2 = NodeTestHelpers.test(
        id: 'node2',
        title: 'Node 2',
        content: 'Content 2',
        references: {
          'node3': const NodeReference(
            nodeId: 'node3',
            type: ReferenceType.contains,
          ),
        },
      );

      final node3 = NodeTestHelpers.test(id: 'node3', title: 'Node 3', content: 'Content 3');

      final connections = Connection.calculateConnections([node1, node2, node3]);

      expect(connections.length, 1); // Only node2 -> node3
      expect(connections[0].fromNodeId, 'node2');
      expect(connections[0].toNodeId, 'node3');
      expect(connections[0].referenceType, ReferenceType.contains);
    });

    test('should get correct line style for reference type', () {
      final containsConnection = const Connection(
        id: 'node1_node2',
        fromNodeId: 'node1',
        toNodeId: 'node2',
        referenceType: ReferenceType.contains,
        lineStyle: LineStyle.dashed,
        thickness: 2.0,
      );

      expect(containsConnection.lineStyle, LineStyle.dashed);

      final causesConnection = const Connection(
        id: 'node1_node2',
        fromNodeId: 'node1',
        toNodeId: 'node2',
        referenceType: ReferenceType.causes,
        lineStyle: LineStyle.solid,
        thickness: 3.0,
      );

      expect(causesConnection.lineStyle, LineStyle.solid);
    });

    test('should get correct thickness for reference type', () {
      final containsConnection = const Connection(
        id: 'node1_node2',
        fromNodeId: 'node1',
        toNodeId: 'node2',
        referenceType: ReferenceType.contains,
        lineStyle: LineStyle.dashed,
        thickness: 2.0,
      );

      expect(containsConnection.thickness, 2.0);

      final causesConnection = const Connection(
        id: 'node1_node2',
        fromNodeId: 'node1',
        toNodeId: 'node2',
        referenceType: ReferenceType.causes,
        lineStyle: LineStyle.solid,
        thickness: 3.0,
      );

      expect(causesConnection.thickness, 3.0);
    });

    test('should create reverse connection', () {
      final reverseConnection = testConnection.reverse;

      expect(reverseConnection.id, 'node2_node1');
      expect(reverseConnection.fromNodeId, 'node2');
      expect(reverseConnection.toNodeId, 'node1');
      expect(reverseConnection.referenceType, testConnection.referenceType);
      expect(reverseConnection.role, testConnection.role);
      expect(reverseConnection.color, testConnection.color);
      expect(reverseConnection.lineStyle, testConnection.lineStyle);
      expect(reverseConnection.thickness, testConnection.thickness);
    });

    test('should implement equality based on id', () {
      const identicalConnection = Connection(
        id: 'node1_node2',
        fromNodeId: 'node1',
        toNodeId: 'node2',
        referenceType: ReferenceType.relatesTo,
        lineStyle: LineStyle.solid,
        thickness: 2.0,
      );

      expect(testConnection, identicalConnection);
      expect(testConnection.hashCode, identicalConnection.hashCode);
    });

    test('should not be equal with different id', () {
      const differentConnection = Connection(
        id: 'node2_node3', // Different ID
        fromNodeId: 'node2',
        toNodeId: 'node3',
        referenceType: ReferenceType.relatesTo,
        lineStyle: LineStyle.solid,
        thickness: 2.0,
      );

      expect(testConnection == differentConnection, false);
    });

    test('should provide meaningful toString', () {
      final str = testConnection.toString();

      expect(str, contains('node1'));
      expect(str, contains('node2'));
      expect(str, contains('relatesTo'));
    });

    group('JSON Serialization', () {
      test('should serialize to JSON correctly', () {
        final json = testConnection.toJson();

        expect(json['id'], 'node1_node2');
        expect(json['fromNodeId'], 'node1');
        expect(json['toNodeId'], 'node2');
        expect(json['referenceType'], 'relatesTo');
        expect(json['role'], 'connected');
        expect(json['color'], '#FF0000');
        expect(json['lineStyle'], 'solid');
        expect(json['thickness'], 2.0);
      });

      test('should deserialize from JSON correctly', () {
        final json = testConnection.toJson();
        final deserializedConnection = Connection.fromJson(json);

        expect(deserializedConnection.id, testConnection.id);
        expect(deserializedConnection.fromNodeId, testConnection.fromNodeId);
        expect(deserializedConnection.toNodeId, testConnection.toNodeId);
        expect(deserializedConnection.referenceType, testConnection.referenceType);
        expect(deserializedConnection.role, testConnection.role);
        expect(deserializedConnection.color, testConnection.color);
        expect(deserializedConnection.lineStyle, testConnection.lineStyle);
        expect(deserializedConnection.thickness, testConnection.thickness);
      });

      test('should handle serialization/deserialization roundtrip', () {
        final json = testConnection.toJson();
        final roundtripConnection = Connection.fromJson(json);

        expect(testConnection, roundtripConnection);
      });
    });

    group('calculateConnections', () {
      test('should handle empty node list', () {
        final connections = Connection.calculateConnections([]);

        expect(connections, isEmpty);
      });

      test('should handle nodes with no references', () {
        final node = NodeTestHelpers.test(
          id: 'node1',
          title: 'Node 1',
          content: 'Content',
        );

        final connections = Connection.calculateConnections([node]);

        expect(connections, isEmpty);
      });

      test('should ignore references to non-existent nodes', () {
        final node1 = NodeTestHelpers.test(
          id: 'node1',
          title: 'Node 1',
          content: 'Content',
          references: const {
            'non-existent': NodeReference(
              nodeId: 'non-existent',
              type: ReferenceType.relatesTo,
            ),
          },
        );

        final connections = Connection.calculateConnections([node1]);

        expect(connections, isEmpty);
      });

      test('should generate connection ID from node IDs', () {
        final node1 = NodeTestHelpers.test(
          id: 'abc',
          title: 'Node 1',
          content: 'Content',
        );

        final node2 = NodeTestHelpers.test(
          id: 'def',
          title: 'Node 2',
          content: 'Content',
          references: const {
            'abc': NodeReference(
              nodeId: 'abc',
              type: ReferenceType.relatesTo,
            ),
          },
        );

        final connections = Connection.calculateConnections([node1, node2]);

        expect(connections[0].id, 'def_abc');
      });

      test('should preserve reference role and metadata in connection', () {
        final node1 = NodeTestHelpers.test(
          id: 'node1',
          title: 'Node 1',
          content: 'Content',
        );

        final node2 = NodeTestHelpers.test(
          id: 'node2',
          title: 'Node 2',
          content: 'Content',
          references: const {
            'node1': NodeReference(
              nodeId: 'node1',
              type: ReferenceType.relatesTo,
              role: 'parent',
            ),
          },
        );

        final connections = Connection.calculateConnections([node1, node2]);

        expect(connections[0].role, 'parent');
      });
    });
  });
}
