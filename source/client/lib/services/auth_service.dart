import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AuthService {
  final String baseUrl = 'http://5.35.125.180:8000'; //  УБЕДИСЬ, ЧТО АДРЕС ПРАВИЛЬНЫЙ!

  Future<String?> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/token'), // Используем /token
      body: {
        'username': username,
        'password': password,
        'grant_type': 'password', //  Явно указываем grant_type
      },
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)); //  ПРАВИЛЬНОЕ ДЕКОДИРОВАНИЕ
      final token = data['access_token'];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      return token; // Возвращаем токен
    } else {
      print('Login failed: ${response.statusCode}, ${response.body}'); //Для дебага
      return null; // Возвращаем null в случае ошибки
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

  Future<dynamic> register(String username, String email, String password, String passwordConfirm, String? fullName, String role) async {
    final response = await http.post(
        Uri.parse('$baseUrl/users/'),
        body: jsonEncode({ //  ИСПРАВЛЕНО: кодируем в JSON
          'username': username,
          'email': email,
          'password': password,
          'password_confirm': passwordConfirm, //  ДОБАВИТЬ
          'full_name': fullName,
          'role': role,
        }),
        headers: {
          'Content-Type': 'application/json',
        }
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data;

    } else {
      print('Registration failed: ${response.statusCode}, ${response.body}');
      return response.body; // Возвращаем  ошибку
    }
  }
}