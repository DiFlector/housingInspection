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
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAppeals();
  }

  Future<void> _loadAppeals() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await Provider.of<AppealProvider>(context, listen: false)
          .fetchAppeals()
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      setState(() {
        _error = 'Failed to load appeals: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Обращения'),
        actions: [
          //  ВРЕМЕННАЯ кнопка для перехода к списку пользователей
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
          //  Получаем роль текущего пользователя
          final role = Provider.of<AuthProvider>(context, listen: false).role;

          //  Фильтруем список обращений в зависимости от роли
          List<Appeal> displayedAppeals = [];
          if (role == 'inspector') {
            displayedAppeals = appealProvider.appeals; //  Инспекторы видят все
          } else {
            //  Граждане видят только свои (фильтруем по user_id)

            final currentUserId = Provider.of<AuthProvider>(context, listen: false).userId; //  Получаем ID пользователя
            displayedAppeals = appealProvider.appeals.where((appeal) => appeal.userId == currentUserId).toList();
          }

          return RefreshIndicator(
            onRefresh: _loadAppeals,
            child:_isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(child: Text(_error!))
                : displayedAppeals.isEmpty
                ? const Center(child: Text('Нет существующих обращений'))
                : ListView.builder(
              itemCount: displayedAppeals.length,
              itemBuilder: (context, index) {
                final appeal = displayedAppeals[index];
                return ListTile(
                  title: Text(appeal.address),
                  subtitle: Text(
                      'Статус: ${Provider.of<StatusProvider>(context, listen: false).getStatusName(appeal.statusId)}'),
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