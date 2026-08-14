/// LuaEngine 最小冒烟（定位引擎挂点；非正式验收测试）。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:node_lua/src/lua_engine.dart';

void main() {
  test('引擎初始化 + 简单脚本', () {
    final engine = LuaEngine()..initialize();
    expect(engine.run('x = 1 + 1'), '');
    expect(engine.evalBound('return x'), 2);
    engine.dispose();
  });

  test('脚本定义表 → getGlobalTable', () {
    final engine = LuaEngine()..initialize();
    engine.run('T = { a = 1, b = "hi" }');
    final table = engine.getGlobalTable('T');
    expect(table['a'], 1);
    expect(table['b'], 'hi');
    engine.dispose();
  });

  test('函数定义与调用', () {
    final engine = LuaEngine()..initialize();
    engine.run('function double(x) return x * 2 end');
    expect(engine.evalBound('return double(21)'), 42);
    engine.dispose();
  });

  test('嵌套表（元数据形态）', () {
    final engine = LuaEngine()..initialize();
    engine.run('M = { kind = "special", tags = { t1 = true } }');
    final table = engine.getGlobalTable('M');
    expect(table['kind'], 'special');
    engine.dispose();
  });
}
