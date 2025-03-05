import 'package:flutter/material.dart';
import 'package:housing_inspection_client/models/user.dart';
import 'package:housing_inspection_client/providers/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:housing_inspection_client/providers/auth_provider.dart';
import 'package:housing_inspection_client/screens/user_edit_screen.dart';

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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Provider.of<UserProvider>(context, listen: false).fetchUsers();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = Provider.of<AuthProvider>(context, listen: false).role;
    if (role != 'inspector') {
      return const SizedBox
          .shrink(); //  Если не инспектор, вообще ничего не отображаем
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Пользователи'),
      ),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, child) {
          return RefreshIndicator(  //  Добавляем RefreshIndicator
            onRefresh: () async {
              //  Обновляем список пользователей
              await Provider.of<UserProvider>(context, listen: false).fetchUsers();
            },
            child: userProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : userProvider.users.isEmpty
                ? const Center(child: Text('Пользователи не найдены.'))
                : ListView.builder(
              itemCount: userProvider.users.length,
              itemBuilder: (context, index) {
                final user = userProvider.users[index];
                return user.isActive ?
                ListTile(
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
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: const Text('Подтверждение удаления'),
                                content: const Text('Вы уверены, что хотите удалить этого пользователя?'),
                                actions: <Widget>[
                                  TextButton(
                                    child: const Text('Отмена'),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    },
                                  ),
                                  TextButton(
                                    child: const Text('Удалить'),
                                    onPressed: () {
                                      Provider.of<UserProvider>(context, listen: false).deleteUser(user.id);
                                      Navigator.of(context).pop();
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
                ): const SizedBox.shrink();
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
              builder: (context) => const UserEditScreen(user: null),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}