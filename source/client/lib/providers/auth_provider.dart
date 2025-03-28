import 'package:flutter/material.dart';
import 'package:housing_inspection_client/services/auth_service.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:housing_inspection_client/services/api_service.dart';
import 'dart:io' show Platform;

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();
  String? _token;
  bool _isLoggedIn = false;
  String? _role;
  int? _userId;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

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
      } else {
        _initFCM();
      }
    }
    notifyListeners();
  }

  Future<String?> register(String username, String email, String password, String passwordConfirm, String? fullName) async {
    const role = 'citizen';
    final result = await _authService.register(username, email, password, passwordConfirm, fullName, role);
    if (result == null) {
      final success = await login(username, password);
      if (success == true) {
        return null;
      } else {
        return "Ошибка входа после регистрации";
      }
    } else {
      return result;
    }
  }

  Future<bool> login(String username, String password) async {
    final token = await _authService.login(username, password);
    if (token != null && token != "Inactive user") {
      _token = token;
      _isLoggedIn = true;
      _extractRoleFromToken();
      _initFCM();
      notifyListeners();
      return true;
    } else if (token == "Inactive user") {
      print("Login failed: User is inactive");
      return false;
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
        print("Ошибка при декодировании токена: $e");
        _role = null;
        _userId = null;
      }
    }
  }

  void _initFCM() {
    _firebaseMessaging.requestPermission();

    _firebaseMessaging.getToken().then((fcmToken) {
      if (fcmToken != null) {
        print("FCM Token: $fcmToken");
        _sendTokenToServer(fcmToken);
      } else {
        print("Failed to get FCM token.");
      }
    });

    _firebaseMessaging.onTokenRefresh.listen((fcmToken) {
      print("FCM Token refreshed: $fcmToken");
      _sendTokenToServer(fcmToken);
    }).onError((err) {
      print("Error refreshing FCM token: $err");
    });
  }

  Future<void> _sendTokenToServer(String fcmToken) async {
    String? deviceType;
    if (Platform.isAndroid) {
      deviceType = 'android';
    } else if (Platform.isIOS) {
      deviceType = 'ios';
    }
    await _apiService.registerDeviceToken(fcmToken, deviceType);
  }

  bool isTokenExpired() {
    if (_token == null) {
      return true;
    }
    return JwtDecoder.isExpired(_token!);
  }
}