import 'package:flutter/material.dart';
import 'package:housing_inspection_client/models/appeal.dart';
import 'package:housing_inspection_client/services/api_service.dart';
import 'package:housing_inspection_client/models/api_exception.dart';

class AppealProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<Appeal> _appeals = [];
  bool _isLoading = false;

  List<Appeal> get appeals => _appeals;
  bool get isLoading => _isLoading;

  String _sortBy = 'created_at';
  String _sortOrder = 'desc';

  String get sortBy => _sortBy;
  String get sortOrder => _sortOrder;

  int? _statusId;
  int? _categoryId;

  int? get statusId => _statusId;
  int? get categoryId => _categoryId;

  void setStatusFilter(int? statusId) {
    _statusId = statusId;
    notifyListeners();
  }

  void setCategoryFilter(int? categoryId) {
    _categoryId = categoryId;
    notifyListeners();
  }

  void clearFilters() {
    _statusId = null;
    _categoryId = null;
    notifyListeners();
  }

  void setSortBy(String field) {
    _sortBy = field;
    notifyListeners();
  }

  void setSortOrder(String order) {
    _sortOrder = order;
    notifyListeners();
  }

  Future<void> fetchAppeals() async {
    _isLoading = true;
    notifyListeners();
    try {
      _appeals = await _apiService.getAppeals(
        sortBy: _sortBy,
        sortOrder: _sortOrder,
        statusId: _statusId,
        categoryId: _categoryId,

      );
    } on ApiException catch (e) {
      print(e);
      rethrow;
    } catch (e) {
      print('Error fetching appeals: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  Future<void> addAppeal(Appeal newAppeal, List<String> filePaths) async {
    try {
      final createdAppeal = await _apiService.createAppeal(newAppeal, filePaths);
      _appeals.add(createdAppeal);
      notifyListeners();
    } on ApiException catch (e){
      rethrow;
    }
    catch (e){
      print('Error add user: $e');
      rethrow;
    }
  }
  Future<void> refreshAppeal(int appealId) async {
    try {
      final updatedAppeal = await _apiService.getAppeal(appealId);
      final index = _appeals.indexWhere((appeal) => appeal.id == appealId);
      if (index != -1) {
        _appeals[index] = updatedAppeal;
        notifyListeners();
      }
    } on ApiException catch (e) {
      rethrow;
    }
    catch (e){
      print('Error refresh appeal: $e');
      rethrow;
    }
  }
  // Future<void> deleteAppeal(int id) async {
  //   try {
  //     await _apiService.deleteAppeal(id);
  //     _appeals.removeWhere((appeal) => appeal.id == id);
  //     notifyListeners();
  //   } on ApiException catch (e) {
  //     rethrow;
  //   }
  //   catch (e){
  //     print('Error delete appeal: $e');
  //     rethrow;
  //   }
  // }

  Future<void> updateAppealData(Appeal updatedAppeal) async { // УБРАЛИ List<String> filePaths
    try{
      // Вызываем apiService.updateAppeal только с одним аргументом
      final newAppeal = await _apiService.updateAppeal(updatedAppeal);
      final index = _appeals.indexWhere((appeal) => appeal.id == newAppeal.id);

      if (index != -1) {
        _appeals[index] = newAppeal;
        notifyListeners();
      }
    } on ApiException catch (e){
      rethrow;
    }
    catch (e){
      print('Error update appeal: $e');
      rethrow;
    }
  }
}