import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../../../core/models/models.dart';
import '../model/search_preset_model.dart';
import '../model/search_query.dart';

/// 哨兵值，用于区分 "未传递参数" 和 "传递了 null"
class _Sentinel {
  const _Sentinel();
}

/// 搜索状态基类
@immutable
class SearchState extends Equatable {
  /// 创建一个新的搜索状态
  ///
  /// [results] - 搜索结果列表
  /// [presets] - 搜索预设列表
  /// [isLoading] - 是否正在加载
  /// [isSavingPreset] - 是否正在保存预设
  /// [currentQuery] - 当前搜索查询
  /// [error] - 错误信息
  const SearchState({
    required this.results,
    required this.presets,
    required this.isLoading,
    required this.isSavingPreset,
    this.currentQuery,
    this.error,
  });

  /// 初始状态
  factory SearchState.initial() => const SearchState(
      results: [],
      presets: [],
      isLoading: false,
      isSavingPreset: false,
      currentQuery: null,
      error: null,
    );

  /// 搜索结果列表
  final List<Node> results;

  /// 搜索预设列表
  final List<SearchPreset> presets;

  /// 是否正在加载
  final bool isLoading;

  /// 是否正在保存预设
  final bool isSavingPreset;

  /// 当前搜索查询
  final SearchQuery? currentQuery;

  /// 错误信息
  final String? error;

  /// 便捷方法：是否有错误
  bool get hasError => error != null;

  /// 便捷方法：是否有搜索结果
  bool get hasResults => results.isNotEmpty;

  /// 便捷方法：是否有搜索预设
  bool get hasPresets => presets.isNotEmpty;

  /// 便捷方法：搜索结果数量
  int get resultCount => results.length;

  /// 复制并更新部分字段
  ///
  /// 返回一个新的搜索状态，其中包含指定的字段更新
  /// 使用 [clearQuery] 参数设置为 true 来清除当前查询
  SearchState copyWith({
    List<Node>? results,
    List<SearchPreset>? presets,
    bool? isLoading,
    bool? isSavingPreset,
    Object? currentQuery = const _Sentinel(),
    String? error,
    bool clearQuery = false,
  }) => SearchState(
      results: results ?? this.results,
      presets: presets ?? this.presets,
      isLoading: isLoading ?? this.isLoading,
      isSavingPreset: isSavingPreset ?? this.isSavingPreset,
      currentQuery: clearQuery
          ? null
          : (currentQuery is SearchQuery
              ? currentQuery
              : (currentQuery == null ? null : this.currentQuery)),
      error: error,
    );

  @override
  List<Object?> get props => [
    results,
    presets,
    isLoading,
    isSavingPreset,
    currentQuery,
    error,
  ];
}
