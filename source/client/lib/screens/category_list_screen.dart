import 'package:flutter/material.dart';
import 'package:housing_inspection_client/models/appeal_category.dart';
import 'package:housing_inspection_client/providers/auth_provider.dart';
import 'package:housing_inspection_client/providers/category_provider.dart';
import 'package:housing_inspection_client/screens/category_edit_screen.dart';
import 'package:provider/provider.dart';
import 'package:housing_inspection_client/models/api_exception.dart';

class CategoryListScreen extends StatefulWidget {
  const CategoryListScreen({super.key});

  @override
  _CategoryListScreenState createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends State<CategoryListScreen> {
  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.role != 'inspector') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/');
      });
    } else {
      Provider.of<CategoryProvider>(context, listen: false).fetchCategories();
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
                Text("Невозможно удалить категорию: она используется в обращениях."),
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
        title: const Text('Категории'), //  Перевод
      ),
      body: Consumer<CategoryProvider>(
        builder: (context, categoryProvider, child) {
          if (categoryProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (categoryProvider.categories.isEmpty) {
            return const Center(child: Text('Категории не найдены.')); //  Перевод
          } else {
            return ListView.builder(
              itemCount: categoryProvider.categories.length,
              itemBuilder: (context, index) {
                final category = categoryProvider.categories[index];
                return ListTile(
                  title: Text(category.name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  CategoryEditScreen(category: category),
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
                                content: Text('Вы уверены, что хотите удалить категорию "${category.name}"?'),  //  Перевод + имя
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
                                        await Provider.of<CategoryProvider>(context, listen: false)
                                            .deleteCategory(category.id);
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
              builder: (context) => const CategoryEditScreen(category: null),
            ),
          );
        },
        child: const Icon(Icons.add),
        tooltip: 'Добавить категорию', //  Перевод
      ),
    );
  }
}