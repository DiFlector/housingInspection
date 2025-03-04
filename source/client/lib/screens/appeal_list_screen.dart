import 'package:flutter/material.dart';
import 'package:housing_inspection_client/screens/appeal_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:housing_inspection_client/providers/appeal_provider.dart';
import 'package:housing_inspection_client/screens/appeal_create_screen.dart';
import 'package:housing_inspection_client/providers/status_provider.dart';
import 'package:housing_inspection_client/providers/auth_provider.dart';
import 'package:housing_inspection_client/models/appeal.dart';

class AppealListScreen extends StatefulWidget {
  const AppealListScreen({super.key});

  @override
  _AppealListScreenState createState() => _AppealListScreenState();
}

class _AppealListScreenState extends State<AppealListScreen> {
  bool _isLoading = false; //  Добавляем локальный isLoading
  String? _error; //  Добавляем сообщение об ошибке

  @override
  void initState() {
    super.initState();
    _loadAppeals(); //  Вызываем _loadAppeals (см. ниже)
  }

  //  Добавляем метод _loadAppeals
  Future<void> _loadAppeals() async {
    setState(() {
      _isLoading = true;
      _error = null; //  Сбрасываем ошибку
    });

    try {
      await Provider.of<AppealProvider>(context, listen: false)
          .fetchAppeals()
          .timeout(const Duration(seconds: 5)); //  Устанавливаем таймаут 5 секунд
      // Если загрузка успешна, _error останется null, и список отобразится
    } catch (e) {
      setState(() {
        _error = 'Failed to load appeals: $e'; //  Сохраняем сообщение об ошибке
      });
    } finally {
      setState(() {
        _isLoading = false; //  В любом случае выключаем isLoading
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appeals'),
        actions: [
          if (Provider.of<AuthProvider>(context, listen: false).role ==
              'inspector')
            IconButton(
              icon: const Icon(Icons.people),
              onPressed: () {
                Navigator.pushNamed(context, '/users');
              },
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Provider.of<AuthProvider>(context, listen: false).logout();
              Navigator.of(context).pushReplacementNamed('/auth');
            },
          ),
        ],
      ),
      body: Consumer<AppealProvider>(
        builder: (context, appealProvider, child) {
          return RefreshIndicator(
            onRefresh: _loadAppeals, //  Используем _loadAppeals
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null //  Если есть ошибка - показываем сообщение
                ? Center(child: Text(_error!))
                : appealProvider.appeals.isEmpty
                ? const Center(child: Text('Нет существующих обращений'))
                : ListView.builder(
              itemCount: appealProvider.appeals.length,
              itemBuilder: (context, index) {
                final appeal = appealProvider.appeals[index];
                return ListTile(
                  title: Text(appeal.address),
                  subtitle: Text(
                      'Status: ${Provider.of<StatusProvider>(context, listen: false).getStatusName(appeal.statusId)}'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            AppealDetailScreen(appealId: appeal.id),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const AppealCreateScreen()));
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}