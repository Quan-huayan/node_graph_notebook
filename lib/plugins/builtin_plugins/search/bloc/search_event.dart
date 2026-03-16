import 'package:equatable/equatable.dart';
import '../model/search_preset_model.dart';
import '../model/search_query.dart';

/// 搜索事件基类
abstract class SearchEvent extends Equatable {
  /// 创建搜索事件
  const SearchEvent();

  @override
  List<Object?> get props => [];
}

/// 执行搜索事件
class SearchPerformEvent extends SearchEvent {
  /// 创建执行搜索事件
  /// 
  /// [query] - 搜索查询
  const SearchPerformEvent(this.query);

  /// 搜索查询
  final SearchQuery query;

  @override
  List<Object?> get props => [query];
}

/// 加载预设列表事件
class SearchLoadPresetsEvent extends SearchEvent {
  /// 创建加载预设列表事件
  const SearchLoadPresetsEvent();
}

/// 保存预设事件
class SearchSavePresetEvent extends SearchEvent {
  /// 创建保存预设事件
  /// 
  /// [name] - 预设名称
  /// [query] - 搜索查询
  const SearchSavePresetEvent(this.name, this.query);

  /// 预设名称
  final String name;
  
  /// 搜索查询
  final SearchQuery query;

  @override
  List<Object?> get props => [name, query];
}

/// 加载预设事件
class SearchLoadPresetEvent extends SearchEvent {
  /// 创建加载预设事件
  /// 
  /// [preset] - 搜索预设
  const SearchLoadPresetEvent(this.preset);

  /// 搜索预设
  final SearchPreset preset;

  @override
  List<Object?> get props => [preset];
}

/// 删除预设事件
class SearchDeletePresetEvent extends SearchEvent {
  /// 创建删除预设事件
  /// 
  /// [id] - 预设ID
  const SearchDeletePresetEvent(this.id);

  /// 预设ID
  final String id;

  @override
  List<Object?> get props => [id];
}

/// 清除搜索结果事件
class SearchClearEvent extends SearchEvent {
  /// 创建清除搜索结果事件
  const SearchClearEvent();
}
