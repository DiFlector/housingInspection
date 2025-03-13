import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:housing_inspection_client/models/appeal.dart';
import 'package:housing_inspection_client/services/api_service.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/appeal_provider.dart';
import 'appeal_update_screen.dart';

import '../providers/category_provider.dart';
import '../providers/status_provider.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
//Импортируем
import 'package:housing_inspection_client/providers/auth_provider.dart';
import 'dart:math'; //  Добавляем импорт

class AppealDetailScreen extends StatefulWidget {
  final int appealId;

  const AppealDetailScreen({super.key, required this.appealId});

  @override
  _AppealDetailScreenState createState() => _AppealDetailScreenState();
}

class _AppealDetailScreenState extends State<AppealDetailScreen> {
//  Убираем initState

  @override
  Widget build(BuildContext context) {
    // Получаем роль пользователя
    final role = Provider.of<AuthProvider>(context, listen: false).role;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Детали обращения'),
        actions: [
          //  Показываем кнопку "Редактировать", только если роль пользователя - инспектор
          if (role == 'inspector')
            IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          AppealUpdateScreen(appealId: widget.appealId),
                    ),
                  );
                }),
          //  Показываем кнопку "Удалить", только если роль пользователя - инспектор
          if (role == 'inspector')
            IconButton(
                onPressed: () {
                  Provider.of<AppealProvider>(context, listen: false)
                      .deleteAppeal(widget.appealId)
                      .then((_) {
                    Navigator.pop(context);
                  });
                },
                icon: const Icon(Icons.delete)),
        ],
      ),
      body: Consumer<AppealProvider>( //  Используем просто Consumer
        builder: (context, appealProvider, child) {
          final appeal = appealProvider.appeals.firstWhere(
                (a) => a.id == widget.appealId,
            orElse: () => Appeal( //  Тут тоже добавляем user: null
              id: 0,
              userId: 0,
              categoryId: 0,
              statusId: 0,
              address: '',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              user: null, //  Добавляем
            ),
          );

          if (appeal.id == 0) {
            return const Center(child: CircularProgressIndicator());
          }

          final categoryName =
          Provider.of<CategoryProvider>(context, listen: false)
              .getCategoryName(appeal.categoryId);
          final statusName = Provider.of<StatusProvider>(context, listen: false)
              .getStatusName(appeal.statusId);

          final filePaths = appeal.filePaths ?? []; //  Получаем список путей

          // Формируем строку с именем отправителя:
          final senderName = (appeal.user?.fullName != null && appeal.user!.fullName!.isNotEmpty)
              ? '${appeal.user!.fullName} (${appeal.user!.username})'
              : appeal.user?.username ?? 'Неизвестный пользователь';


          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Адрес: ${appeal.address}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Категория: $categoryName'),
                const SizedBox(height: 8),
                Text('Статус: $statusName'),
                const SizedBox(height: 8),
                Text("Описание: ${appeal.description ?? 'Нет описания'}"),
                const SizedBox(height: 8),
                Text('Создано: ${appeal.createdAt}'),
                const SizedBox(height: 8),
                Text('Обновлено: ${appeal.updatedAt}'),
                const SizedBox(height: 8),
                // Добавляем отображение имени пользователя
                Text('Отправитель: $senderName'),
                const SizedBox(height: 8),
                // Вместо Wrap используем Column и InkWell
                Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: filePaths.map((path) {
                      String fileName = path.split('/').last;
                      // String fileInfo = appeal.fileType ?? 'Неизвестно'; //  Убираем

                      return InkWell(
                        onTap: () async {
                          if (!await launchUrl(Uri.parse(path))) {
                            throw Exception('Could not launch $path');
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Text(
                            '$fileName', //  Оставляем только размер
                            style: const TextStyle(
                                color: Colors.blue, decoration: TextDecoration.underline),
                          ),
                        ),
                      );
                    }).toList()
                )
              ],
            ),
          );
        },
      ),
    );
  }
  // Вспомогательная функция для форматирования размера файла
  String formatBytes(int? bytes, [int decimals = 2]) {
    if (bytes == null) return '0 Bytes';
    if (bytes <= 0) return "0 Bytes";
    const suffixes = ["Bytes", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
    var i = (log(bytes) / log(1024)).floor(); //  Используем log
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }
}