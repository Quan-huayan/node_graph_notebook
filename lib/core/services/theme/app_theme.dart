import 'package:flutter/material.dart';

/// 节点主题颜色
class NodeThemeColors {
  /// 构造函数
  const NodeThemeColors({
    required this.folderPrimary,
    required this.folderBackground,
    required this.nodePrimary,
    required this.nodeBackground,
    required this.selectedOverlay,
    required this.hoverBackground,
  });

  /// 从JSON创建NodeThemeColors
  factory NodeThemeColors.fromJson(Map<String, dynamic> json) => NodeThemeColors(
        folderPrimary: Color(json['folderPrimary'] as int),
        folderBackground: Color(json['folderBackground'] as int),
        nodePrimary: Color(json['nodePrimary'] as int),
        nodeBackground: Color(json['nodeBackground'] as int),
        selectedOverlay: Color(json['selectedOverlay'] as int),
        hoverBackground: Color(json['hoverBackground'] as int),
      );

  /// 文件夹主色
  final Color folderPrimary;
  /// 文件夹背景色
  final Color folderBackground;
  /// 节点主色
  final Color nodePrimary;
  /// 节点背景色
  final Color nodeBackground;
  /// 选中覆盖色
  final Color selectedOverlay;
  /// 悬停背景色
  final Color hoverBackground;

  /// 复制并修改属性
  NodeThemeColors copyWith({
    Color? folderPrimary,
    Color? folderBackground,
    Color? nodePrimary,
    Color? nodeBackground,
    Color? selectedOverlay,
    Color? hoverBackground,
  }) => NodeThemeColors(
        folderPrimary: folderPrimary ?? this.folderPrimary,
        folderBackground: folderBackground ?? this.folderBackground,
        nodePrimary: nodePrimary ?? this.nodePrimary,
        nodeBackground: nodeBackground ?? this.nodeBackground,
        selectedOverlay: selectedOverlay ?? this.selectedOverlay,
        hoverBackground: hoverBackground ?? this.hoverBackground,
      );

  /// 转换为JSON
  Map<String, dynamic> toJson() => {
        'folderPrimary': folderPrimary.toARGB32(),
        'folderBackground': folderBackground.toARGB32(),
        'nodePrimary': nodePrimary.toARGB32(),
        'nodeBackground': nodeBackground.toARGB32(),
        'selectedOverlay': selectedOverlay.toARGB32(),
        'hoverBackground': hoverBackground.toARGB32(),
      };
}

/// 连接线主题颜色
class ConnectionThemeColors {
  /// 构造函数
  const ConnectionThemeColors({
    required this.contains,
    required this.causes,
    required this.dependsOn,
    required this.partOf,
    required this.instanceOf,
    required this.relatesTo,
    required this.mentions,
    required this.references,
    this.defaultColor = const Color(0xFF4A90E2),
  });

  /// 从JSON创建ConnectionThemeColors
  factory ConnectionThemeColors.fromJson(Map<String, dynamic> json) => ConnectionThemeColors(
        contains: Color(json['contains'] as int),
        causes: Color(json['causes'] as int),
        dependsOn: Color(json['dependsOn'] as int),
        partOf: Color(json['partOf'] as int),
        instanceOf: Color(json['instanceOf'] as int),
        relatesTo: Color(json['relatesTo'] as int),
        mentions: Color(json['mentions'] as int),
        references: Color(json['references'] as int),
      );

  /// 包含关系颜色
  final Color contains;
  /// 因果关系颜色
  final Color causes;
  /// 依赖关系颜色
  final Color dependsOn;
  /// 部分关系颜色
  final Color partOf;
  /// 实例关系颜色
  final Color instanceOf;
  /// 相关关系颜色
  final Color relatesTo;
  /// 提及关系颜色
  final Color mentions;
  /// 引用关系颜色
  final Color references;
  /// 默认颜色
  final Color defaultColor;

  /// 复制并修改属性
  ConnectionThemeColors copyWith({
    Color? contains,
    Color? causes,
    Color? dependsOn,
    Color? partOf,
    Color? instanceOf,
    Color? relatesTo,
    Color? mentions,
    Color? references,
  }) => ConnectionThemeColors(
        contains: contains ?? this.contains,
        causes: causes ?? this.causes,
        dependsOn: dependsOn ?? this.dependsOn,
        partOf: partOf ?? this.partOf,
        instanceOf: instanceOf ?? this.instanceOf,
        relatesTo: relatesTo ?? this.relatesTo,
        mentions: mentions ?? this.mentions,
        references: references ?? this.references,
      );

