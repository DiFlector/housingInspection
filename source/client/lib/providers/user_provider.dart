import 'package:flutter/material.dart';
import 'package:housing_inspection_client/models/user.dart';
import 'package:housing_inspection_client/services/api_service.dart';
import 'package:housing_inspection_client/models/api_exception.dart';

class UserProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<User> _users = [];
  bool _isLoading = false;

  String _sortBy = 'username';
  String _sortOrder = 'asc';

  String get sortBy => _sortBy;
  String get sortOrder => _sortOrder;

  void setSortBy(String field) {
    _sortBy = field;
    notifyListeners();
  }

  void setSortOrder(String order) {
    _sortOrder = order;
    notifyListeners();
  }

  bool? _activeFilter = null;

  bool? get activeFilter => _activeFilter;

  void setActiveFilter(bool? value) {
    _activeFilter = value;
    fetchUsers();
    notifyListeners();
  }

  List<User> get users => _users;
  bool get isLoading => _isLoading;

  Future<void> fetchUsers() async {
    _isLoading = true;
    notifyListeners();
    try {
      if (await _apiService.checkToken()) {
        if (_activeFilter == true) {
          _users = await _apiService.getUsersActive(sortBy: _sortBy, sortOrder: _sortOrder);
        } else if (_activeFilter == false) {
          _users = await _apiService.getUsersInactive(sortBy: _sortBy, sortOrder: _sortOrder);
        } else {
          final activeUsers = await _apiService.getUsersActive(sortBy: _sortBy, sortOrder: _sortOrder);
          final inactiveUsers = await _apiService.getUsersInactive(sortBy: _sortBy, sortOrder: _sortOrder);
          _users = [...activeUsers, ...inactiveUsers];

          if (_sortBy == 'username') {
            _users.sort((a, b) => _sortOrder == 'asc'
                ? a.username.compareTo(b.username)
                : b.username.compareTo(a.username));
          } else if (_sortBy == 'email') {
            _users.sort((a, b) => _sortOrder == 'asc'
                ? a.email.compareTo(b.email)
                : b.email.compareTo(a.email));
          } else if (_sortBy == 'role') {
            _users.sort((a, b) => _sortOrder == 'asc'
                ? a.role.compareTo(b.role)
                : b.role.compareTo(a.role));
          } else if (_sortBy == 'created_at') {
            _users.sort((a, b) => _sortOrder == 'asc'
                ? a.createdAt.compareTo(b.createdAt)
                : b.createdAt.compareTo(a.createdAt));
          }
        }
      } else {
        _users = [];
      }
    } on ApiException catch (e) {
      print(e);
      rethrow;
    } catch (e) {
      print('Error fetching users: $e');
      rethrow;
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
      rethrow;
    }
    catch (e){
      print('Error add user: $e');
      rethrow;
    }
  }

  Future<User?> updateUser(User updatedUser) async {
    try{
      final newUser = await _apiService.updateUser(updatedUser);
      final index = _users.indexWhere((user) => user.id == newUser.id);
      if (index != -1) {
        _users[index] = newUser;
        notifyListeners();
      }
      return newUser;
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
      _users.removeWhere((user) => user.id == userId);
      notifyListeners();
    } on ApiException catch (e){
      rethrow;
    }
    catch (e){
      print('Error delete user: $e');
      rethrow;
    }
  }
}