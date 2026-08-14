/// AIProviderConfig —— LLM 后端配置（M7.2 阶段 C：AI API key 设置恢复；
/// M7.2 补修：增 model/baseUrl——设置不再简陋）。
///
/// 服务级状态（ChangeNotifier——设置表单编辑，ConfigAIProvider 读取）；
/// MVP 内存态（持久化 = SharedPreferences 由 app 层提供，后续迭代）。
/// key 为空 → Mock 后端（演示/测试可跑）；非空 → OpenAI 兼容后端。
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AI 后端配置。
///
/// P1-1：持久化绑定——[attach] 注入 SharedPreferences（app 层经
/// AiPlugin 传入）后，读回上次配置并随 setter 自动保存；null = 纯
/// 内存。验收 = 重启后 AI key 保持（00 §4.2 判据）。
class AIProviderConfig extends ChangeNotifier {
  /// 构造（缺省空 key = Mock 后端，OpenAI 默认参数）。
  AIProviderConfig({
    this.apiKey = '',
    this.model = 'gpt-4o-mini',
    this.baseUrl = 'https://api.openai.com/v1',
  });

  /// OpenAI 兼容 API 密钥（空 = 未配置 → Mock 后端）。
  String apiKey;

  /// 模型名。
  String model;

  /// API 基础 URL（兼容网关/代理）。
  String baseUrl;

  static const String _kApiKey = 'ai.apiKey';
  static const String _kModel = 'ai.model';
  static const String _kBaseUrl = 'ai.baseUrl';

  SharedPreferences? _prefs;

  /// 绑定持久化并恢复上次配置（AiPlugin 注册服务时调用）。
  void attach(SharedPreferences? prefs) {
    _prefs = prefs;
    if (prefs == null) {
      return;
    }
    apiKey = prefs.getString(_kApiKey) ?? apiKey;
    model = prefs.getString(_kModel) ?? model;
    baseUrl = prefs.getString(_kBaseUrl) ?? baseUrl;
    notifyListeners();
  }

  /// 更新密钥（通知 ConfigAIProvider/表单；已绑定则持久化）。
  void setApiKey(String value) {
    apiKey = value.trim();
    _prefs?.setString(_kApiKey, apiKey);
    notifyListeners();
  }

  /// 更新模型名。
  void setModel(String value) {
    model = value.trim();
    _prefs?.setString(_kModel, model);
    notifyListeners();
  }

  /// 更新 API 基础 URL。
  void setBaseUrl(String value) {
    baseUrl = value.trim();
    _prefs?.setString(_kBaseUrl, baseUrl);
    notifyListeners();
  }
}
