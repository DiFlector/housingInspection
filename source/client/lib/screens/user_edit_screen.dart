import 'package:flutter/material.dart';
import 'package:housing_inspection_client/models/user.dart';
import 'package:housing_inspection_client/providers/user_provider.dart';
import 'package:provider/provider.dart';

class UserEditScreen extends StatefulWidget {
  final User? user; //  Может быть null (для создания)

  const UserEditScreen({super.key, required this.user});

  @override
  _UserEditScreenState createState() => _UserEditScreenState();
}

class _UserEditScreenState extends State<UserEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _fullNameController = TextEditingController();
  String? _role;
  bool _isActive = true;

  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.user != null) {
      _usernameController.text = widget.user!.username;
      _emailController.text = widget.user!.email;
      _fullNameController.text = widget.user!.fullName ?? '';
      _role = widget.user!.role;
      _isActive = widget.user!.isActive;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _fullNameController.dispose();
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
        if (widget.user == null) {
          // Создание нового пользователя
          final newUser = User(
            id: 0, // ID = 0 - признак нового пользователя (backend заменит на реальный)
            username: _usernameController.text,
            email: _emailController.text,
            fullName: _fullNameController.text,
            role: _role!,
            isActive: _isActive,
            createdAt: DateTime.now(),  // Временное значение
          );
          await Provider.of<UserProvider>(context, listen: false)
              .addUser(newUser, _passwordController.text); // Передаём пароль
        } else {
          // Редактирование существующего пользователя
          final updatedUser = User(
            id: widget.user!.id,  //  ID берем из widget.user
            username: _usernameController.text,
            email: _emailController.text,
            fullName: _fullNameController.text,
            role: _role!,
            isActive: _isActive,
            createdAt: widget.user!.createdAt, // Используем старое время создания
          );
          await Provider.of<UserProvider>(context, listen: false).updateUser(updatedUser);
        }

        Navigator.of(context).pop(); //  Возвращаемся назад после сохранения
      } catch (e) {
        setState(() {
          _error = 'Error saving user: $e';
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
        title: Text(widget.user == null ? 'Create User' : 'Edit User'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a username';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an email address';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              if (widget.user == null) ...[
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 8) {
                      return 'Password must be at least 8 characters long';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _passwordConfirmController,
                  decoration:
                  const InputDecoration(labelText: 'Confirm Password'),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm the password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
              ],
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Role'),
                value: _role,
                items: const [
                  DropdownMenuItem(value: 'citizen', child: Text('Citizen')),
                  DropdownMenuItem(value: 'inspector', child: Text('Inspector')),
                ],
                onChanged: (value) {
                  setState(() {
                    _role = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a role';
                  }
                  return null;
                },
              ),
              SwitchListTile(
                title: const Text('Active'),
                value: _isActive,
                onChanged: (value) {
                  setState(() {
                    _isActive = value;
                  });
                },
              ),
              const SizedBox(height: 20),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                onPressed: _submit,
                child: const Text('Save'),
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