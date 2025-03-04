import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
  int _categoryId = 1;
  String _description = '';
  int _statusId = 1;
  List<String> _newFilePaths =
  [];
  final ApiService _apiService = ApiService();
  late List<AppealCategory> _categories = [];
  late List<AppealStatus> _statuses = [];
  Appeal? _appeal;
  bool _isLoading = true;
  String? _error; //  Добавили для отображения ошибок

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      _categories =
      await Provider.of<CategoryProvider>(context, listen: false).categories;
      _statuses =
      await Provider.of<StatusProvider>(context, listen: false).statuses;
      _appeal = Provider.of<AppealProvider>(context, listen: false)
          .appeals
          .firstWhere((a) => a.id == widget.appealId);

      _address = _appeal!.address;
      _categoryId = _appeal!.categoryId;
      _description = _appeal!.description ?? '';
      _statusId = _appeal!.statusId;

      setState(() {
        _isLoading = false;
      });
    } catch (e){ //  Ловим ошибки при загрузке данных
      setState(() {
        _isLoading = false;
        _error = 'Failed to load appeal data: $e';
      });
    }

  }

  Future<void> _pickFiles() async {
    FilePickerResult? result =
    await FilePicker.platform.pickFiles(allowMultiple: true);

    if (result != null) {
      setState(() {
        _newFilePaths
            .addAll(result.paths.map((path) => path!).toList());
      });
    }
  }

  Future<void> _takePicture() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);

    if (photo != null) {
      setState(() {
        _newFilePaths.add(photo.path);
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
      _isLoading ? const Center(child: CircularProgressIndicator()) :
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
                value: _statusId,
                items:_statuses.map((status) {
                  return DropdownMenuItem<int>(value: status.id, child: Text(status.name));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _statusId = value!;
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
                children: _newFilePaths.map((path) => Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: _buildFilePreview(path),
                )).toList(),
              ),

              if (_error != null)  //  Отображение ошибки
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

              ElevatedButton(
                onPressed: () async {  //  Делаем асинхронным
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();

                    final updatedAppeal = Appeal(
                        id: widget.appealId,
                        userId: _appeal!.userId,
                        categoryId: _categoryId,
                        statusId: _statusId,
                        address: _address,
                        description: _description,
                        createdAt: _appeal!.createdAt,
                        updatedAt: DateTime.now(),
                        filePaths: _appeal!.filePaths
                    );

                    setState(() {
                      _isLoading = true; //  Включаем индикатор
                      _error = null;     //  Сбрасываем ошибку
                    });

                    try {
                      await Provider.of<AppealProvider>(context, listen: false).updateAppealData(updatedAppeal, _newFilePaths);
                      Navigator.pop(context);
                    } catch (e){
                      setState(() {
                        _error = 'Error updating appeal: $e';
                      });
                    } finally {
                      setState(() {
                        _isLoading = false; //  В любом случае выключаем
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