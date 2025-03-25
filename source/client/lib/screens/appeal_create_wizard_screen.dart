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
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p; //  ДОБАВИТЬ ЭТУ СТРОКУ

class AppealCreateWizardScreen extends StatefulWidget {
  const AppealCreateWizardScreen({Key? key}) : super(key: key);

  @override
  State<AppealCreateWizardScreen> createState() => _AppealCreateWizardScreenState();
}

String _shortenFileName(String path, int maxLength) {
  String fileName = p.basename(path);
  if (fileName.length > maxLength) {
    return fileName.substring(0, maxLength - 3) + "...";
  }
  return fileName;
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
  String? _imagePath; // Путь к выбранному изображению
  String? _pdfPath; // Путь к выбранному PDF
  String? _fileError; // Ошибка, связанная с выбором файлов
  List<AppealCategory> _categories = [];

  bool _isLoading = false;
  String? _error;


  @override
  void initState() {
    super.initState();
    //  Загружаем категории (лучше делать это в main.dart и передавать сюда через Provider)
    _loadCategories();
  }

  String _shortenFileName(String path, int maxLength) {
    String fileName = p.basename(path);
    if (fileName.length > maxLength) {
      return fileName.substring(0, maxLength - 3) + "...";
    }
    return fileName;
  }

  Future<void> _loadCategories() async {
    try {
      _categories = await Provider
          .of<CategoryProvider>(context, listen: false)
          .categories;
      if (_categories.isNotEmpty) { //Если категории есть
        setState(() {
          _categoryId =
              _categories.first.id; //  Устанавливаем начальное значение
        });
      }
    } catch (e) {
      setState(() {
        _error = "Ошибка загрузки категорий: $e";
      });
    }
  }

  Future<void> _pickImage() async {
    setState(() {
      _fileError = null;
    }); // Сбрасываем ошибку
    try {
      // Выбираем только изображения
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image, // Фильтр по изображениям
        allowMultiple: false, // Только один файл
      );

      if (result != null && result.files.single.path != null) {
        // Проверяем, не выбрано ли уже изображение
        // (Хотя allowMultiple=false, пользователь может выбрать другое)
        // if (_imagePath != null) {
        //   setState(() { _fileError = 'Вы можете добавить только одно изображение.'; });
        //   return;
        // }
        setState(() {
          _imagePath = result.files.single.path!;
        });
      }
    } catch (e) {
      setState(() {
        _fileError = 'Ошибка при выборе изображения: $e';
      });
    }
  }

  Future<void> _pickPdf() async {
    setState(() {
      _fileError = null;
    });
    try {
      // Выбираем только PDF
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'], // Фильтр по PDF
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        // if (_pdfPath != null) {
        //   setState(() { _fileError = 'Вы можете добавить только один PDF файл.'; });
        //   return;
        // }
        setState(() {
          _pdfPath = result.files.single.path!;
        });
      }
    } catch (e) {
      setState(() {
        _fileError = 'Ошибка при выборе PDF: $e';
      });
    }
  }

