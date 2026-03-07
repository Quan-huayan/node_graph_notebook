import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/models/models.dart';

void main() {
  group('NodeReference', () {
    late NodeReference testReference;

    setUp(() {
      testReference = const NodeReference(
        nodeId: 'target-node-id',
        type: ReferenceType.relatesTo,
        role: 'connected',
        metadata: {'strength': 0.8},
      );
    });

    test('should create a reference with all fields', () {
      expect(testReference.nodeId, 'target-node-id');
      expect(testReference.type, ReferenceType.relatesTo);
      expect(testReference.role, 'connected');
      expect(testReference.metadata, {'strength': 0.8});
    });

    test('should create a reference with only required fields', () {
      const minimalReference = NodeReference(
        nodeId: 'target-id',
        type: ReferenceType.dependsOn,
      );

      expect(minimalReference.nodeId, 'target-id');
      expect(minimalReference.type, ReferenceType.dependsOn);
      expect(minimalReference.role, null);
      expect(minimalReference.metadata, null);
    });

    test('should copy with updated fields', () {
      final updatedReference = testReference.copyWith(
        role: 'updated-role',
        type: ReferenceType.contains,
      );

      expect(updatedReference.nodeId, testReference.nodeId); // Unchanged
      expect(updatedReference.role, 'updated-role');
      expect(updatedReference.type, ReferenceType.contains);
      expect(updatedReference.metadata, testReference.metadata); // Unchanged
    });

    test('should implement equality based on nodeId and type', () {
      const ref1 = NodeReference(
        nodeId: 'node-1',
        type: ReferenceType.relatesTo,
        role: 'role1',
      );

      const ref2 = NodeReference(
        nodeId: 'node-1',
        type: ReferenceType.relatesTo,
        role: 'role2', // Different role but same nodeId and type
      );

      const ref3 = NodeReference(
        nodeId: 'node-2', // Different nodeId
        type: ReferenceType.relatesTo,
      );

      const ref4 = NodeReference(
        nodeId: 'node-1',
        type: ReferenceType.contains, // Different type
      );

      expect(ref1, ref2); // Same nodeId and type
      expect(ref1 == ref3, false); // Different nodeId
      expect(ref1 == ref4, false); // Different type
      expect(ref1.hashCode, ref2.hashCode);
    });

    test('should provide meaningful toString', () {
      final str = testReference.toString();
      expect(str, contains('target-node-id'));
      expect(str, contains('relatesTo'));
      expect(str, contains('connected'));
    });

    group('JSON Serialization', () {
      test('should serialize to JSON correctly', () {
        final json = testReference.toJson();

        expect(json['nodeId'], 'target-node-id');
        expect(json['type'], 'relatesTo');
        expect(json['role'], 'connected');
        expect(json['metadata'], {'strength': 0.8});
      });

      test('should deserialize from JSON correctly', () {
        final json = testReference.toJson();
        final deserializedRef = NodeReference.fromJson(json);

        expect(deserializedRef.nodeId, testReference.nodeId);
        expect(deserializedRef.type, testReference.type);
        expect(deserializedRef.role, testReference.role);
        expect(deserializedRef.metadata, testReference.metadata);
      });

      test('should handle serialization/deserialization roundtrip', () {
        final json = testReference.toJson();
        final roundtripRef = NodeReference.fromJson(json);

        expect(testReference, roundtripRef);
      });

      test('should deserialize JSON with null optional fields', () {
        final json = {
          'nodeId': 'target-id',
          'type': 'relatesTo',
          'role': null,
          'metadata': null,
        };

        final ref = NodeReference.fromJson(json);

        expect(ref.nodeId, 'target-id');
        expect(ref.type, ReferenceType.relatesTo);
        expect(ref.role, null);
        expect(ref.metadata, null);
      });
    });
  });

  group('ReferenceType enum', () {
    test('should have all expected values', () {
      expect(ReferenceType.values.length, 8);
      expect(ReferenceType.values, contains(ReferenceType.mentions));
      expect(ReferenceType.values, contains(ReferenceType.contains));
      expect(ReferenceType.values, contains(ReferenceType.dependsOn));
      expect(ReferenceType.values, contains(ReferenceType.causes));
      expect(ReferenceType.values, contains(ReferenceType.partOf));
      expect(ReferenceType.values, contains(ReferenceType.relatesTo));
      expect(ReferenceType.values, contains(ReferenceType.references));
      expect(ReferenceType.values, contains(ReferenceType.instanceOf));
    });

    test('should serialize enum values correctly', () {
      expect(ReferenceType.mentions.name, 'mentions');
      expect(ReferenceType.contains.name, 'contains');
      expect(ReferenceType.dependsOn.name, 'dependsOn');
      expect(ReferenceType.causes.name, 'causes');
      expect(ReferenceType.partOf.name, 'partOf');
      expect(ReferenceType.relatesTo.name, 'relatesTo');
      expect(ReferenceType.references.name, 'references');
      expect(ReferenceType.instanceOf.name, 'instanceOf');
    });
  });

  group('NodeViewMode enum', () {
    test('should have all expected values', () {
      expect(NodeViewMode.values.length, 4);
      expect(NodeViewMode.values, contains(NodeViewMode.titleOnly));
      expect(NodeViewMode.values, contains(NodeViewMode.titleWithPreview));
      expect(NodeViewMode.values, contains(NodeViewMode.fullContent));
      expect(NodeViewMode.values, contains(NodeViewMode.compact));
    });
  });

  group('LayoutAlgorithm enum', () {
    test('should have all expected values', () {
      expect(LayoutAlgorithm.values.length, 5);
      expect(LayoutAlgorithm.values, contains(LayoutAlgorithm.forceDirected));
      expect(LayoutAlgorithm.values, contains(LayoutAlgorithm.hierarchical));
      expect(LayoutAlgorithm.values, contains(LayoutAlgorithm.circular));
      expect(LayoutAlgorithm.values, contains(LayoutAlgorithm.conceptMap));
      expect(LayoutAlgorithm.values, contains(LayoutAlgorithm.free));
    });
  });

  group('BackgroundStyle enum', () {
    test('should have all expected values', () {
      expect(BackgroundStyle.values.length, 3);
      expect(BackgroundStyle.values, contains(BackgroundStyle.grid));
      expect(BackgroundStyle.values, contains(BackgroundStyle.dots));
      expect(BackgroundStyle.values, contains(BackgroundStyle.none));
    });
  });

  group('LineStyle enum', () {
    test('should have all expected values', () {
      expect(LineStyle.values.length, 3);
      expect(LineStyle.values, contains(LineStyle.solid));
      expect(LineStyle.values, contains(LineStyle.dashed));
      expect(LineStyle.values, contains(LineStyle.dotted));
    });
  });
}
