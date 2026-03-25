import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:node_graph_notebook/core/models/enums.dart';
import 'package:node_graph_notebook/core/models/node.dart';
import 'package:node_graph_notebook/core/repositories/graph_repository.dart';
import 'package:node_graph_notebook/core/repositories/node_repository.dart';
import 'package:node_graph_notebook/plugins/lua/service/lua_api_implementation.dart';
import 'package:node_graph_notebook/plugins/lua/service/lua_engine_service.dart';

@GenerateMocks([NodeRepository, GraphRepository])
import 'lua_deep_integration_test.mocks.dart';

/// Lua 插件深度集成测试
///
/// 测试 Lua 脚本与应用功能的实际集成场景
void main() {
  group('Lua 深度集成测试', () {
    late LuaEngineService engineService;
    late LuaAPIImplementation apiImpl;
    late MockNodeRepository mockNodeRepo;
    late MockGraphRepository mockGraphRepo;

    setUp(() async {
      // 创建引擎服务
      engineService = LuaEngineService(
        engineType: LuaEngineType.realLua,
        enableDebugOutput: true,
        enableSandbox: false, // 测试环境关闭沙箱
      );

      // 初始化引擎
      await engineService.initialize();

      // 创建 mock 仓储
      mockNodeRepo = MockNodeRepository();
      mockGraphRepo = MockGraphRepository();

      // 创建 API 实现
      apiImpl = LuaAPIImplementation(
        engineService: engineService,
        nodeRepository: mockNodeRepo,
        graphRepository: mockGraphRepo,
      );

      // 注册所有 API
      apiImpl.registerAllAPIs();
    });

    tearDown(() async {
      await engineService.dispose();
    });

    group('节点操作 API 测试', () {
      test('createNode - 创建节点并异步回调', () async {
        // Arrange
        final testNode = Node(
          id: 'test-node-1',
          title: 'Test Node',
          content: 'Test Content',
          references: const {},
          position: const Offset(100, 100),
          size: const Size(200, 250),
          viewMode: NodeViewMode.titleWithPreview,
          color: null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          metadata: const {},
        );

        when(mockNodeRepo.save(any)).thenAnswer((_) async => {});

        // Act
        const script = '''
          debugPrint("开始创建节点...")

          -- 定义回调函数
          onCreateComplete = function(success, result)
            if success then
              debugPrint("节点创建成功!")
              debugPrint("节点ID: " .. result.id)
              debugPrint("节点标题: " .. result.title)
              _create_success = true
            else
              debugPrint("节点创建失败: " .. result.error)
              _create_success = false
            end
          end

          -- 调用 API
          createNode("Test Node", "Test Content", "onCreateComplete")

          debugPrint("创建请求已提交...")
        ''';

        final result = await engineService.executeString(script);

        // Assert
        expect(result.success, true);
        expect(result.output, contains('节点创建成功'));
        verify(mockNodeRepo.save(argThat(
          isA<Node>()
              .having((n) => n.title, 'title', 'Test Node')
              .having((n) => n.content, 'content', 'Test Content'),
        ))).called(1);
      });

      test('updateNode - 更新节点内容', () async {
        // Arrange
        final existingNode = Node(
          id: 'node-123',
          title: 'Old Title',
          content: 'Old Content',
          references: const {},
          position: const Offset(100, 100),
          size: const Size(200, 250),
          viewMode: NodeViewMode.titleWithPreview,
          color: null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          metadata: const {},
        );

        when(mockNodeRepo.load('node-123')).thenAnswer((_) async => existingNode);
        when(mockNodeRepo.save(any)).thenAnswer((_) async => {});

        // Act
        const script = '''
          onUpdateComplete = function(success, result)
            if success then
              debugPrint("更新成功: " .. result.title)
              _update_success = true
            else
              debugPrint("更新失败: " .. result.error)
              _update_success = false
            end
          end

          updateNode("node-123", "New Title", "New Content", "onUpdateComplete")
        ''';

        final result = await engineService.executeString(script);

        // Assert
        expect(result.success, true);
        verify(mockNodeRepo.load('node-123')).called(1);
        verify(mockNodeRepo.save(argThat(
          isA<Node>()
              .having((n) => n.id, 'id', 'node-123')
              .having((n) => n.title, 'title', 'New Title')
              .having((n) => n.content, 'content', 'New Content'),
        ))).called(1);
      });

      test('deleteNode - 删除节点', () async {
        // Arrange
        when(mockNodeRepo.delete('node-123')).thenAnswer((_) async => {});

        // Act
        const script = '''
          onDeleteComplete = function(success, result)
            if success then
              debugPrint("删除成功")
              _delete_success = true
            else
              debugPrint("删除失败: " .. result.error)
              _delete_success = false
            end
          end

          deleteNode("node-123", "onDeleteComplete")
        ''';

        final result = await engineService.executeString(script);

        // Assert
        expect(result.success, true);
        verify(mockNodeRepo.delete('node-123')).called(1);
      });

      test('getNode - 获取单个节点', () async {
        // Arrange
        final testNode = Node(
          id: 'node-456',
          title: 'Test Node',
          content: 'Test Content',
          references: const {},
          position: const Offset(100, 100),
          size: const Size(200, 250),
          viewMode: NodeViewMode.titleWithPreview,
          color: null,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 2),
          metadata: const {},
        );

        when(mockNodeRepo.load('node-456')).thenAnswer((_) async => testNode);

        // Act
        const script = '''
          onGetComplete = function(success, result)
            if success then
              debugPrint("获取成功: " .. result.title)
              debugPrint("内容: " .. (result.content or "无"))
              _get_success = true
              _get_title = result.title
            else
              debugPrint("获取失败: " .. result.error)
              _get_success = false
            end
          end

          getNode("node-456", "onGetComplete")
        ''';

        final result = await engineService.executeString(script);

        // Assert
        expect(result.success, true);
        verify(mockNodeRepo.load('node-456')).called(1);
      });

      test('getAllNodes - 获取所有节点', () async {
        // Arrange
        final testNodes = [
          Node(
            id: 'node-1',
            title: 'Node 1',
            content: 'Content 1',
            references: const {},
            position: const Offset(100, 100),
            size: const Size(200, 250),
            viewMode: NodeViewMode.titleWithPreview,
            color: null,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            metadata: const {},
          ),
          Node(
            id: 'node-2',
            title: 'Node 2',
            content: 'Content 2',
            references: const {},
            position: const Offset(100, 100),
            size: const Size(200, 250),
            viewMode: NodeViewMode.titleWithPreview,
            color: null,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            metadata: const {},
          ),
        ];

        when(mockNodeRepo.queryAll()).thenAnswer((_) async => testNodes);

        // Act
        const script = '''
          onGetAllComplete = function(success, result)
            if success then
              debugPrint("获取成功，共 " .. result.count .. " 个节点")
              for i, node in pairs(result.nodes) do
                debugPrint(i .. ": " .. node.title)
              end
              _get_all_count = result.count
            else
              debugPrint("获取失败: " .. result.error)
              _get_all_count = 0
            end
          end

          getAllNodes("onGetAllComplete")
        ''';

        final result = await engineService.executeString(script);

        // Assert
        expect(result.success, true);
        expect(result.output, contains('共 2 个节点'));
        expect(result.output, contains('1: Node 1'));
        expect(result.output, contains('2: Node 2'));
        verify(mockNodeRepo.queryAll()).called(1);
      });
    });

    group('消息 API 测试', () {
      test('showMessage - 显示消息', () async {
        const script = '''
          showMessage("操作成功完成")
          showMessage("处理了 100 个节点")
        ''';

        final result = await engineService.executeString(script);

        expect(result.success, true);
        expect(result.output, contains('[LUA MESSAGE] 操作成功完成'));
        expect(result.output, contains('[LUA MESSAGE] 处理了 100 个节点'));
      });

      test('showWarning - 显示警告', () async {
        const script = '''
          showWarning("磁盘空间不足")
          showWarning("发现 10 个重复节点")
        ''';

        final result = await engineService.executeString(script);

        expect(result.success, true);
        expect(result.output, contains('[LUA WARNING] 磁盘空间不足'));
        expect(result.output, contains('[LUA WARNING] 发现 10 个重复节点'));
      });

      test('showError - 显示错误', () async {
        const script = '''
          showError("无法保存节点")
          showError("找不到节点: node-123")
        ''';

        final result = await engineService.executeString(script);

        expect(result.success, true);
        expect(result.output, contains('[LUA ERROR] 无法保存节点'));
        expect(result.output, contains('[LUA ERROR] 找不到节点: node-123'));
      });
    });

    group('工具函数 API 测试', () {
      test('generateUUID - 生成唯一ID', () async {
        const script = '''
          local id1 = generateUUID()
          local id2 = generateUUID()

          debugPrint("ID1: " .. tostring(id1))
          debugPrint("ID2: " .. tostring(id2))

          -- 检查ID不相同
          if id1 ~= id2 then
            debugPrint("UUID唯一性测试通过")
          end
        ''';

        final result = await engineService.executeString(script);

        expect(result.success, true);
        expect(result.output, contains('UUID唯一性测试通过'));
      });

      test('getCurrentTime - 获取当前时间', () async {
        const script = '''
          local time = getCurrentTime()
          debugPrint("当前时间: " .. time)

          -- 验证时间格式 (ISO 8601)
          if string.match(time, "^%d%d%d%d%-%d%d%-%d%d") then
            debugPrint("时间格式正确")
          end
        ''';

        final result = await engineService.executeString(script);

        expect(result.success, true);
        expect(result.output, contains('当前时间:'));
        expect(result.output, contains('时间格式正确'));
      });
    });

    group('类型转换测试', () {
      test('字符串类型转换', () async {
        when(mockNodeRepo.save(any)).thenAnswer((_) async => {});

        const script = '''
          createNode("字符串标题", "字符串内容", nil)
        ''';

        final result = await engineService.executeString(script);

        expect(result.success, true);
        verify(mockNodeRepo.save(argThat(
          isA<Node>()
              .having((n) => n.title, 'title', '字符串标题')
              .having((n) => n.content, 'content', '字符串内容'),
        ))).called(1);
      });

      test('数字类型转换', () async {
        const script = '''
          local count = 42
          local price = 19.99
          debugPrint("数量: " .. count)
          debugPrint("价格: " .. price)
        ''';

        final result = await engineService.executeString(script);

        expect(result.success, true);
        expect(result.output, contains('数量: 42'));
        expect(result.output, contains('价格: 19.99'));
      });

      test('布尔类型转换', () async {
        const script = '''
          local isActive = true
          local isDeleted = false
          debugPrint("激活状态: " .. tostring(isActive))
          debugPrint("删除状态: " .. tostring(isDeleted))
        ''';

        final result = await engineService.executeString(script);

        expect(result.success, true);
        expect(result.output, contains('激活状态: true'));
        expect(result.output, contains('删除状态: false'));
      });

      test('nil 值处理', () async {
        when(mockNodeRepo.save(any)).thenAnswer((_) async => {});

        const script = '''
          createNode("标题", nil, nil)
        ''';

        final result = await engineService.executeString(script);

        expect(result.success, true);
        verify(mockNodeRepo.save(argThat(
          isA<Node>().having((n) => n.content, 'content', null),
        ))).called(1);
      });

      test('表(Table)类型转换', () async {
        const script = '''
          local config = {
            name = "Test",
            count = 10,
            enabled = true
          }

          for key, value in pairs(config) do
            debugPrint(key .. " = " .. tostring(value))
          end
        ''';

        final result = await engineService.executeString(script);

        expect(result.success, true);
        expect(result.output.any((line) => line.contains('name = Test')), true);
        expect(result.output.any((line) => line.contains('count = 10')), true);
      });
    });

    group('错误处理测试', () {
      test('Lua 语法错误处理', () async {
        const script = '''
          debugPrint("unclosed string)
        ''';

        final result = await engineService.executeString(script);

        expect(result.success, false);
        expect(result.error, isNotNull);
        expect(result.error, contains('Syntax Error'));
      });

      test('Lua 运行时错误处理', () async {
        const script = '''
          callUndefinedFunction()
        ''';

        final result = await engineService.executeString(script);

        expect(result.success, false);
        expect(result.error, isNotNull);
        expect(result.error, contains('Runtime Error'));
      });

      test('API 参数验证 - 空标题', () async {
        const script = '''
          createNode("", "内容", nil)
        ''';

        final result = await engineService.executeString(script);

        expect(result.success, true); // 脚本执行成功，但 API 调用会失败
      });

      test('API 参数验证 - 缺少必需参数', () async {
        const script = '''
          createNode()
        ''';

        final result = await engineService.executeString(script);

        expect(result.success, true); // Lua 执行成功，参数验证在 API 层
      });

      test('节点不存在处理', () async {
        // Arrange
        when(mockNodeRepo.load('nonexistent')).thenAnswer((_) async => null);

        // Act
        const script = '''
          onUpdateComplete = function(success, result)
            if not success then
              debugPrint("正确处理错误: " .. result.error)
              _error_handled = true
            end
          end

          updateNode("nonexistent", "New Title", nil, "onUpdateComplete")
        ''';

        final result = await engineService.executeString(script);

        // Assert
        expect(result.success, true);
        expect(result.output, contains('正确处理错误'));
      });
    });

    group('异步操作测试', () {
      test('多个异步操作顺序执行', () async {
        // Arrange
        when(mockNodeRepo.save(any)).thenAnswer((_) async => {});
        when(mockNodeRepo.load(any)).thenAnswer((_) async => null);

        // Act
        const script = '''
          debugPrint("开始批量操作...")

          local completed = 0
          local total = 3

          local callback = function(success, result)
            completed = completed + 1
            debugPrint("已完成 " .. completed .. "/" .. total)

            if completed == total then
              debugPrint("所有操作完成!")
              _batch_complete = true
            end
          end

          createNode("Node 1", "Content 1", "callback")
          createNode("Node 2", "Content 2", "callback")
          createNode("Node 3", "Content 3", "callback")
        ''';

        final result = await engineService.executeString(script);

        // Assert
        expect(result.success, true);
        expect(result.output, contains('所有操作完成'));
        verify(mockNodeRepo.save(argThat(
          isA<Node>().having((n) => n.title, 'title', 'Node 1'),
        ))).called(1);
        verify(mockNodeRepo.save(argThat(
          isA<Node>().having((n) => n.title, 'title', 'Node 2'),
        ))).called(1);
        verify(mockNodeRepo.save(argThat(
          isA<Node>().having((n) => n.title, 'title', 'Node 3'),
        ))).called(1);
      });

      test('异步回调中的错误处理', () async {
        // Arrange
        when(mockNodeRepo.load('error-node')).thenThrow(
          Exception('Repository error'),
        );

        // Act
        const script = '''
          onError = function(success, result)
            if not success then
              debugPrint("捕获到错误: " .. result.error)
              _async_error_caught = true
            end
          end

          updateNode("error-node", "New Title", nil, "onError")
        ''';

        final result = await engineService.executeString(script);

        // Assert
        expect(result.success, true);
        expect(result.output, contains('捕获到错误'));
      });
    });

    group('复杂场景测试', () {
      test('批量节点处理', () async {
        // Arrange
        final existingNodes = List.generate(
          5,
          (i) => Node(
            id: 'node-$i',
            title: 'Node $i',
            content: 'Content $i',
            references: const {},
            position: const Offset(100, 100),
            size: const Size(200, 250),
            viewMode: NodeViewMode.titleWithPreview,
            color: null,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            metadata: const {},
          ),
        );

        when(mockNodeRepo.queryAll()).thenAnswer((_) async => existingNodes);
        when(mockNodeRepo.save(any)).thenAnswer((_) async => {});

        // Act
        const script = '''
          onGetAll = function(success, result)
            if success then
              debugPrint("获取到 " .. result.count .. " 个节点")

              -- 批量重命名
              local renamed = 0
              for i, node in pairs(result.nodes) do
                local newTitle = "Updated " .. node.title
                updateNode(node.id, newTitle, nil, nil)
                renamed = renamed + 1
              end

              debugPrint("已重命名 " .. renamed .. " 个节点")
              _batch_rename_count = renamed
            end
          end

          getAllNodes("onGetAll")
        ''';

        final result = await engineService.executeString(script);

        // Assert
        expect(result.success, true);
        expect(result.output, contains('获取到 5 个节点'));
        expect(result.output, contains('已重命名 5 个节点'));
      });

      test('条件分支和逻辑处理', () async {
        // Arrange
        when(mockNodeRepo.save(any)).thenAnswer((_) async => {});

        // Act
        const script = '''
          local mode = "production"

          if mode == "development" then
            createNode("Dev Node", "开发环境节点", nil)
          elseif mode == "production" then
            createNode("Prod Node", "生产环境节点", nil)
          else
            createNode("Test Node", "测试环境节点", nil)
          end

          debugPrint("根据模式创建节点: " .. mode)
        ''';

        final result = await engineService.executeString(script);

        // Assert
        expect(result.success, true);
        expect(result.output, contains('根据模式创建节点: production'));
        verify(mockNodeRepo.save(argThat(
          isA<Node>().having((n) => n.title, 'title', 'Prod Node'),
        ))).called(1);
      });

      test('循环和集合操作', () async {
        // Arrange
        when(mockNodeRepo.save(any)).thenAnswer((_) async => {});

        // Act
        const script = '''
          local tags = {"重要", "学习", "待办"}

          for i, tag in pairs(tags) do
            local nodeName = "任务_" .. i
            createNode(nodeName, "标签: " .. tag, nil)
            debugPrint("创建节点: " .. nodeName .. " [" .. tag .. "]")
          end
        ''';

        final result = await engineService.executeString(script);

        // Assert
        expect(result.success, true);
        expect(result.output, contains('创建节点: 任务_1 [重要]'));
        expect(result.output, contains('创建节点: 任务_2 [学习]'));
        expect(result.output, contains('创建节点: 任务_3 [待办]'));
      });
    });

    group('性能和边界测试', () {
      test('大量输出处理', () async {
        const script = '''
          for i = 1, 100 do
            debugPrint("输出行 " .. i)
          end
          debugPrint("完成")
        ''';

        final result = await engineService.executeString(script);

        expect(result.success, true);
        expect(result.output.length, greaterThan(100));
        expect(result.output.last, contains('完成'));
      });

      test('长字符串处理', () async {
        final longString = 'A' * 10000;

        const script = '''
          local longStr = string.rep("A", 10000)
          debugPrint("字符串长度: " .. string.len(longStr))
        ''';

        final result = await engineService.executeString(script);

        expect(result.success, true);
        expect(result.output, contains('字符串长度: 10000'));
      });

      test('深度嵌套调用', () async {
        const script = '''
          function nestedCall(depth)
            if depth > 0 then
              return nestedCall(depth - 1)
            else
              return "reached"
            end
          end

          local result = nestedCall(100)
          debugPrint("递归结果: " .. result)
        ''';

        final result = await engineService.executeString(script);

        expect(result.success, true);
        expect(result.output, contains('递归结果: reached'));
      });
    });

    group('沙箱模式测试', () {
      test('沙箱模式应该禁用危险API', () async {
        // 创建启用沙箱的引擎
        final sandboxEngine = LuaEngineService(
          engineType: LuaEngineType.realLua,
          enableSandbox: true,
          enableDebugOutput: true,
        );

        await sandboxEngine.initialize();

        // 注册 API
        final sandboxApi = LuaAPIImplementation(
          engineService: sandboxEngine,
          nodeRepository: mockNodeRepo,
          graphRepository: mockGraphRepo,
        );
        sandboxApi.registerAllAPIs();

        const script = '''
          -- 尝试访问被禁用的 API
          if os == nil then
            debugPrint("os API 已被禁用 ✓")
          else
            debugPrint("os API 仍然可用 ✗")
          end

          if io == nil then
            debugPrint("io API 已被禁用 ✓")
          else
            debugPrint("io API 仍然可用 ✗")
          end
        ''';

        final result = await sandboxEngine.executeString(script);

        expect(result.success, true);
        expect(result.output.any((line) => line.contains('os API 已被禁用')), true);
        expect(result.output.any((line) => line.contains('io API 已被禁用')), true);

        await sandboxEngine.dispose();
      });
    });

    group('上下文变量注入测试', () {
      test('上下文变量应该正确注入到Lua环境', () async {
        final context = {
          'userName': 'Alice',
          'userAge': 30,
          'isActive': true,
          'preferences': {
            'theme': 'dark',
            'language': 'zh-CN',
          },
        };

        const script = '''
          debugPrint("用户名: " .. userName)
          debugPrint("年龄: " .. userAge)
          debugPrint("激活状态: " .. tostring(isActive))

          -- 访问嵌套对象
          if preferences ~= nil then
            debugPrint("主题: " .. preferences.theme)
            debugPrint("语言: " .. preferences.language)
          end
        ''';

        final result = await engineService.executeString(script, context: context);

        expect(result.success, true);
        expect(result.output, contains('用户名: Alice'));
        expect(result.output, contains('年龄: 30'));
        expect(result.output, contains('激活状态: true'));
        expect(result.output, contains('主题: dark'));
        expect(result.output, contains('语言: zh-CN'));
      });

      test('上下文变量应该支持动态更新', () async {
        final context1 = {'value': 100};
        final context2 = {'value': 200};

        final result1 = await engineService.executeString(
          'debugPrint("值: " .. value)',
          context: context1,
        );

        final result2 = await engineService.executeString(
          'debugPrint("值: " .. value)',
          context: context2,
        );

        expect(result1.success, true);
        expect(result1.output, contains('值: 100'));

        expect(result2.success, true);
        expect(result2.output, contains('值: 200'));
      });
    });

    group('回调函数测试', () {
      test('应该能够调用Lua中定义的回调函数', () async {
        const script = '''
          -- 定义回调函数
          myCallback = function(data)
            debugPrint("回调被调用!")
            debugPrint("数据: " .. tostring(data))
            _callback_called = true
          end

          debugPrint("回调函数已定义")
        ''';

        final result = await engineService.executeString(script);

        expect(result.success, true);
        expect(result.output, contains('回调函数已定义'));

        // 从 Dart 侧调用回调
        final callbackResult = await engineService.invokeCallback(
          'myCallback',
          ['测试数据'],
        );

        expect(callbackResult.success, true);
        expect(callbackResult.output, contains('回调被调用!'));
        expect(callbackResult.output, contains('数据: 测试数据'));
      });

      test('回调函数应该能够接收多个参数', () async {
        const script = '''
          multiParamCallback = function(a, b, c)
            debugPrint("参数1: " .. tostring(a))
            debugPrint("参数2: " .. tostring(b))
            debugPrint("参数3: " .. tostring(c))
            _multi_param_received = true
          end
        ''';

        await engineService.executeString(script);

        final result = await engineService.invokeCallback(
          'multiParamCallback',
          ['first', 42, true],
        );

        expect(result.success, true);
        expect(result.output, contains('参数1: first'));
        expect(result.output, contains('参数2: 42'));
        expect(result.output, contains('参数3: true'));
      });
    });
  });
}
