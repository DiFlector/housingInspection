import 'package:flutter/material.dart';
import 'package:housing_inspection_client/models/appeal_category.dart';
import 'package:housing_inspection_client/providers/appeal_provider.dart';
import 'package:housing_inspection_client/providers/category_provider.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart'; //  Для file_picker
import 'package:image_picker/image_picker.dart'; //  Для image_picker
import 'dart:io'; // Для File
import 'package:housing_inspection_client/models/appeal.dart';
import 'package:flutter/foundation.dart';

class AppealCreateWizardScreen extends StatefulWidget {
  const AppealCreateWizardScreen({Key? key}) : super(key: key);

  @override
  State<AppealCreateWizardScreen> createState() => _AppealCreateWizardScreenState();
}

class _AppealCreateWizardScreenState extends State<AppealCreateWizardScreen> {
  int _currentStep = 0;
  final _formKeys = [
    GlobalKey<FormState>(), //  Для каждого шага свой GlobalKey
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
  ];

  //  Переменные для хранения данных
  String _address = '';
  int _categoryId = 1; //  Начальное значение
  String _description = '';
  List<String> _filePaths = [];
  List<AppealCategory> _categories = [];

  bool _isLoading = false;
  String? _error;


  @override
  void initState() {
    super.initState();
    //  Загружаем категории (лучше делать это в main.dart и передавать сюда через Provider)
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      _categories = await Provider.of<CategoryProvider>(context, listen: false).categories;
      if (_categories.isNotEmpty) { //Если категории есть
        setState(() {
          _categoryId = _categories.first.id;  //  Устанавливаем начальное значение
        });
      }
    } catch (e) {
      setState(() {
        _error = "Ошибка загрузки категорий: $e";
      });
    }
  }

  //  Методы для выбора файлов (как в appeal_create_screen.dart)
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

  // Виджет для отображения превью файла
  Widget _buildFilePreview(String path) {
    final extension = path.split('.').last.toLowerCase();
    if (['jpg', '.jpeg', '.png', '.gif', '.bmp'].contains(extension)) {
      return kIsWeb
          ? Image.network(path, width: 100, height: 100)
          : Image.file(File(path), width: 100, height: 100);
    } else if (extension == 'pdf') {
      return const SizedBox(width: 100, height: 100, child: Icon(Icons.picture_as_pdf, size: 64));
    } else {
      return const SizedBox(width: 100, height: 100, child: Icon(Icons.file_present, size: 64));
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Подача обращения'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stepper(
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep < 4) { //  Проверяем, НЕ последний ли шаг
            if (_formKeys[_currentStep].currentState!.validate()) {
              _formKeys[_currentStep].currentState!.save();
              setState(() {
                _currentStep += 1;
              });
            }
          } else {
            //  Последний шаг - отправка
            _submitAppeal();
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() {
              _currentStep -= 1;
            });
          }
        },
        onStepTapped: (int index) { //Убрали валидацию
          setState(() {
            _currentStep = index;
          });
        },
        steps: [
          // Шаг 1: Адрес
          Step(
            title: const Text('Адрес'),
            content: Form(
              key: _formKeys[0],
              child: TextFormField(
                decoration: const InputDecoration(labelText: 'Введите адрес'),
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
            ),
            isActive: _currentStep >= 0,
            state: _currentStep >= 0 ? StepState.complete : StepState.disabled,
          ),

          // Шаг 2: Категория
          Step(
            title: const Text('Категория'),
            content: Form(
              key: _formKeys[1],
              child: DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: 'Выберите категорию'),
                value: _categoryId,
                items: _categories.map((category) { //  Используем _categories
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
                validator: (value) {
                  if (value == null) {
                    return 'Пожалуйста, выберите категорию';
                  }
                  return null;
                },
              ),
            ),
            isActive: _currentStep >= 1,
            state: _currentStep >= 1 ? StepState.complete : StepState.disabled,
          ),

          // Шаг 3: Описание
          Step(
            title: const Text('Описание'),
            content: Form(
              key: _formKeys[2],
              child: TextFormField(
                decoration: const InputDecoration(labelText: 'Описание проблемы'),
                maxLines: 3,
                onSaved: (value) {
                  _description = value ?? '';
                },
              ),
            ),
            isActive: _currentStep >= 2,
            state: _currentStep >= 2 ? StepState.complete : StepState.disabled,
          ),

          // Шаг 4: Файлы
          Step(
            title: const Text('Файлы'),
            content: Form(
              key: _formKeys[3],
              child: Column(
                children: [
                  ElevatedButton(
                    onPressed: _pickFiles,
                    child: const Text('Выбрать файлы'),
                  ),
                  ElevatedButton(
                    onPressed: _takePicture,
                    child: const Text('Сделать фото'),
                  ),
                  const SizedBox(height: 10),
                  Wrap(  //  Для отображения превью
                    children: _filePaths.map((path) => Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: _buildFilePreview(path),
                    )).toList(),
                  ),
                ],
              ),
            ),
            isActive: _currentStep >= 3,
            state: _currentStep >= 3 ? StepState.complete : StepState.disabled,
          ),

          // Шаг 5: Подтверждение
          Step(
            title: const Text('Подтверждение'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Адрес: $_address'),
                //  Добавляем проверку на  _categories.isNotEmpty:
                Text('Категория: ${_categories.isNotEmpty ? _categories.firstWhere((cat) => cat.id == _categoryId).name : "Неизвестно"}'), //  Отображаем название категории
                Text('Описание: $_description'),
                Text('Файлы: ${_filePaths.length} шт.'), //  Количество файлов
                //  Можно добавить отображение самих файлов (превью)
              ],
            ),
            isActive: _currentStep >= 4,
            state: _currentStep >= 4 ? StepState.complete : StepState.disabled,
          ),
        ],
        controlsBuilder: (BuildContext context, ControlsDetails details) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              if (_currentStep > 0)
                TextButton(
                  onPressed: details.onStepCancel,
                  child: const Text('Назад'),
                ),
              TextButton(
                onPressed: details.onStepContinue,
                child: Text(_currentStep == 4 ? 'Отправить' : 'Далее'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _submitAppeal() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final newAppeal = Appeal(
        id: 0, //  ID сгенерируется на сервере
        userId: 0,  //  Будет подставлен сервером
        categoryId: _categoryId,
        statusId: 1, //  Новое
        address: _address,
        description: _description,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await Provider.of<AppealProvider>(context, listen: false).addAppeal(newAppeal, _filePaths);
      Navigator.of(context).pop(true); //  Передаем true
    } catch (e) {
      setState(() {
        _error = 'Ошибка при отправке обращения: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}