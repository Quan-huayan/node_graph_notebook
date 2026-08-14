/// Lua 动态 Concept 引擎测试（M7，01-E 承诺落地）：
///
/// 脚本定义 Concept（validate/createHook 用 Lua 实现）→ findFor 命中
/// （结构匹配）；脚本命令（Commands 表）→ dispatch 路由；宿主写 API
/// （host.node_update）→ LuaWriteCommand → 落盘 + 写后通知；坏脚本隔离；
/// 沙箱（危险 API 禁用）；插件禁用 → 兜底（永不空洞）。
library;

import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:core/core.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_lua/node_lua.dart';
import 'package:plugon/plugon.dart';

/// 示例脚本夹具（定义动态 Concept「special」+ 命令 mine.markSpecial）。
///
/// 约定：slots/requiredMetadataKeys 用**键集形态**（{ kind = true }——
/// Lua 数组形态的数字键在表提取中不可枚举，01 文档化约定）。
const String sampleSpecialScript = '''
Concept = {
  id = "com.example.mine:special",
  name = "特殊节点",
  description = "Lua 动态 Concept 示例",
  slots = { source = true },
  requiredSlots = {},
  requiredMetadataKeys = { kind = true },
  contentRequirement = "none",
  validate = function(node)
    return node.metadata.kind == "special"
  end,
  createHook = function(node, kind)
    return { nodeId = node.id, hookId = node.id .. "@" .. kind }
  end,
}

Commands = {
  ["mine.markSpecial"] = function(payload)
    local ok = host.node_update({ id = payload.target, metadata = { kind = "special" } })
    if string.sub(ok, 1, 2) == "ok" or string.sub(ok, 1, 8) == "affected" then
      return "affected:" .. payload.target .. ";data"
    end
    return ok
  end,
}
''';