// Оставляем _takePicture, но немного изменяем
  Future<void> _takePicture() async {
    setState(() {
      _fileError = null;
    });
    try {
      // if (_imagePath != null) {
      //   setState(() { _fileError = 'Вы можете добавить только одно изображение.'; });
      //   return;
      // }
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(source: ImageSource.camera);

      if (photo != null) {
        setState(() {
          _imagePath = photo.path;
        });
      }
    } catch (e) {
      setState(() {
        _fileError = 'Ошибка при съемке фото: $e';
      });
    }
  }

  // Виджет для отображения превью файла
  Widget _buildFilePreview(String path) {
    final extension = path.split('.').last.toLowerCase();
    const int maxLen = 20; // Максимальная длина имени файла для превью

    if (['jpg', '.jpeg', '.png', '.gif', '.bmp'].contains(extension)) {
      // Для изображений оставляем превью картинки
      return SizedBox( // Обернем в SizedBox для единообразия размера
        width: 100,
        height: 100,
        child: ClipRRect( // Обрезаем углы
          borderRadius: BorderRadius.circular(8.0),
          child: kIsWeb
              ? Image.network(path, fit: BoxFit.cover)
              : Image.file(File(path), fit: BoxFit.cover),
        ),
      );
    } else { // Для PDF и других файлов показываем иконку и сокращенное имя
      return Container(
        width: 100,
        height: 100,
        padding: EdgeInsets.all(4), // Небольшой отступ
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon( extension == 'pdf' ? Icons.picture_as_pdf_outlined : Icons.insert_drive_file_outlined, size: 40), // Иконка
            SizedBox(height: 4),
            Text(
              _shortenFileName(path, maxLen), // Сокращенное имя
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis, // Добавим на всякий случай
              maxLines: 2, // В две строки если нужно
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      );
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
        onStepTapped: (int index) {
          // Разрешаем переход только вперед и только если предыдущие шаги валидны
          if (index > _currentStep) {
            bool canProceed = true;
            // Проверяем все шаги ДО целевого шага (index)
            for (int i = 0; i < index; i++) {
              // Проверяем валидность формы (шаги 0, 1, 2)
              if (i < 3 && !_formKeys[i].currentState!.validate()) {
                canProceed = false;
                // Устанавливаем _currentStep на шаг с ошибкой, чтобы пользователь видел ее
                setState(() { _currentStep = i; });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Пожалуйста, заполните шаг ${i + 1} корректно.')),
                );
                break; // Выходим из цикла, дальше проверять нет смысла
              }
              // Проверяем файлы на шаге 4 (если переходим на шаг 5)
              if (i == 3 && index == 4 && (_imagePath == null || _pdfPath == null)) {
                canProceed = false;
                setState(() {
                  _currentStep = 3; // Остаемся на шаге файлов
                  _fileError = 'Необходимо прикрепить изображение и PDF файл.';
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(_fileError!)),
                );
                break;
              }
              // Сохраняем данные валидных шагов, чтобы не потерять их
              if (i < 3) _formKeys[i].currentState!.save();
            }
            // Если все предыдущие шаги валидны, переходим
            if (canProceed) {
              setState(() { _currentStep = index; });
            }
          } else {
            // Разрешаем переход назад без проверок
            setState(() { _currentStep = index; });
          }
        },
        steps: [
          // Шаг 1: Адрес
          Step(
            title: const Text('Адрес'),
            content: Form(
              key: _formKeys[0],
              child: TextFormField(
                initialValue: _address,
                decoration: const InputDecoration(labelText: 'Введите адрес'),
                maxLines: 1,
                keyboardType: TextInputType.streetAddress,
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\n'))
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
            ),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 // Шаг пройден, если мы НЕ на нем
                ? (_formKeys[0].currentState?.validate() ?? false) // Проверяем валидность
                ? StepState.complete
                : StepState.error // Показываем ошибку, если невалиден
                : StepState.indexed, // Текущий шаг
          ),

          // Шаг 2: Категория
          Step(
            title: const Text('Категория'),
            content: Form(
              key: _formKeys[1],
              child: DropdownButtonFormField<int>(
                decoration: const InputDecoration(
                    labelText: 'Выберите категорию'),
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
            state: _currentStep > 1
                ? (_formKeys[1].currentState?.validate() ?? false) && (_formKeys[0].currentState?.validate() ?? false) // Проверяем валидность и предыдущий шаг
                ? StepState.complete
                : StepState.error
                : _currentStep == 1 ? StepState.indexed : StepState.disabled, // Текущий или неактивный
          ),

          // Шаг 3: Описание
          Step(
            title: const Text('Описание'),
            content: Form(
              key: _formKeys[2],
              child: TextFormField(
                initialValue: _description,
                decoration: const InputDecoration(
                    labelText: 'Описание проблемы'),
                minLines: 1,
                maxLines: 3,
                keyboardType: TextInputType.text,
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'\n'))
                ],
                validator: (value) {
                  if (value != null && value.length > 250) {
                    return 'Описание не должно превышать 250 символов';
                  }
                  return null;
                },
                onSaved: (value) {
                  _description = value ?? '';
                },
              ),
            ),
            isActive: _currentStep >= 2,
            state: _currentStep > 2
                ? (_formKeys[2].currentState?.validate() ?? false) && (_formKeys[1].currentState?.validate() ?? false) && (_formKeys[0].currentState?.validate() ?? false) // Проверяем валидность и предыдущие
                ? StepState.complete
                : StepState.error
                : _currentStep == 2 ? StepState.indexed : StepState.disabled,
          ),

          // Шаг 4: Файлы
          Step(
            title: const Text('Файлы'),
            content: Form( // Оставляем Form для единообразия
              key: _formKeys[3], // Используем ключ, хотя валидации нет
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                // Выравнивание по левому краю
                children: [
                  // --- Выбор изображения ---
                  Text('Изображение (JPG, PNG):', style: Theme
                      .of(context)
                      .textTheme
                      .titleMedium),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _pickImage,
                        icon: Icon(Icons.image_search),
                        label: const Text('Выбрать'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _takePicture,
                        icon: Icon(Icons.camera_alt),
                        label: const Text('Сделать фото'),
                      ),
                    ],
                  ),
                  if (_imagePath !=
                      null) // Показываем превью, если изображение выбрано
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Stack(
                        alignment: Alignment.topRight,
                        children: [
                          _buildFilePreview(_imagePath!),
                          GestureDetector( // Кнопка удаления
                            onTap: () => setState(() => _imagePath = null),
                            child: Container(
                              padding: EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.7),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                  Icons.close, color: Colors.white, size: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16), // Отступ

                  // --- Выбор PDF ---
                  Text('Документ PDF:', style: Theme
                      .of(context)
                      .textTheme
                      .titleMedium),
                  const SizedBox(height: 8),
                  Center( // Центрируем кнопку выбора PDF
                    child: ElevatedButton.icon(
                      onPressed: _pickPdf,
                      icon: Icon(Icons.picture_as_pdf),
                      label: const Text('Выбрать PDF'),
                    ),
                  ),
                  if (_pdfPath != null) // Показываем превью PDF
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Stack(
                        alignment: Alignment.topRight,
                        children: [
                          _buildFilePreview(_pdfPath!),
                          GestureDetector( // Кнопка удаления
                            onTap: () => setState(() => _pdfPath = null),
                            child: Container(
                              padding: EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.7),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                  Icons.close, color: Colors.white, size: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Отображение ошибки выбора файлов
                  if (_fileError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        _fileError!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
            ),
            isActive: _currentStep >= 3,
            // Состояние шага файлов: пройден, если оба файла выбраны и предыдущие шаги валидны
            state: _currentStep > 3
                ? (_imagePath != null && _pdfPath != null) && (_formKeys[2].currentState?.validate() ?? false) && (_formKeys[1].currentState?.validate() ?? false) && (_formKeys[0].currentState?.validate() ?? false)
                ? StepState.complete
                : StepState.error
                : _currentStep == 3 ? StepState.indexed : StepState.disabled,
          ),

          // Шаг 5: Подтверждение
          Step(
            title: const Text('Подтверждение'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Адрес: $_address'),
                Text(
                    'Категория: ${_categoryId != null && _categories.isNotEmpty
                        ? _categories
                        .firstWhere((cat) => cat.id == _categoryId,
                        orElse: () => AppealCategory(id: 0, name: 'Неизвестно'))
                        .name
                        : "Не выбрана"}'),
                Text('Описание: $_description'),
                const SizedBox(height: 10),
                Text('Прикрепленные файлы:', style: Theme.of(context).textTheme.titleMedium),
                if (_imagePath != null)
                  Row(children: [
                    Icon(Icons.image, size: 18),
                    SizedBox(width: 5),
                    Expanded( // Обернуть в Expanded, чтобы текст переносился или обрезался
                        child: Text(
                          _shortenFileName(_imagePath!, 32), // Используем функцию сокращения
                          overflow: TextOverflow.ellipsis, // Добавляем эллипсис
                        )
                    )
                  ]),
                if (_pdfPath != null)
                  Row(children: [
                    Icon(Icons.picture_as_pdf, size: 18),
                    SizedBox(width: 5),
                    Expanded( // Обернуть в Expanded
                        child: Text(
                          _shortenFileName(_pdfPath!, 30), // Используем функцию сокращения
                          overflow: TextOverflow.ellipsis,
                        )
                    )
                  ]),
                // Показываем превью и здесь (по желанию)
                 //if (_imagePath != null) Padding(padding: const EdgeInsets.only(top: 8.0), child: _buildFilePreview(_imagePath!)),
                 //if (_pdfPath != null) Padding(padding: const EdgeInsets.only(top: 8.0), child: _buildFilePreview(_pdfPath!)),

                if (_error != null) // Отображаем общую ошибку отправки
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
            isActive: _currentStep >= 4,
            // Состояние последнего шага: всегда indexed, если активен, иначе disabled
            state: _currentStep == 4 ? StepState.indexed : StepState.disabled,
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
    // Валидация предыдущих шагов
    bool allFormsValid = true;
    for (int i = 0; i <
        _formKeys.length; i++) {
      if (!_formKeys[i].currentState!.validate()) {
        allFormsValid = false;
        // Переходим на шаг с ошибкой
        setState(() {
          _currentStep = i;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Пожалуйста, исправьте ошибки на шаге ${i + 1}.')),
        );
        return;
      }
    }

    // Валидация файлов
    if (_imagePath == null || _pdfPath == null) {
      setState(() {
        _fileError = 'Необходимо прикрепить одно изображение и один PDF файл.';
        _currentStep = 3; // Переходим на шаг выбора файлов
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_fileError!)),
      );
      return; // Не отправляем
    }

    // Сохраняем данные всех форм перед отправкой
    for (var key in _formKeys) {
      key.currentState!.save();
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _fileError = null; // Сбрасываем ошибку файлов
    });

    try {
      final newAppeal = Appeal(
        id: 0,
        userId: 0,
        categoryId: _categoryId!,
        statusId: 1,
        address: _address,
        description: _description,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Собираем список файлов для отправки
      final filesToSend = [_imagePath!, _pdfPath!];

      await Provider.of<AppealProvider>(context, listen: false)
          .addAppeal(newAppeal, filesToSend); // Отправляем оба файла

      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = 'Ошибка при отправке обращения: $e';
        _currentStep = 4; // Показываем ошибку на шаге подтверждения
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}