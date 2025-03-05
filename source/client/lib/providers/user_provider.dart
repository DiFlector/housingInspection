import 'package:flutter/material.dart';
import 'package:housing_inspection_client/models/user.dart';
import 'package:housing_inspection_client/services/api_service.dart';
import 'package:housing_inspection_client/models/api_exception.dart';

class UserProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<User> _users = [];
  bool _isLoading = false;

  List<User> get users => _users;
  bool get isLoading => _isLoading;

  Future<void> fetchUsers() async {
    _isLoading = true;
    notifyListeners();
    try {
      _users = await _apiService.getUsers();
    } on ApiException catch (e) {
      print(e); //  TODO:  Обработать ошибку (показать сообщение)
    } catch (e) {
      print('Error fetching users: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addUser(User newUser, String password) async {
    try {
      final createdUser = await _apiService.createUser(
          newUser.username,
          newUser.email,
          password,
          newUser.fullName,
          newUser.role
      );
      _users.add(createdUser);
      notifyListeners();
    } on ApiException catch (e){
      print(e); //  TODO:  Обработать ошибку (показать сообщение)
    }
    catch (e){
      print('Error add user: $e');
    }
  }

  Future<User?> updateUser(User updatedUser) async { //Изменили
    print("UserProvider.updateUser called with: ${updatedUser.toJson()}");
    try{
      final newUser = await _apiService.updateUser(updatedUser);
      final index = _users.indexWhere((user) => user.id == newUser.id);
      if (index != -1) {
        _users[index] = newUser;
        notifyListeners();
      }
      return newUser; //Возвращаем
    } on ApiException catch (e){
      print(e);
      return null;
    }
    catch (e){
      print('Error update user: $e');
      return null;
    }
  }

  Future<void> deleteUser(int userId) async {
    try{
      await _apiService.deleteUser(userId);
      _users.removeWhere((user) => user.id == userId); //Удаляем из списка
      notifyListeners();
    } on ApiException catch (e){
      print(e);
    }
    catch (e){
      print('Error delete user: $e');
    }
  }
}