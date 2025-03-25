import 'package:flutter/material.dart';
import 'package:housing_inspection_client/models/message.dart';
import 'package:housing_inspection_client/services/api_service.dart';

class MessageProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<Message> _messages = [];
  bool _isLoading = false;
  String? _error;
  int? _lastMessageId; //  ДОБАВЛЯЕМ

  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool _hasNewMessages = false; //  ДОБАВЛЯЕМ ФЛАГ
  bool get hasNewMessages => _hasNewMessages; //Геттер

  set hasNewMessages(bool value) {
    _hasNewMessages = value;
    notifyListeners(); //  Уведомляем слушателей об изменении
  }

  Future<void> fetchMessages(int appealId, {int skip = 0, int limit = 100}) async {
    _isLoading = true;
    _error = null;
    if (_lastMessageId == null) {
      _messages = [];
    }
    // notifyListeners();  //  УБИРАЕМ отсюда!

    try {
      final newMessages = await _apiService.getMessages(
          appealId, skip: skip, limit: limit, lastMessageId: _lastMessageId);

      if (newMessages.isNotEmpty) {
        _messages.addAll(newMessages);
        _lastMessageId = newMessages.last.id;
        _hasNewMessages = true; //  УСТАНАВЛИВАЕМ ФЛАГ
        notifyListeners();
      }
    } catch (e) {
      _error = 'Ошибка при загрузке сообщений: $e';
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage(int appealId, String content, List<String> filePaths) async {
    try{
      final newMessage = await _apiService.createMessage(appealId, content, filePaths);
      _messages.add(newMessage);
      _lastMessageId = newMessage.id;
      _hasNewMessages = true; //  УСТАНАВЛИВАЕМ ФЛАГ
      notifyListeners();
    }
    catch (e){
      _error = 'Ошибка при отправке сообщения: $e';
    }
  }

  void clearMessages() {
    _messages = [];
    _lastMessageId = null;
    _hasNewMessages = false; // Сбрасываем
    // notifyListeners();  // НЕ НУЖНО
  }
}