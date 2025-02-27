import 'package:flutter/material.dart';
import 'package:housing_inspection_client/services/auth_service.dart';
import 'package:housing_inspection_client/models/user.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  String? _token;
  bool _isLoggedIn = false;

  String? get token => _token;
  bool get isLoggedIn => _isLoggedIn;

  Future<void> loadToken() async {
    _token = await _authService.getToken();
    _isLoggedIn = _token != null;
    notifyListeners();
  }

  Future<dynamic> register(String username, String email, String password,  String passwordConfirm, String? fullName) async { //Добавили
    const role = 'citizen';
    final result = await _authService.register(username, email, password, passwordConfirm, fullName, role); //изменили
    if(result is String){ //Если вернулась строка с ошибкой
      return result; //Возвращаем
    }
    else if(result != null){ //Если не null - рег успешна
      final success = await login(username, password);
      return success;
    }
    else {
      return false; //Регистрация не удалась
    }
  }

  Future<bool> login(String username, String password) async {
    final token = await _authService.login(username, password);
    if (token != null) {
      _token = token;
      _isLoggedIn = true;
      notifyListeners();
      return true;
    }
    return false; // Раньше не обрабатывалась ошибка
  }

  Future<void> logout() async {
    await _authService.logout();
    _token = null;
    _isLoggedIn = false;
    notifyListeners();
  }
}