import 'package:flutter/material.dart';

/// Node theme colors
///
/// Defines color schemes for nodes in the graph.
class NodeThemeColors {
  /// Creates a NodeThemeColors instance.
  const NodeThemeColors({
    required this.folderPrimary,
    required this.folderBackground,
    required this.nodePrimary,
    required this.nodeBackground,
    required this.selectedOverlay,
    required this.hoverBackground,
  });

  /// Creates a NodeThemeColors instance from JSON data.
  ///
  /// [json] - The JSON map containing color data.
  factory NodeThemeColors.fromJson(Map<String, dynamic> json) => NodeThemeColors(
        folderPrimary: Color(json['folderPrimary'] as int),
        folderBackground: Color(json['folderBackground'] as int),
        nodePrimary: Color(json['nodePrimary'] as int),
        nodeBackground: Color(json['nodeBackground'] as int),
        selectedOverlay: Color(json['selectedOverlay'] as int),
        hoverBackground: Color(json['hoverBackground'] as int),
      );

  /// Folder node primary color.
  final Color folderPrimary;
  /// Folder node background color.
  final Color folderBackground;
  /// Regular node primary color.
  final Color nodePrimary;
  /// Regular node background color.
  final Color nodeBackground;
  /// Selected node overlay color.
  final Color selectedOverlay;
  /// Hover background color.
  final Color hoverBackground;

  /// Creates a copy of NodeThemeColors with updated values.
  ///
  /// [folderPrimary] - Folder node primary color.
  /// [folderBackground] - Folder node background color.
  /// [nodePrimary] - Regular node primary color.
  /// [nodeBackground] - Regular node background color.
  /// [selectedOverlay] - Selected node overlay color.
  /// [hoverBackground] - Hover background color.
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

  /// Converts NodeThemeColors to JSON map.
  Map<String, dynamic> toJson() => {
        'folderPrimary': folderPrimary.toARGB32(),
        'folderBackground': folderBackground.toARGB32(),
        'nodePrimary': nodePrimary.toARGB32(),
        'nodeBackground': nodeBackground.toARGB32(),
        'selectedOverlay': selectedOverlay.toARGB32(),
        'hoverBackground': hoverBackground.toARGB32(),
      };
}

/// Connection theme colors
///
/// Defines color schemes for different types of connections between nodes.
class ConnectionThemeColors {
  /// Creates a ConnectionThemeColors instance.
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

  /// Creates a ConnectionThemeColors instance from JSON data.
  ///
  /// [json] - The JSON map containing color data.
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

  /// Color for "contains" connections.
  final Color contains;
  /// Color for "causes" connections.
  final Color causes;
  /// Color for "dependsOn" connections.
  final Color dependsOn;
  /// Color for "partOf" connections.
  final Color partOf;
  /// Color for "instanceOf" connections.
  final Color instanceOf;
  /// Color for "relatesTo" connections.
  final Color relatesTo;
  /// Color for "mentions" connections.
  final Color mentions;
  /// Color for "references" connections.
  final Color references;
  /// Default connection color.
  final Color defaultColor;

  /// Creates a copy of ConnectionThemeColors with updated values.
  ///
  /// [contains] - Color for "contains" connections.
  /// [causes] - Color for "causes" connections.
  /// [dependsOn] - Color for "dependsOn" connections.
  /// [partOf] - Color for "partOf" connections.
  /// [instanceOf] - Color for "instanceOf" connections.
  /// [relatesTo] - Color for "relatesTo" connections.
  /// [mentions] - Color for "mentions" connections.
  /// [references] - Color for "references" connections.
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

  /// Converts ConnectionThemeColors to JSON map.
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

/// UI theme colors
///
/// Defines color schemes for UI components.
class UIThemeColors {
  /// Creates a UIThemeColors instance.
  const UIThemeColors({
    required this.card,
    required this.divider,
    required this.icon,
    required this.badge,
    required this.badgeBackground,
  });

  /// Creates a UIThemeColors instance from JSON data.
  ///
  /// [json] - The JSON map containing color data.
  factory UIThemeColors.fromJson(Map<String, dynamic> json) => UIThemeColors(
        card: Color(json['card'] as int),
        divider: Color(json['divider'] as int),
        icon: Color(json['icon'] as int),
        badge: Color(json['badge'] as int),
        badgeBackground: Color(json['badgeBackground'] as int),
      );