void main() {
  late Directory root;
  late Directory scriptsDir;
  late HostRuntime host;
  late LuaPlugin luaPlugin;
  final writes = <WriteResult>[];

  setUp(() async {
    root = Directory.systemTemp.createTempSync('ngn_lua');
    scriptsDir = Directory('${root.path}${Platform.pathSeparator}lua_scripts')
      ..createSync();
    addTearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });
    writes.clear();
    host = HostRuntime(dataRoot: root);
    final now = DateTime.now();
    <StoredNode>[
      StoredNode(
        id: 'root',
        title: '根目录',
        metadata: const <String, dynamic>{'kind': 'folder'},
        createdAt: now,
        updatedAt: now,
      ),
      StoredNode(
        id: 'noteA',
        title: '笔记A',
        content: '普通笔记',
        createdAt: now,
        updatedAt: now,
      ),
    ].forEach(host.graph.save);
    // 示例脚本（测试夹具，内联——flutter test cwd = workspace 根，
    // 相对路径不可靠）。
    File(
      '${scriptsDir.path}${Platform.pathSeparator}special.lua',
    ).writeAsStringSync(sampleSpecialScript);
    luaPlugin = LuaPlugin(scriptsDir: scriptsDir);
    await host.start(plugins: <Plugin>[luaPlugin], rootNodeId: 'root');
    host.commandBus.attach(writes.add);
  });

  group('LuaConcept（脚本化 Concept，01-E 薄度验证）', () {
    test('脚本加载：Concept 表解析为 LuaConcept', () {
      expect(luaPlugin.concepts, hasLength(1));
      final concept = luaPlugin.concepts['special']!;
      expect(concept.id, 'com.example.mine:special');
      expect(concept.name, '特殊节点');
      expect(concept.requiredMetadataKeys, <String>{'kind'});
    });

    test('归属判定 = Lua validate（kind == special 命中）', () {
      final special = StoredNode(
        id: 's1',
        title: '特殊',
        metadata: const <String, dynamic>{'kind': 'special'},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final concept = host.concepts.findFor(special);
      expect(concept.id, 'com.example.mine:special');
      // 普通笔记不命中（Lua validate 返回 false → 兜底 Concept）。
      final note = host.graph.get('noteA')!;
      expect(host.concepts.findFor(note).id, isNot('com.example.mine:special'));
    });

    test('createHook 委托 Lua（hookId = nodeId@kind）', () {
      final concept = luaPlugin.concepts['special']!;
      final hook = concept.createHook(
        StoredNode(
          id: 's1',
          title: '特殊',
          metadata: const <String, dynamic>{'kind': 'special'},
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        const HookContext(kind: 'graph'),
      );
      expect(hook.hookId, 's1@graph');
    });

    test('脚本未定义 validate → Dart 侧结构匹配兜底（永不空洞）', () async {
      // 坏脚本场景在下一组测；此处验证 LuaConcept 默认 validate 路径
      // （脚本只有 requiredMetadataKeys 无 validate 函数时）。
      final scriptDir2 = Directory('${root.path}${Platform.pathSeparator}lua2')
        ..createSync();
      File(
        '${scriptDir2.path}${Platform.pathSeparator}kv.lua',
      ).writeAsStringSync(
        'Concept = { id = "com.example.kv:kv", name = "KV", '
        'requiredMetadataKeys = { kv = true }, contentRequirement = "none" }\n',
      );
      final engine = LuaEngine()..initialize();
      final loader = LuaScriptLoader(engine: engine);
      final result = loader.loadAll(scriptDir2.path).single;
      expect(result.ok, isTrue);
      final kv = result.concept!;
      expect(
        kv.validate(
          StoredNode(
            id: 'k1',
            title: 'K',
            metadata: const <String, dynamic>{'kv': true},
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ),
        isTrue,
      );
      expect(
        kv.validate(
          StoredNode(
            id: 'k2',
            title: 'K',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ),
        isFalse,
      );
      engine.dispose();
    });
  });

  group('脚本命令（Commands 表 → LuaCommandHandler）', () {
    test('脚本命令路由 + Lua 写经宿主 API 落盘', () async {
      // 命令将 noteA 的 kind 改为 special（host.node_update 经 LuaWriteCommand）。
      final result = await host.commandBus
          .dispatch<LuaCommand, LuaCommandResult>(
            const LuaCommand(
              commandName: 'mine.markSpecial',
              payloadValue: <String, dynamic>{'target': 'noteA'},
            ),
          );
      expect(result.affectedNodeIds, <String>{'noteA'});
      expect(result.changeKind, ChangeKind.data);
      // 落盘生效（写经 Dart Handler，00 不变量 4.4-1）。
      final note = host.graph.get('noteA')!;
      expect(note.metadata['kind'], 'special');
      // 写后通知（LuaWriteCommand dispatch 后 CommandBus 统一发）。
      expect(writes.any((w) => w.affectedNodeIds.contains('noteA')), isTrue);
      // 改后归属 = Lua Concept（结构匹配实时生效）。
      expect(host.concepts.findFor(note).id, 'com.example.mine:special');
    });

    test('未注册命令 → StateError', () async {
      expect(
        () => host.commandBus.dispatch<LuaCommand, LuaCommandResult>(
          const LuaCommand(
            commandName: 'no.such',
            payloadValue: <String, dynamic>{},
          ),
        ),
        throwsStateError,
      );
    });
  });

  group('宿主写 API（LuaWriteCommand）', () {
    test('node_create 落盘（经 CommandBus dispatch 直连）', () async {
      final result = await host.commandBus
          .dispatch<LuaWriteCommand, LuaWriteResult>(
            const LuaWriteCommand(
              action: 'create',
              nodeId: 'lua1',
              title: 'Lua 创建',
              content: '内容',
              metadata: <String, dynamic>{'kind': 'special'},
            ),
          );
      expect(result.affectedNodeIds, <String>{'lua1'});
      final node = host.graph.get('lua1')!;
      expect(node.title, 'Lua 创建');
      expect(node.metadata['kind'], 'special');
      expect(host.concepts.findFor(node).id, 'com.example.mine:special');
    });

    test('update 引用变更触发环校验（Lua 写不绕过 Handler）', () async {
      // 先写入合法引用（references 变更落盘）。
      await host.commandBus.dispatch<LuaWriteCommand, LuaWriteResult>(
        const LuaWriteCommand(
          action: 'update',
          nodeId: 'noteA',
          references: <String, String>{'related': 'root'},
        ),
      );
      expect(host.graph.get('noteA')!.references['related'], 'root');
      // 自引用 → CycleError（00 不变量 4.4-1：写校验不因 Lua 而豁免）。
      expect(
        () => host.commandBus.dispatch<LuaWriteCommand, LuaWriteResult>(
          const LuaWriteCommand(
            action: 'update',
            nodeId: 'noteA',
            references: <String, String>{'self': 'noteA'},
          ),
        ),
        throwsA(isA<CycleError>()),
      );
      // 被拒后节点保持原引用（无副作用）。
      expect(host.graph.get('noteA')!.references['related'], 'root');
    });

    test('delete 不存在节点 → StateError', () async {
      expect(
        () => host.commandBus.dispatch<LuaWriteCommand, LuaWriteResult>(
          const LuaWriteCommand(action: 'delete', nodeId: 'ghost'),
        ),
        throwsStateError,
      );
    });
  });

  group('隔离与沙箱', () {
    test('坏脚本隔离：语法错误脚本跳过，好脚本正常', () async {
      final scriptDir2 = Directory('${root.path}${Platform.pathSeparator}lua3')
        ..createSync();
      // 坏脚本（语法错误）。
      File(
        '${scriptDir2.path}${Platform.pathSeparator}bad.lua',
      ).writeAsStringSync('Concept = { id = "bad" 这语法错');
      // 好脚本。
      File(
        '${scriptDir2.path}${Platform.pathSeparator}good.lua',
      ).writeAsStringSync(
        'Concept = { id = "com.example.good:g", name = "G", '
        'requiredMetadataKeys = { "g" }, contentRequirement = "none" }\n',
      );
      final engine = LuaEngine()..initialize();
      final loader = LuaScriptLoader(engine: engine);
      final results = loader.loadAll(scriptDir2.path);
      // 坏脚本被隔离（ok = false 且带错误），好脚本正常。
      expect(results, hasLength(2));
      final bad = results.firstWhere((r) => r.scriptId == 'bad');
      expect(bad.ok, isFalse);
      expect(bad.error, isNotNull);
      final good = results.firstWhere((r) => r.scriptId == 'good');
      expect(good.ok, isTrue);
      expect(good.concept!.id, 'com.example.good:g');
      engine.dispose();
    });

    test('沙箱：os 被禁用（脚本无法执行系统命令）', () {
      final engine = LuaEngine()..initialize();
      // os/io 已置 nil——访问即报错（LuaEngineException）。
      expect(
        () => engine.run('os.execute("echo hi")'),
        throwsA(isA<LuaEngineException>()),
      );
      engine.dispose();
    });

    test('引擎重复初始化 → StateError（状态机防护）', () {
      final engine = LuaEngine();
      engine.initialize();
      expect(engine.initialize, throwsStateError);
      engine.dispose();
    });
  });
}
