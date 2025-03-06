import 'package:flutter/material.dart';
import 'package:housing_inspection_client/services/api_service.dart';
import '../models/appeal_status.dart';
import 'package:housing_inspection_client/models/api_exception.dart';

class StatusProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<AppealStatus> _statuses = [];
  bool _isLoading = false;

  List<AppealStatus> get statuses => _statuses;
  bool get isLoading => _isLoading;

  Future<void> fetchStatuses() async {
    _isLoading = true;
    notifyListeners();
    try {
      _statuses = await _apiService.getAppealStatuses();
    } catch (e){
      print('Error loading categories and statuses: $e');
      rethrow;
    }
    finally{
      _isLoading = false;
      notifyListeners();
    }
  }
  String getStatusName(int id) {
    final status = _statuses.firstWhere((element) => element.id == id,
        orElse: () => AppealStatus(id: 0, name: 'Неизвестно'));
    return status.name;
  }

  Future<void> addStatus(AppealStatus status) async {
    try {
      final newStatus = await _apiService.createStatus(status.name);
      _statuses.add(newStatus);
      notifyListeners();
    } on ApiException catch (e) {
      rethrow;
    } catch (e) {
      print('Error adding status: $e');
      rethrow;
    }
  }

  Future<void> updateStatus(AppealStatus updatedStatus) async {
    try {
      final newStatus = await _apiService.updateStatus(updatedStatus);
      final index = _statuses.indexWhere((status) => status.id == newStatus.id);
      if (index != -1) {
        _statuses[index] = newStatus;
        notifyListeners();
      }
    } on ApiException catch (e){
      rethrow;
    }
    catch (e){
      print('Error update status: $e');
      rethrow;
    }
  }

  Future<void> deleteStatus(int statusId) async {
    try{
      await _apiService.deleteStatus(statusId);
      _statuses.removeWhere((status) => status.id == statusId);
      notifyListeners();
    } on ApiException catch (e){
      if(e.message == 'Failed to delete status: 400, {"detail":"Cannot delete status: it\'s in use"}'){
        throw ApiException("Невозможно удалить статус: он используется в обращениях.");
      }
      else{
        rethrow;
      }
    }
    catch (e){
      print('Error delete status: $e');
      rethrow;
    }
  }
}