  /// 转换为JSON
  Map<String, dynamic> toJson() => {
        'contains': contains.toARGB32(),
        'causes': causes.toARGB32(),
        'dependsOn': dependsOn.toARGB32(),
        'partOf': partOf.toARGB32(),
        'instanceOf': instanceOf.toARGB32(),
        'relatesTo': relatesTo.toARGB32(),
        'mentions': mentions.toARGB32(),
        'references': references.toARGB32(),
        'defaultColor': defaultColor.toARGB32(),
      };
}

/// UI 主题颜色
class UIThemeColors {
  /// 构造函数
  const UIThemeColors({
    required this.card,
    required this.divider,
    required this.icon,
    required this.badge,
    required this.badgeBackground,
  });

  /// 从JSON创建UIThemeColors
  factory UIThemeColors.fromJson(Map<String, dynamic> json) => UIThemeColors(
        card: Color(json['card'] as int),
        divider: Color(json['divider'] as int),
        icon: Color(json['icon'] as int),
        badge: Color(json['badge'] as int),
        badgeBackground: Color(json['badgeBackground'] as int),
      );

  /// 卡片颜色
  final Color card;
  /// 分隔线颜色
  final Color divider;
  /// 图标颜色
  final Color icon;
  /// 徽章颜色
  final Color badge;
  /// 徽章背景色
  final Color badgeBackground;

  /// 复制并修改属性
  UIThemeColors copyWith({
    Color? card,
    Color? divider,
    Color? icon,
    Color? badge,
    Color? badgeBackground,
  }) => UIThemeColors(
        card: card ?? this.card,
        divider: divider ?? this.divider,
        icon: icon ?? this.icon,
        badge: badge ?? this.badge,
        badgeBackground: badgeBackground ?? this.badgeBackground,
      );

  /// 转换为JSON
  Map<String, dynamic> toJson() => {
        'card': card.toARGB32(),
        'divider': divider.toARGB32(),
        'icon': icon.toARGB32(),
        'badge': badge.toARGB32(),
        'badgeBackground': badgeBackground.toARGB32(),
      };
}

/// 文本主题颜色
class TextThemeColors {
  /// 构造函数
  const TextThemeColors({
    required this.primary,
    required this.secondary,
    required this.hint,
    required this.onDark,
  });

  /// 从JSON创建TextThemeColors
  factory TextThemeColors.fromJson(Map<String, dynamic> json) => TextThemeColors(
        primary: Color(json['primary'] as int),
        secondary: Color(json['secondary'] as int),
        hint: Color(json['hint'] as int),
        onDark: Color(json['onDark'] as int),
      );

  /// 主要文本颜色
  final Color primary;
  /// 次要文本颜色
  final Color secondary;
  /// 提示文本颜色
  final Color hint;
  /// 深色背景上的文本颜色
  final Color onDark;

  /// 复制并修改属性
  TextThemeColors copyWith({
    Color? primary,
    Color? secondary,
    Color? hint,
    Color? onDark,
  }) => TextThemeColors(
        primary: primary ?? this.primary,
        secondary: secondary ?? this.secondary,
        hint: hint ?? this.hint,
        onDark: onDark ?? this.onDark,
      );

  /// 转换为JSON
  Map<String, dynamic> toJson() => {
        'primary': primary.toARGB32(),
        'secondary': secondary.toARGB32(),
        'hint': hint.toARGB32(),
        'onDark': onDark.toARGB32(),
      };
}

/// 背景主题颜色
class BackgroundThemeColors {
  /// 构造函数
  const BackgroundThemeColors({
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.canvas,
  });

  /// 从JSON创建BackgroundThemeColors
  factory BackgroundThemeColors.fromJson(Map<String, dynamic> json) => BackgroundThemeColors(
        primary: Color(json['primary'] as int),
        secondary: Color(json['secondary'] as int),
        tertiary: Color(json['tertiary'] as int),
        canvas: Color(json['canvas'] as int),
      );

  /// 主要背景色
  final Color primary;
  /// 次要背景色
  final Color secondary;
  /// 第三级背景色
  final Color tertiary;
  /// 画布背景色
  final Color canvas;

  /// 复制并修改属性
  BackgroundThemeColors copyWith({
    Color? primary,
    Color? secondary,
    Color? tertiary,
    Color? canvas,
  }) => BackgroundThemeColors(
        primary: primary ?? this.primary,
        secondary: secondary ?? this.secondary,
        tertiary: tertiary ?? this.tertiary,
        canvas: canvas ?? this.canvas,
      );

