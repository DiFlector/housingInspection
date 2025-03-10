import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:housing_inspection_client/models/appeal.dart';
import 'package:housing_inspection_client/models/appeal_category.dart';
import 'package:housing_inspection_client/models/appeal_status.dart';
import 'package:housing_inspection_client/providers/appeal_provider.dart';
import 'package:housing_inspection_client/providers/category_provider.dart';
import 'package:housing_inspection_client/providers/status_provider.dart';
import 'package:housing_inspection_client/services/api_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;

class AppealCreateScreen extends StatefulWidget {
  const AppealCreateScreen({super.key});

  @override
  _AppealCreateScreenState createState() => _AppealCreateScreenState();
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

class _AppealCreateScreenState extends State<AppealCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  String _address = '';
  int _categoryId = 1;
  String _description = '';
  List<String> _filePaths = [];
  final ApiService _apiService = ApiService();
  late List<AppealCategory> _categories = [];
  late List<AppealStatus> _statuses = [];

  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategoriesAndStatuses();
  }

  Future<void> _loadCategoriesAndStatuses() async {
    try {
      _categories =
      await Provider.of<CategoryProvider>(context, listen: false).categories;
      _statuses =
      await Provider.of<StatusProvider>(context, listen: false).statuses;
      setState(() {});
    } catch (e) {
      print('Ошибка загрузки категорий и статусов: $e');
      setState(() {
        _error = 'Загрузка категорий и статусов не удалась: $e';
      });
    }
  }

  Future<void> _pickFiles() async {
    FilePickerResult? result =
    await FilePicker.platform.pickFiles(allowMultiple: true);

    if (result != null) {
      setState(() {
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
        title: const Text('Создать обращение'),
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
                decoration: const InputDecoration(labelText: 'Адрес'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Пожалуйста, введите адрес';
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
                onChanged: (value) {
                  setState(() {
                    _categoryId = value!;
                  });
                },
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Описание'),
                maxLines: 3,
                onSaved: (value) {
                  _description = value ?? '';
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _pickFiles,
                child: const Text('Добавить файлы'),
              ),
              ElevatedButton(
                onPressed: _takePicture,
                child: const Text('Добавить фото'),
              ),
              const SizedBox(height: 10),
              Wrap(
                children: _filePaths.map((path) => Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: _buildFilePreview(path),
                )).toList(),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();

                    setState(() {
                      _isLoading = true;
                      _error = null;
                    });

                    try {
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
                      await Provider.of<AppealProvider>(context, listen: false)
                          .addAppeal(newAppeal, _filePaths);
                      Navigator.of(context).pop();
                    } catch (e) {
                      setState(() {
                        _error = 'Ошибка при создании обращения: $e';
                      });
                    } finally {
                      setState(() {
                        _isLoading = false;
                      });
                    }
                  }
                },
                child: const Text('Отправить'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}