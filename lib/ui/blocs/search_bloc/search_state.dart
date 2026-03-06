import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../../../core/models/models.dart';
import '../../../ui/models/search_preset_model.dart';
import '../../../ui/models/search_query.dart';

/// 搜索状态基类
@immutable
class SearchState extends Equatable {
  const SearchState({
    required this.results,
    required this.presets,
    required this.isLoading,
    required this.isSavingPreset,
    this.currentQuery,
    this.error,
  });

  /// 初始状态
  factory SearchState.initial() {
    return const SearchState(
      results: [],
      presets: [],
      isLoading: false,
      isSavingPreset: false,
      currentQuery: null,
      error: null,
    );
  }

  final List<Node> results;
  final List<SearchPreset> presets;
  final bool isLoading;
  final bool isSavingPreset;
  final SearchQuery? currentQuery;
  final String? error;

  /// 便捷方法
  bool get hasError => error != null;
  bool get hasResults => results.isNotEmpty;
  bool get hasPresets => presets.isNotEmpty;
  int get resultCount => results.length;

  SearchState copyWith({
    List<Node>? results,
    List<SearchPreset>? presets,
    bool? isLoading,
    bool? isSavingPreset,
    SearchQuery? currentQuery,
    String? error,
  }) {
    return SearchState(
      results: results ?? this.results,
      presets: presets ?? this.presets,
      isLoading: isLoading ?? this.isLoading,
      isSavingPreset: isSavingPreset ?? this.isSavingPreset,
      currentQuery: currentQuery ?? this.currentQuery,
      error: error,
    );
  }

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
