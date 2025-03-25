import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:housing_inspection_client/models/appeal_category.dart';
import 'package:housing_inspection_client/models/appeal_status.dart';
import 'package:housing_inspection_client/services/api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/appeal.dart';
import '../providers/appeal_provider.dart';
import 'package:housing_inspection_client/providers/category_provider.dart';
import 'package:housing_inspection_client/providers/status_provider.dart';

import 'package:path/path.dart' as p;
import 'package:flutter/services.dart'; // Для InputFormatters

class AppealUpdateScreen extends StatefulWidget {
  final int appealId;

  const AppealUpdateScreen({super.key, required this.appealId});

  @override
  _AppealUpdateScreenState createState() => _AppealUpdateScreenState();
}

class _AppealUpdateScreenState extends State<AppealUpdateScreen> {
  final _formKey = GlobalKey<FormState>();
  String _address = '';
  int? _categoryId; // Сделали nullable
  String _description = '';
  int? _statusId; // Сделали nullable
  // final ApiService _apiService = ApiService(); // Не нужен здесь
  late List<AppealCategory> _categories = [];
  late List<AppealStatus> _statuses = [];
  Appeal? _appeal;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; }); // Показываем загрузку
    try {
      // Загружаем категории и статусы, если они еще не загружены
      final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
      final statusProvider = Provider.of<StatusProvider>(context, listen: false);

      if (categoryProvider.categories.isEmpty) {
        await categoryProvider.fetchCategories();
      }
      _categories = categoryProvider.categories;

      if (statusProvider.statuses.isEmpty) {
        await statusProvider.fetchStatuses();
      }
      _statuses = statusProvider.statuses;

      // Ищем обращение в провайдере. Если нет - загружаем с сервера (на случай прямого перехода по ссылке, например)
      _appeal = Provider.of<AppealProvider>(context, listen: false)
          .appeals
          .firstWhere((a) => a.id == widget.appealId, orElse: null); // Добавили orElse: null

      // if (_appeal == null) {
      //   // Если в провайдере нет, пытаемся загрузить с API
      //   // Нужно добавить метод getAppeal в ApiService и AppealProvider
      //    final apiService = ApiService(); // Создаем экземпляр ApiService
      //    _appeal = await apiService.getAppeal(widget.appealId);
      //    // Можно добавить это обращение в AppealProvider, если нужно кэширование
      //    Provider.of<AppealProvider>(context, listen: false).addOrUpdateAppeal(_appeal!);
      // }

      if (_appeal != null) {
        _address = _appeal!.address;
        _categoryId = _appeal!.categoryId;
        _description = _appeal!.description ?? '';
        _statusId = _appeal!.statusId;
      } else {
        // Обработка случая, когда обращение не найдено
        throw Exception('Обращение с ID ${widget.appealId} не найдено.');
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e){
      setState(() {
        _isLoading = false;
        _error = 'Ошибка при загрузке данных обращения: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Изменить обращение'),
      ),
      body:
      _isLoading ? const Center(child: CircularProgressIndicator()) :
      _error != null ? Center(child: Text('Ошибка: $_error')) : // Показываем ошибку загрузки
      Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Адрес'),
                initialValue: _address,
                maxLines: 1, // Одна строка
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\n')) // Запрет переноса
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Пожалуйста, введите адрес';
                  }
                  if (value.length < 5) {
                    return 'Адрес должен содержать не менее 5 символов';
                  }
                  if (value.length > 96) {
                    return 'Адрес не должен превышать 96 символов';
                  }
                  return null;
                },
                onSaved: (value) {
                  _address = value!;
                },
              ),
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: 'Категория'),
                value: _categoryId,
                items: _categories.map((category) {
                  return DropdownMenuItem<int>(
                    value: category.id,
                    child: Text(category.name),
                  );
                }).toList(),
                onChanged: (value) { // Должен быть onChanged
                  setState(() {
                    _categoryId = value;
                  });
                },
                validator: (value) { // Валидация категории
                  if (value == null) {
                    return 'Пожалуйста, выберите категорию';
                  }
                  return null;
                },
                onSaved: (value) {
                  _categoryId = value;
                },
              ),
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: 'Статус'),
                value: _statusId,
                items:_statuses.map((status) {
                  return DropdownMenuItem<int>(value: status.id, child: Text(status.name));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _statusId = value;
                  });
                },
                validator: (value) { // Валидация статуса
                  if (value == null) {
                    return 'Пожалуйста, выберите статус';
                  }
                  return null;
                },
                onSaved: (value) {
                  _statusId = value;
                },
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Описание'),
                initialValue: _description,
                minLines: 1,
                maxLines: 3, // Несколько строк
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\n')) // Запрет переноса
                ],
                validator: (value) {
                  // Описание опционально, но если есть, проверяем длину
                  if (value != null && value.length > 250) {
                    return 'Описание не должно превышать 250 символов';
                  }
                  return null; // Если пусто или длина в норме
                },
                onSaved: (value) {
                  _description = value ?? '';
                },
              ),
              const SizedBox(height: 20),

              if (_error != null) // Оставляем для ошибок отправки
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) { // ПРОВЕРЯЕМ ВАЛИДНОСТЬ ФОРМЫ
                    _formKey.currentState!.save();

                    // Создаем объект ТОЛЬКО с обновляемыми полями
                    final appealUpdateData = Appeal(
                        id: widget.appealId,
                        userId: _appeal!.userId,
                        address: _address,
                        categoryId: _categoryId!, // Уверены, что не null после валидации
                        statusId: _statusId!, // Уверены, что не null после валидации
                        description: _description,
                        createdAt: _appeal!.createdAt,
                        updatedAt: DateTime.now(),
                        filePaths: _appeal!.filePaths,
                        user: _appeal!.user
                    );


                    setState(() {
                      _isLoading = true;
                      _error = null;
                    });

                    try {
                      // Передаем ТОЛЬКО appealUpdateData
                      await Provider.of<AppealProvider>(context, listen: false)
                          .updateAppealData(appealUpdateData);
                      Navigator.pop(context);
                      Provider.of<AppealProvider>(context, listen: false).refreshAppeal(widget.appealId);
                    } catch (e){
                      setState(() {
                        _error = 'Ошибка при изменении обращения: $e';
                      });
                    } finally {
                      // Проверяем смонтирован ли виджет
                      if(mounted) {
                        setState(() {
                          _isLoading = false;
                        });
                      }
                    }
                  } else {
                    // Показываем сообщение, если форма не валидна
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Пожалуйста, исправьте ошибки в форме.')),
                    );
                  }
                },
                child: const Text('Сохранить'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}