  /// Card background color.
  final Color card;
  /// Divider color.
  final Color divider;
  /// Icon color.
  final Color icon;
  /// Badge text color.
  final Color badge;
  /// Badge background color.
  final Color badgeBackground;

  /// Creates a copy of UIThemeColors with updated values.
  ///
  /// [card] - Card background color.
  /// [divider] - Divider color.
  /// [icon] - Icon color.
  /// [badge] - Badge text color.
  /// [badgeBackground] - Badge background color.
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

  /// Converts UIThemeColors to JSON map.
  Map<String, dynamic> toJson() => {
        'card': card.toARGB32(),
        'divider': divider.toARGB32(),
        'icon': icon.toARGB32(),
        'badge': badge.toARGB32(),
        'badgeBackground': badgeBackground.toARGB32(),
      };
}

/// Text theme colors
///
/// Defines color schemes for text elements.
class TextThemeColors {
  /// Creates a TextThemeColors instance.
  const TextThemeColors({
    required this.primary,
    required this.secondary,
    required this.hint,
    required this.onDark,
  });

  /// Creates a TextThemeColors instance from JSON data.
  ///
  /// [json] - The JSON map containing color data.
  factory TextThemeColors.fromJson(Map<String, dynamic> json) => TextThemeColors(
        primary: Color(json['primary'] as int),
        secondary: Color(json['secondary'] as int),
        hint: Color(json['hint'] as int),
        onDark: Color(json['onDark'] as int),
      );

  /// Primary text color.
  final Color primary;
  /// Secondary text color.
  final Color secondary;
  /// Hint text color.
  final Color hint;
  /// Text color on dark backgrounds.
  final Color onDark;

  /// Creates a copy of TextThemeColors with updated values.
  ///
  /// [primary] - Primary text color.
  /// [secondary] - Secondary text color.
  /// [hint] - Hint text color.
  /// [onDark] - Text color on dark backgrounds.
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

  /// Converts TextThemeColors to JSON map.
  Map<String, dynamic> toJson() => {
        'primary': primary.toARGB32(),
        'secondary': secondary.toARGB32(),
        'hint': hint.toARGB32(),
        'onDark': onDark.toARGB32(),
      };
}

/// Background theme colors
///
/// Defines color schemes for background elements.
class BackgroundThemeColors {
  /// Creates a BackgroundThemeColors instance.
  const BackgroundThemeColors({
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.canvas,
  });

  /// Creates a BackgroundThemeColors instance from JSON data.
  ///
  /// [json] - The JSON map containing color data.
  factory BackgroundThemeColors.fromJson(Map<String, dynamic> json) => BackgroundThemeColors(
        primary: Color(json['primary'] as int),
        secondary: Color(json['secondary'] as int),
        tertiary: Color(json['tertiary'] as int),
        canvas: Color(json['canvas'] as int),
      );

  /// Primary background color.
  final Color primary;
  /// Secondary background color.
  final Color secondary;
  /// Tertiary background color.
  final Color tertiary;
  /// Canvas background color.
  final Color canvas;

  /// Creates a copy of BackgroundThemeColors with updated values.
  ///
  /// [primary] - Primary background color.
  /// [secondary] - Secondary background color.
  /// [tertiary] - Tertiary background color.
  /// [canvas] - Canvas background color.
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

  /// Converts BackgroundThemeColors to JSON map.
  Map<String, dynamic> toJson() => {
        'primary': primary.toARGB32(),
        'secondary': secondary.toARGB32(),
        'tertiary': tertiary.toARGB32(),
        'canvas': canvas.toARGB32(),
      };
}

/// Status theme colors
///
/// Defines color schemes for status indicators (error, success, warning, info).
class StatusThemeColors {
  /// Creates a StatusThemeColors instance.
  const StatusThemeColors({
    required this.error,
    required this.success,
    required this.warning,
    required this.info,
  });

  /// Creates a StatusThemeColors instance from JSON data.
  ///
  /// [json] - The JSON map containing color data.
  factory StatusThemeColors.fromJson(Map<String, dynamic> json) => StatusThemeColors(
        error: Color(json['error'] as int),
        success: Color(json['success'] as int),
        warning: Color(json['warning'] as int),
        info: Color(json['info'] as int),
      );

