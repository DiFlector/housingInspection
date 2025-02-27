import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:housing_inspection_client/models/appeal_category.dart';
import 'package:housing_inspection_client/models/appeal_status.dart';
import 'package:housing_inspection_client/services/api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:housing_inspection_client/providers/category_provider.dart';
import 'package:housing_inspection_client/providers/status_provider.dart';

import '../models/appeal.dart';
import '../providers/appeal_provider.dart';

import 'package:path/path.dart' as p;

class AppealUpdateScreen extends StatefulWidget {
  final int appealId;

  const AppealUpdateScreen({super.key, required this.appealId});

  @override
  _AppealUpdateScreenState createState() => _AppealUpdateScreenState();
}

Widget _buildFilePreview(String path) {
  final extension = p.extension(path).toLowerCase();

  if (['.jpg', '.jpeg', '.png', '.gif', '.bmp'].contains(extension)) {
    return kIsWeb
        ? Image.network(path, width: 100, height: 100)
        : Image.file(File(path), width: 100, height: 100);
  } else if (extension == '.pdf') {
    return const SizedBox(
        width: 100, height: 100, child: Icon(Icons.picture_as_pdf, size: 64));
  } else {
    return const SizedBox(
        width: 100, height: 100, child: Icon(Icons.file_present, size: 64));
  }
}

class _AppealUpdateScreenState extends State<AppealUpdateScreen> {
  final _formKey = GlobalKey<FormState>();
  String _address = '';
  int _categoryId = 1; // Начальное значение
  String _description = '';
  int _statusId = 1;
  List<String> _newFilePaths =
  []; // Список для *новых* файлов (выбранных при обновлении)
  final ApiService _apiService = ApiService();
  late List<AppealCategory> _categories = [];
  late List<AppealStatus> _statuses = [];
  Appeal? _appeal;
  bool _isLoading = true; // Индикатор загрузки

  @override
  void initState() {
    super.initState();
    _loadData();
  }
  Future<void> _loadData() async {

    _categories = await Provider.of<CategoryProvider>(context, listen: false).categories;
    _statuses = await Provider.of<StatusProvider>(context, listen: false).statuses;
    // Получаем данные об обращении из провайдера.
    _appeal = Provider.of<AppealProvider>(context, listen: false).appeals.firstWhere((a) => a.id == widget.appealId);
    // Заполняем поля формы начальными значениями
    _address = _appeal!.address;
    _categoryId = _appeal!.categoryId;
    _description = _appeal!.description ?? '';
    _statusId = _appeal!.statusId;
    //_filePaths = _appeal!.filePaths?.split(',') ?? []; //  НЕ НУЖНО

    setState(() {
      _isLoading = false; // Убираем индикатор загрузки
    });

  }

  Future<void> _pickFiles() async {
    FilePickerResult? result =
    await FilePicker.platform.pickFiles(allowMultiple: true);

    if (result != null) {
      setState(() {
        _newFilePaths
            .addAll(result.paths.map((path) => path!).toList()); // Добавляем НОВЫЕ файлы
      });
    }
  }

  Future<void> _takePicture() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);

    if (photo != null) {
      setState(() {
        _newFilePaths.add(photo.path); // Добавляем НОВЫЙ файл
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Appeal'),
      ),
      body:
      _isLoading ? const Center(child: CircularProgressIndicator()) : //  Индикатор загрузки
      Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Address'),
                initialValue: _address,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an address';
                  }
                  return null;
                },
                onSaved: (value) {
                  _address = value!;
                },
              ),
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: 'Category'),
                value: _categoryId,
                items: _categories.map((category) {
                  return DropdownMenuItem<int>(
                    value: category.id,
                    child: Text(category.name),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _categoryId = value!;
                  });
                },
              ),
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: 'Status'),
                value: _statusId, // Установите начальное значение
                items:_statuses.map((status) {
                  return DropdownMenuItem<int>(value: status.id, child: Text(status.name));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _statusId = value!; // Обновляем выбранный статус
                  });
                },
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
                initialValue: _description,
                onSaved: (value) {
                  _description = value ?? '';
                },
              ),
              const SizedBox(height: 20), // Добавляем отступ
              ElevatedButton(
                onPressed: _pickFiles,
                child: const Text('Select Files'),
              ),
              ElevatedButton(
                onPressed: _takePicture,
                child: const Text('Take a Picture'),
              ),
              const SizedBox(height: 10),
              Wrap(
                children: _newFilePaths.map((path) => Padding( // প্রিভিউ новых файлов
                  padding: const EdgeInsets.all(4.0),
                  child: _buildFilePreview(path),
                )).toList(),
              ),

              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();

                    final updatedAppeal = Appeal(
                        id: widget.appealId,  // ID редактируемого обращения
                        userId: _appeal!.userId, // Используем старый userId
                        categoryId: _categoryId,
                        statusId: _statusId, // Статус может быть изменен
                        address: _address,
                        description: _description,
                        createdAt: _appeal!.createdAt, // Используем старое время создания
                        updatedAt: DateTime.now(), // Обновляем время редактирования
                        filePaths: _appeal!.filePaths //Используем старые файлы
                    );

                    setState(() {
                      _isLoading = true;
                    });

                    try {
                      await Provider.of<AppealProvider>(context, listen: false).updateAppealData(updatedAppeal, _newFilePaths);
                      Navigator.pop(context);
                    } catch (e){
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error updating appeal: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    } finally {
                      setState(() {
                        _isLoading = false;
                      });
                    }

                  }
                },
                child: const Text('Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}