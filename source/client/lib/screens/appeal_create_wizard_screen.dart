// Файл: client/lib/screens/appeal_create_wizard_screen.dart
import 'package:flutter/gestures.dart'; // Для TapGestureRecognizer (ссылки в тексте)
import 'package:flutter/material.dart';
import 'package:housing_inspection_client/models/appeal_category.dart'; // Модель категории
import 'package:housing_inspection_client/models/appeal_status.dart'; // Модель статуса
import 'package:housing_inspection_client/providers/appeal_provider.dart'; // Провайдер обращений
import 'package:housing_inspection_client/providers/category_provider.dart'; // Провайдер категорий
import 'package:housing_inspection_client/providers/status_provider.dart'; // Провайдер статусов
import 'package:provider/provider.dart'; // Для Provider.of
import 'package:file_picker/file_picker.dart'; // Для выбора файлов
import 'package:image_picker/image_picker.dart'; // Для съемки фото
import 'dart:io'; // Для работы с File
import 'package:housing_inspection_client/models/appeal.dart'; // Модель обращения
import 'package:flutter/foundation.dart' show kIsWeb; // Для определения платформы (веб)
import 'package:flutter/services.dart'; // Для FilteringTextInputFormatter
import 'package:path/path.dart' as p; // Для работы с путями файлов
import 'package:http/http.dart' as http; // Для загрузки текста соглашения
import 'package:flutter_markdown/flutter_markdown.dart'; // Для отображения Markdown
import 'package:url_launcher/url_launcher.dart'; // Для открытия ссылок
import 'dart:convert'; // Для utf8.decode
import 'dart:math'; // Для min() в _shortenFileName

// --- Виджет экрана мастера создания обращения ---
class AppealCreateWizardScreen extends StatefulWidget {
  const AppealCreateWizardScreen({Key? key}) : super(key: key);

  @override
  State<AppealCreateWizardScreen> createState() => _AppealCreateWizardScreenState();
}

// --- Утилита для сокращения имени файла ---
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

// --- Состояние виджета мастера ---
class _AppealCreateWizardScreenState extends State<AppealCreateWizardScreen> {
  int _currentStep = 0; // Текущий активный шаг мастера
  final _formKeys = [
    GlobalKey<FormState>(), // Шаг 0: Адрес (теперь 4 поля)
    GlobalKey<FormState>(), // Шаг 1: Категория
    GlobalKey<FormState>(), // Шаг 2: Описание
    GlobalKey<FormState>(), // Шаг 3: Файлы
  ];

  // --- Состояние полей формы ---
  // ИЗМЕНЕНО: Добавляем город
  String _city = '';           // Город
  String _street = '';         // Улица/Проспект/Шоссе
  String _houseNumber = '';    // Номер дома
  String _apartmentNumber = '';// Номер квартиры (необязательный)

  int? _categoryId; // ID выбранной категории
  String _description = ''; // Введенное описание
  String? _imagePath; // Путь к фото
  String? _pdfPath; // Путь к PDF

  // --- Состояние для шага соглашения ---
  bool _isAgreementAccepted = false;
  String? _agreementLoadingError;
  bool _isAgreementLoading = false;

  // --- Общее состояние ---
  List<AppealCategory> _categories = [];
  String? _fileError;
  bool _isLoading = false; // Флаг отправки обращения
  String? _error; // Общая ошибка

  // --- URL соглашения ---
  final String _agreementUrl = 'https://storage.yandexcloud.net/housinginspection/knowledge_base/privacy_policy.md';


  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  // --- Загрузка категорий ---
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

