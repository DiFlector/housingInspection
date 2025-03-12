import 'package:flutter/material.dart';
import 'package:housing_inspection_client/models/appeal_category.dart';
import 'package:housing_inspection_client/providers/category_provider.dart';
import 'package:provider/provider.dart';
import 'package:housing_inspection_client/models/api_exception.dart';

class CategoryEditScreen extends StatefulWidget {
  final AppealCategory? category;

  const CategoryEditScreen({super.key, required this.category});

  @override
  _CategoryEditScreenState createState() => _CategoryEditScreenState();
}

class _CategoryEditScreenState extends State<CategoryEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _nameController.text = widget.category!.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      setState(() {
        _isLoading = true;
        _error = null;
      });

      try {
        if (widget.category == null) {
          final newCategory = AppealCategory(id: 0, name: _nameController.text);
          await Provider.of<CategoryProvider>(context, listen: false).addCategory(newCategory);
        } else {
          final updatedCategory = AppealCategory(id: widget.category!.id, name: _nameController.text);
          await Provider.of<CategoryProvider>(context, listen: false).updateCategory(updatedCategory);
        }
        Navigator.of(context).pop();
      } on ApiException catch (e) {
        setState(() {
          _error = e.message;
        });
      } catch (e) {
        setState(() {
          _error = 'Error saving category: $e';
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category == null ? 'Создать категорию' : 'Редактировать категорию'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Название категории'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Пожалуйста, введите название категории';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                onPressed: _submit,
                child: const Text('Сохранить'),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}