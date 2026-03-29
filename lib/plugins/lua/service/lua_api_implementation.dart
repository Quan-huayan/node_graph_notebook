import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/node.dart';
import '../../../core/repositories/graph_repository.dart';
import '../../../core/repositories/node_repository.dart';
import 'global_message_service.dart';
import 'lua_engine_service.dart';

/// Lua参数验证异常
class LuaArgumentException implements Exception {
  const LuaArgumentException(this.message);

  final String message;

  @override
  String toString() => 'LuaArgumentException: $message';
}

/// Lua API实现
///
/// 提供Lua脚本访问应用功能的实际实现
///
/// 注意：当前为简化版本，用于测试环境
/// TODO: 实现完整的异步API调用机制
class LuaAPIImplementation {
  /// 构造函数
  LuaAPIImplementation({
    required this.engineService,
    required this.nodeRepository,
    required this.graphRepository,
  });

  /// Lua引擎服务
  final LuaEngineService engineService;

  /// 节点仓储
  final NodeRepository nodeRepository;

  /// 图仓储
  final GraphRepository graphRepository;

  /// UUID生成器
  final Uuid _uuid = const Uuid();

  /// 注册所有API
  void registerAllAPIs() {
    _registerNodeAPIs();
    _registerMessageAPIs();
    _registerUtilityAPIs();
  }

  /// 验证字符串参数
  String? _validateString(dynamic value, String paramName) {
    if (value == null) return null;
    if (value is! String) {
      throw LuaArgumentException('$paramName must be string, got ${value.runtimeType}');
    }
    if (value.isEmpty) {
      throw LuaArgumentException('$paramName cannot be empty');
    }
    return value;
  }

