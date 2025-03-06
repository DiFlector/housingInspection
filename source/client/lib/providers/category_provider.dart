import 'package:flutter/material.dart';
import 'package:housing_inspection_client/models/appeal_category.dart';
import 'package:housing_inspection_client/services/api_service.dart';

class CategoryProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<AppealCategory> _categories = [];

  List<AppealCategory> get categories => _categories;

  Future<void> fetchCategories() async {
    print("Получение категорий..."); // Добавляем вывод
    try { // Добавляем try-catch
      _categories = await _apiService.getAppealCategories();
      print("Категорий получено:: ${_categories.length}"); // Добавляем вывод
      notifyListeners();
    } catch (e) {
      print("Ошибка при получении категорий: $e"); // Добавляем вывод ошибки
    }
  }
  String getCategoryName(int id) {
    print("id = $id");
    final category = _categories.firstWhere(
          (cat) => cat.id == id,
      orElse: () => AppealCategory(id: 0, name: 'Неизвестно'), // Обработка случая, когда категория не найдена
    );
    print(category);
    return category.name;
  }
}