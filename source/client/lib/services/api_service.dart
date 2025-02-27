import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:housing_inspection_client/models/appeal.dart';
import 'package:housing_inspection_client/models/appeal_category.dart';
import 'package:housing_inspection_client/models/appeal_status.dart';
import 'package:housing_inspection_client/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ApiService {
  final String baseUrl = 'http://5.35.125.180:8000';

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<String> _copyFileToAppDirectory(String filePath) async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName = p.basename(filePath);
    final newPath = p.join(directory.path, fileName);

    final file = File(filePath);
    await file.copy(newPath);
    return newPath;
  }

  // --- Appeals ---

  Future<List<Appeal>> getAppeals() async {
    final token = await _getToken();
    final Map<String,String> headers = {}; //Создаем переменную
    if(token != null){ //Если токен есть - добавляем
      headers.addAll({'Authorization': 'Bearer $token'});
    }
    final response = await http.get(
      Uri.parse('$baseUrl/appeals/'),
      headers: headers, //  Добавляем заголовок
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => Appeal.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load appeals: ${response.statusCode}');
    }
  }

  Future<Appeal> getAppeal(int id) async {
    final token = await _getToken();
    final Map<String,String> headers = {}; //Создаем переменную
    if(token != null){ //Если токен есть - добавляем
      headers.addAll({'Authorization': 'Bearer $token'});
    }
    final response = await http.get(Uri.parse('$baseUrl/appeals/$id'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return Appeal.fromJson(jsonDecode(utf8.decode(response.bodyBytes))); // ИСПРАВЛЕНО
    } else {
      throw Exception('Failed to load appeal: ${response.statusCode}');
    }
  }

  Future<Appeal> createAppeal(Appeal appeal, List<String> filePaths) async {
    final token = await _getToken();
    final Map<String,String> headers = {}; //Создаем переменную
    if(token != null){ //Если токен есть - добавляем
      headers.addAll({'Authorization': 'Bearer $token'});
    }
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/appeals/'));

    request.fields['address'] = appeal.address;
    request.fields['category_id'] = appeal.categoryId.toString();
    if (appeal.description != null) {
      request.fields['description'] = appeal.description!;
    }

    // Копируем файлы и используем НОВЫЕ пути:
    List<String> newFilePaths = [];
    for (var filePath in filePaths) {
      final newPath = await _copyFileToAppDirectory(filePath); // КОПИРУЕМ
      newFilePaths.add(newPath);
    }

    for (var filePath in newFilePaths) { // Используем новые пути
      request.files.add(await http.MultipartFile.fromPath('files', filePath));
    }

    request.headers.addAll(headers); //
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return Appeal.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      print(response.body);
      throw Exception(
          'Failed to create appeal: ${response.statusCode}, ${response.body}');
    }
  }

  Future<Appeal> updateAppeal(Appeal appeal, List<String> newFilePaths) async {
    final token = await _getToken();
    final Map<String,String> headers = {}; //Создаем переменную
    if(token != null){ //Если токен есть - добавляем
      headers.addAll({'Authorization': 'Bearer $token'});
    }
    final request = http.MultipartRequest(
        'PUT', Uri.parse('$baseUrl/appeals/${appeal.id}'));

    request.fields['address'] = appeal.address;
    request.fields['category_id'] = appeal.categoryId.toString();
    if (appeal.description != null) {
      request.fields['description'] = appeal.description!;
    }
    if (appeal.statusId != null) {
      request.fields['status_id'] = appeal.statusId.toString();
    }

    // Копируем файлы и используем НОВЫЕ пути:
    List<String> updatedFilePaths = [];
    for (var filePath in newFilePaths) {
      final newPath = await _copyFileToAppDirectory(filePath); // КОПИРУЕМ
      updatedFilePaths.add(newPath);
    }

    for (var filePath in updatedFilePaths) { // Используем новые пути
      request.files.add(await http.MultipartFile.fromPath('files', filePath));
    }
    request.headers.addAll(headers);
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return Appeal.fromJson(jsonDecode(utf8.decode(response.bodyBytes))); // ИСПРАВЛЕНО
    } else {
      throw Exception(
          'Failed to update appeal: ${response.statusCode}, ${response.body}');
    }
  }

  Future<void> deleteAppeal(int id) async {
    final token = await _getToken();
    final Map<String,String> headers = {}; //Создаем переменную
    if(token != null){ //Если токен есть - добавляем
      headers.addAll({'Authorization': 'Bearer $token'});
    }
    final response = await http.delete(Uri.parse('$baseUrl/appeals/$id'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete appeal: ${response.statusCode}');
    }
  }

  // --- Appeal Categories ---

  Future<List<AppealCategory>> getAppealCategories() async {
    final response = await http.get(Uri.parse('$baseUrl/appeal_categories/'));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => AppealCategory.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load categories: ${response.statusCode}');
    }
  }

  // --- Appeal Statuses ---
  Future<List<AppealStatus>> getAppealStatuses() async {
    final response = await http.get(Uri.parse('$baseUrl/appeal_statuses/'));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => AppealStatus.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load statuses: ${response.statusCode}');
    }
  }

  // --- Users ---
  Future<User> getUser(int id) async {
    final token = await _getToken();
    final Map<String,String> headers = {}; //Создаем переменную
    if(token != null){ //Если токен есть - добавляем
      headers.addAll({'Authorization': 'Bearer $token'});
    }
    final response = await http.get(Uri.parse('$baseUrl/users/$id'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(utf8.decode(response.bodyBytes))); // ИСПРАВЛЕНО
    } else {
      throw Exception('Failed to load user: ${response.statusCode}');
    }
  }

  Future<User?> register(String username, String email, String password, String? fullName, String role) async {
    final response = await http.post(
        Uri.parse('$baseUrl/users/'),
        body: {
          'username': username,
          'email': email,
          'password': password,
          'full_name': fullName,
          'role': role,
        },
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded', //Важно!
        }
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return User.fromJson(data);

    } else {
      print('Registration failed: ${response.statusCode}, ${response.body}');
      return null; // Возвращаем null в случае ошибки
    }
  }
}