  /// 注册节点操作API
  void _registerNodeAPIs() {
    // createNode(title, content, callback)
    // callback: function(success, result) end
    engineService..registerFunction('createNode', (args) {
      try {
        // 🔒 参数验证
        if (args.isEmpty) {
          throw const LuaArgumentException('createNode requires at least title parameter');
        }

        final title = _validateString(args[0], 'title');
        if (title == null || title.isEmpty) {
          throw const LuaArgumentException('title cannot be empty');
        }

        final content = args.length > 1 ? _validateString(args[1], 'content') : null;
        final callback = args.length > 2 ? args[2] : null;

        // 创建节点（使用正确的构造函数参数）
        final now = DateTime.now();
        final node = Node(
          id: _uuid.v4(),
          title: title,
          content: content,
          references: const {},
          position: const Offset(100, 100),
          size: const Size(200, 250),
          viewMode: NodeViewMode.titleWithPreview,
          color: null,
          createdAt: now,
          updatedAt: now,
          metadata: const {},
        );

        // 异步保存并调用回调
        nodeRepository.save(node).then((_) {
          debugPrint('[LUA API] 节点已创建: ${node.id}');
          // 调用回调报告成功
          if (callback != null) {
            _invokeCallback(callback, [true, {
              'id': node.id,
              'title': node.title,
              'content': node.content,
              'createdAt': node.createdAt.toIso8601String(),
            }]);
          }
        }).catchError((e) {
          _showError('创建节点失败: $e');
          // 调用回调报告错误
          if (callback != null) {
            _invokeCallback(callback, [false, {'error': e.toString()}]);
          }
        });

        return 0;
      } catch (e) {
        _showError('创建节点失败: $e');
        final callback = args.length > 2 ? args[2] : null;
        if (callback != null) {
          _invokeCallback(callback, [false, {'error': e.toString()}]);
        }
        return 0;
      }
    })

    // updateNode(id, title, content, callback)
    // callback: function(success, result) end
    ..registerFunction('updateNode', (args) {
      try {
        // 🔒 参数验证
        if (args.isEmpty) {
          throw const LuaArgumentException('updateNode requires id parameter');
        }

        final id = _validateString(args[0], 'id');
        if (id == null || id.isEmpty) {
          throw const LuaArgumentException('id cannot be empty');
        }

        final title = args.length > 1 ? _validateString(args[1], 'title') : null;
        final content = args.length > 2 ? _validateString(args[2], 'content') : null;
        final callback = args.length > 3 ? args[3] : null;

        debugPrint('[LUA API] 更新节点请求: $id');

        // 异步更新节点
        nodeRepository.load(id).then((existingNode) {
          if (existingNode == null) {
            _showError('节点不存在: $id');
            if (callback != null) {
              _invokeCallback(callback, [false, {'error': '节点不存在: $id'}]);
            }
            return;
          }

          // 更新节点字段
          final updatedNode = existingNode.copyWith(
            title: title ?? existingNode.title,
            content: content ?? existingNode.content,
            updatedAt: DateTime.now(),
          );

          // 保存更新
          nodeRepository.save(updatedNode).then((_) {
            debugPrint('[LUA API] 节点已更新: $id');
            if (callback != null) {
              _invokeCallback(callback, [true, {
                'id': updatedNode.id,
                'title': updatedNode.title,
                'content': updatedNode.content,
                'updatedAt': updatedNode.updatedAt.toIso8601String(),
              }]);
            }
          }).catchError((e) {
            _showError('更新节点失败: $e');
            if (callback != null) {
              _invokeCallback(callback, [false, {'error': e.toString()}]);
            }
          });
        }).catchError((e) {
          _showError('获取节点失败: $e');
          if (callback != null) {
            _invokeCallback(callback, [false, {'error': e.toString()}]);
          }
        });

        return 0;
      } catch (e) {
        _showError('更新节点失败: $e');
        final callback = args.length > 3 ? args[3] : null;
        if (callback != null) {
          _invokeCallback(callback, [false, {'error': e.toString()}]);
        }
        return 0;
      }
    })

    // deleteNode(id, callback)
    // callback: function(success, result) end
    ..registerFunction('deleteNode', (args) {
      try {
        // 🔒 参数验证
        if (args.isEmpty) {
          throw const LuaArgumentException('deleteNode requires id parameter');
        }

        final id = _validateString(args[0], 'id');
        if (id == null || id.isEmpty) {
          throw const LuaArgumentException('id cannot be empty');
        }

        final callback = args.length > 1 ? args[1] : null;

        debugPrint('[LUA API] 删除节点请求: $id');

        // 异步删除节点
        nodeRepository.delete(id).then((_) {
          debugPrint('[LUA API] 节点已删除: $id');
          if (callback != null) {
            _invokeCallback(callback, [true, {
              'id': id,
              'deleted': true,
            }]);
          }
        }).catchError((e) {
          _showError('删除节点失败: $e');
          if (callback != null) {
            _invokeCallback(callback, [false, {'error': e.toString()}]);
          }
        });

        return 0;
      } catch (e) {
        _showError('删除节点失败: $e');
        final callback = args.length > 1 ? args[1] : null;
        if (callback != null) {
          _invokeCallback(callback, [false, {'error': e.toString()}]);
        }
        return 0;
      }
    })

    // getNode(id, callback)
    // callback: function(success, result) end
    ..registerFunction('getNode', (args) {
      try {
        // 🔒 参数验证
        if (args.isEmpty) {
          throw const LuaArgumentException('getNode requires id parameter');
        }

        final id = _validateString(args[0], 'id');
        if (id == null || id.isEmpty) {
          throw const LuaArgumentException('id cannot be empty');
        }

        final callback = args.length > 1 ? args[1] : null;

        debugPrint('[LUA API] 获取节点请求: $id');

        // 异步获取节点
        nodeRepository.load(id).then((node) {
          if (node == null) {
            _showError('节点不存在: $id');
            if (callback != null) {
              _invokeCallback(callback, [false, {'error': '节点不存在: $id'}]);
            }
            return;
          }

          debugPrint('[LUA API] 节点已获取: ${node.title}');
          if (callback != null) {
            _invokeCallback(callback, [true, {
              'id': node.id,
              'title': node.title,
              'content': node.content,
              'createdAt': node.createdAt.toIso8601String(),
              'updatedAt': node.updatedAt.toIso8601String(),
            }]);
          }
        }).catchError((e) {
          _showError('获取节点失败: $e');
          if (callback != null) {
            _invokeCallback(callback, [false, {'error': e.toString()}]);
          }
        });

        return 0;
      } catch (e) {
        _showError('获取节点失败: $e');
        final callback = args.length > 1 ? args[1] : null;
        if (callback != null) {
          _invokeCallback(callback, [false, {'error': e.toString()}]);
        }
        return 0;
      }
    })

    // getAllNodes(callback)
    // callback: function(success, result) end
    ..registerFunction('getAllNodes', (args) {
      try {
        final callback = args.isNotEmpty ? args[0] : null;

        debugPrint('[LUA API] 获取所有节点请求');

        // 异步获取所有节点
        nodeRepository.queryAll().then((nodes) {
          debugPrint('[LUA API] 已获取 ${nodes.length} 个节点');

          // 转换为Lua友好的格式
          final nodesList = nodes.map((node) => {
            'id': node.id,
            'title': node.title,
            'content': node.content,
            'createdAt': node.createdAt.toIso8601String(),
            'updatedAt': node.updatedAt.toIso8601String(),
          }).toList();

          if (callback != null) {
            _invokeCallback(callback, [true, {
              'count': nodes.length,
              'nodes': nodesList,
            }]);
          }
        }).catchError((e) {
          _showError('获取节点列表失败: $e');
          if (callback != null) {
            _invokeCallback(callback, [false, {'error': e.toString()}]);
          }
        });

        return 0;
      } catch (e) {
        _showError('获取节点列表失败: $e');
        final callback = args.isNotEmpty ? args[0] : null;
        if (callback != null) {
          _invokeCallback(callback, [false, {'error': e.toString()}]);
        }
        return 0;
      }
    })

    // getChildNodes(parentId, callback)
    // callback: function(success, result) end
    ..registerFunction('getChildNodes', (args) {
      try {
        // 🔒 参数验证
        if (args.isEmpty) {
          throw const LuaArgumentException('getChildNodes requires parentId parameter');
        }

        final parentId = _validateString(args[0], 'parentId');
        if (parentId == null || parentId.isEmpty) {
          throw const LuaArgumentException('parentId cannot be empty');
        }

        final callback = args.length > 1 ? args[1] : null;

        debugPrint('[LUA API] 获取子节点请求: $parentId');

        // ✅ 实现异步获取子节点
        graphRepository.getAll().then((graphs) {
          // 查找包含指定节点的图
          final targetGraph = graphs.where((g) => g.nodeIds.contains(parentId)).firstOrNull;

          if (targetGraph == null) {
            _showError('图不存在: 节点 $parentId 不在任何图中');
            if (callback != null) {
              _invokeCallback(callback, [false, {'error': '图不存在'}]);
            }
            return;
          }

          // 获取图中的所有节点（除了父节点本身）
          final childNodes = targetGraph.nodeIds.where((id) => id != parentId).toList();

          debugPrint('[LUA API] 找到 ${childNodes.length} 个子节点');

          if (callback != null) {
            _invokeCallback(callback, [true, {
              'parentId': parentId,
              'count': childNodes.length,
              'children': childNodes,
            }]);
          }
        }).catchError((e) {
          _showError('获取子节点失败: $e');
          if (callback != null) {
            _invokeCallback(callback, [false, {'error': e.toString()}]);
          }
        });

        return 0;
      } catch (e) {
        _showError('获取子节点失败: $e');
        final callback = args.length > 1 ? args[1] : null;
        if (callback != null) {
          _invokeCallback(callback, [false, {'error': e.toString()}]);
        }
        return 0;
      }
    });
  }