  /// Error state color.
  final Color error;
  /// Success state color.
  final Color success;
  /// Warning state color.
  final Color warning;
  /// Info state color.
  final Color info;

  /// Creates a copy of StatusThemeColors with updated values.
  ///
  /// [error] - Error state color.
  /// [success] - Success state color.
  /// [warning] - Warning state color.
  /// [info] - Info state color.
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

  /// Converts StatusThemeColors to JSON map.
  Map<String, dynamic> toJson() => {
        'error': error.toARGB32(),
        'success': success.toARGB32(),
        'warning': warning.toARGB32(),
        'info': info.toARGB32(),
      };
}

/// Flame theme colors
///
/// Defines color schemes for Flame engine rendering (grid, axes, selection).
class FlameThemeColors {
  /// Creates a FlameThemeColors instance.
  const FlameThemeColors({
    required this.gridLine,
    required this.originAxis,
    required this.selectionBox,
  });

  /// Creates a FlameThemeColors instance from JSON data.
  ///
  /// [json] - The JSON map containing color data.
  factory FlameThemeColors.fromJson(Map<String, dynamic> json) => FlameThemeColors(
        gridLine: Color(json['gridLine'] as int),
        originAxis: Color(json['originAxis'] as int),
        selectionBox: Color(json['selectionBox'] as int),
      );

  /// Grid line color.
  final Color gridLine;
  /// Origin axis color.
  final Color originAxis;
  /// Selection box color.
  final Color selectionBox;

  /// Creates a copy of FlameThemeColors with updated values.
  ///
  /// [gridLine] - Grid line color.
  /// [originAxis] - Origin axis color.
  /// [selectionBox] - Selection box color.
  FlameThemeColors copyWith({
    Color? gridLine,
    Color? originAxis,
    Color? selectionBox,
  }) => FlameThemeColors(
        gridLine: gridLine ?? this.gridLine,
        originAxis: originAxis ?? this.originAxis,
        selectionBox: selectionBox ?? this.selectionBox,
      );

  /// Converts FlameThemeColors to JSON map.
  Map<String, dynamic> toJson() => {
        'gridLine': gridLine.toARGB32(),
        'originAxis': originAxis.toARGB32(),
        'selectionBox': selectionBox.toARGB32(),
      };
}

/// Sidebar theme colors
///
/// Defines color schemes for sidebar components (activity bar, content panel).
class SidebarThemeColors {
  /// Creates a SidebarThemeColors instance.
  const SidebarThemeColors({
    required this.activityBarBackground,
    required this.activityBarIcon,
    required this.activityBarIconSelected,
    required this.activityBarIndicator,
    required this.activityBarHover,
    required this.contentBackground,
    required this.contentBorder,
  });

  /// Creates a SidebarThemeColors instance from JSON data.
  ///
  /// [json] - The JSON map containing color data.
  factory SidebarThemeColors.fromJson(Map<String, dynamic> json) => SidebarThemeColors(
        activityBarBackground: Color(json['activityBarBackground'] as int),
        activityBarIcon: Color(json['activityBarIcon'] as int),
        activityBarIconSelected: Color(json['activityBarIconSelected'] as int),
        activityBarIndicator: Color(json['activityBarIndicator'] as int),
        activityBarHover: Color(json['activityBarHover'] as int),
        contentBackground: Color(json['contentBackground'] as int),
        contentBorder: Color(json['contentBorder'] as int),
      );

  /// Activity bar background color.
  final Color activityBarBackground;
  /// Activity bar icon color (unselected).
  final Color activityBarIcon;
  /// Activity bar icon color (selected).
  final Color activityBarIconSelected;
  /// Activity bar selection indicator color.
  final Color activityBarIndicator;
  /// Activity bar hover background color.
  final Color activityBarHover;
  /// Sidebar content panel background color.
  final Color contentBackground;
  /// Sidebar content panel border color.
  final Color contentBorder;

