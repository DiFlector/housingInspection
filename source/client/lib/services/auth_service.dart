import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AuthService {
  final String baseUrl = 'http://5.35.125.180:8000';

  Future<String?> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/token'),
      body: {
        'username': username,
        'password': password,
        'grant_type': 'password',
      },
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final token = data['access_token'];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      return token;
    } else if (response.statusCode == 400 && response.body.contains("Inactive user")) {
      return "Inactive user";
    }
    else {
      print('Login failed: ${response.statusCode}, ${response.body}');
      return null;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  Future<String?> register(String username, String email, String password, String passwordConfirm, String? fullName, String role) async{
    final response = await http.post(
        Uri.parse('$baseUrl/users/'),
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
          'password_confirm': passwordConfirm,
          'full_name': fullName,
          'role': role,
        }),
        headers: {
          'Content-Type': 'application/json',
        }
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return null;

    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      if (errorData.containsKey('detail')) {
        if (errorData['detail'] is String) {
          return errorData['detail'];
        } else if (errorData['detail'] is List) {
          final errorMessages = (errorData['detail'] as List).map((e) => e['msg'] as String).toList();
          return errorMessages.join('\n');
        }
      }
      return 'Registration failed: ${response.statusCode}';
    }
  }
}