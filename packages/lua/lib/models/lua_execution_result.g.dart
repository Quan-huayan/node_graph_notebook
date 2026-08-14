// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lua_execution_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LuaExecutionResult _$LuaExecutionResultFromJson(Map<String, dynamic> json) =>
    LuaExecutionResult(
      success: json['success'] as bool,
      returnValue: json['returnValue'],
      output:
          (json['output'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      error: json['error'] as String?,
      executionTime: json['executionTime'] == null
          ? null
          : Duration(microseconds: (json['executionTime'] as num).toInt()),
      errorLine: (json['errorLine'] as num?)?.toInt(),
      errorContext: json['errorContext'] as String?,
      stackTrace:
          (json['stackTrace'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$LuaExecutionResultToJson(LuaExecutionResult instance) =>
    <String, dynamic>{
      'success': instance.success,
      'returnValue': instance.returnValue,
      'output': instance.output,
      'error': instance.error,
      'executionTime': instance.executionTime?.inMicroseconds,
      'errorLine': instance.errorLine,
      'errorContext': instance.errorContext,
      'stackTrace': instance.stackTrace,
    };