  /// Creates a copy of SidebarThemeColors with updated values.
  SidebarThemeColors copyWith({
    Color? activityBarBackground,
    Color? activityBarIcon,
    Color? activityBarIconSelected,
    Color? activityBarIndicator,
    Color? activityBarHover,
    Color? contentBackground,
    Color? contentBorder,
  }) => SidebarThemeColors(
        activityBarBackground: activityBarBackground ?? this.activityBarBackground,
        activityBarIcon: activityBarIcon ?? this.activityBarIcon,
        activityBarIconSelected: activityBarIconSelected ?? this.activityBarIconSelected,
        activityBarIndicator: activityBarIndicator ?? this.activityBarIndicator,
        activityBarHover: activityBarHover ?? this.activityBarHover,
        contentBackground: contentBackground ?? this.contentBackground,
        contentBorder: contentBorder ?? this.contentBorder,
      );

  /// Converts SidebarThemeColors to JSON map.
  Map<String, dynamic> toJson() => {
        'activityBarBackground': activityBarBackground.toARGB32(),
        'activityBarIcon': activityBarIcon.toARGB32(),
        'activityBarIconSelected': activityBarIconSelected.toARGB32(),
        'activityBarIndicator': activityBarIndicator.toARGB32(),
        'activityBarHover': activityBarHover.toARGB32(),
        'contentBackground': contentBackground.toARGB32(),
        'contentBorder': contentBorder.toARGB32(),
      };
}

/// MainToolbar theme colors
///
/// Defines color schemes for main toolbar components (app bar, title, actions).
class MainToolbarThemeColors {
  /// Creates a MainToolbarThemeColors instance.
  const MainToolbarThemeColors({
    required this.background,
    required this.foreground,
    required this.icon,
    required this.iconHover,
    required this.border,
  });

  /// Creates a MainToolbarThemeColors instance from JSON data.
  ///
  /// [json] - The JSON map containing color data.
  factory MainToolbarThemeColors.fromJson(Map<String, dynamic> json) => MainToolbarThemeColors(
        background: Color(json['background'] as int),
        foreground: Color(json['foreground'] as int),
        icon: Color(json['icon'] as int),
        iconHover: Color(json['iconHover'] as int),
        border: Color(json['border'] as int),
      );

  /// Toolbar background color.
  final Color background;
  /// Toolbar foreground color (title text).
  final Color foreground;
  /// Toolbar icon color.
  final Color icon;
  /// Toolbar icon hover color.
  final Color iconHover;
  /// Toolbar border color.
  final Color border;

  /// Creates a copy of MainToolbarThemeColors with updated values.
  MainToolbarThemeColors copyWith({
    Color? background,
    Color? foreground,
    Color? icon,
    Color? iconHover,
    Color? border,
  }) => MainToolbarThemeColors(
        background: background ?? this.background,
        foreground: foreground ?? this.foreground,
        icon: icon ?? this.icon,
        iconHover: iconHover ?? this.iconHover,
        border: border ?? this.border,
      );

  /// Converts MainToolbarThemeColors to JSON map.
  Map<String, dynamic> toJson() => {
        'background': background.toARGB32(),
        'foreground': foreground.toARGB32(),
        'icon': icon.toARGB32(),
        'iconHover': iconHover.toARGB32(),
        'border': border.toARGB32(),
      };
}

/// Application theme data
///
/// Contains all theme colors for the application including nodes, connections, UI, text, backgrounds, status, and Flame rendering.
class AppThemeData {
  /// Creates an AppThemeData instance.
  const AppThemeData({
    required this.nodes,
    required this.connections,
    required this.ui,
    required this.text,
    required this.backgrounds,
    required this.status,
    required this.flame,
    required this.sidebar,
    required this.mainToolbar,
    this.fontFamily,
  });

  /// Creates an AppThemeData instance from JSON data.
  ///
  /// [json] - The JSON map containing theme data.
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
        sidebar: SidebarThemeColors.fromJson(json['sidebar'] as Map<String, dynamic>),
        mainToolbar: MainToolbarThemeColors.fromJson(json['mainToolbar'] as Map<String, dynamic>),
        fontFamily: json['fontFamily'] as String?,
      );

