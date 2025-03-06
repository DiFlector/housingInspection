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
      print('Ошибка при получении пользователей: $e');
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
        newUser.role,
      );
      _users.add(createdUser);
      notifyListeners();
      //  Добавляем обработку ApiException
    } on ApiException catch (e) {
      rethrow; //Перебрасываем ошибку, чтобы обработать в виджете
    }
    catch (e){
      print('Error add user: $e');
      rethrow; //  Перебрасываем ошибку, чтобы ее поймал виджет.
    }
  }

  Future<void> updateUser(User updatedUser) async {
    try{
      final newUser = await _apiService.updateUser(updatedUser);
      final index = _users.indexWhere((user) => user.id == newUser.id);
      if (index != -1) {
        _users[index] = newUser;
        notifyListeners();
      }
    } on ApiException catch (e){ //  Добавили обработку ошибок ApiException
      rethrow; //Перебрасываем ошибку, чтобы обработать в виджете
    }
    catch (e){
      print('Error update user: $e');
      rethrow; //  Перебрасываем ошибку, чтобы ее поймал виджет.
    }
  }

  Future<void> deleteUser(int userId) async {
    try {
      await _apiService.deleteUser(userId);
      _users.removeWhere((user) => user.id == userId);
      notifyListeners();
    } on ApiException catch (e) {
      if(e.message == 'Failed to delete user: 400, {"detail":"Cannot delete user: it\'s in use"}'){
        throw ApiException("Невозможно удалить пользователя с незакрытыми обращениями."); //  Конкретное сообщение
      }
      else{
        rethrow; //  Перебрасываем другие ошибки
      }
    } catch (e) {
      print('Error delete user: $e');
      rethrow; //  Перебрасываем другие ошибки
    }
  }
}