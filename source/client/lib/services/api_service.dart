import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:housing_inspection_client/models/appeal.dart';
import 'package:housing_inspection_client/models/appeal_category.dart';
import 'package:housing_inspection_client/models/appeal_status.dart';
import 'package:housing_inspection_client/models/user.dart';
import 'package:housing_inspection_client/models/message.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../main.dart';
import 'package:housing_inspection_client/models/api_exception.dart'; //  Импортируем

class ApiService {
  final String baseUrl = 'http://5.35.125.180:8000';

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return token;
  }

  Future<String> _copyFileToAppDirectory(String filePath) async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName = p.basename(filePath);
    final newPath = p.join(directory.path, fileName);

    final file = File(filePath);
    await file.copy(newPath);
    return newPath;
  }

  Future<void> registerDeviceToken(String fcmToken, String? deviceType) async {
    final token = await _getToken();
    if (token == null || JwtDecoder.isExpired(token)) {
      print("Cannot register device token: User not logged in or token expired.");
      return;
    }

    final Map<String, String> headers = {};
    headers['Authorization'] = 'Bearer $token';
    headers['Content-Type'] = 'application/json';

    final body = jsonEncode({
      'fcm_token': fcmToken,
      if (deviceType != null) 'device_type': deviceType,
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/users/me/devices'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('Device token registered successfully.');
      } else {
        print('Failed to register device token: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('Error registering device token: $e');
    }
  }

  // --- Appeals ---

  Future<List<Appeal>> getAppeals({
    String sortBy = 'created_at',
    String sortOrder = 'desc',
    int? statusId,
    int? categoryId,
  }) async {
    final token = await _getToken();

    if (token == null || JwtDecoder.isExpired(token)) {
      MyApp.navigatorKey.currentState
          ?.pushNamedAndRemoveUntil('/auth', (route) => false);
      throw ApiException("Authentication required");
    }

    final Map<String, String> headers = {};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    final queryParameters = <String, String>{
      'sort_by': sortBy,
      'sort_order': sortOrder,
      if (statusId != null) 'status_id': statusId.toString(),
      if (categoryId != null) 'category_id': categoryId.toString(),
    };

    final Uri uri = Uri.parse('$baseUrl/appeals/').replace(
      queryParameters: queryParameters,
    );

    final response = await http.get(
      uri,
      headers: headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => Appeal.fromJson(json)).toList();
    } else {
      throw ApiException(
          'Failed to load appeals: ${response.statusCode}');
    }
  }

  Future<bool> checkToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null || JwtDecoder.isExpired(token)) {
      return false;
    }
    return true;
  }

  Future<Appeal> getAppeal(int id) async {
    final token = await _getToken();

    if (token == null || JwtDecoder.isExpired(token)) {
      MyApp.navigatorKey.currentState
          ?.pushNamedAndRemoveUntil('/auth', (route) => false);
      throw ApiException("Authentication required");
    }

    final Map<String, String> headers = {};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    final response = await http.get(
      Uri.parse('$baseUrl/appeals/$id'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return Appeal.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      throw ApiException(
          'Failed to load appeal', response.statusCode);
    }
  }

  Future<Appeal> createAppeal(Appeal appeal, List<String> filePaths) async {
    final token = await _getToken();
    if (token == null || JwtDecoder.isExpired(token)) {
      MyApp.navigatorKey.currentState
          ?.pushNamedAndRemoveUntil('/auth', (route) => false);
      throw ApiException("Authentication required");
    }

    final Map<String, String> headers = {};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    final request =
    http.MultipartRequest('POST', Uri.parse('$baseUrl/appeals/'));

    request.fields['address'] = appeal.address;
    request.fields['category_id'] = appeal.categoryId.toString();
    if (appeal.description != null) {
      request.fields['description'] = appeal.description!;
    }

    List<String> newFilePaths = [];
    for (var filePath in filePaths) {
      final newPath = await _copyFileToAppDirectory(filePath);
      newFilePaths.add(newPath);
    }

    for (var filePath in newFilePaths) {
      request.files.add(await http.MultipartFile.fromPath('files', filePath));
    }

    request.headers.addAll(headers);
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return Appeal.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      final errorMessage = errorData.containsKey('detail')
          ? errorData['detail']
          : 'Failed to create appeal';
      throw ApiException(errorMessage, response.statusCode);
    }
  }

  Future<Appeal> updateAppeal(Appeal appeal) async {
    final token = await _getToken();

    if (token == null || JwtDecoder.isExpired(token)) {
      MyApp.navigatorKey.currentState?.pushNamedAndRemoveUntil('/auth', (route) => false);
      throw ApiException("Authentication required");
    }

    final Map<String, String> headers = {};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    headers['Content-Type'] = 'application/json';

    final body = jsonEncode({
      'address': appeal.address,
      'category_id': appeal.categoryId,
      'description': appeal.description,
      'status_id': appeal.statusId,
    });

    final response = await http.put(
      Uri.parse('$baseUrl/appeals/${appeal.id}'),
      headers: headers,
      body: body,
    );

    if (response.statusCode == 200) {
      return Appeal.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      print("Update Appeal Error Body: ${response.body}");
      try {
        final errorData = jsonDecode(utf8.decode(response.bodyBytes));
        final errorMessage = errorData.containsKey('detail') ? errorData['detail'] : 'Failed to update appeal';
        throw ApiException(errorMessage, response.statusCode);
      } catch (e) {
        throw ApiException('Failed to update appeal: ${response.statusCode}', response.statusCode);
      }
    }
  }

  // Future<void> deleteAppeal(int id) async {
  //   final token = await _getToken();
  //   if (token == null || JwtDecoder.isExpired(token)) {
  //     MyApp.navigatorKey.currentState
  //         ?.pushNamedAndRemoveUntil('/auth', (route) => false);
  //     throw ApiException("Authentication required");
  //   }
  //   final Map<String, String> headers = {};
  //   if (token != null) {
  //     headers.addAll({'Authorization': 'Bearer $token'});
  //   }
  //   final response = await http.delete(
  //     Uri.parse('$baseUrl/appeals/$id'),
  //     headers: headers,
  //   );
  //
  //   if (response.statusCode != 200) {
  //     throw ApiException('Failed to delete appeal', response.statusCode);
  //   }
  // }

  // --- Appeal Categories ---

  Future<List<AppealCategory>> getAppealCategories() async {
    final response = await http.get(Uri.parse('$baseUrl/appeal_categories/'));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => AppealCategory.fromJson(json)).toList();
    } else {
      throw ApiException('Failed to load categories', response.statusCode);
    }
  }

  // --- Appeal Statuses ---
  Future<List<AppealStatus>> getAppealStatuses() async {
    final response = await http.get(Uri.parse('$baseUrl/appeal_statuses/'));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => AppealStatus.fromJson(json)).toList();
    } else {
      throw ApiException('Failed to load statuses', response.statusCode);
    }
  }

  Future<AppealStatus> createStatus(String name) async {
    final token = await _getToken();
    final Map<String, String> headers = {};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    headers['Content-Type'] = 'application/json';
    final response = await http.post(
      Uri.parse('$baseUrl/appeal_statuses/'),
      headers: headers,
      body: jsonEncode({'name': name}),
    );

    if (response.statusCode == 200) {
      return AppealStatus.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      final errorMessage = errorData.containsKey('detail')
          ? errorData['detail']
          : 'Failed to create status';
      throw ApiException(errorMessage, response.statusCode);
    }
  }

  Future<AppealStatus> updateStatus(AppealStatus updatedStatus) async {
    final token = await _getToken();
    final Map<String, String> headers = {};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    headers['Content-Type'] = 'application/json';
    final response = await http.put(
      Uri.parse('$baseUrl/appeal_statuses/${updatedStatus.id}'),
      headers: headers,
      body: jsonEncode({'name': updatedStatus.name}),
    );

    if (response.statusCode == 200) {
      return AppealStatus.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      final errorMessage = errorData.containsKey('detail')
          ? errorData['detail']
          : 'Failed to update status';
      throw ApiException(errorMessage, response.statusCode);
    }
  }

  Future<void> deleteStatus(int statusId) async {
    final token = await _getToken();
    final Map<String, String> headers = {};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    final response = await http.delete(
      Uri.parse('$baseUrl/appeal_statuses/$statusId'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      final errorMessage = errorData.containsKey('detail')
          ? errorData['detail']
          : 'Failed to delete status';
      throw ApiException(errorMessage, response.statusCode);
    }
  }

  Future<AppealCategory> createCategory(String name) async {
    final token = await _getToken();
    final Map<String, String> headers = {};
    if (token != null) {
      headers.addAll(
          {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'});
    }
    final response = await http.post(
      Uri.parse('$baseUrl/appeal_categories/'),
      headers: headers,
      body: jsonEncode({'name': name}),
    );

    if (response.statusCode == 200) {
      return AppealCategory.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      final errorMessage = errorData.containsKey('detail')
          ? errorData['detail']
          : 'Failed to create category';
      throw ApiException(errorMessage, response.statusCode);
    }
  }

  Future<AppealCategory> updateCategory(AppealCategory updatedCategory) async {
    final token = await _getToken();
    final Map<String, String> headers = {};
    if (token != null) {
      headers.addAll(
          {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'});
    }
    final response = await http.put(
      Uri.parse('$baseUrl/appeal_categories/${updatedCategory.id}'),
      headers: headers,
      body: jsonEncode({'name': updatedCategory.name}),
    );
    if (response.statusCode == 200) {
      return AppealCategory.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      final errorMessage = errorData.containsKey('detail')
          ? errorData['detail']
          : 'Failed to update category';
      throw ApiException(errorMessage, response.statusCode);
    }
  }

  Future<void> deleteCategory(int categoryId) async {
    final token = await _getToken();
    final Map<String, String> headers = {};
    if (token != null) {
      headers.addAll({'Authorization': 'Bearer $token'});
    }
    final response = await http.delete(
      Uri.parse('$baseUrl/appeal_categories/$categoryId'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      final errorMessage = errorData.containsKey('detail')
          ? errorData['detail']
          : 'Failed to delete category';
      throw ApiException(errorMessage, response.statusCode);
    }
  }

// --- Users ---
  Future<User> getUser(int id) async {
    final token = await _getToken();

    if (token == null || JwtDecoder.isExpired(token)) {
      MyApp.navigatorKey.currentState
          ?.pushNamedAndRemoveUntil('/auth', (route) => false);
      throw ApiException("Authentication required");
    }

    final Map<String, String> headers = {};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    final response = await http.get(
      Uri.parse('$baseUrl/users/$id'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      throw ApiException('Failed to load user', response.statusCode);
    }
  }

  Future<List<User>> getUsersActive(
      {String sortBy = 'username', String sortOrder = 'asc'}) async {
    return _getUsersByActivity(
        sortBy: sortBy, sortOrder: sortOrder, active: true);
  }

  Future<List<User>> getUsersInactive(
      {String sortBy = 'username', String sortOrder = 'asc'}) async {
    return _getUsersByActivity(
        sortBy: sortBy, sortOrder: sortOrder, active: false);
  }

  Future<List<User>> _getUsersByActivity(
      {String sortBy = 'username',
        String sortOrder = 'asc',
        required bool active}) async {
    final token = await _getToken();

    if (token == null || JwtDecoder.isExpired(token)) {
      MyApp.navigatorKey.currentState
          ?.pushNamedAndRemoveUntil('/auth', (route) => false);
      throw ApiException("Authentication required");
    }

    final Map<String, String> headers = {};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    final queryParameters = <String, String>{
      'sort_by': sortBy,
      'sort_order': sortOrder,
      'is_active': active.toString(),
    };
    final response = await http.get(
      Uri.parse('$baseUrl/users/').replace(queryParameters: queryParameters),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => User.fromJson(json)).toList();
    } else {
      throw ApiException('Failed to load users', response.statusCode);
    }
  }

  Future<List<User>> getUsers(
      {String sortBy = 'username', String sortOrder = 'asc'}) async {
    final token = await _getToken();

    if (token == null || JwtDecoder.isExpired(token)) {
      MyApp.navigatorKey.currentState
          ?.pushNamedAndRemoveUntil('/auth', (route) => false);
      throw ApiException("Authentication required");
    }

    final Map<String, String> headers = {};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    final queryParameters = <String, String>{
      'sort_by': sortBy,
      'sort_order': sortOrder,
    };

    final response = await http.get(
      Uri.parse('$baseUrl/users/').replace(queryParameters: queryParameters),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => User.fromJson(json)).toList();
    } else {
      throw ApiException('Failed to load users', response.statusCode);
    }
  }

  Future<dynamic> register(String username, String email, String password,
      String passwordConfirm, String? fullName, String role) async {
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
        });
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data;
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      if (errorData.containsKey('detail')) {
        if (errorData['detail'] is String) {
          throw ApiException(errorData['detail'], response.statusCode);
        } else if (errorData['detail'] is List) {
          final errorMessages = (errorData['detail'] as List)
              .map((e) => e['msg'] as String)
              .toList();
          throw ApiException(errorMessages.join('\n'), response.statusCode);
        }
      }
      throw ApiException('Registration failed', response.statusCode);
    }
  }

  Future<User> createUser(String username, String email, String password,
      String? fullName, String role) async {
    final token = await _getToken();

    if (token == null || JwtDecoder.isExpired(token)) {
      MyApp.navigatorKey.currentState
          ?.pushNamedAndRemoveUntil('/auth', (route) => false);
      throw ApiException("Authentication required");
    }

    final Map<String, String> headers = {};
    if (token != null) {
      headers.addAll({'Authorization': 'Bearer $token'});
    }
    headers.addAll({'Content-Type': 'application/json'});
    final response = await http.post(
        Uri.parse('$baseUrl/users/'),
        headers: headers,
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
          'password_confirm': password,
          'full_name': fullName,
          'role': role,
        }));
    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      final errorMessage = errorData.containsKey('detail')
          ? errorData['detail']
          : 'Failed to create user';
      throw ApiException(errorMessage, response.statusCode);
    }
  }

  Future<User> updateUser(User updatedUser) async {
    final token = await _getToken();

    if (token == null || JwtDecoder.isExpired(token)) {
      MyApp.navigatorKey.currentState
          ?.pushNamedAndRemoveUntil('/auth', (route) => false);
      throw ApiException("Authentication required");
    }
    final Map<String, String> headers = {};
    if (token != null) {
      headers.addAll({'Authorization': 'Bearer $token'});
    }
    headers.addAll({'Content-Type': 'application/json'});

    print("updateUser called with: ${updatedUser.toJson()}");

    final response = await http.put(
        Uri.parse('$baseUrl/users/${updatedUser.id}'),
        headers: headers,
        body: jsonEncode({
          'username': updatedUser.username,
          'email': updatedUser.email,
          'full_name': updatedUser.fullName,
          'role': updatedUser.role,
          'is_active': updatedUser.isActive,
        }));

    print(
        "updateUser response: statusCode=${response.statusCode}, body=${response.body}");

    if (response.statusCode == 200) {
      return User.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      final errorMessage = errorData.containsKey('detail')
          ? errorData['detail']
          : 'Failed to update user';
      throw ApiException(errorMessage, response.statusCode);
    }
  }

  Future<void> deleteUser(int userId) async {
    final token = await _getToken();

    if (token == null || JwtDecoder.isExpired(token)) {
      MyApp.navigatorKey.currentState
          ?.pushNamedAndRemoveUntil('/auth', (route) => false);
      throw ApiException("Authentication required");
    }
    final Map<String, String> headers = {};
    if (token != null) {
      headers.addAll({'Authorization': 'Bearer $token'});
    }
    final response = await http.delete(
      Uri.parse('$baseUrl/users/$userId'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      final errorMessage = errorData.containsKey('detail')
          ? errorData['detail']
          : 'Failed to create user';
      throw ApiException(errorMessage, response.statusCode);
    }
  }

  Future<List<Message>> getMessages(int appealId, {int skip = 0, int limit = 100, int? lastMessageId}) async {
    final token = await _getToken();
    if (token == null || JwtDecoder.isExpired(token)) {
      MyApp.navigatorKey.currentState?.pushNamedAndRemoveUntil('/auth', (route) => false);
      throw ApiException("Authentication required");
    }
    final Map<String,String> headers = {};
    if(token != null){
      headers.addAll({'Authorization': 'Bearer $token'});
    }

    final queryParameters = <String, String>{
      'skip': skip.toString(),
      'limit': limit.toString(),
      if (lastMessageId != null) 'last_message_id': lastMessageId.toString(),
    };
    final response = await http.get(
        Uri.parse('$baseUrl/appeals/$appealId/messages').replace(queryParameters: queryParameters),
        headers: headers
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((json) => Message.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load messages: ${response.statusCode}');
    }
  }

  Future<Message> createMessage(int appealId, String content, List<String> filePaths) async {
    final token = await _getToken();
    if (token == null || JwtDecoder.isExpired(token)) {
      MyApp.navigatorKey.currentState?.pushNamedAndRemoveUntil('/auth', (route) => false);
      throw ApiException("Authentication required");
    }
    final Map<String,String> headers = {};
    if(token != null){
      headers.addAll({'Authorization': 'Bearer $token'});
    }

    headers.addAll({'Content-Type': 'application/json'});
    final response = await http.post(
      Uri.parse('$baseUrl/appeals/$appealId/messages'),
      headers: headers,
      body: jsonEncode({'content': content}),
    );

    if (response.statusCode == 200) {
      return Message.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } else {
      print(response.body);
      final errorData = jsonDecode(utf8.decode(response.bodyBytes));
      final errorMessage = errorData.containsKey('detail') ? errorData['detail'] : 'Failed to create message';
      throw ApiException(errorMessage, response.statusCode);
    }
  }

  Future<List<String>> getKnowledgeBaseCategoryFiles(String category) async {
    final response =
    await http.get(Uri.parse('$baseUrl/knowledge_base/$category'));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((e) => e as String).toList();
    } else {
      throw Exception(
          'Failed to load knowledge base files: ${response.statusCode}');
    }
  }
}