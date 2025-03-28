import 'package:flutter/material.dart';
import 'package:housing_inspection_client/services/api_service.dart';
import 'package:path/path.dart' as p;

class KnowledgeBaseProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<String>? _fileUrls;
  bool _isLoading = false;
  String? _error;

  List<String>? get fileUrls => _fileUrls;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchCategoryFiles(String category) async {
    _isLoading = true;
    _error = null;
    _fileUrls = null;
    notifyListeners();

    try {
      final List<String> fetchedUrls =
      await _apiService.getKnowledgeBaseCategoryFiles(category);
      _fileUrls =
          fetchedUrls.where((url) => !p.basename(url).endsWith('/')).toList();
    } catch (e) {
      _error = 'Ошибка при загрузке файлов: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}