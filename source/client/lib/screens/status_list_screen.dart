import 'package:flutter/material.dart';
import 'package:housing_inspection_client/models/appeal_status.dart';
import 'package:housing_inspection_client/providers/auth_provider.dart';
import 'package:housing_inspection_client/providers/status_provider.dart';
import 'package:provider/provider.dart';
import 'package:housing_inspection_client/models/api_exception.dart';

import 'status_edit_screen.dart';
class StatusListScreen extends StatefulWidget {
  const StatusListScreen({super.key});

  @override
  _StatusListScreenState createState() => _StatusListScreenState();
}

class _StatusListScreenState extends State<StatusListScreen> {
  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.role != 'inspector') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/');
      });
    } else {
      Provider.of<StatusProvider>(context, listen: false).fetchStatuses();
    }
  }

  Future<void> _showErrorDialog(BuildContext context, String message) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Ошибка'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text("Невозможно удалить статус: он используется в обращениях."),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Ок'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = Provider.of<AuthProvider>(context, listen: false).role;
    if (role != 'inspector') {
      return const SizedBox.shrink();
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Статусы'), //  Перевод
      ),
      body: Consumer<StatusProvider>(
        builder: (context, statusProvider, child) {
          if (statusProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (statusProvider.statuses.isEmpty) {
            return const Center(child: Text('Статусы не найдены.')); //  Перевод
          } else {
            return ListView.builder(
              itemCount: statusProvider.statuses.length,
              itemBuilder: (context, index) {
                final status = statusProvider.statuses[index];
                return ListTile(
                  title: Text(status.name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        tooltip: 'Редактировать', //  Перевод
                        onPressed: (){
                          Navigator.push(context,
                              MaterialPageRoute(builder:
                                  (context) => StatusEditScreen(status: status)
                              )
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        tooltip: 'Удалить', //  Перевод
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text('Подтверждение удаления'), //  Перевод
                                content: Text('Вы уверены, что хотите удалить статус "${status.name}"?'),  //  Перевод + имя
                                actions: <Widget>[
                                  TextButton(
                                    child: const Text('Отмена'), //  Перевод
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                  TextButton(
                                      child: const Text('Удалить'), //  Перевод
                                      onPressed: () async {
                                        Navigator.of(context).pop();
                                        try {
                                          await Provider.of<StatusProvider>(context, listen: false).deleteStatus(status.id);
                                        } on ApiException catch (e) {
                                          _showErrorDialog(context, e.message);
                                        }
                                      }
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context,
              MaterialPageRoute(builder:
                  (context) => const StatusEditScreen(status: null)
              )
          );
        },
        child: const Icon(Icons.add),
        tooltip: 'Добавить статус', //  Перевод
      ),
    );
  }
}