  /// 转换为JSON
  Map<String, dynamic> toJson() => {
        'primary': primary.toARGB32(),
        'secondary': secondary.toARGB32(),
        'tertiary': tertiary.toARGB32(),
        'canvas': canvas.toARGB32(),
      };
}

/// 状态主题颜色
class StatusThemeColors {
  /// 构造函数
  const StatusThemeColors({
    required this.error,
    required this.success,
    required this.warning,
    required this.info,
  });

  /// 从JSON创建StatusThemeColors
  factory StatusThemeColors.fromJson(Map<String, dynamic> json) => StatusThemeColors(
        error: Color(json['error'] as int),
        success: Color(json['success'] as int),
        warning: Color(json['warning'] as int),
        info: Color(json['info'] as int),
      );

  /// 错误状态颜色
  final Color error;
  /// 成功状态颜色
  final Color success;
  /// 警告状态颜色
  final Color warning;
  /// 信息状态颜色
  final Color info;

  /// 复制并修改属性
  StatusThemeColors copyWith({
    Color? error,
    Color? success,
    Color? warning,
    Color? info,
  }) => StatusThemeColors(
        error: error ?? this.error,
        success: success ?? this.success,
        warning: warning ?? this.warning,
        info: info ?? this.info,
      );

  /// 转换为JSON
  Map<String, dynamic> toJson() => {
        'error': error.toARGB32(),
        'success': success.toARGB32(),
        'warning': warning.toARGB32(),
        'info': info.toARGB32(),
      };
}

/// Flame 特定主题颜色
class FlameThemeColors {
  /// 构造函数
  const FlameThemeColors({
    required this.gridLine,
    required this.originAxis,
    required this.selectionBox,
  });

  /// 从JSON创建FlameThemeColors
  factory FlameThemeColors.fromJson(Map<String, dynamic> json) => FlameThemeColors(
        gridLine: Color(json['gridLine'] as int),
        originAxis: Color(json['originAxis'] as int),
        selectionBox: Color(json['selectionBox'] as int),
      );

  /// 网格线颜色
  final Color gridLine;
  /// 原点轴线颜色
  final Color originAxis;
  /// 选择框颜色
  final Color selectionBox;

  /// 复制并修改属性
  FlameThemeColors copyWith({
    Color? gridLine,
    Color? originAxis,
    Color? selectionBox,
  }) => FlameThemeColors(
        gridLine: gridLine ?? this.gridLine,
        originAxis: originAxis ?? this.originAxis,
        selectionBox: selectionBox ?? this.selectionBox,
      );

  /// 转换为JSON
  Map<String, dynamic> toJson() => {
        'gridLine': gridLine.toARGB32(),
        'originAxis': originAxis.toARGB32(),
        'selectionBox': selectionBox.toARGB32(),
      };
}

/// 应用主题数据
class AppThemeData {
  /// 构造函数
  const AppThemeData({
    required this.nodes,
    required this.connections,
    required this.ui,
    required this.text,
    required this.backgrounds,
    required this.status,
    required this.flame,
    this.fontFamily,
  });

  /// 从JSON创建AppThemeData
  factory AppThemeData.fromJson(Map<String, dynamic> json) => AppThemeData(
        nodes: NodeThemeColors.fromJson(json['nodes'] as Map<String, dynamic>),
        connections: ConnectionThemeColors.fromJson(
          json['connections'] as Map<String, dynamic>,
        ),
        ui: UIThemeColors.fromJson(json['ui'] as Map<String, dynamic>),
        text: TextThemeColors.fromJson(json['text'] as Map<String, dynamic>),
        backgrounds: BackgroundThemeColors.fromJson(
          json['backgrounds'] as Map<String, dynamic>,
        ),
        status: StatusThemeColors.fromJson(
          json['status'] as Map<String, dynamic>,
        ),
        flame: FlameThemeColors.fromJson(json['flame'] as Map<String, dynamic>),
        fontFamily: json['fontFamily'] as String?,
      );

  /// 节点主题颜色
  final NodeThemeColors nodes;
  /// 连接线主题颜色
  final ConnectionThemeColors connections;
  /// UI主题颜色
  final UIThemeColors ui;
  /// 文本主题颜色
  final TextThemeColors text;
  /// 背景主题颜色
  final BackgroundThemeColors backgrounds;
  /// 状态主题颜色
  final StatusThemeColors status;
  /// Flame特定主题颜色
  final FlameThemeColors flame;
  /// 字体族（null 表示使用系统默认字体）
  final String? fontFamily;

