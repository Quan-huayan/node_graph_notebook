import 'package:equatable/equatable.dart';

/// 搜索查询模型
class SearchQuery extends Equatable {
  /// 创建搜索查询
  /// 
  /// [searchText] - 搜索文本
  /// [titleQuery] - 标题查询
  /// [contentQuery] - 内容查询
  /// [tags] - 标签列表
  /// [createdAfter] - 创建时间之后
  /// [createdBefore] - 创建时间之前
  /// [isFolder] - 是否为文件夹
  const SearchQuery({
    this.searchText,
    this.titleQuery,
    this.contentQuery,
    this.tags,
    this.createdAfter,
    this.createdBefore,
    this.isFolder,
  });

  /// 搜索文本
  final String? searchText;
  
  /// 标题查询
  final String? titleQuery;
  
  /// 内容查询
  final String? contentQuery;
  
  /// 标签列表
  final List<String>? tags;
  
  /// 创建时间之后
  final DateTime? createdAfter;
  
  /// 创建时间之前
  final DateTime? createdBefore;
  
  /// 是否为文件夹
  final bool? isFolder;

  /// 是否为空查询
  bool get isEmpty => (searchText == null || searchText!.isEmpty) &&
        (titleQuery == null || titleQuery!.isEmpty) &&
        (contentQuery == null || contentQuery!.isEmpty) &&
        (tags == null || tags!.isEmpty) &&
        createdAfter == null &&
        createdBefore == null &&
        isFolder == null;

  /// 复制并更新搜索查询
  SearchQuery copyWith({
    String? searchText,
    String? titleQuery,
    String? contentQuery,
    List<String>? tags,
    DateTime? createdAfter,
    DateTime? createdBefore,
    bool? isFolder,
  }) => SearchQuery(
      searchText: searchText ?? this.searchText,
      titleQuery: titleQuery ?? this.titleQuery,
      contentQuery: contentQuery ?? this.contentQuery,
      tags: tags ?? this.tags,
      createdAfter: createdAfter ?? this.createdAfter,
      createdBefore: createdBefore ?? this.createdBefore,
      isFolder: isFolder ?? this.isFolder,
    );

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
