import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/api_config.dart';
import '../models/auth_flow.dart';
import '../services/craft_api.dart';
import '../services/token_store.dart';

class AuthController extends ChangeNotifier {
  AuthController() {
    _bootstrap();
  }

  final TokenStore _store = TokenStore();
  CraftApi? _api;
  String? _token;
  Map<String, dynamic>? _user;
  bool _ready = false;
  String? _error;

  CraftApi get api {
    _api ??= CraftApi(token: _token);
    return _api!;
  }

  bool get ready => _ready;
  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  String? get error => _error;

  Future<void> _bootstrap() async {
    _token = await _store.readToken();
    _api = CraftApi(token: _token);
    if (_token != null && _token!.isNotEmpty) {
      try {
        final data = await _api!.me();
        _user = data['user'] as Map<String, dynamic>?;
      } catch (_) {
        _token = null;
        _user = null;
        await _store.saveToken(null);
        _api = CraftApi();
      }
    }
    _ready = true;
    notifyListeners();
  }

  Future<void> _applyTokenResponse(Map<String, dynamic> data) async {
    _token = data['token'] as String?;
    _user = data['user'] as Map<String, dynamic>?;
    api.setToken(_token);
    await _store.saveToken(_token);
    notifyListeners();
  }

  /// Login now completes immediately after password verification.
  Future<LoginFlowResult> loginWithPassword(String email, String password) async {
    _error = null;
    notifyListeners();
    try {
      final data = await api.login(email: email, password: password);
      await _applyTokenResponse(data);
      return LoginFlowResult.success();
    } on DioException catch (e) {
      final body = e.response?.data;
      if (e.response?.statusCode == 403 && body is Map && body['code'] == 'EMAIL_NOT_VERIFIED') {
        final em = body['email'] as String? ?? email;
        return LoginFlowResult.finishRegistrationOtp(em);
      }
      return LoginFlowResult.failure(_dioMsg(e));
    }
  }

  Future<String?> verifyLoginOtp({required String preAuthToken, required String code}) async {
    try {
      final data = await api.verifyLogin(preAuthToken: preAuthToken, code: code.trim());
      await _applyTokenResponse(data);
      return null;
    } on DioException catch (e) {
      return _dioMsg(e);
    }
  }

  Future<String?> resendLoginOtp(String preAuthToken) async {
    try {
      await api.resendLoginOtp(preAuthToken: preAuthToken);
      return null;
    } on DioException catch (e) {
      return _dioMsg(e);
    }
  }

  /// Step 1: create unverified account; OTP email sent — use [verifyRegisterOtp].
  Future<RegisterFlowResult> registerAccount({
    required String email,
    required String password,
    required String name,
    required String username,
    String bio = '',
    List<String> genres = const [],
  }) async {
    _error = null;
    notifyListeners();
    try {
      final data = await api.register(
        email: email,
        password: password,
        name: name,
        username: username,
        bio: bio,
        genres: genres,
      );
      if (data['needOtp'] == true) {
        final em = data['email'] as String? ?? email;
        return RegisterFlowResult(verifyEmail: em);
      }
      return RegisterFlowResult(error: 'Unexpected server response');
    } on DioException catch (e) {
      return RegisterFlowResult(error: _dioMsg(e));
    }
  }

  Future<String?> verifyRegisterOtp({required String email, required String code}) async {
    try {
      final data = await api.verifyRegister(email: email, code: code.trim());
      await _applyTokenResponse(data);
      return null;
    } on DioException catch (e) {
      return _dioMsg(e);
    }
  }

  Future<String?> resendRegisterOtp(String email) async {
    try {
      await api.resendRegisterOtp(email: email);
      return null;
    } on DioException catch (e) {
      return _dioMsg(e);
    }
  }

  Future<void> refreshMe() async {
    final data = await api.me();
    _user = data['user'] as Map<String, dynamic>?;
    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    api.setToken(null);
    await _store.saveToken(null);
    notifyListeners();
  }

  static String _dioMsg(Object e) {
    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Server took too long to respond. Is the API running at ${ApiConfig.baseUrl}? '
              'On a phone, use your PC IP: flutter run --dart-define=API_BASE=http://YOUR_IP:3000';
        case DioExceptionType.connectionError:
          return 'Cannot connect to ${ApiConfig.baseUrl}. Start the backend (npm start), use the correct IP on a real device, and check Wi‑Fi / firewall.';
        default:
          break;
      }
      if (e.response?.data is Map) {
        final m = e.response!.data as Map;
        return m['error']?.toString() ?? e.message ?? 'Request failed';
      }
    }
    return e.toString();
  }
}
