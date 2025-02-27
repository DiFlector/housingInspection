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
    } else {
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

  Future<dynamic> register(String username, String email, String password, String passwordConfirm, String? fullName, String role) async {  // Добавили passwordConfirm
    final response = await http.post(
      Uri.parse('$baseUrl/users/'),
      body: jsonEncode({
        'username': username,
        'email': email,
        'password': password,
        'password_confirm': passwordConfirm, // Добавили
        'full_name': fullName,
        'role': role,
      }),
      headers: {
        'Content-Type': 'application/json',
      },
    );

    print("Response status code: ${response.statusCode}");  //  ДОБАВИТЬ
    print("Response headers: ${response.headers}");      //  ДОБАВИТЬ
    print("Response body: ${response.body}");

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data;

    } else {
      // Раньше было: return null;
      // Теперь возвращаем сообщение об ошибке:
      final errorData = jsonDecode(utf8.decode(response.bodyBytes)); // Декодируем JSON
      if (errorData.containsKey('detail')) { // Проверяем, есть ли ключ 'detail'
        if (errorData['detail'] is String) {
          return errorData['detail'];  // Если detail - строка, возвращаем её
        } else if (errorData['detail'] is List) { // Если detail - список (как в случае ошибок валидации Pydantic)
          // Формируем строку из списка ошибок
          final errorMessages = (errorData['detail'] as List).map((e) => e['msg'] as String).toList();
          return errorMessages.join('\n'); // Объединяем сообщения через перенос строки
        }
      }
      //Если нет ключа detail
      return 'Registration failed: ${response.statusCode}'; // Общая ошибка, если нет detail

    }
  }
}