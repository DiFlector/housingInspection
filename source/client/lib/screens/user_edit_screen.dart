import 'package:flutter/material.dart';
import 'package:housing_inspection_client/models/user.dart';
import 'package:housing_inspection_client/providers/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:housing_inspection_client/providers/auth_provider.dart'; //Импортируем

class UserEditScreen extends StatefulWidget {
  final User? user;

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
  //bool _isActive = true;  //  УДАЛЯЕМ
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
      //_isActive = widget.user!.is_active;  //  УДАЛЯЕМ
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
            id: 0,
            username: _usernameController.text,
            email: _emailController.text,
            fullName: _fullNameController.text,
            role: _role!,
            isActive: true, //  ВСЕГДА true при создании
            createdAt: DateTime.now(),
          );
          await Provider.of<UserProvider>(context, listen: false)
              .addUser(newUser, _passwordController.text);
        } else {
          // Редактирование существующего пользователя
          final updatedUser = User(
            id: widget.user!.id,
            username: _usernameController.text,
            email: _emailController.text,
            fullName: _fullNameController.text,
            role: _role!,
            isActive: widget.user!.isActive,  //  Берем из widget.user
            createdAt: widget.user!.createdAt,
          );
          await Provider.of<UserProvider>(context, listen: false)
              .updateUser(updatedUser);
        }

        Navigator.of(context).pop();
      } catch (e) {
        setState(() {
          _error = 'Ошибка при сохранении пользователя: $e';
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
    final currentRole = Provider.of<AuthProvider>(context, listen: false).role;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.user == null ? 'Создать пользователя' : 'Редактирование пользователя'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Имя пользователя'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Пожалуйста, введите имя пользователя';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Почта'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Пожалуйста, введите адрес почты';
                  }
                  if (!value.contains('@')) {
                    return 'Пожалуйста, введите правильный адрес почты';
                  }
                  return null;
                },
              ),
              if (widget.user == null) ...[
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Пароль'),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Пожалуйста, введите пароль';
                    }
                    if (value.length < 8) {
                      return 'Пароль должен быть не менее 8 символов';
                    }  if (!value.contains(RegExp(r'[0-9]'))) {
                      return 'Пароль должен содержать не менее 1 цифры';
                    }
                    if (!value.contains(RegExp(r'[A-Z]'))) {
                      return 'Пароль должен содержать не менее 1 заглавной буквы';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _passwordConfirmController,
                  decoration:
                  const InputDecoration(labelText: 'Подтвердите пароль'),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Пожалуйста, подтвердите пароль';
                    }
                    if (value != _passwordController.text) {
                      return 'Пароли не совпадают';
                    }
                    return null;
                  },
                ),
              ],
              TextFormField(
                controller: _fullNameController,
                decoration: const InputDecoration(labelText: 'Полное имя'),
              ),
              if (currentRole == "inspector")
                DropdownButtonFormField<String>( //Роль
                  decoration: const InputDecoration(labelText: 'Роль'),
                  value: _role,
                  items: const [
                    DropdownMenuItem(value: 'citizen', child: Text('Гражданин')),
                    DropdownMenuItem(value: 'inspector', child: Text('Инспектор')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _role = value;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Пожалуйста, выберите роль';
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