import 'package:flutter/material.dart';
import 'package:housing_inspection_client/screens/appeal_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:housing_inspection_client/providers/appeal_provider.dart';
import 'package:housing_inspection_client/screens/appeal_create_screen.dart';
import 'package:housing_inspection_client/providers/status_provider.dart';
import 'package:housing_inspection_client/providers/auth_provider.dart';
import 'package:housing_inspection_client/models/appeal.dart';
import 'package:housing_inspection_client/providers/category_provider.dart';
import 'package:housing_inspection_client/models/api_exception.dart';
import 'package:housing_inspection_client/screens/knowledge_base_screen.dart';

class AppealListScreen extends StatefulWidget {
  const AppealListScreen({super.key});

  @override
  _AppealListScreenState createState() => _AppealListScreenState();
}

class _AppealListScreenState extends State<AppealListScreen> {
  int? _selectedStatusId;
  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppealProvider>(context, listen: false).fetchAppeals();
    });
  }

  Future<void> _loadAppeals() async {
    try {
      await Provider.of<AppealProvider>(context, listen: false).fetchAppeals();
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      print('Error loading categories and statuses: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Ошибка загрузки данных"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Обращения'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (String item) {
              switch (item) {
                case 'address_asc':
                  Provider.of<AppealProvider>(context, listen: false)
                      .setSortBy('address');
                  Provider.of<AppealProvider>(context, listen: false)
                      .setSortOrder('asc');
                  break;
                case 'address_desc':
                  Provider.of<AppealProvider>(context, listen: false)
                      .setSortBy('address');
                  Provider.of<AppealProvider>(context, listen: false)
                      .setSortOrder('desc');
                  break;
                case 'category_asc':
                  Provider.of<AppealProvider>(context, listen: false)
                      .setSortBy('category_id');
                  Provider.of<AppealProvider>(context, listen: false)
                      .setSortOrder('asc');
                  break;
                case 'category_desc':
                  Provider.of<AppealProvider>(context, listen: false)
                      .setSortBy('category_id');
                  Provider.of<AppealProvider>(context, listen: false)
                      .setSortOrder('desc');
                  break;
                case 'status_asc':
                  Provider.of<AppealProvider>(context, listen: false)
                      .setSortBy('status_id');
                  Provider.of<AppealProvider>(context, listen: false)
                      .setSortOrder('asc');
                  break;
                case 'status_desc':
                  Provider.of<AppealProvider>(context, listen: false)
                      .setSortBy('status_id');
                  Provider.of<AppealProvider>(context, listen: false)
                      .setSortOrder('desc');
                  break;
                case 'date_asc':
                  Provider.of<AppealProvider>(context, listen: false)
                      .setSortBy('created_at');
                  Provider.of<AppealProvider>(context, listen: false)
                      .setSortOrder('asc');
                  break;
                case 'date_desc':
                  Provider.of<AppealProvider>(context, listen: false)
                      .setSortBy('created_at');
                  Provider.of<AppealProvider>(context, listen: false)
                      .setSortOrder('desc');
                  break;
              }
              _loadAppeals();
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'address_asc',
                child: Text('Адрес (А-Я)'),
              ),
              const PopupMenuItem<String>(
                value: 'address_desc',
                child: Text('Адрес (Я-А)'),
              ),
              const PopupMenuItem<String>(
                value: 'category_asc',
                child: Text('Категория (А-Я)'),
              ),
              const PopupMenuItem<String>(
                value: 'category_desc',
                child: Text('Категория (Я-А)'),
              ),
              const PopupMenuItem<String>(
                value: 'status_asc',
                child: Text('Статус (А-Я)'),
              ),
              const PopupMenuItem<String>(
                value: 'status_desc',
                child: Text('Статус (Я-А)'),
              ),
              const PopupMenuItem<String>(
                value: 'date_asc',
                child: Text('Дата (сначала старые)'),
              ),
              const PopupMenuItem<String>(
                value: 'date_desc',
                child: Text('Дата (сначала новые)'),
              ),
            ],
            icon: const Icon(Icons.filter_list),
          ),
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
              icon: const Icon(Icons.fact_check),
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                DropdownButtonFormField<int?>(
                  decoration: const InputDecoration(labelText: 'Статус'),
                  value: _selectedStatusId,
                  items: [
                    const DropdownMenuItem<int?>(
                        value: null, child: Text('Все')),
                    ...Provider.of<StatusProvider>(context)
                        .statuses
                        .map((status) {
                      return DropdownMenuItem<int?>(
                        value: status.id,
                        child: Text(status.name),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedStatusId = value;
                    });
                    Provider.of<AppealProvider>(context, listen: false)
                        .setStatusFilter(_selectedStatusId);
                    _loadAppeals();
                  },
                  isExpanded: true,
                ),
                DropdownButtonFormField<int?>(
                  decoration: const InputDecoration(labelText: 'Категория'),
                  value: _selectedCategoryId,
                  items: [
                    const DropdownMenuItem<int?>(
                        value: null, child: Text('Все')),
                    ...Provider.of<CategoryProvider>(context)
                        .categories
                        .map((category) {
                      return DropdownMenuItem<int?>(
                        value: category.id,
                        child: Text(category.name),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedCategoryId = value;
                    });
                    Provider.of<AppealProvider>(context, listen: false)
                        .setCategoryFilter(_selectedCategoryId);
                    _loadAppeals();
                  },
                  isExpanded: true,
                ),
              ],
            ),
          ),
          Expanded(
            child: Consumer<AppealProvider>(
              builder: (context, appealProvider, child) {
                final role =
                    Provider.of<AuthProvider>(context, listen: false).role;

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
                  onRefresh: _loadAppeals,
                  child: appealProvider.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : displayedAppeals.isEmpty
                      ? const Center(child: Text('Нет существующих обращений'))
                      : ListView.builder(
                    itemCount: displayedAppeals.length,
                    itemBuilder: (context, index) {
                      final appeal = displayedAppeals[index];
                      final categoryName =
                      Provider.of<CategoryProvider>(context,
                          listen: false)
                          .getCategoryName(appeal.categoryId);
                      final statusName = Provider.of<StatusProvider>(
                          context,
                          listen: false)
                          .getStatusName(appeal.statusId);
                      return ListTile(
                        title: Text(appeal.address),
                        subtitle: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
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
                                  AppealDetailScreen(
                                      appealId: appeal.id),
                            ),
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
          )
        ],
      ),
      floatingActionButton: Row(
        //  ИЗМЕНЕНИЕ:  Используем Row
        mainAxisAlignment:
        MainAxisAlignment.end, //  Выравнивание по правому краю
        children: [
          FloatingActionButton(
            onPressed: () {
              Navigator.pushNamed(context, '/knowledge_base');
            },
            child: const Icon(Icons.book), //  Иконка книги
            tooltip: 'База знаний',
            heroTag: 'knowledge_base_button', // Уникальный тег
          ),
          const SizedBox(width: 16), //  Отступ между кнопками
          FloatingActionButton(
            onPressed: () {
              Navigator.pushNamed(context, '/appeals/create').then((value) {
                if (value == true) {
                  // Если обращение создано
                  _loadAppeals(); // Обновляем список
                }
              });
            },
            child: const Icon(Icons.add),
            tooltip: 'Создать обращение',
            heroTag: 'create_appeal_button', // Уникальный тег
          ),
        ],
      ),
    );
  }

  Future<void> _showFilterSortDialog(BuildContext context) async {
    final appealProvider = Provider.of<AppealProvider>(context, listen: false);
    int? tempStatusId = appealProvider.statusId;
    int? tempCategoryId = appealProvider.categoryId;
    String tempSortBy = appealProvider.sortBy;
    String tempSortOrder = appealProvider.sortOrder;

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: const Text('Фильтры и сортировка'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int?>(
                      decoration: const InputDecoration(labelText: 'Статус'),
                      value: tempStatusId,
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<int?>(
                            value: null, child: Text('Все')),
                        ...Provider.of<StatusProvider>(context)
                            .statuses
                            .map((status) {
                          return DropdownMenuItem<int?>(
                            value: status.id,
                            child: Text(status.name),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          tempStatusId = value;
                        });
                      },
                    ),
                    DropdownButtonFormField<int?>(
                      decoration: const InputDecoration(labelText: 'Категория'),
                      value: tempCategoryId,
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<int?>(
                            value: null, child: Text('Все')),
                        ...Provider.of<CategoryProvider>(context)
                            .categories
                            .map((category) {
                          return DropdownMenuItem<int?>(
                            value: category.id,
                            child: Text(category.name),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          tempCategoryId = value;
                        });
                      },
                    ),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      decoration:
                      const InputDecoration(labelText: 'Сортировать по'),
                      value: tempSortBy,
                      items: const [
                        DropdownMenuItem(
                            value: 'address', child: Text('Адресу')),
                        DropdownMenuItem(
                            value: 'category_id', child: Text('Категории')),
                        DropdownMenuItem(
                            value: 'status_id', child: Text('Статусу')),
                        DropdownMenuItem(
                            value: 'created_at', child: Text('Дате создания')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          tempSortBy = value!;
                        });
                      },
                    ),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        const Text('Порядок:'),
                        Radio<String>(
                          value: 'asc',
                          groupValue: tempSortOrder,
                          onChanged: (value) {
                            setState(() {
                              tempSortOrder = value!;
                            });
                          },
                        ),
                        const Text('Возрастанию'),
                        Radio<String>(
                          value: 'desc',
                          groupValue: tempSortOrder,
                          onChanged: (value) {
                            setState(() {
                              tempSortOrder = value!;
                            });
                          },
                        ),
                        const Text('Убыванию'),
                      ],
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Отмена'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: const Text('Применить'),
                  onPressed: () {
                    appealProvider.setSortBy(tempSortBy);
                    appealProvider.setSortOrder(tempSortOrder);
                    appealProvider.setStatusFilter(tempStatusId);
                    appealProvider.setCategoryFilter(tempCategoryId);

                    Navigator.of(context).pop();
                    _loadAppeals();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}