import 'package:flutter/material.dart';
import 'package:housing_inspection_client/services/api_service.dart';
import '../models/appeal_status.dart';

class StatusProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<AppealStatus> _statuses = [];

  List<AppealStatus> get statuses => _statuses;

  Future<void> fetchStatuses() async {
    print("Получение статусов..."); // Добавляем
    try {
      _statuses = await _apiService.getAppealStatuses();
      print("Статусов получено: ${_statuses.length}");
      notifyListeners();
    }
    catch (e){
      print("Ошибка при получении статусов: $e");
    }
  }
  String getStatusName(int id) {
    print("id = $id");
    final status = _statuses.firstWhere((element) => element.id == id,
        orElse: () => AppealStatus(id: 0, name: 'Неизвестно')); //Обработка на случай если статус не найден.
    print(status);
    return status.name;
  }
}