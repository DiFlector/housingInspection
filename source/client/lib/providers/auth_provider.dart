import 'package:flutter/material.dart';
import 'package:housing_inspection_client/services/auth_service.dart';
import 'package:housing_inspection_client/models/user.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  String? _token;
  bool _isLoggedIn = false;
  String? _role;
  int? _userId;

  String? get token => _token;
  bool get isLoggedIn => _isLoggedIn;
  String? get role => _role;
  int? get userId => _userId;

  Future<void> loadToken() async {
    _token = await _authService.getToken();
    _isLoggedIn = _token != null;
    if (_isLoggedIn) {
      _extractRoleFromToken();
      if (JwtDecoder.isExpired(_token!)) {
        await logout();
      }
    }
    notifyListeners();
  }

  Future<String?> register(String username, String email, String password,  String passwordConfirm, String? fullName) async {
    const role = 'citizen';
    final result = await _authService.register(username, email, password, passwordConfirm, fullName, role);
    if(result == null){ //Если ошибок нет
      final success = await login(username, password);
      if(success){
        return null;
      }
      else{
        return "Ошибка входа"; //Какая-то ошибка
      }
    }
    else {
      return result; //Возвращаем ошибку
    }
  }

  Future<bool> login(String username, String password) async {
    final token = await _authService.login(username, password);
    if (token != null) {
      _token = token;
      _isLoggedIn = true;
      _extractRoleFromToken();
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    await _authService.logout();
    _token = null;
    _isLoggedIn = false;
    _role = null;
    _userId = null;
    notifyListeners();
  }

  void _extractRoleFromToken() {
    if (_token != null) {
      try {
        Map<String, dynamic> decodedToken = JwtDecoder.decode(_token!);
        _role = decodedToken['role'];
        _userId = decodedToken['user_id'];
      } catch (e) {
        print("Error decoding token: $e");
        _role = null;
        _userId = null;
      }
    }
  }

  bool isTokenExpired() {
    if (_token == null) {
      return true;
    }
    return JwtDecoder.isExpired(_token!);
  }
}