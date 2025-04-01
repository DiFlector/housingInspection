import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:housing_inspection_client/models/appeal_category.dart';
import 'package:housing_inspection_client/providers/appeal_provider.dart';
import 'package:housing_inspection_client/providers/category_provider.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:housing_inspection_client/models/appeal.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:convert';
import 'dart:math';
import 'package:housing_inspection_client/providers/status_provider.dart';

import 'package:url_launcher/url_launcher.dart';

import '../models/appeal_status.dart';

class AppealCreateWizardScreen extends StatefulWidget {
  const AppealCreateWizardScreen({Key? key}) : super(key: key);

  @override
  State<AppealCreateWizardScreen> createState() => _AppealCreateWizardScreenState();
}

String _shortenFileName(String path, int maxLength) {
  if (path.isEmpty) return '';
  try {
    String fileName = p.basename(path);
    if (fileName.length <= maxLength) {
      return fileName;
    }
    final extension = p.extension(fileName);
    final nameWithoutExtension = p.basenameWithoutExtension(fileName);

    final charsToKeep = maxLength - extension.length - 3;

    if (charsToKeep <= 0) {
      return fileName.substring(0, min(fileName.length, maxLength - 3)) + "...";
    }

    return nameWithoutExtension.substring(0, charsToKeep) + "..." + extension;
  } catch (e) {

    print("Error shortening file name '$path': $e");
    return path.length > maxLength ? path.substring(0, maxLength - 3) + "..." : path;
  }
}

class _AppealCreateWizardScreenState extends State<AppealCreateWizardScreen> {
  int _currentStep = 0;
  final _formKeys = [
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
  ];

  String _address = '';
  int? _categoryId;
  String _description = '';
  String? _imagePath;
  String? _pdfPath;

  bool _isAgreementAccepted = false;
  String? _agreementLoadingError;
  bool _isAgreementLoading = false;

  List<AppealCategory> _categories = [];
  String? _fileError;
  bool _isLoading = false;
  String? _error;

