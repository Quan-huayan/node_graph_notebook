/// SettingsPlugin —— 设置插件（M7，01 拍板 #39；M7.2 主题接线 +
/// 阶段 C 设置容器化）。
///
/// 贡献：SettingsContainerConcept（设置容器节点，子级 = references
/// 反查）+ ThemeSettingsConcept（主题条目）。'settings.open' 工具栏
/// 动作（M7 修正：按钮 = UI 节点，动作 = 本插件 UI）→ **打开设置容器**
/// （D1 打开契约：发起方弹框，外壳含关闭与回收）。主题状态 = 壳层
/// ThemeController（appframe，M7.2 E3：设置插件编辑，MaterialApp 消费）。
///
/// M7.1 修正（M7 插件约束 #41 补漏）：动作点击解析服务必须经构造
/// 注入的 servicesProvider 宿主入口——onLoad 快照会被后续 loadPlugin
/// dispose（plugon：每次 loadPlugin 销毁旧 provider），设置/市场
/// 插件此前漏改，点击即崩（"ServiceProvider 已销毁"）。
library;

import 'package:appframe/appframe.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:plugon/plugon.dart';

import 'src/appearance_settings.dart';
import 'src/settings_container.dart';
import 'src/theme_settings.dart';
import 'src/vault_settings.dart';

/// 设置插件。
class SettingsPlugin extends Plugin {
  /// [servicesProvider] 宿主注入的**最新** provider 解析入口
  /// （M7 修正模式，见 GraphPlugin 同款注释）。
  SettingsPlugin({ServiceProvider Function()? servicesProvider})
    : _servicesProvider = servicesProvider;

  final ServiceProvider Function()? _servicesProvider;

  ServiceProvider? _snapshot;

  /// 服务解析：宿主入口（运行时最新）优先；缺省回退 onLoad 快照
  /// （单插件测试兼容）。
  ServiceProvider get _provider => _servicesProvider?.call() ?? _snapshot!;

  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'com.example.settings',
    name: '设置插件',
    version: '1.0.0',
  );

  @override
  void registerExtensions(ExtensionRegistry registry) {
    // 设置容器 + 主题条目（M7.2 阶段 C：聚合 = Hook Tree，零新机制）。
    registry.addContribution(
      conceptPoint,
      const SettingsContainerConcept(),
      ownerPluginId: metadata.id,
    );
    registry.addContribution(
      conceptPoint,
      const ThemeSettingsConcept(),
      ownerPluginId: metadata.id,
    );
    // M7.2：字体大小（外观）条目。
    registry.addContribution(
      conceptPoint,
      const AppearanceSettingsConcept(),
      ownerPluginId: metadata.id,
    );
    // M7.3：多仓库条目（列表/切换/移除/新建）——**合并旧'存储'条目**
    // （数据目录信息由仓库表单呈现，settings-storage 概念已删除）。
    registry.addContribution(
      conceptPoint,
      const VaultSettingsConcept(),
      ownerPluginId: metadata.id,
    );
  }

  @override
  Future<void> onLoad(PluginContext context) async {
    // R13 豁免注释（docs/review 总览 P1-5 裁决）：生产路径永远经宿主注入的
    // servicesProvider 运行时求值（01 #47）；快照仅单插件测试兜底，非生产装配依赖。
    _snapshot = context.services;
    // M7 修正（Hook 承载 UI）：注册设置动作——按钮 = UI 节点
    // （metadata.action = 'settings.open'），动作 = 本插件 UI。
    _provider.get<ToolbarActionRegistry>().register('settings.open', (ctx) {
      // M7.2（E：语言切换即时刷新设置页——对话框监听 i18n）。
      final i18n = _provider.get<I18nService>();
      showDialog<void>(
        context: ctx,
        builder: (context) => ListenableBuilder(
          listenable: i18n,
          builder: (context, _) => Dialog(
            // M7.2 修正（用户裁决）：设置 = 单视图内联铺开（所有条目
            // 表单同一页，内容区滚动），无嵌套弹框。
            child: SizedBox(
              width: 520,
              height: 560,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: _provider.get<I18nService>().t('dialog.close'),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Expanded(
                    child: HookView(
                      host: _provider.get<HostRuntime>(),
                      nodeId: 'settings-root',
                      kind: 'open',
                      recycleOnDispose: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}