  /// Node theme colors.
  final NodeThemeColors nodes;
  /// Connection theme colors.
  final ConnectionThemeColors connections;
  /// UI theme colors.
  final UIThemeColors ui;
  /// Text theme colors.
  final TextThemeColors text;
  /// Background theme colors.
  final BackgroundThemeColors backgrounds;
  /// Status theme colors.
  final StatusThemeColors status;
  /// Flame theme colors.
  final FlameThemeColors flame;
  /// Sidebar theme colors.
  final SidebarThemeColors sidebar;
  /// MainToolbar theme colors.
  final MainToolbarThemeColors mainToolbar;
  /// Font family name.
  final String? fontFamily;

  /// Creates a copy of AppThemeData with updated values.
  ///
  /// [nodes] - Node theme colors.
  /// [connections] - Connection theme colors.
  /// [ui] - UI theme colors.
  /// [text] - Text theme colors.
  /// [backgrounds] - Background theme colors.
  /// [status] - Status theme colors.
  /// [flame] - Flame theme colors.
  /// [sidebar] - Sidebar theme colors.
  /// [mainToolbar] - MainToolbar theme colors.
  /// [fontFamily] - Font family name.
  AppThemeData copyWith({
    NodeThemeColors? nodes,
    ConnectionThemeColors? connections,
    UIThemeColors? ui,
    TextThemeColors? text,
    BackgroundThemeColors? backgrounds,
    StatusThemeColors? status,
    FlameThemeColors? flame,
    SidebarThemeColors? sidebar,
    MainToolbarThemeColors? mainToolbar,
    String? fontFamily,
  }) => AppThemeData(
        nodes: nodes ?? this.nodes,
        connections: connections ?? this.connections,
        ui: ui ?? this.ui,
        text: text ?? this.text,
        backgrounds: backgrounds ?? this.backgrounds,
        status: status ?? this.status,
        flame: flame ?? this.flame,
        sidebar: sidebar ?? this.sidebar,
        mainToolbar: mainToolbar ?? this.mainToolbar,
        fontFamily: fontFamily ?? this.fontFamily,
      );

  /// Converts AppThemeData to JSON map.
  Map<String, dynamic> toJson() => {
        'nodes': nodes.toJson(),
        'connections': connections.toJson(),
        'ui': ui.toJson(),
        'text': text.toJson(),
        'backgrounds': backgrounds.toJson(),
        'status': status.toJson(),
        'flame': flame.toJson(),
        'sidebar': sidebar.toJson(),
        'mainToolbar': mainToolbar.toJson(),
        if (fontFamily != null) 'fontFamily': fontFamily,
      };

  /// Light theme preset.
  static const AppThemeData lightTheme = AppThemeData(
    nodes: NodeThemeColors(
      folderPrimary: Color(0xFFFFA000),
      folderBackground: Color(0xFFFFF8E1),
      nodePrimary: Color(0xFF1976D2),
      nodeBackground: Color(0xFFFFFFFF),
      selectedOverlay: Color(0x802196F3),
      hoverBackground: Color(0xFFEEEEEE),
    ),
    connections: ConnectionThemeColors(
      contains: Color(0xFFFF9800),
      causes: Color(0xFFF44336),
      dependsOn: Color(0xFF2196F3),
      partOf: Color(0xFF4CAF50),
      instanceOf: Color(0xFF9C27B0),
      relatesTo: Color(0xFF9E9E9E),
      mentions: Color(0xFF9E9E9E),
      references: Color(0xFF9E9E9E),
    ),
    ui: UIThemeColors(
      card: Color(0xFFFFFFFF),
      divider: Color(0xFFE0E0E0),
      icon: Color(0xFF757575),
      badge: Color(0xFFFFFFFF),
      badgeBackground: Color(0xFF757575),
    ),
    text: TextThemeColors(
      primary: Color(0xDE000000),
      secondary: Color(0x8A000000),
      hint: Color(0x61000000),
      onDark: Color(0xFFFFFFFF),
    ),
    backgrounds: BackgroundThemeColors(
      primary: Color(0xFFFFFFFF),
      secondary: Color(0xFFF5F5F5),
      tertiary: Color(0xFFEEEEEE),
      canvas: Color(0xFFF5F5F5),
    ),
    status: StatusThemeColors(
      error: Color(0xFFF44336),
      success: Color(0xFF4CAF50),
      warning: Color(0xFFFF9800),
      info: Color(0xFF2196F3),
    ),
    flame: FlameThemeColors(
      gridLine: Color(0xFFE0E0E0),
      originAxis: Color(0xFFF44336),
      selectionBox: Color(0x802196F3),
    ),
    sidebar: SidebarThemeColors(
      activityBarBackground: Color(0xFFFFFFFF),
      activityBarIcon: Color(0xFF1976D2),
      activityBarIconSelected: Color(0xFF1976D2),
      activityBarIndicator: Color(0xFFFFFFFF),
      activityBarHover: Color(0xFF1565C0),
      contentBackground: Color(0xFFFFFFFF),
      contentBorder: Color(0xFFE0E0E0),
    ),
    mainToolbar: MainToolbarThemeColors(
      background: Color(0xFF1976D2),
      foreground: Color(0xFFFFFFFF),
      icon: Color(0xFFFFFFFF),
      iconHover: Color(0xFFE3F2FD),
      border: Color(0xFF1565C0),
    ),
  );

