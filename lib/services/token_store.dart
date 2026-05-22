import 'package:shared_preferences/shared_preferences.dart';

class TokenStore {
  static const _kToken = 'jwt_token';

  Future<String?> readToken() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kToken);
  }

  Future<void> saveToken(String? token) async {
    final p = await SharedPreferences.getInstance();
    if (token == null || token.isEmpty) {
      await p.remove(_kToken);
    } else {
      await p.setString(_kToken, token);
    }
  }
}