  /// 注册消息API
  void _registerMessageAPIs() {
    // showMessage(title, message) 或 showMessage(message)
    engineService..registerFunction('showMessage', (args) {
      try {
        debugPrint('[LUA API] showMessage called with ${args.length} args');

        if (args.isEmpty) {
          debugPrint('[LUA API] showMessage: No arguments provided');
          return 0;
        }

        var title = '消息';
        var message = '';

        if (args.length == 1) {
          // showMessage(message)
          message = args[0]?.toString() ?? '';
        } else if (args.length >= 2) {
          // showMessage(title, message)
          title = args[0]?.toString() ?? '消息';
          message = args[1]?.toString() ?? '';
        }

        debugPrint('[LUA MESSAGE] Title: "$title", Message: "$message"');
        debugPrint('[LUA MESSAGE] Calling GlobalMessageService.showMessage');

        // ✅ 实际显示消息
        GlobalMessageService.showMessage(title, message);

        debugPrint('[LUA MESSAGE] GlobalMessageService.showMessage called');

        return 1;
      } catch (e) {
        debugPrint('[LUA MESSAGE] Error: $e');
        return 0;
      }
    })

    // showWarning(message)
    ..registerFunction('showWarning', (args) {
      try {
        if (args.isEmpty) return 0;

        final message = args[0]?.toString() ?? '';
        debugPrint('[LUA WARNING] $message');

        return 0;
      } catch (e) {
        return 0;
      }
    })

    // showError(message)
    ..registerFunction('showError', (args) {
      try {
        if (args.isEmpty) return 0;

        final message = args[0]?.toString() ?? '';
        debugPrint('[LUA ERROR] $message');

        return 0;
      } catch (e) {
        return 0;
      }
    });
  }

  /// 注册工具API
  void _registerUtilityAPIs() {
    // generateUUID()
    engineService..registerFunction('generateUUID', (args) {
      try {
        final id = _uuid.v4();
        engineService.executeString('return "$id"');
        return 0;
      } catch (e) {
        return 0;
      }
    })

    // getCurrentTime()
    ..registerFunction('getCurrentTime', (args) {
      try {
        final time = DateTime.now().toIso8601String();
        engineService.executeString('return "$time"');
        return 0;
      } catch (e) {
        return 0;
      }
    });
  }

  /// 显示错误消息
  void _showError(String message) {
    debugPrint('[LUA API ERROR] $message');
  }

  /// 调用Lua回调函数
  ///
  /// [callbackName] 回调函数的全局变量名
  /// [args] 传递给回调的参数
  void _invokeCallback(String? callbackName, List<dynamic> args) async {
    if (callbackName == null || callbackName.isEmpty) {
      return; // 没有回调，直接返回
    }

    try {
      final result = await engineService.invokeCallback(callbackName, args);

      if (!result.success && result.error != null) {
        debugPrint('[LUA CALLBACK ERROR] ${result.error}');
      }
    } catch (e) {
      debugPrint('[LUA CALLBACK ERROR] 调用回调失败: $e');
    }
  }
}