  /// 复制并修改属性
  AppThemeData copyWith({
    NodeThemeColors? nodes,
    ConnectionThemeColors? connections,
    UIThemeColors? ui,
    TextThemeColors? text,
    BackgroundThemeColors? backgrounds,
    StatusThemeColors? status,
    FlameThemeColors? flame,
    String? fontFamily,
  }) => AppThemeData(
        nodes: nodes ?? this.nodes,
        connections: connections ?? this.connections,
        ui: ui ?? this.ui,
        text: text ?? this.text,
        backgrounds: backgrounds ?? this.backgrounds,
        status: status ?? this.status,
        flame: flame ?? this.flame,
        fontFamily: fontFamily ?? this.fontFamily,
      );

  /// 转换为JSON
  Map<String, dynamic> toJson() => {
        'nodes': nodes.toJson(),
        'connections': connections.toJson(),
        'ui': ui.toJson(),
        'text': text.toJson(),
        'backgrounds': backgrounds.toJson(),
        'status': status.toJson(),
        'flame': flame.toJson(),
        if (fontFamily != null) 'fontFamily': fontFamily,
      };

  /// 亮色主题
  static const AppThemeData lightTheme = AppThemeData(
    nodes: NodeThemeColors(
      folderPrimary: Color(0xFFFFA000), // amber.shade700
      folderBackground: Color(0xFFFFF8E1), // amber.shade50
      nodePrimary: Color(0xFF1976D2), // blue.shade700
      nodeBackground: Color(0xFFFFFFFF), // white
      selectedOverlay: Color(0x802196F3), // blue.withValues(alpha: 0.5)
      hoverBackground: Color(0xFFEEEEEE), // grey.shade200
    ),
    connections: ConnectionThemeColors(
      contains: Color(0xFFFF9800), // orange
      causes: Color(0xFFF44336), // red
      dependsOn: Color(0xFF2196F3), // blue
      partOf: Color(0xFF4CAF50), // green
      instanceOf: Color(0xFF9C27B0), // purple
      relatesTo: Color(0xFF9E9E9E), // grey
      mentions: Color(0xFF9E9E9E), // grey
      references: Color(0xFF9E9E9E), // grey
    ),
    ui: UIThemeColors(
      card: Color(0xFFFFFFFF), // white
      divider: Color(0xFFE0E0E0), // grey.shade300
      icon: Color(0xFF757575), // grey.shade600
      badge: Color(0xFFFFFFFF), // white
      badgeBackground: Color(0xFF757575), // grey.shade600
    ),
    text: TextThemeColors(
      primary: Color(0xDE000000), // black87
      secondary: Color(0x8A000000), // black54
      hint: Color(0x61000000), // black38
      onDark: Color(0xFFFFFFFF), // white
    ),
    backgrounds: BackgroundThemeColors(
      primary: Color(0xFFFFFFFF), // white
      secondary: Color(0xFFF5F5F5), // grey.shade100
      tertiary: Color(0xFFEEEEEE), // grey.shade200
      canvas: Color(0xFFF5F5F5), // grey.shade100
    ),
    status: StatusThemeColors(
      error: Color(0xFFF44336), // red
      success: Color(0xFF4CAF50), // green
      warning: Color(0xFFFF9800), // orange
      info: Color(0xFF2196F3), // blue
    ),
    flame: FlameThemeColors(
      gridLine: Color(0xFFE0E0E0), // grey.shade300
      originAxis: Color(0xFFF44336), // red
      selectionBox: Color(0x802196F3), // blue.withValues(alpha: 0.5)
    ),
  );

