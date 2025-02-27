import 'package:flutter/material.dart';
import 'package:housing_inspection_client/models/appeal.dart';
import 'package:housing_inspection_client/services/api_service.dart';

class AppealProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<Appeal> _appeals = [];
  bool _isLoading = false; //  Добавляем флаг isLoading

  List<Appeal> get appeals => _appeals;
  bool get isLoading => _isLoading; //  Геттер для isLoading

  Future<void> fetchAppeals() async {
    _isLoading = true; //  Устанавливаем isLoading в true перед загрузкой
    notifyListeners();    //  Уведомляем слушателей (чтобы показать индикатор загрузки)

    _appeals = await _apiService.getAppeals();

    _isLoading = false; //  Устанавливаем isLoading в false после загрузки
    notifyListeners();    //  Уведомляем слушателей (чтобы обновить UI)
  }
  Future<void> addAppeal(Appeal newAppeal, List<String> filePaths) async {
    final createdAppeal = await _apiService.createAppeal(newAppeal, filePaths);
    _appeals.add(createdAppeal);
    notifyListeners();
  }
  Future<void> refreshAppeal(int appealId) async {
    final updatedAppeal = await _apiService.getAppeal(appealId);
    final index = _appeals.indexWhere((appeal) => appeal.id == appealId);
    if (index != -1) {
      _appeals[index] = updatedAppeal;
      notifyListeners();
    }
  }
  Future<void> deleteAppeal(int id) async {
    await _apiService.deleteAppeal(id); //Удаляем с сервера
    _appeals.removeWhere((appeal) => appeal.id == id); //Удаляем из списка.
    notifyListeners(); //Сообщаем, что данные изменились.
  }

  Future<void> updateAppealData(Appeal updatedAppeal, List<String> filePaths) async {
    final newAppeal = await _apiService.updateAppeal(updatedAppeal, filePaths); //Обновляем на сервере
    final index = _appeals.indexWhere((appeal) => appeal.id == newAppeal.id);

    if (index != -1) {
      _appeals[index] = newAppeal; //Обновляем в списке.
      notifyListeners();  //Сообщаем, что данные изменились.
    }
  }
}