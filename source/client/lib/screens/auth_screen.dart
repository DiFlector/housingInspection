import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:housing_inspection_client/providers/auth_provider.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;
  bool _isLoading = false; // Добавляем индикатор загрузки

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true; // Включаем индикатор
        _error = null;     // Сбрасываем предыдущую ошибку
      });

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      try { // Добавляем try-catch
        final success = await authProvider.login(
          _usernameController.text,
          _passwordController.text,
        );

        if (success) {
          Navigator.of(context).pushReplacementNamed('/');
        } else {
          //  Ошибка, но authProvider.login  и так обрабатывает это.
          //  Тут можно добавить проверку на конкретные коды ошибок, если нужно
          setState(() {
            _error = 'Invalid username or password';
          });
        }
      } catch (e) {
        setState(() {
          _error = 'Login failed: $e'; // Показываем детальную ошибку
        });
      } finally {
        setState(() {
          _isLoading = false; // Выключаем индикатор
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your username';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _isLoading // Используем _isLoading
                  ? const CircularProgressIndicator() // Показываем индикатор
                  : ElevatedButton(
                onPressed: _submit,
                child: const Text('Login'),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              TextButton( onPressed: () {
                Navigator.pushNamed(context, '/register');
              }, child: const Text("Регистрация"))
            ],
          ),
        ),
      ),
    );
  }
}