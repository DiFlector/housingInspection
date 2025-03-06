import 'package:flutter/material.dart';
import 'package:housing_inspection_client/models/appeal_category.dart';
import 'package:housing_inspection_client/services/api_service.dart';
import 'package:housing_inspection_client/models/api_exception.dart';

class CategoryProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<AppealCategory> _categories = [];
  bool _isLoading = false;

  List<AppealCategory> get categories => _categories;
  bool get isLoading => _isLoading;

  Future<void> fetchCategories() async {
    _isLoading = true;
    notifyListeners();
    try {
      _categories = await _apiService.getAppealCategories();
    } catch (e) {
      print('Error fetching categories: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String getCategoryName(int id) {
    final category = _categories.firstWhere(
          (cat) => cat.id == id,
      orElse: () => AppealCategory(id: 0, name: 'Неизвестно'),
    );
    return category.name;
  }

  Future<void> addCategory(AppealCategory category) async {
    try {
      final newCategory = await _apiService.createCategory(category.name);
      _categories.add(newCategory);
      notifyListeners();
    } on ApiException catch (e) {
      rethrow;
    } catch (e) {
      print('Error adding category: $e');
      rethrow;
    }
  }

  Future<void> updateCategory(AppealCategory updatedCategory) async {
    try {
      final newCategory = await _apiService.updateCategory(updatedCategory);
      final index = _categories.indexWhere((category) => category.id == newCategory.id);
      if (index != -1) {
        _categories[index] = newCategory;
        notifyListeners();
      }
    } on ApiException catch (e){
      rethrow;
    }
    catch (e){
      print('Error update category: $e');
      rethrow;
    }
  }

  Future<void> deleteCategory(int categoryId) async {
    try{
      await _apiService.deleteCategory(categoryId);
      _categories.removeWhere((category) => category.id == categoryId);
      notifyListeners();
    } on ApiException catch (e){
      if(e.message == 'Failed to delete category: 400, {"detail":"Cannot delete category: it\'s in use"}'){
        throw ApiException("Невозможно удалить категорию: она используется в обращениях.");
      }
      else {
        rethrow;
      }
    }
    catch (e){
      print('Error delete category: $e');
      rethrow;
    }
  }

}