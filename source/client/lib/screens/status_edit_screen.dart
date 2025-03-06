import 'package:flutter/material.dart';
import 'package:housing_inspection_client/providers/status_provider.dart';
import 'package:provider/provider.dart';
import 'package:housing_inspection_client/models/appeal_status.dart';
import 'package:housing_inspection_client/models/api_exception.dart';

class StatusEditScreen extends StatefulWidget {
  final AppealStatus? status;

  const StatusEditScreen({super.key, required this.status});

  @override
  _StatusEditScreenState createState() => _StatusEditScreenState();
}

class _StatusEditScreenState extends State<StatusEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.status != null) {
      _nameController.text = widget.status!.name;
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
        if (widget.status == null) {
          final newStatus = AppealStatus(id: 0, name: _nameController.text);
          await Provider.of<StatusProvider>(context, listen: false).addStatus(newStatus);
        } else {
          final updatedStatus = AppealStatus(id: widget.status!.id, name: _nameController.text);
          await Provider.of<StatusProvider>(context, listen: false).updateStatus(updatedStatus);
        }
        Navigator.of(context).pop();
      } on ApiException catch (e) {
        setState(() {
          _error = e.message;
        });
      }
      catch (e) {
        setState(() {
          _error = 'Error saving status: $e';
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
        title: Text(widget.status == null ? 'Создать статус' : 'Редактировать статус'), //  Перевод
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Название статуса'), //  Перевод
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Пожалуйста, введите название статуса'; //  Перевод
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                onPressed: _submit,
                child: const Text('Сохранить'), //  Перевод
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