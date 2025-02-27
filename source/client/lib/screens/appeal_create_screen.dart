import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:housing_inspection_client/models/appeal.dart';
import 'package:housing_inspection_client/models/appeal_category.dart';
import 'package:housing_inspection_client/models/appeal_status.dart';
import 'package:housing_inspection_client/providers/appeal_provider.dart';
import 'package:housing_inspection_client/services/api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import 'package:housing_inspection_client/providers/category_provider.dart';
import 'package:housing_inspection_client/providers/status_provider.dart';


class AppealCreateScreen extends StatefulWidget {
  const AppealCreateScreen({super.key});

  @override
  _AppealCreateScreenState createState() => _AppealCreateScreenState();
}

Widget _buildFilePreview(String path) {
  final extension = p.extension(path).toLowerCase(); // Получаем расширение

  if (['.jpg', '.jpeg', '.png', '.gif', '.bmp'].contains(extension)) {
    // Это изображение
    return kIsWeb
        ? Image.network(path, width: 100, height: 100)
        : Image.file(File(path), width: 100, height: 100);
  } else if (extension == '.pdf') {
    // Это PDF
    return const SizedBox(width: 100, height: 100, child: Icon(Icons.picture_as_pdf, size: 64)); // Иконка PDF
  } else {
    // Другой тип файла
    return const SizedBox(width: 100, height: 100, child: Icon(Icons.file_present, size: 64)); // Иконка файла
  }
}

class _AppealCreateScreenState extends State<AppealCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  String _address = '';
  int _categoryId = 1; // Начальное значение
  String _description = '';
  List<String> _filePaths = [];
  final ApiService _apiService = ApiService(); // Создаем экземпляр ApiService
  late List<AppealCategory> _categories = [];
  late List<AppealStatus> _statuses = [];

  bool _isLoading = false; //  Добавляем флаг загрузки

  @override
  void initState() {
    super.initState();
    _loadCategoriesAndStatuses(); // Загружаем категории и статусы при инициализации
  }
  Future<void> _loadCategoriesAndStatuses() async {
    try {
      _categories = await Provider.of<CategoryProvider>(context, listen: false).categories;
      _statuses = await Provider.of<StatusProvider>(context, listen: false).statuses;
      setState(() {});
    } catch (e) {
      print('Error loading categories and statuses: $e');
      // Обработка ошибок (например, показ сообщения пользователю)
    }
  }

  Future<void> _pickFiles() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(allowMultiple: true);

    if (result != null) {
      setState(() {
        //_filePaths = result.paths.map((path) => File(path)).toList();
        _filePaths = result.paths.map((path) => path!).toList();
      });
    }
  }
  Future<void> _takePicture() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);

    if (photo != null) {
      setState(() {
        _filePaths.add(photo.path);
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Appeal'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child:
          _isLoading ? const Center(child: CircularProgressIndicator()) :
          ListView(
            children: [
              TextFormField(
                decoration: const InputDecoration(labelText: 'Address'),
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
                items: _categories.map((category) { // Используем _categories
                  return DropdownMenuItem<int>(
                    value: category.id,
                    child: Text(category.name), // Отображаем name
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _categoryId = value!;
                  });
                },
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
                onSaved: (value) {
                  _description = value ?? '';
                },
              ),
              const SizedBox(height: 20),
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
                children: _filePaths.map((path) => Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: _buildFilePreview(path), // Используем вспомогательную функцию
                )).toList(),
              ),

              ElevatedButton(
                onPressed: () async {  //  Делаем обработчик асинхронным
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();

                    final newAppeal = Appeal(
                      id: 0,
                      userId: 0,
                      categoryId: _categoryId,
                      statusId: 1,
                      address: _address,
                      description: _description,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    );

                    setState(() {
                      _isLoading = true; //  Включаем индикатор загрузки
                    });

                    try {
                      await Provider.of<AppealProvider>(context, listen: false).addAppeal(newAppeal, _filePaths);
                      Navigator.pop(context); //  Возвращаемся назад в случае успеха
                    } catch (e) {
                      //  Обработка ошибок
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error creating appeal: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    } finally {
                      setState(() {
                        _isLoading = false; //  Выключаем индикатор загрузки
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