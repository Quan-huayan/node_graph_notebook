import 'package:node_graph_notebook/core/commands/command_bus.dart';
import 'package:node_graph_notebook/plugins/graph/service/node_service.dart';
import 'package:node_graph_notebook/plugins/lua/service/lua_engine_service.dart';
import 'package:node_graph_notebook/core/repositories/node_repository.dart';
import 'package:node_graph_notebook/plugins/graph/command/node_commands.dart';
import 'package:node_graph_notebook/plugins/graph/handler/create_node_handler.dart';
import 'dart:io';

/// 独立的Lua脚本执行工具
///
/// 使用方法：
/// 1. 启动Node Graph Notebook应用
/// 2. 在另一个终端运行此脚本
/// 3. 脚本会通过Lua创建节点，应用中会立即看到
void main(List<String> arguments) async {
  print('🚀 Lua脚本执行工具');
  print('━' * 60);

  // 初始化服务
  print('初始化服务...');
  final nodeRepository = FileSystemNodeRepository();
  final nodeService = NodeServiceImpl(nodeRepository);
  final commandBus = CommandBus();

  // 注册命令处理器
  commandBus.registerHandler(CreateNodeCommand, CreateNodeHandler(nodeService));

  // 初始化Lua引擎
  final engine = LuaEngineService(enableDebugOutput: true);
  await engine.initialize();
  print('✅ 服务初始化完成\n');

  // 注册Lua API
  var createdCount = 0;
  engine.registerFunction('createNode', (args) {
    if (args.isEmpty) return -1;

    final nodeName = args[0].toString();
    final nodeContent = args.length > 1 ? args[1].toString() : null;

    print('  🔧 Lua: createNode("$nodeName")');

    // 通过CommandBus创建节点
    commandBus.dispatch(CreateNodeCommand(
      title: nodeName,
      content: nodeContent,
    )).then((result) {
      if (result.isSuccess && result.data != null) {
        createdCount++;
        print('  ✅ 节点创建成功! ID: ${result.data!.id}');
      } else {
        print('  ❌ 创建失败: ${result.error}');
      }
    });

    return 0;
  });

  // Lua脚本
  final luaScript = '''
print("=== Lua脚本开始执行 ===")
print()

print("📝 创建演示节点...")

createNode("Lua演示节点1", "通过Lua脚本创建的第一个节点")
createNode("Lua演示节点2", "通过Lua脚本创建的第二个节点")
createNode("Lua演示节点3", "通过Lua脚本创建的第三个节点")

print()
print("✅ 所有节点创建完成！")
print("💡 请在应用中查看这些节点")
print("=== 脚本执行完成 ===")
''';

  print('执行Lua脚本:\n');
  final result = await engine.executeString(luaScript);

  print('\n📊 执行结果:');
  print('━' * 60);
  print('成功: ${result.success}');
  print('输出: ${result.output.length}行');

  if (result.output.isNotEmpty) {
    print('\n脚本输出:');
    for (final line in result.output) {
      print('  $line');
    }
  }

  // 等待异步操作完成
  print('\n⏳ 等待节点创建完成...');
  await Future.delayed(const Duration(seconds: 2));

  print('\n📊 统计:');
  print('━' * 60);
  print('请求创建: 3个节点');
  print('实际创建: $createdCount个节点');

  if (createdCount > 0) {
    print('\n🎉 成功！节点已创建到数据存储！');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📱 下一步:');
    print('   1. 打开Node Graph Notebook应用');
    print('   2. 查找标题为"Lua演示节点1/2/3"的节点');
    print('   3. 这些节点应该现在可见了');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  } else {
    print('\n❌ 没有节点被创建');
    print('💡 可能的原因:');
    print('   - 数据目录权限问题');
    print('   - 存储路径配置问题');
  }

  // 清理
  await engine.dispose();

  print('\n按任意键退出...');
  stdin.echoMode = false;
  stdin.lineMode = false;
  stdin.readByteSync();
}
