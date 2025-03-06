import 'package:flutter/material.dart';
import 'package:housing_inspection_client/screens/appeal_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:housing_inspection_client/providers/appeal_provider.dart';
import 'package:housing_inspection_client/screens/appeal_create_screen.dart';
import 'package:housing_inspection_client/providers/status_provider.dart';
import 'package:housing_inspection_client/providers/auth_provider.dart';
import 'package:housing_inspection_client/models/appeal.dart';
import 'package:housing_inspection_client/providers/category_provider.dart';

class AppealListScreen extends StatefulWidget {
  const AppealListScreen({super.key});

  @override
  _AppealListScreenState createState() => _AppealListScreenState();
}

class _AppealListScreenState extends State<AppealListScreen> {
  @override
  void initState() {
    super.initState();
    //  ОТКЛАДЫВАЕМ вызов fetchAppeals:
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppealProvider>(context, listen: false).fetchAppeals();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Обращения'),
        actions: [
          // ВРЕМЕННЫЕ кнопки для перехода к спискам пользователей, категорий и статусов
          if (Provider.of<AuthProvider>(context, listen: false).role ==
              'inspector')
            IconButton(
              icon: const Icon(Icons.people),
              onPressed: () {
                Navigator.pushNamed(context, '/users');
              },
            ),
          if (Provider.of<AuthProvider>(context, listen: false).role ==
              'inspector')
            IconButton(
              icon: const Icon(Icons.category),
              onPressed: () {
                Navigator.pushNamed(context, '/categories');
              },
            ),
          if (Provider.of<AuthProvider>(context, listen: false).role ==
              'inspector')
            IconButton(
              icon: const Icon(Icons.filter_list), //  Иконка для статусов (пример)
              onPressed: () {
                Navigator.pushNamed(context, '/statuses');
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
          final role = Provider.of<AuthProvider>(context, listen: false).role;

          List<Appeal> displayedAppeals = [];
          if (role == 'inspector') {
            displayedAppeals = appealProvider.appeals;
          } else {
            final currentUserId =
                Provider.of<AuthProvider>(context, listen: false).userId;
            displayedAppeals = appealProvider.appeals
                .where((appeal) => appeal.userId == currentUserId)
                .toList();
          }

          return RefreshIndicator(
            onRefresh: () async {
              await Provider.of<AppealProvider>(context, listen: false)
                  .fetchAppeals();
            },
            child: appealProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : displayedAppeals.isEmpty
                ? const Center(child: Text('Нет существующих обращений'))
                : ListView.builder(
              itemCount: displayedAppeals.length,
              itemBuilder: (context, index) {
                final appeal = displayedAppeals[index];
                final categoryName =
                Provider.of<CategoryProvider>(context, listen: false)
                    .getCategoryName(appeal.categoryId);
                final statusName =
                Provider.of<StatusProvider>(context, listen: false)
                    .getStatusName(appeal.statusId);
                return ListTile(
                  title: Text(appeal.address),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Категория: $categoryName'),
                      Text('Статус: $statusName'),
                    ],
                  ),
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
              builder: (context) => const AppealCreateScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}