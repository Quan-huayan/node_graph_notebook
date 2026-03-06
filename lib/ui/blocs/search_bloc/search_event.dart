import 'package:equatable/equatable.dart';
import '../../../ui/models/search_query.dart';
import '../../../ui/models/search_preset_model.dart';

/// 搜索事件基类
abstract class SearchEvent extends Equatable {
  const SearchEvent();

  @override
  List<Object?> get props => [];
}

/// 执行搜索事件
class SearchPerformEvent extends SearchEvent {
  const SearchPerformEvent(this.query);

  final SearchQuery query;

  @override
  List<Object?> get props => [query];
}

/// 加载预设列表事件
class SearchLoadPresetsEvent extends SearchEvent {
  const SearchLoadPresetsEvent();
}

/// 保存预设事件
class SearchSavePresetEvent extends SearchEvent {
  const SearchSavePresetEvent(this.name, this.query);

  final String name;
  final SearchQuery query;

  @override
  List<Object?> get props => [name, query];
}

/// 加载预设事件
class SearchLoadPresetEvent extends SearchEvent {
  const SearchLoadPresetEvent(this.preset);

  final SearchPreset preset;

  @override
  List<Object?> get props => [preset];
}

/// 删除预设事件
class SearchDeletePresetEvent extends SearchEvent {
  const SearchDeletePresetEvent(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

/// 清除搜索结果事件
class SearchClearEvent extends SearchEvent {
  const SearchClearEvent();
}