  /// Dark theme preset.
  static const AppThemeData darkTheme = AppThemeData(
    nodes: NodeThemeColors(
      folderPrimary: Color(0xFFFFC107),
      folderBackground: Color(0xFF3E2723),
      nodePrimary: Color(0xFF64B5F6),
      nodeBackground: Color(0xFF212121),
      selectedOverlay: Color(0x80448AFF),
      hoverBackground: Color(0xFF424242),
    ),
    connections: ConnectionThemeColors(
      contains: Color(0xFFFFB74D),
      causes: Color(0xFFEF5350),
      dependsOn: Color(0xFF64B5F6),
      partOf: Color(0xFF81C784),
      instanceOf: Color(0xFFBA68C8),
      relatesTo: Color(0xFFBDBDBD),
      mentions: Color(0xFFBDBDBD),
      references: Color(0xFFBDBDBD),
    ),
    ui: UIThemeColors(
      card: Color(0xFF1E1E1E),
      divider: Color(0xFF424242),
      icon: Color(0xFFBDBDBD),
      badge: Color(0xFFFFFFFF),
      badgeBackground: Color(0xFF616161),
    ),
    text: TextThemeColors(
      primary: Color(0xFFFFFFFF),
      secondary: Color(0xB3FFFFFF),
      hint: Color(0x80FFFFFF),
      onDark: Color(0xFFFFFFFF),
    ),
    backgrounds: BackgroundThemeColors(
      primary: Color(0xFF121212),
      secondary: Color(0xFF1E1E1E),
      tertiary: Color(0xFF2C2C2C),
      canvas: Color(0xFF121212),
    ),
    status: StatusThemeColors(
      error: Color(0xFFEF5350),
      success: Color(0xFF66BB6A),
      warning: Color(0xFFFFA726),
      info: Color(0xFF42A5F5),
    ),
    flame: FlameThemeColors(
      gridLine: Color(0xFF424242),
      originAxis: Color(0xFFEF5350),
      selectionBox: Color(0x80448AFF),
    ),
    sidebar: SidebarThemeColors(
      activityBarBackground: Color(0xFF1E1E1E),
      activityBarIcon: Color(0xFFFFFFFF),
      activityBarIconSelected: Color(0xFF64B5F6),
      activityBarIndicator: Color(0xFF64B5F6),
      activityBarHover: Color(0xFF2C2C2C),
      contentBackground: Color(0xFF1E1E1E),
      contentBorder: Color(0xFF424242),
    ),
    mainToolbar: MainToolbarThemeColors(
      background: Color(0xFF1E1E1E),
      foreground: Color(0xFFFFFFFF),
      icon: Color(0xFFFFFFFF),
      iconHover: Color(0xFF64B5F6),
      border: Color(0xFF424242),
    ),
  );
}

/// Application theme utility
///
/// Provides helper methods for converting AppThemeData to Material ThemeData.
class AppTheme {
  /// Creates a Material ThemeData from AppThemeData.
  ///
  /// [appTheme] - The application theme data.
  /// [brightness] - The brightness mode (light/dark).
  static ThemeData getMaterialTheme(
    AppThemeData appTheme,
    Brightness brightness,
  ) {
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