  /// 暗色主题
  static const AppThemeData darkTheme = AppThemeData(
    nodes: NodeThemeColors(
      folderPrimary: Color(0xFFFFC107), // amber.shade500
      folderBackground: Color(0xFF3E2723), // dark brown
      nodePrimary: Color(0xFF64B5F6), // blue.shade300
      nodeBackground: Color(0xFF212121), // dark grey
      selectedOverlay: Color(0x80448AFF), // blue.withValues(alpha: 0.5)
      hoverBackground: Color(0xFF424242), // grey.shade800
    ),
    connections: ConnectionThemeColors(
      contains: Color(0xFFFFB74D), // orange.shade300
      causes: Color(0xFFEF5350), // red.shade400
      dependsOn: Color(0xFF64B5F6), // blue.shade300
      partOf: Color(0xFF81C784), // green.shade300
      instanceOf: Color(0xFFBA68C8), // purple.shade300
      relatesTo: Color(0xFFBDBDBD), // grey.shade400
      mentions: Color(0xFFBDBDBD), // grey.shade400
      references: Color(0xFFBDBDBD), // grey.shade400
    ),
    ui: UIThemeColors(
      card: Color(0xFF1E1E1E), // dark grey
      divider: Color(0xFF424242), // grey.shade800
      icon: Color(0xFFBDBDBD), // grey.shade400
      badge: Color(0xFFFFFFFF), // white
      badgeBackground: Color(0xFF616161), // grey.shade700
    ),
    text: TextThemeColors(
      primary: Color(0xFFFFFFFF), // white
      secondary: Color(0xB3FFFFFF), // white70
      hint: Color(0x80FFFFFF), // white50
      onDark: Color(0xFFFFFFFF), // white
    ),
    backgrounds: BackgroundThemeColors(
      primary: Color(0xFF121212), // almost black
      secondary: Color(0xFF1E1E1E), // dark grey
      tertiary: Color(0xFF2C2C2C), // grey.shade900
      canvas: Color(0xFF121212), // almost black
    ),
    status: StatusThemeColors(
      error: Color(0xFFEF5350), // red.shade400
      success: Color(0xFF66BB6A), // green.shade400
      warning: Color(0xFFFFA726), // orange.shade400
      info: Color(0xFF42A5F5), // blue.shade400
    ),
    flame: FlameThemeColors(
      gridLine: Color(0xFF424242), // grey.shade800
      originAxis: Color(0xFFEF5350), // red.shade400
      selectionBox: Color(0x80448AFF), // blue.withValues(alpha: 0.5)
    ),
  );
}

/// AppTheme 辅助类
class AppTheme {
  /// 将 AppThemeData 转换为 Material ThemeData
  static ThemeData getMaterialTheme(
    AppThemeData appTheme,
    Brightness brightness,
  ) {
    // 获取字体族，如果未设置则使用系统默认字体
    final fontFamily = appTheme.fontFamily;

    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: appTheme.nodes.nodePrimary,
        brightness: brightness,
        primary: appTheme.nodes.nodePrimary,
        secondary: appTheme.nodes.folderPrimary,
        error: appTheme.status.error,
        surface: appTheme.backgrounds.primary,
        onPrimary: appTheme.text.onDark,
        onSecondary: appTheme.text.onDark,
        onError: appTheme.text.onDark,
        onSurface: appTheme.text.primary,
      ),
      scaffoldBackgroundColor: appTheme.backgrounds.canvas,
      cardColor: appTheme.ui.card,
      dividerColor: appTheme.ui.divider,
      fontFamily: fontFamily,
      textTheme: TextTheme(
        displayLarge: TextStyle(color: appTheme.text.primary, fontSize: 57, fontFamily: fontFamily),
        displayMedium: TextStyle(color: appTheme.text.primary, fontSize: 45, fontFamily: fontFamily),
        displaySmall: TextStyle(color: appTheme.text.primary, fontSize: 36, fontFamily: fontFamily),
        headlineMedium: TextStyle(color: appTheme.text.primary, fontSize: 28, fontFamily: fontFamily),
        headlineSmall: TextStyle(color: appTheme.text.primary, fontSize: 24, fontFamily: fontFamily),
        titleLarge: TextStyle(color: appTheme.text.primary, fontSize: 22, fontFamily: fontFamily),
        titleMedium: TextStyle(color: appTheme.text.primary, fontSize: 16, fontFamily: fontFamily),
        titleSmall: TextStyle(color: appTheme.text.secondary, fontSize: 14, fontFamily: fontFamily),
        bodyLarge: TextStyle(color: appTheme.text.primary, fontSize: 16, fontFamily: fontFamily),
        bodyMedium: TextStyle(color: appTheme.text.primary, fontSize: 14, fontFamily: fontFamily),
        bodySmall: TextStyle(color: appTheme.text.secondary, fontSize: 12, fontFamily: fontFamily),
        labelLarge: TextStyle(color: appTheme.text.primary, fontSize: 14, fontFamily: fontFamily),
        labelMedium: TextStyle(color: appTheme.text.secondary, fontSize: 12, fontFamily: fontFamily),
        labelSmall: TextStyle(color: appTheme.text.secondary, fontSize: 11, fontFamily: fontFamily),
      ),
      useMaterial3: true,
    );
  }
}