  final String _agreementUrl = 'https://storage.yandexcloud.net/housinginspection/knowledge_base/privacy_policy.md';


  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final categoryProvider = Provider.of<CategoryProvider>(context, listen: false);
      _categories = categoryProvider.categories;
      if (_categories.isEmpty) {
        await categoryProvider.fetchCategories();
        _categories = categoryProvider.categories;
      }
      if (_categories.isNotEmpty && _categoryId == null) {
        if (mounted) {
          setState(() { _categoryId = _categories.first.id; });
        }
      }
    } catch (e) {
      print("Error loading categories: $e");
      if (mounted) {
        setState(() { _error = "Ошибка загрузки категорий: $e"; });
      }
    }
  }

  Future<void> _pickImage() async {
    if (!mounted) return;
    setState(() { _fileError = null; });
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null && mounted) {
        setState(() { _imagePath = result.files.single.path!; });
      }
    } catch (e) {
      print("Image picking error: $e");
      if (mounted) setState(() { _fileError = 'Ошибка при выборе изображения: $e'; });
    }
  }

  Future<void> _pickPdf() async {
    if (!mounted) return;
    setState(() { _fileError = null; });
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null && mounted) {
        setState(() { _pdfPath = result.files.single.path!; });
      }
    } catch (e) {
      print("PDF picking error: $e");
      if (mounted) setState(() { _fileError = 'Ошибка при выборе PDF: $e'; });
    }
  }

  Future<void> _takePicture() async {
    if (!mounted) return;
    setState(() { _fileError = null; });
    try {
      final ImagePicker picker = ImagePicker();

      final XFile? photo = await picker.pickImage(source: ImageSource.camera);

      if (photo != null && mounted) {
        setState(() { _imagePath = photo.path; });
      }
    } catch (e) {
      print("Camera error: $e");
      if (mounted) setState(() { _fileError = 'Ошибка при съемке фото: $e'; });
    }
  }

  Widget _buildFilePreview(String path) {
    final extension = path.split('.').last.toLowerCase();
    const int maxLen = 20;

    if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(extension)) {
      return SizedBox(
        width: 100, height: 100,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: kIsWeb
              ? Icon(Icons.image, size: 64)
              : Image.file(File(path), fit: BoxFit.cover),
        ),
      );
    }
    else {
      return Container(
        width: 100, height: 100, padding: EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon( extension == 'pdf' ? Icons.picture_as_pdf_outlined : Icons.insert_drive_file_outlined, size: 40),
            SizedBox(height: 4),
            Text(
              _shortenFileName(path, maxLen),
              textAlign: TextAlign.center, overflow: TextOverflow.ellipsis,
              maxLines: 2, style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _showAgreement() async {
    if (!mounted) return;
    setState(() {
      _isAgreementLoading = true;
      _agreementLoadingError = null;
    });

    String? agreementContent;
    try {
      print("Loading agreement from: $_agreementUrl");
      final response = await http.get(Uri.parse(_agreementUrl));
      if (!mounted) return;

      if (response.statusCode == 200) {
        agreementContent = utf8.decode(response.bodyBytes);
        print("Agreement loaded successfully.");
      } else {
        print("Failed to load agreement. Status code: ${response.statusCode}");
        throw Exception('Ошибка загрузки (${response.statusCode})');
      }
    } catch (e) {
      print("Error loading agreement: $e");
      if (mounted) {
        setState(() { _agreementLoadingError = 'Не удалось загрузить текст соглашения: $e'; });
      }
    } finally {
      if (mounted) {
        setState(() { _isAgreementLoading = false; });
      }
    }

    if (mounted) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Пользовательское соглашение'),
            content: _isAgreementLoading
                ? Center(child: CircularProgressIndicator())
                : _agreementLoadingError != null
                ? Text(_agreementLoadingError!, style: TextStyle(color: Colors.red))
                : agreementContent != null
                ? SingleChildScrollView(
              child: MarkdownBody(
                data: agreementContent,
                onTapLink: (text, href, title) {
                  if (href != null) {
                    launchUrl(Uri.parse(href));
                  }
                },
              ),
            )
                : Text('Текст соглашения не удалось отобразить.'),
            actions: <Widget>[
              TextButton(
                child: const Text('Закрыть'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
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
          ? const Center(child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
      ))
          : Stepper(
        type: StepperType.vertical,
        currentStep: _currentStep,
        onStepContinue: () {
          bool isCurrentStepValid = true;
          if (_currentStep < _formKeys.length && _formKeys[_currentStep].currentState != null) {
            isCurrentStepValid = _formKeys[_currentStep].currentState!.validate();
            if (isCurrentStepValid) {
              _formKeys[_currentStep].currentState!.save();
            }
          }
          if (_currentStep == 3 && (_imagePath == null || _pdfPath == null)) {
            setState(() { _fileError = 'Необходимо прикрепить изображение и PDF файл.'; });
            isCurrentStepValid = false;
          } else if (_currentStep == 3) {
            setState(() { _fileError = null; });
          }
          if (_currentStep == 4 && !_isAgreementAccepted) {
            setState(() { _error = 'Ошибка: Примите условия Пользовательского соглашения.'; });
            isCurrentStepValid = false;
          } else if (_currentStep == 4) {
            setState(() { _error = null; });
          }

          if (isCurrentStepValid) {
            if (_currentStep < 4) {
              setState(() { _currentStep += 1; });
            }
            else {
              _submitAppeal();
            }
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() { _currentStep -= 1; });
          }
        },
        onStepTapped: (int index) {
          if (index <= _currentStep) {
            bool canGo = true;
            for (int i = 0; i < index; i++) {
              if (i < _formKeys.length && _formKeys[i].currentState != null && !_formKeys[i].currentState!.validate()) {
                canGo = false;
                break;
              }
              if (i == 3 && (_imagePath == null || _pdfPath == null)) {
                canGo = false;
                break;
              }
            }
            if (canGo) {
              setState(() { _currentStep = index; });
            }
          }
        },
        steps: [
          // --- Шаг 0: Адрес ---
          Step(
            title: const Text('Адрес'),
            content: Form(
              key: _formKeys[0],
              child: TextFormField(
                initialValue: _address,
                decoration: const InputDecoration(labelText: 'Введите адрес', hintText: 'ул. Примерная, д. 1, кв. 10'),
                minLines: 1,
                maxLines: 2,
                maxLength: 96,
                keyboardType: TextInputType.streetAddress,
                inputFormatters: [ FilteringTextInputFormatter.deny(RegExp(r'\n')) ],
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Пожалуйста, введите адрес';
                  if (value.length < 5) return 'Адрес должен содержать не менее 5 символов';
                  if (value.length > 96) return 'Адрес не должен превышать 96 символов';
                  return null;
                },
                onSaved: (value) { _address = value!; },
              ),
            ),
            isActive: _currentStep >= 0,
            state: _getStepState(0),
          ),

          // --- Шаг 1: Категория ---
          Step(
            title: const Text('Категория'),
            content: Form(
              key: _formKeys[1],
              child: DropdownButtonFormField<int>(
                decoration: const InputDecoration( labelText: 'Выберите категорию' ),
                value: _categoryId,
                items: _categories.isNotEmpty
                    ? _categories.map((category) {
                  return DropdownMenuItem<int>(
                    value: category.id,
                    child: Text(category.name),
                  );
                }).toList()
                    : [],
                onChanged: _categories.isNotEmpty ? (value) {
                  setState(() { _categoryId = value!; });
                } : null,
                validator: (value) {
                  if (value == null) return 'Пожалуйста, выберите категорию';
                  return null;
                },
                onSaved: (value) { _categoryId = value;},
                hint: _categories.isEmpty ? Text('Загрузка категорий...') : null,
                disabledHint: _categories.isEmpty ? Text('Категории не загружены') : null,
              ),
            ),
            isActive: _currentStep >= 1,
            state: _getStepState(1),
          ),

          // --- Шаг 2: Описание ---
          Step(
            title: const Text('Описание'),
            content: Form(
              key: _formKeys[2],
              child: TextFormField(
                initialValue: _description,
                decoration: const InputDecoration( labelText: 'Описание проблемы (необязательно)', alignLabelWithHint: true ),
                minLines: 1,
                maxLines: 3,
                maxLength: 256,
                keyboardType: TextInputType.multiline,
                validator: (value) {
                  if (value != null && value.length > 256) return 'Описание не должно превышать 256 символов';
                  return null;
                },
                onSaved: (value) { _description = value ?? ''; },
              ),
            ),
            isActive: _currentStep >= 2,
            state: _getStepState(2),
          ),

          // --- Шаг 3: Файлы ---
          Step(
            title: const Text('Файлы'),
            content: Form(
              key: _formKeys[3],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Изображение (JPG, PNG...) - обязательно:', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  if (_imagePath != null)
                    Row(
                      children: [
                        _buildFilePreview(_imagePath!),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: Colors.red),
                          tooltip: 'Удалить фото',
                          onPressed: () => setState(() => _imagePath = null),
                        )
                      ],
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(onPressed: _pickImage, icon: Icon(Icons.image_search), label: const Text('Выбрать')),
                        ElevatedButton.icon(onPressed: _takePicture, icon: Icon(Icons.camera_alt), label: const Text('Сделать фото')),
                      ],
                    ),
                  const SizedBox(height: 16),

                  Text('Документ PDF - обязательно:', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  if (_pdfPath != null)
                    Row(
                      children: [
                        _buildFilePreview(_pdfPath!),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: Colors.red),
                          tooltip: 'Удалить PDF',
                          onPressed: () => setState(() => _pdfPath = null),
                        )
                      ],
                    )
                  else
                    Center( child: ElevatedButton.icon( onPressed: _pickPdf, icon: Icon(Icons.picture_as_pdf), label: const Text('Выбрать PDF'))),

                  if (_fileError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text( _fileError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                    ),
                ],
              ),
            ),
            isActive: _currentStep >= 3,
            state: _getStepState(3),
          ),

          // --- Шаг 4: Подтверждение и Соглашение ---
          Step(
            title: const Text('Подтверждение'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Проверьте введенные данные:', style: Theme.of(context).textTheme.titleMedium),
                Divider(),
                Text('Адрес: $_address'),
                Text('Категория: ${_categoryId != null && _categories.isNotEmpty ? _categories.firstWhere((cat) => cat.id == _categoryId, orElse: () => AppealCategory(id: 0, name: 'Неизвестно')).name : "Не выбрана"}'),
                Text('Описание: ${_description.isNotEmpty ? _description : "Нет"}'),
                const SizedBox(height: 10),
                Text('Прикрепленные файлы:', style: Theme.of(context).textTheme.titleSmall),
                if (_imagePath != null) Row(children: [ Icon(Icons.image_outlined, size: 18, color: Colors.grey[700]), SizedBox(width: 5), Expanded(child: Text(_shortenFileName(_imagePath!, 32), overflow: TextOverflow.ellipsis))]),
                if (_pdfPath != null) Row(children: [ Icon(Icons.picture_as_pdf_outlined, size: 18, color: Colors.grey[700]), SizedBox(width: 5), Expanded(child: Text(_shortenFileName(_pdfPath!, 30), overflow: TextOverflow.ellipsis))]),
                Divider(height: 20),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Checkbox(
                      value: _isAgreementAccepted,
                      onChanged: (bool? value) {
                        setState(() { _isAgreementAccepted = value ?? false; });
                      },
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).textTheme.bodySmall?.color),
                          children: <TextSpan>[
                            TextSpan(text: 'Я принимаю условия '),
                            TextSpan(
                                text: 'Пользовательского соглашения',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  decoration: TextDecoration.underline,
                                  decorationColor: Theme.of(context).colorScheme.primary,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    _showAgreement();
                                  }),
                            TextSpan(text: '.'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (_error != null && _error!.contains("Примите условия"))
                  Padding(
                    padding: const EdgeInsets.only(left: 48.0, top: 0),
                    child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                if (_error != null && !_error!.contains("Примите условия"))
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
              ],
            ),
            isActive: _currentStep >= 4,
            state: _getStepState(4),
          ),
        ],
        controlsBuilder: (BuildContext context, ControlsDetails details) {
          return Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                if (_currentStep > 0)
                  OutlinedButton(
                    onPressed: details.onStepCancel,
                    child: const Text('Назад'),
                  ),
                if (_currentStep == 0)
                  Container(),
                ElevatedButton(
                  onPressed: details.onStepContinue,
                  child: Text(_currentStep == 4 ? 'Отправить' : 'Далее'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  StepState _getStepState(int stepIndex) {
    if (_currentStep > stepIndex) {
      if (stepIndex < _formKeys.length && _formKeys[stepIndex].currentState != null) {
        return _formKeys[stepIndex].currentState!.validate() ? StepState.complete : StepState.error;
      }
      if (stepIndex == 3) {
        return (_imagePath != null && _pdfPath != null) ? StepState.complete : StepState.error;
      }
      if (stepIndex == 4) {
        return _isAgreementAccepted ? StepState.complete : StepState.error;
      }
      return StepState.complete;
    }
    else if (_currentStep == stepIndex) {
      if (stepIndex == 4 && _error != null && _error!.contains("Примите условия")) {
        return StepState.error;
      }
      if (stepIndex == 3 && _fileError != null) {
        return StepState.error;
      }
      return StepState.editing;
    }
    else {
      return StepState.indexed;
    }
  }

  Future<void> _submitAppeal() async {
    if (!mounted || _isLoading) return;
    setState(() { _error = null; _fileError = null; });

    if (!_isAgreementAccepted) {
      setState(() {
        _error = 'Ошибка: Примите условия Пользовательского соглашения.';
        _currentStep = 4;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_error!), backgroundColor: Colors.orange[700]),
      );
      return;
    }

    bool allFormsValid = true;
    for (int i = 0; i < _formKeys.length; i++) {
      if (_formKeys[i].currentState == null || !_formKeys[i].currentState!.validate()) {
        allFormsValid = false;
        setState(() { _currentStep = i; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Пожалуйста, исправьте ошибки на шаге ${i + 1}.')),
        );
        return;
      }
      _formKeys[i].currentState!.save();
    }

    if (_imagePath == null || _pdfPath == null) {
      setState(() {
        _fileError = 'Необходимо прикрепить одно изображение и один PDF файл.';
        _currentStep = 3;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_fileError!)),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _fileError = null;
    });

    try {
      final newAppeal = Appeal(
        id: 0, userId: 0,
        categoryId: _categoryId!,
        statusId: Provider.of<StatusProvider>(context, listen: false).statuses.firstWhere((s) => s.name == 'Новое', orElse: () => AppealStatus(id: 1, name:'Новое')).id,
        address: _address,
        description: _description,
        createdAt: DateTime.now(), updatedAt: DateTime.now(),
      );

      final filesToSend = [_imagePath!, _pdfPath!];

      print("Submitting appeal...");
      await Provider.of<AppealProvider>(context, listen: false)
          .addAppeal(newAppeal, filesToSend);
      print("Appeal submitted successfully!");

      if (mounted) Navigator.of(context).pop(true);

    } catch (e) {
      print("Error submitting appeal: $e");
      if (mounted) {
        setState(() {
          _error = 'Ошибка при отправке обращения: $e';
          _currentStep = 4;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}