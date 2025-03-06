import 'package:flutter/material.dart';
import 'package:housing_inspection_client/models/user.dart';
import 'package:housing_inspection_client/providers/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:housing_inspection_client/providers/auth_provider.dart';
import 'package:housing_inspection_client/screens/user_edit_screen.dart';
import 'package:housing_inspection_client/models/api_exception.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  _UserListScreenState createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  @override
  void initState() {
    super.initState();
    final role = Provider.of<AuthProvider>(context, listen: false).role;
    if (role != 'inspector') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/');
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) { //  ОТКЛАДЫВАЕМ
        Provider.of<UserProvider>(context, listen: false).fetchUsers();
      });
    }
  }

  Future<void> _showErrorDialog(BuildContext context, String message) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, //  Нельзя закрыть диалог, нажав мимо
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Ошибка'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text("Невозможно удалить пользователя с незакрытыми обращениями."),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Ок'),
              onPressed: () {
                Navigator.of(context).pop(); //  Закрываем диалог
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
        title: const Text('Пользователи'), //  Перевод
      ),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, child) {
          if (userProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (userProvider.users.isEmpty) {
            return const Center(child: Text('Пользователи не найдены.')); //  Перевод
          } else {
            return ListView.builder(
              itemCount: userProvider.users.length,
              itemBuilder: (context, index) {
                final user = userProvider.users[index];
                return ListTile(
                  title: Text(user.username),
                  subtitle: Text(user.email),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UserEditScreen(user: user),
                            ),
                          );
                        },
                        tooltip: 'Редактировать', //  Перевод
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
                                content: Text('Вы уверены, что хотите удалить пользователя "${user.username}"?'),  //  Перевод и подстановка имени
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
                                        await Provider.of<UserProvider>(context, listen: false).deleteUser(user.id);
                                      } on ApiException catch (e) {
                                        _showErrorDialog(context, e.message);
                                      }
                                    },
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
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const UserEditScreen(user: null),
            ),
          );
        },
        child: const Icon(Icons.add),
        tooltip: 'Добавить пользователя', //  Перевод
      ),
    );
  }
}