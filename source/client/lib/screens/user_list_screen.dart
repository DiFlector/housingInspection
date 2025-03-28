import 'package:flutter/material.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<UserProvider>(context, listen: false).setActiveFilter(true);
      _loadUsers();
    });
  }

  Future<void> _loadUsers() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      await userProvider.fetchUsers();
    } on ApiException catch (e) {
      _showErrorDialog(context, e.message);
    } catch (e) {
      _showErrorDialog(context, 'Failed to load users: $e');
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
                Text(message),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
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
          title: const Text('Пользователи'),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.filter_list),
              onSelected: (String item) {
                switch (item) {
                  case 'username_asc':
                    Provider.of<UserProvider>(context, listen: false).setSortBy('username');
                    Provider.of<UserProvider>(context, listen: false).setSortOrder('asc');
                    break;
                  case 'username_desc':
                    Provider.of<UserProvider>(context, listen: false).setSortBy('username');
                    Provider.of<UserProvider>(context, listen: false).setSortOrder('desc');
                    break;
                  case 'email_asc':
                    Provider.of<UserProvider>(context, listen: false).setSortBy('email');
                    Provider.of<UserProvider>(context, listen: false).setSortOrder('asc');
                    break;
                  case 'email_desc':
                    Provider.of<UserProvider>(context, listen: false).setSortBy('email');
                    Provider.of<UserProvider>(context, listen: false).setSortOrder('desc');
                    break;
                  case 'role_asc':
                    Provider.of<UserProvider>(context, listen: false).setSortBy('role');
                    Provider.of<UserProvider>(context, listen: false).setSortOrder('asc');
                    break;
                  case 'role_desc':
                    Provider.of<UserProvider>(context, listen: false).setSortBy('role');
                    Provider.of<UserProvider>(context, listen: false).setSortOrder('desc');
                    break;
                  case 'date_asc':
                    Provider.of<UserProvider>(context, listen: false).setSortBy('created_at');
                    Provider.of<UserProvider>(context, listen: false).setSortOrder('asc');
                    break;
                  case 'date_desc':
                    Provider.of<UserProvider>(context, listen: false).setSortBy('created_at');
                    Provider.of<UserProvider>(context, listen: false).setSortOrder('desc');
                    break;
                }
                _loadUsers();
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'username_asc',
                  child: Text('Имя пользователя (А-Я)'),
                ),
                const PopupMenuItem<String>(
                  value: 'username_desc',
                  child: Text('Имя пользователя (Я-А)'),
                ),
                const PopupMenuItem<String>(
                  value: 'email_asc',
                  child: Text('Email (А-Я)'),
                ),
                const PopupMenuItem<String>(
                  value: 'email_desc',
                  child: Text('Email (Я-А)'),
                ),
                const PopupMenuItem<String>(
                  value: 'role_asc',
                  child: Text('Роль (А-Я)'),
                ),
                const PopupMenuItem<String>(
                  value: 'role_desc',
                  child: Text('Роль (Я-А)'),
                ),
                const PopupMenuItem<String>(
                  value: 'date_asc',
                  child: Text('Дата создания (сначала старые)'),
                ),
                const PopupMenuItem<String>(
                  value: 'date_desc',
                  child: Text('Дата создания (сначала новые)'),
                ),
              ],
            ),
          ]
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton(
                  onPressed: () {
                    Provider.of<UserProvider>(context, listen: false)
                        .setActiveFilter(true);
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: Provider.of<UserProvider>(context).activeFilter == true ? Colors.blue : Colors.grey,
                    ),
                  ),
                  child: const Text('Активные'),
                ),
                OutlinedButton(
                  onPressed: () {
                    Provider.of<UserProvider>(context, listen: false)
                        .setActiveFilter(false);
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: Provider.of<UserProvider>(context).activeFilter == false ? Colors.blue : Colors.grey,
                    ),
                  ),
                  child: const Text('Неактивные'),
                ),
                OutlinedButton(
                  onPressed: () {
                    Provider.of<UserProvider>(context, listen: false)
                        .setActiveFilter(null);
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: Provider.of<UserProvider>(context).activeFilter == null ? Colors.blue : Colors.grey,
                    ),
                  ),
                  child: const Text('Все'),
                ),
              ],
            ),
          ),
          Expanded(
            child: Consumer<UserProvider>(
              builder: (context, userProvider, child) {
                if (userProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (userProvider.users.isEmpty) {
                  return const Center(child: Text('Пользователи не найдены.'));
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
                              tooltip: 'Редактировать',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              tooltip: 'Удалить',
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return AlertDialog(
                                      title: const Text('Подтверждение удаления'),
                                      content: Text('Вы уверены, что хотите удалить пользователя "${user.username}"?'),
                                      actions: <Widget>[
                                        TextButton(
                                          child: const Text('Отмена'),
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                        ),
                                        TextButton(
                                          child: const Text('Удалить'),
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
          ),
        ],
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
        tooltip: 'Добавить пользователя',
      ),
    );
  }
}