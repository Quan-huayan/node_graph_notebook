import 'package:equatable/equatable.dart';

/// 搜索查询模型
class SearchQuery extends Equatable {
  const SearchQuery({
    this.searchText,
    this.titleQuery,
    this.contentQuery,
    this.tags,
    this.createdAfter,
    this.createdBefore,
    this.isFolder,
  });

  final String? searchText;
  final String? titleQuery;
  final String? contentQuery;
  final List<String>? tags;
  final DateTime? createdAfter;
  final DateTime? createdBefore;
  final bool? isFolder;

  /// 是否为空查询
  bool get isEmpty {
    return (searchText == null || searchText!.isEmpty) &&
        (titleQuery == null || titleQuery!.isEmpty) &&
        (contentQuery == null || contentQuery!.isEmpty) &&
        (tags == null || tags!.isEmpty) &&
        createdAfter == null &&
        createdBefore == null &&
        isFolder == null;
  }

  SearchQuery copyWith({
    String? searchText,
    String? titleQuery,
    String? contentQuery,
    List<String>? tags,
    DateTime? createdAfter,
    DateTime? createdBefore,
    bool? isFolder,
  }) {
    return SearchQuery(
      searchText: searchText ?? this.searchText,
      titleQuery: titleQuery ?? this.titleQuery,
      contentQuery: contentQuery ?? this.contentQuery,
      tags: tags ?? this.tags,
      createdAfter: createdAfter ?? this.createdAfter,
      createdBefore: createdBefore ?? this.createdBefore,
      isFolder: isFolder ?? this.isFolder,
    );
  }

  @override
  List<Object?> get props => [
        searchText,
        titleQuery,
        contentQuery,
        tags,
        createdAfter,
        createdBefore,
        isFolder,
      ];
}