  // --- Выбор изображения ---
  Future<void> _pickImage() async {
    if (!mounted) return;
    setState(() { _fileError = null; });
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles( type: FileType.image, allowMultiple: false );
      if (result != null && result.files.single.path != null && mounted) {
        setState(() { _imagePath = result.files.single.path!; });
      }
    } catch (e) {
      print("Image picking error: $e");
      if (mounted) setState(() { _fileError = 'Ошибка при выборе изображения: $e'; });
    }
  }

  // --- Съемка фото ---
  Future<void> _takePicture() async {
    if (!mounted) return;
    setState(() { _fileError = null; });
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(source: ImageSource.camera);
      if (photo != null && mounted) { setState(() { _imagePath = photo.path; }); }
    } catch (e) {
      print("Camera error: $e");
      if (mounted) setState(() { _fileError = 'Ошибка при съемке фото: $e'; });
    }
  }

  // --- Выбор PDF ---
  Future<void> _pickPdf() async {
    if (!mounted) return;
    setState(() { _fileError = null; });
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles( type: FileType.custom, allowedExtensions: ['pdf'], allowMultiple: false );
      if (result != null && result.files.single.path != null && mounted) { setState(() { _pdfPath = result.files.single.path!; }); }
    } catch (e) {
      print("PDF picking error: $e");
      if (mounted) setState(() { _fileError = 'Ошибка при выборе PDF: $e'; });
    }
  }

  // --- Генерация превью файла ---
  Widget _buildFilePreview(String path) {
    final extension = path.split('.').last.toLowerCase();
    const int maxLen = 20;
    if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(extension)) {
      return SizedBox( width: 100, height: 100, child: ClipRRect( borderRadius: BorderRadius.circular(8.0), child: kIsWeb ? Icon(Icons.image, size: 64) : Image.file(File(path), fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) { print("Error loading image preview for $path: $error"); return Icon(Icons.broken_image, size: 64); }), ), );
    } else {
      return Container( width: 100, height: 100, padding: EdgeInsets.all(4), decoration: BoxDecoration( border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8.0), ), child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [ Icon( extension == 'pdf' ? Icons.picture_as_pdf_outlined : Icons.insert_drive_file_outlined, size: 40), SizedBox(height: 4), Text( _shortenFileName(path, maxLen), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, maxLines: 2, style: TextStyle(fontSize: 12), ), ], ), );
    }
  }

  // --- Показ соглашения ---
  Future<void> _showAgreement() async {
    if (!mounted) return;
    setState(() { _isAgreementLoading = true; _agreementLoadingError = null; });
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
      if (mounted) { setState(() { _agreementLoadingError = 'Не удалось загрузить текст соглашения: $e'; }); }
    } finally {
      if (mounted) { setState(() { _isAgreementLoading = false; }); }
    }
    if (mounted) {
      showDialog( context: context, builder: (BuildContext context) {
        return AlertDialog( title: const Text('Пользовательское соглашение'), content: _isAgreementLoading ? Center(child: CircularProgressIndicator()) : _agreementLoadingError != null ? Text(_agreementLoadingError!, style: TextStyle(color: Colors.red)) : agreementContent != null ? Scrollbar( thumbVisibility: true, child: SingleChildScrollView( child: MarkdownBody( data: agreementContent, onTapLink: (text, href, title) { if (href != null) { launchUrl(Uri.parse(href)); } }, ), ), ) : Text('Текст соглашения не удалось отобразить.'), actions: <Widget>[ TextButton( child: const Text('Закрыть'), onPressed: () { Navigator.of(context).pop(); }, ), ], );
      },
      );
    }
  }

  // --- Основной метод сборки UI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar( title: const Text('Подача обращения'), ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator( valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple) ))
          : Stepper(
        type: StepperType.vertical,
        currentStep: _currentStep,
        onStepContinue: () { /* ... (логика перехода/отправки из предыдущего шага) ... */
          bool isCurrentStepValid = true;
          if (_currentStep < _formKeys.length && _formKeys[_currentStep].currentState != null) { isCurrentStepValid = _formKeys[_currentStep].currentState!.validate(); if (isCurrentStepValid) { _formKeys[_currentStep].currentState!.save(); } }
          if (_currentStep == 3 && (_imagePath == null || _pdfPath == null)) { setState(() { _fileError = 'Необходимо прикрепить изображение и PDF файл.'; }); isCurrentStepValid = false; } else if (_currentStep == 3) { setState(() { _fileError = null; }); }
          if (_currentStep == 4 && !_isAgreementAccepted) { setState(() { _error = 'Ошибка: Примите условия Пользовательского соглашения.'; }); isCurrentStepValid = false; } else if (_currentStep == 4) { setState(() { _error = null; }); }
          if (isCurrentStepValid) { if (_currentStep < 4) { setState(() { _currentStep += 1; }); } else { _submitAppeal(); } }
        },
        onStepCancel: () { if (_currentStep > 0) { setState(() { _currentStep -= 1; }); } },
        onStepTapped: (int index) { /* ... (логика перехода по заголовкам) ... */
          if (index <= _currentStep) { bool canGo = true; for (int i = 0; i < index; i++) { if (i < _formKeys.length && _formKeys[i].currentState != null && !_formKeys[i].currentState!.validate()) { canGo = false; break; } if (i == 3 && (_imagePath == null || _pdfPath == null)) { canGo = false; break; } } if (canGo) { setState(() { _currentStep = index; }); } }
        },
        steps: [
          // --- Шаг 0: Адрес (ИЗМЕНЕНО) ---
          Step(
            title: const Text('Адрес'),
            content: Form(
              key: _formKeys[0], // Ключ для этой формы
              child: Column( // Используем колонку для ЧЕТЫРЕХ полей
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ИЗМЕНЕНО: Поле "Город" добавлено в начало
                  TextFormField(
                    initialValue: _city,
                    decoration: const InputDecoration(labelText: 'Город*', hintText: 'Москва / Санкт-Петербург'),
                    keyboardType: TextInputType.text,
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Пожалуйста, введите город';
                      if (value.length < 2) return 'Название должно быть не менее 2 символов';
                      if (value.length > 50) return 'Название не должно превышать 50 символов';
                      return null;
                    },
                    onSaved: (value) { _city = value?.trim() ?? ''; },
                  ),
                  SizedBox(height: 8),
                  // Поле "Улица"
                  TextFormField(
                    initialValue: _street,
                    decoration: const InputDecoration(labelText: 'Улица/Шоссе/Проспект*', hintText: 'ул. Примерная / пр-кт Космонавтов'),
                    keyboardType: TextInputType.streetAddress,
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Пожалуйста, введите улицу';
                      if (value.length < 3) return 'Название должно быть не менее 3 символов';
                      if (value.length > 60) return 'Название не должно превышать 60 символов';
                      return null;
                    },
                    onSaved: (value) { _street = value?.trim() ?? ''; },
                  ),
                  SizedBox(height: 8),
                  // Поле "Дом"
                  TextFormField(
                    initialValue: _houseNumber,
                    decoration: const InputDecoration(labelText: 'Дом*', hintText: '1к2 стр.3 / 5А'),
                    keyboardType: TextInputType.text,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return 'Пожалуйста, введите номер дома';
                      if (value.length > 20) return 'Номер дома не должен превышать 20 символов';
                      if (!value.contains(RegExp(r'[0-9]'))) return 'Введите корректный номер дома';
                      return null;
                    },
                    onSaved: (value) { _houseNumber = value?.trim() ?? ''; },
                  ),
                  SizedBox(height: 8),
                  // Поле "Квартира"
                  TextFormField(
                    initialValue: _apartmentNumber,
                    decoration: const InputDecoration(labelText: 'Квартира/Офис', hintText: '10 (необязательно)'),
                    keyboardType: TextInputType.text,
                    validator: (value) {
                      if (value != null && value.isNotEmpty && value.length > 15) return 'Номер не должен превышать 15 символов';
                      return null;
                    },
                    onSaved: (value) { _apartmentNumber = value?.trim() ?? ''; },
                  ),
                ],
              ),
            ),
            isActive: _currentStep >= 0,
            state: _getStepState(0),
          ),

          // --- Шаг 1: Категория (Без изменений) ---
          Step(
            title: const Text('Категория'),
            content: Form( key: _formKeys[1], child: DropdownButtonFormField<int>( decoration: const InputDecoration( labelText: 'Выберите категорию*' ), value: _categoryId, items: _categories.isNotEmpty ? _categories.map((category) { return DropdownMenuItem<int>( value: category.id, child: Text(category.name), ); }).toList() : [], onChanged: _categories.isNotEmpty ? (value) { setState(() { _categoryId = value!; }); } : null, validator: (value) { if (value == null) return 'Пожалуйста, выберите категорию'; return null; }, onSaved: (value) { _categoryId = value;}, hint: _categories.isEmpty ? Text('Загрузка категорий...') : null, disabledHint: _categories.isEmpty ? Text('Категории не загружены') : null, ), ),
            isActive: _currentStep >= 1, state: _getStepState(1),
          ),

          // --- Шаг 2: Описание (Без изменений) ---
          Step(
            title: const Text('Описание'),
            content: Form( key: _formKeys[2], child: TextFormField( initialValue: _description, decoration: const InputDecoration( labelText: 'Описание проблемы (необязательно)', alignLabelWithHint: true ), minLines: 3, maxLines: 8, maxLength: 1000, keyboardType: TextInputType.multiline, validator: (value) { if (value != null && value.length > 1000) return 'Описание не должно превышать 1000 символов'; return null; }, onSaved: (value) { _description = value ?? ''; }, ), ),
            isActive: _currentStep >= 2, state: _getStepState(2),
          ),

          // --- Шаг 3: Файлы (Без изменений) ---
          Step(
            title: const Text('Файлы'),
            content: Form( key: _formKeys[3], child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [ Text('Изображение (JPG, PNG...) - обязательно*:', style: Theme.of(context).textTheme.titleSmall), const SizedBox(height: 8), if (_imagePath != null) Row( children: [ _buildFilePreview(_imagePath!), IconButton( icon: Icon(Icons.delete_outline, color: Colors.red), tooltip: 'Удалить фото', onPressed: () => setState(() => _imagePath = null))]) else Row( mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [ ElevatedButton.icon(onPressed: _pickImage, icon: Icon(Icons.image_search), label: const Text('Выбрать')), ElevatedButton.icon(onPressed: _takePicture, icon: Icon(Icons.camera_alt), label: const Text('Сделать фото'))]), const SizedBox(height: 16), Text('Документ PDF - обязательно*:', style: Theme.of(context).textTheme.titleSmall), const SizedBox(height: 8), if (_pdfPath != null) Row(children: [ _buildFilePreview(_pdfPath!), IconButton( icon: Icon(Icons.delete_outline, color: Colors.red), tooltip: 'Удалить PDF', onPressed: () => setState(() => _pdfPath = null))]) else Center( child: ElevatedButton.icon( onPressed: _pickPdf, icon: Icon(Icons.picture_as_pdf), label: const Text('Выбрать PDF'))), if (_fileError != null) Padding( padding: const EdgeInsets.only(top: 10), child: Text( _fileError!, style: const TextStyle(color: Colors.red, fontSize: 12))), ], ), ),
            isActive: _currentStep >= 3, state: _getStepState(3),
          ),

          // --- Шаг 4: Подтверждение и Соглашение (ИЗМЕНЕНО отображение адреса) ---
          Step(
            title: const Text('Подтверждение'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Проверьте введенные данные:', style: Theme.of(context).textTheme.titleMedium),
                Divider(),
                // ИЗМЕНЕНО: Отображаем адрес по частям, включая город
                Text('Город: $_city'),
                Text('Улица: $_street'),
                Text('Дом: $_houseNumber'),
                if (_apartmentNumber.isNotEmpty) Text('Квартира: $_apartmentNumber'),
                // Остальные данные
                Text('Категория: ${_categoryId != null && _categories.isNotEmpty ? _categories.firstWhere((cat) => cat.id == _categoryId, orElse: () => AppealCategory(id: 0, name: 'Неизвестно')).name : "Не выбрана"}'),
                Text('Описание: ${_description.isNotEmpty ? _description : "Нет"}'),
                const SizedBox(height: 10),
                Text('Прикрепленные файлы:', style: Theme.of(context).textTheme.titleSmall),
                if (_imagePath != null) Row(children: [ Icon(Icons.image_outlined, size: 18, color: Colors.grey[700]), SizedBox(width: 5), Expanded(child: Text(_shortenFileName(_imagePath!, 32), overflow: TextOverflow.ellipsis))]),
                if (_pdfPath != null) Row(children: [ Icon(Icons.picture_as_pdf_outlined, size: 18, color: Colors.grey[700]), SizedBox(width: 5), Expanded(child: Text(_shortenFileName(_pdfPath!, 30), overflow: TextOverflow.ellipsis))]),
                Divider(height: 20),

                // --- Блок соглашения (Без изменений) ---
                Row( crossAxisAlignment: CrossAxisAlignment.center, children: [ Checkbox( value: _isAgreementAccepted, onChanged: (bool? value) { setState(() { _isAgreementAccepted = value ?? false; }); }, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,), Expanded( child: RichText( text: TextSpan( style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).textTheme.bodySmall?.color), children: <TextSpan>[ TextSpan(text: 'Я принимаю условия '), TextSpan( text: 'Пользовательского соглашения', style: TextStyle( color: Theme.of(context).colorScheme.primary, decoration: TextDecoration.underline, decorationColor: Theme.of(context).colorScheme.primary), recognizer: TapGestureRecognizer()..onTap = _showAgreement ), TextSpan(text: '.'), ], ), ), ), ], ),
                // Отображение ошибок (Без изменений)
                if (_error != null && _error!.contains("Примите условия")) Padding( padding: const EdgeInsets.only(left: 48.0, top: 0), child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12))),
                if (_error != null && !_error!.contains("Примите условия")) Padding( padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: const TextStyle(color: Colors.red))),
              ],
            ),
            isActive: _currentStep >= 4,
            state: _getStepState(4),
          ),
        ],
        // --- Конструктор кнопок управления Stepper (Без изменений) ---
        controlsBuilder: (BuildContext context, ControlsDetails details) {
          return Padding( padding: const EdgeInsets.only(top: 16.0), child: Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: <Widget>[ if (_currentStep > 0) OutlinedButton( onPressed: details.onStepCancel, child: const Text('Назад')), if (_currentStep == 0) Container(), ElevatedButton( onPressed: (_currentStep == 4 && !_isAgreementAccepted) ? null : details.onStepContinue, child: Text(_currentStep == 4 ? 'Отправить' : 'Далее'), ), ], ), );
        },
      ),
    );
  }

  // --- Функция определения состояния шага (Без изменений) ---
  StepState _getStepState(int stepIndex) {
    if (_currentStep > stepIndex) { if (stepIndex < _formKeys.length && _formKeys[stepIndex].currentState != null) { return _formKeys[stepIndex].currentState!.validate() ? StepState.complete : StepState.error; } if (stepIndex == 3) { return (_imagePath != null && _pdfPath != null) ? StepState.complete : StepState.error; } if (stepIndex == 4) { return _isAgreementAccepted ? StepState.complete : StepState.error; } return StepState.complete; } else if (_currentStep == stepIndex) { if (stepIndex == 4 && _error != null && _error!.contains("Примите условия")) { return StepState.error; } if (stepIndex == 3 && _fileError != null) { return StepState.error; } return StepState.editing; } else { return StepState.indexed; }
  }

  // --- Функция отправки обращения (ИЗМЕНЕНО: сборка адреса) ---
  Future<void> _submitAppeal() async {
    if (!mounted || _isLoading) return;
    setState(() { _error = null; _fileError = null; });

    // 1. Проверка соглашения
    if (!_isAgreementAccepted) { setState(() { _error = 'Ошибка: Примите условия Пользовательского соглашения.'; _currentStep = 4; }); ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text(_error!), backgroundColor: Colors.orange[700])); return; }

    // 2. Валидация форм
    bool allFormsValid = true;
    for (int i = 0; i < _formKeys.length; i++) { if (_formKeys[i].currentState == null || !_formKeys[i].currentState!.validate()) { allFormsValid = false; setState(() { _currentStep = i; }); ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text('Пожалуйста, исправьте ошибки на шаге ${i + 1}.'))); return; } _formKeys[i].currentState!.save(); }

    // 3. Проверка файлов
    if (_imagePath == null || _pdfPath == null) { setState(() { _fileError = 'Необходимо прикрепить одно изображение и один PDF файл.'; _currentStep = 3; }); ScaffoldMessenger.of(context).showSnackBar( SnackBar(content: Text(_fileError!))); return; }

    // 4. Сборка полного адреса (ИЗМЕНЕНИЕ ЗДЕСЬ: добавляем город)
    // Добавляем префикс "г. ", если его еще нет и город не содержит его
    String cityPrefix = _city.toLowerCase().startsWith('г.') || _city.toLowerCase().startsWith('город') ? '' : 'г. ';
    // Добавляем префикс "д. ", если его еще нет и номер дома не содержит его или "к."/"стр."
    String housePrefix = _houseNumber.toLowerCase().startsWith('д.') || _houseNumber.contains(RegExp(r'[кс]')) ? '' : 'д. ';
    // Добавляем префикс "кв. ", если есть номер квартиры и его еще нет
    String aptPrefix = _apartmentNumber.isNotEmpty && !_apartmentNumber.toLowerCase().startsWith('кв.') ? ', кв. ' : (_apartmentNumber.isNotEmpty ? ', ' : '');

    String combinedAddress = "$cityPrefix$_city, $_street, $housePrefix$_houseNumber$aptPrefix$_apartmentNumber";
    // Убираем лишнюю запятую в конце, если квартиры нет
    if (_apartmentNumber.isEmpty && combinedAddress.endsWith(', ')) {
      combinedAddress = combinedAddress.substring(0, combinedAddress.length - 2);
    }


    // 5. Начинаем отправку
    setState(() { _isLoading = true; _error = null; _fileError = null; });

    try {
      final statusProvider = Provider.of<StatusProvider>(context, listen: false);
      final newStatus = statusProvider.statuses.firstWhere( (s) => s.name == 'Новое', orElse: () => AppealStatus(id: 1, name:'Новое') );

      // Создаем объект Appeal с собранным адресом
      final newAppeal = Appeal(
        id: 0, userId: 0, categoryId: _categoryId!, statusId: newStatus.id,
        address: combinedAddress, // Передаем собранный адрес
        description: _description,
        createdAt: DateTime.now(), updatedAt: DateTime.now(),
      );

      final filesToSend = [_imagePath!, _pdfPath!];

      print("Submitting appeal with address: $combinedAddress");
      await Provider.of<AppealProvider>(context, listen: false).addAppeal(newAppeal, filesToSend);
      print("Appeal submitted successfully!");

      if (mounted) Navigator.of(context).pop(true);

    } catch (e) {
      print("Error submitting appeal: $e");
      if (mounted) { setState(() { _error = 'Ошибка при отправке обращения: $e'; _currentStep = 4; }); }
    } finally {
      if (mounted) { setState(() { _isLoading = false; }); }
    }
  }
} // Конец класса _AppealCreateWizardScreenState