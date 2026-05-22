import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/craft_api.dart';
import '../services/local_notification_service.dart';

enum CraftThemeMode { system, light, dark }

class NotificationPreferences {
  const NotificationPreferences({
    this.enabled = true,
    this.directMessages = true,
    this.workspaceMessages = true,
  });

  final bool enabled;
  final bool directMessages;
  final bool workspaceMessages;

  NotificationPreferences copyWith({
    bool? enabled,
    bool? directMessages,
    bool? workspaceMessages,
  }) {
    return NotificationPreferences(
      enabled: enabled ?? this.enabled,
      directMessages: directMessages ?? this.directMessages,
      workspaceMessages: workspaceMessages ?? this.workspaceMessages,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'directMessages': directMessages,
      'workspaceMessages': workspaceMessages,
    };
  }

  static NotificationPreferences fromJson(Map<String, dynamic>? json) {
    final source = json ?? const <String, dynamic>{};
    return NotificationPreferences(
      enabled: source['enabled'] != false,
      directMessages: source['directMessages'] != false,
      workspaceMessages: source['workspaceMessages'] != false,
    );
  }
}

class AppSettingsController extends ChangeNotifier {
  static const _themeKey = 'app_theme_mode';
  static const _promptSeenKey = 'notifications_prompt_seen';
  static const _permissionGrantedKey = 'notifications_permission_granted';
  static const _notificationPrefix = 'notifications_';

  CraftThemeMode _themeMode = CraftThemeMode.system;
  NotificationPreferences _notifications = const NotificationPreferences();
  bool _ready = false;
  bool _notificationPromptSeen = false;
  bool _notificationPermissionGranted = false;
  String? _boundUserId;

  bool get ready => _ready;
  CraftThemeMode get themeMode => _themeMode;
  NotificationPreferences get notifications => _notifications;
  bool get notificationPromptSeen => _notificationPromptSeen;
  bool get notificationPermissionGranted => _notificationPermissionGranted;
  bool get shouldAskNotificationPermission =>
      !_notificationPromptSeen && !_notificationPermissionGranted;

  ThemeMode get flutterThemeMode {
    switch (_themeMode) {
      case CraftThemeMode.light:
        return ThemeMode.light;
      case CraftThemeMode.dark:
        return ThemeMode.dark;
      case CraftThemeMode.system:
        return ThemeMode.system;
    }
  }

  Future<void> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = _parseThemeMode(prefs.getString(_themeKey));
    _notificationPromptSeen = prefs.getBool(_promptSeenKey) ?? false;
    _notificationPermissionGranted =
        prefs.getBool(_permissionGrantedKey) ?? false;
    _notifications = NotificationPreferences(
      enabled: prefs.getBool('${_notificationPrefix}enabled') ?? true,
      directMessages:
          prefs.getBool('${_notificationPrefix}directMessages') ?? true,
      workspaceMessages:
          prefs.getBool('${_notificationPrefix}workspaceMessages') ?? true,
    );
    _ready = true;
    notifyListeners();
  }

  void attachRemoteUser(Map<String, dynamic>? user) {
    if (user == null) {
      _boundUserId = null;
      return;
    }
    final userId = user['id'] as String?;
    if (userId == null || userId == _boundUserId) return;
    final settings = user['settings'] as Map<String, dynamic>?;
    if (settings == null) {
      _boundUserId = userId;
      return;
    }
    _boundUserId = userId;
    _themeMode = _parseThemeMode(settings['themeMode'] as String?);
    _notifications = NotificationPreferences.fromJson(
      settings['notifications'] as Map<String, dynamic>?,
    );
    _persistLocal();
    notifyListeners();
  }

  Future<void> setThemeMode(CraftThemeMode mode, {CraftApi? api}) async {
    _themeMode = mode;
    await _persistLocal();
    notifyListeners();
    if (api != null) {
      await api.updateMySettings(themeMode: mode.name);
    }
  }

  Future<void> setNotifications(
    NotificationPreferences next, {
    CraftApi? api,
  }) async {
    _notifications = next;
    await _persistLocal();
    notifyListeners();
    if (api != null) {
      await api.updateMySettings(notifications: next.toJson());
    }
  }

  Future<bool> requestAndEnableNotifications({CraftApi? api}) async {
    final granted = await LocalNotificationService.instance.requestPermission();
    _notificationPromptSeen = true;
    _notificationPermissionGranted = granted;
    if (granted && !_notifications.enabled) {
      _notifications = _notifications.copyWith(enabled: true);
    }
    await _persistLocal();
    notifyListeners();
    if (api != null) {
      await api.updateMySettings(notifications: _notifications.toJson());
    }
    return granted;
  }

  Future<void> declineNotifications({CraftApi? api}) async {
    _notificationPromptSeen = true;
    _notificationPermissionGranted = false;
    _notifications = _notifications.copyWith(enabled: false);
    await _persistLocal();
    notifyListeners();
    if (api != null) {
      await api.updateMySettings(notifications: _notifications.toJson());
    }
  }

  bool allowsEvent(String eventType) {
    if (!_notifications.enabled || !_notificationPermissionGranted) {
      return false;
    }
    switch (eventType) {
      case 'direct_message':
        return _notifications.directMessages;
      case 'workspace_message':
        return _notifications.workspaceMessages;
      default:
        return _notifications.enabled;
    }
  }

  CraftThemeMode _parseThemeMode(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'light':
        return CraftThemeMode.light;
      case 'dark':
        return CraftThemeMode.dark;
      default:
        return CraftThemeMode.system;
    }
  }

  Future<void> _persistLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, _themeMode.name);
    await prefs.setBool(_promptSeenKey, _notificationPromptSeen);
    await prefs.setBool(_permissionGrantedKey, _notificationPermissionGranted);
    await prefs.setBool(
      '${_notificationPrefix}enabled',
      _notifications.enabled,
    );
    await prefs.setBool(
      '${_notificationPrefix}directMessages',
      _notifications.directMessages,
    );
    await prefs.setBool(
      '${_notificationPrefix}workspaceMessages',
      _notifications.workspaceMessages,
    );
  }
}
