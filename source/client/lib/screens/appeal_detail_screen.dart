import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:housing_inspection_client/models/appeal.dart';
import 'package:housing_inspection_client/services/api_service.dart';
import 'package:provider/provider.dart';

import '../providers/appeal_provider.dart';
import 'appeal_update_screen.dart';

import '../providers/category_provider.dart';
import '../providers/status_provider.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
//Импортируем
import 'package:housing_inspection_client/providers/auth_provider.dart';

class AppealDetailScreen extends StatefulWidget {
  final int appealId;

  const AppealDetailScreen({super.key, required this.appealId});

  @override
  _AppealDetailScreenState createState() => _AppealDetailScreenState();
}

Widget _buildFilePreview(String path) {
  final extension = p.extension(path).toLowerCase();

  if (['.jpg', '.jpeg', '.png', '.gif', '.bmp'].contains(extension)) {
    return kIsWeb
        ? Image.network(path, width: 100, height: 100)
        : Image.file(File(path), width: 100, height: 100);
  } else if (extension == '.pdf') {
    return const SizedBox(
        width: 100, height: 100, child: Icon(Icons.picture_as_pdf, size: 64));
  } else {
    return const SizedBox(
        width: 100, height: 100, child: Icon(Icons.file_present, size: 64));
  }
}

class _AppealDetailScreenState extends State<AppealDetailScreen> {

  @override
  Widget build(BuildContext context) {
    final role = Provider.of<AuthProvider>(context, listen: false).role;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Детали обращения'),
        actions: [
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
      body: Consumer<AppealProvider>(
        builder: (context, appealProvider, child) {
          final appeal = appealProvider.appeals.firstWhere(
                (a) => a.id == widget.appealId,
            orElse: () => Appeal(
              id: 0,
              userId: 0,
              categoryId: 0,
              statusId: 0,
              address: '',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
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

          final filePaths = appeal.filePaths?.split(',') ?? [];

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
                Text('Отправитель: $senderName'),
                const SizedBox(height: 8),
                Wrap(
                  children: filePaths
                      .map((path) => Padding(
                    padding: const EdgeInsets.all(
                        4.0),
                    child: _buildFilePreview(path),
                  ))
                      .toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}