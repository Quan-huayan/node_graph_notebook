# Dart Fix 脚本说明

## 概述

`dart-fix.bat` (Windows) 和 `dart-fix.sh` (Linux/Mac) 是用于自动修复 Dart 代码格式和 lint 问题的脚本。

## 使用方法

### Windows
```bash
.\scripts\dart-fix.bat
```

### Linux/Mac
```bash
./scripts/dart-fix.sh
```

## 自动修复的问题类型

基于 `analysis_options.yaml` 的配置，以下问题可以被 `dart fix --apply` 自动修复：

### 1. 样式问题 (Style Issues)
- `prefer_single_quotes` - 使用单引号而不是双引号
- `prefer_const_constructors` - 使用 const 构造函数
- `prefer_const_declarations` - 使用 const 声明
- `prefer_const_literals_to_create_immutables` - 使用 const 字面量创建不可变对象
- `sort_constructors_first` - 将构造函数排序在其他成员之前
- `sort_unnamed_constructors_first` - 将未命名构造函数排序在命名构造函数之前

### 2. 不必要的代码 (Unnecessary Code)
- `unnecessary_const` - 移除不必要的 const 关键字
- `unnecessary_new` - 移除不必要的 new 关键字
- `unnecessary_this` - 移除不必要的 this 关键字
- `unnecessary_brace_in_string_interps` - 移除字符串插值中不必要的大括号
- `unnecessary_getters_setters` - 移除不必要的 getter/setter
- `unnecessary_lambdas` - 移除不必要的 lambda 表达式
- `unnecessary_null_aware_assignments` - 移除不必要的 null 赋值
- `unnecessary_null_checks` - 移除不必要的 null 检查
- `unnecessary_null_in_if_null_operators` - 移除 if null 操作符中不必要的 null
- `unnecessary_overrides` - 移除不必要的重写
- `unnecessary_parenthesis` - 移除不必要的括号
- `unnecessary_string_escapes` - 移除不必要的字符串转义
- `unnecessary_string_interpolations` - 移除不必要的字符串插值
- `unnecessary_statements` - 移除不必要的语句
- `unnecessary_await_in_return` - 移除 return 中不必要的 await

### 3. 现代 Dart 模式 (Modern Dart Patterns)
- `prefer_spread_collections` - 使用展开运算符而不是 addAll
- `prefer_for_elements_to_map_fromIterable` - 使用 for 元素而不是 map.fromIterable
- `prefer_if_elements_to_conditional_expressions` - 使用 if 元素而不是条件表达式
- `prefer_if_null_operators` - 使用 if null 操作符
- `prefer_inlined_adds` - 使用内联添加
- `prefer_collection_literals` - 使用集合字面量
- `prefer_is_empty` - 使用 isEmpty 而不是 length == 0
- `prefer_is_not_empty` - 使用 isNotEmpty 而不是 length != 0
- `prefer_expression_function_bodies` - 使用表达式函数体
- `prefer_int_literals` - 使用整数字面量
- `prefer_null_aware_method_calls` - 使用 null 感知方法调用
- `use_enums` - 使用枚举
- `use_if_null_to_convert_nulls_to_bools` - 使用 if null 将 null 转换为 bool
- `use_is_even_rather_than_modulo` - 使用 isEven 而不是 modulo
- `cascade_invocations` - 使用级联调用

### 4. 类型简化 (Type Simplifications)
- `prefer_typing_uninitialized_variables` - 为未初始化变量指定类型
- `omit_local_variable_types` - 省略局部变量类型
- `prefer_final_fields` - 使用 final 字段
- `prefer_final_locals` - 使用 final 局部变量
- `avoid_types_as_parameter_names` - 避免使用类型名作为参数名
- `prefer_void_to_null` - 使用 void 而不是 null

### 5. 其他改进
- `join_return_with_assignment` - 将返回与赋值结合
- `prefer_relative_imports` - 使用相对导入
- `directives_ordering` - 导入排序
- `require_trailing_commas` - 要求尾随逗号
- `prefer_foreach` - 使用 forEach
- `use_rethrow_when_possible` - 尽可能使用 rethrow
- `use_string_buffers` - 使用字符串缓冲区

## 需要手动修复的问题

以下问题需要手动修复，因为它们涉及代码逻辑、性能或需要人工判断：

### 1. 文档相关
- `public_member_api_docs` - 公共成员需要文档注释

### 2. 性能相关
- `avoid_slow_async_io` - 避免缓慢的异步 IO 操作

### 3. 安全相关
- `control_flow_in_finally` - finally 块中的控制流

### 4. 逻辑相关
- `avoid_print` - 避免使用 print（生产代码中）
- `missing_required_param` - 缺少必需参数
- `missing_return` - 缺少返回语句
- `avoid_empty_else` - 避免空的 else 块
- `avoid_function_literals_in_foreach_calls` - 避免 foreach 调用中的函数字面量
- `avoid_bool_literals_in_conditional_expressions` - 避免条件表达式中的布尔字面量

### 5. 其他
- `use_key_in_widget_constructors` - Widget 构造函数中使用 key
- `cancel_subscriptions` - 取消订阅
- `close_sinks` - 关闭 sinks

## 工作流程

1. 脚本检查 Dart 是否已安装
2. 运行 `dart fix --apply` 自动修复可修复的问题
3. 显示修复摘要
4. 建议运行 `flutter analyze` 查看剩余问题

## 注意事项

- 脚本会直接修改源代码文件
- 建议在运行前提交代码或创建备份
- 某些自动修复可能会改变代码的格式，但不影响功能
- 运行后应检查代码确保没有意外更改
- 对于团队项目，建议在 CI/CD 流程中集成此脚本

## 相关命令

```bash
# 预览将要进行的更改（不修改文件）
dart fix --dry-run

# 应用自动修复
dart fix --apply

# 仅修复特定类型的问题
dart fix --apply --code=prefer_single_quotes

# 查看所有可修复的问题
dart fix
```
