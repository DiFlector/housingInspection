import 'package:flutter/material.dart';
import 'package:housing_inspection_client/screens/appeal_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:housing_inspection_client/providers/appeal_provider.dart';
import 'package:housing_inspection_client/screens/appeal_create_screen.dart';
import 'package:housing_inspection_client/providers/status_provider.dart';
import 'package:housing_inspection_client/providers/auth_provider.dart';

class AppealListScreen extends StatefulWidget {
  const AppealListScreen({super.key});

  @override
  _AppealListScreenState createState() => _AppealListScreenState();
}

class _AppealListScreenState extends State<AppealListScreen> {
  @override
  void initState() {
    super.initState();
    Provider.of<AppealProvider>(context, listen: false).fetchAppeals();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Appeals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Provider.of<AuthProvider>(context, listen: false).logout();
              Navigator.of(context).pushReplacementNamed('/auth');
            },
          ),
        ],
      ),
      body: Consumer<AppealProvider>(  //  Используем Consumer
        builder: (context, appealProvider, child) {
          //  Добавляем проверку isLoading
          if (appealProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (appealProvider.appeals.isEmpty) {
            return const Center(child: Text('Нет существующих обращений')); //  Сообщение, если список пуст
          } else {
            return ListView.builder(
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
            );
          }
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