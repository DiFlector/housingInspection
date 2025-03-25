import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
import 'package:housing_inspection_client/providers/auth_provider.dart';
import 'dart:math';

import 'package:housing_inspection_client/providers/message_provider.dart';
import 'package:housing_inspection_client/models/message.dart';
import 'package:intl/intl.dart';
import 'dart:async';

String _shortenFileName(String path, int maxLength) {
  String fileName = p.basename(path);
  if (fileName.length > maxLength) {
    return fileName.substring(0, maxLength - 3) + "...";
  }
  return fileName;
}

class AppealDetailScreen extends StatefulWidget {
  final int appealId;

  const AppealDetailScreen({super.key, required this.appealId});

  @override
  _AppealDetailScreenState createState() => _AppealDetailScreenState();
}

class _AppealDetailScreenState extends State<AppealDetailScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final messageProvider =
      Provider.of<MessageProvider>(context, listen: false);
      messageProvider.clearMessages();
      messageProvider.fetchMessages(widget.appealId).then((_) {
        if (messageProvider.messages.isNotEmpty && mounted && _scrollController.hasClients)
        {
          _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: Duration(milliseconds: 1), curve: Curves.ease);
        }
      });
    });
    _fetchMessagesPeriodically();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _fetchMessagesPeriodically() {
    _timer = Timer.periodic(Duration(seconds: 5), (timer) {
      if (mounted) {
        Provider.of<MessageProvider>(context, listen: false)
            .fetchMessages(widget.appealId);
      }
    });
  }

  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isNotEmpty) {
      Provider.of<MessageProvider>(context, listen: false)
          .sendMessage(widget.appealId, content, []);
      _messageController.clear();

      //  ИЗМЕНЕНИЕ:  Добавляем небольшую задержку:
      Future.delayed(Duration(milliseconds: 500), () { //  Задержка 100 мс
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

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
              },
            ),
        ],
      ),
      resizeToAvoidBottomInset: true, // Убедись, что это здесь
      body: Column(
        children: [
          Expanded( //  Один Expanded на всё
            child: Consumer<AppealProvider>(
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
                    user: null,
                  ),
                );

                if (appeal.id == 0) {
                  return const Center(child: CircularProgressIndicator());
                }

                final categoryName =
                Provider.of<CategoryProvider>(context, listen: false)
                    .getCategoryName(appeal.categoryId);
                final statusName =
                Provider.of<StatusProvider>(context, listen: false)
                    .getStatusName(appeal.statusId);

                final filePaths = appeal.filePaths ?? [];

                final senderName =
                (appeal.user?.fullName != null && appeal.user!.fullName!.isNotEmpty)
                    ? '${appeal.user!.fullName} (${appeal.user!.username})'
                    : appeal.user?.username ?? 'Неизвестный пользователь';

                return Column( //  Внутри Expanded - Column
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    //  Виджеты с информацией об обращении:
                    Padding(
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
                          Text(
                              "Описание: ${appeal.description ?? 'Нет описания'}"),
                          const SizedBox(height: 8),
                          Text('Создано: ${appeal.createdAt}'),
                          const SizedBox(height: 8),
                          Text('Обновлено: ${appeal.updatedAt}'),
                          const SizedBox(height: 8),
                          Text('Отправитель: $senderName'),
                          const SizedBox(height: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: filePaths.map((path) {
                              // String fileName = p.basename(path); // Убираем, используем функцию
                              return InkWell(
                                onTap: () async {
                                  if (!await launchUrl(Uri.parse(path))) {
                                    throw Exception('Could not launch $path');
                                  }
                                },
                                child: Padding(
                                  padding:
                                  const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Text(
                                    _shortenFileName(path, 30), // Используем функцию сокращения
                                    style: const TextStyle(
                                      color: Colors.blue,
                                      decoration: TextDecoration.underline,
                                    ),
                                    overflow: TextOverflow.ellipsis, // Добавляем эллипсис
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    //  Чат (оборачиваем в Flexible):
                    Expanded(
                      //  Оборачиваем в Expanded
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        padding: EdgeInsets.all(8),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 1,
                        ),
                        child: Consumer<MessageProvider>(
                          builder: (context, provider, child) {
                            if (provider.isLoading) {
                              return const Center(child: CircularProgressIndicator());
                            } else if (provider.error != null) {
                              return Center(child: Text('Ошибка: ${provider.error}'));
                            } else {
                              //  ДОБАВЛЯЕМ ПРОВЕРКУ hasNewMessages:
                              if (provider.hasNewMessages) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (mounted && _scrollController.hasClients) {
                                    _scrollController.animateTo(
                                      _scrollController.position.maxScrollExtent,
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeOut,
                                    );
                                  }
                                  provider.hasNewMessages = false; //  ИСПОЛЬЗУЕМ СЕТТЕР
                                });
                              }

                              return ListView.builder(
                                controller: _scrollController,
                                itemCount: provider.messages.length,
                                physics: const ClampingScrollPhysics(),
                                itemBuilder: (context, index) {
                                  final message = provider.messages[index];
                                  return MessageBubble(message: message);
                                },
                              );
                            }
                          },
                        ),
                      ),
                    ),
                    //  Поле ввода (остаётся внизу, как и было):
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: IntrinsicHeight( //  Оборачиваем Row в IntrinsicHeight
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center, //  Центрируем по вертикали
                          children: [
                            Expanded(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight: 150,
                                ),
                                child: TextField(
                                  controller: _messageController,
                                  decoration: const InputDecoration(
                                    hintText: 'Введите сообщение...',
                                    border: OutlineInputBorder(),
                                  ),
                                  maxLines: 3, //  Убираем maxLines: 5
                                  minLines: 1, // Добавили minLines
                                  keyboardType: TextInputType.multiline,
                                  maxLength: 500,
                                  maxLengthEnforcement: MaxLengthEnforcement.enforced,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.send),
                              onPressed: _sendMessage,
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.01), // Отступ снизу
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String formatBytes(int? bytes, [int decimals = 2]) {
    if (bytes == null) return '0 Bytes';
    if (bytes <= 0) return "0 Bytes";
    const suffixes = ["Bytes", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }
}

class MessageBubble extends StatelessWidget {
  final Message message;

  const MessageBubble({Key? key, required this.message}) : super(key: key);

  String _formatDateTime(DateTime dateTime) {
    final formatter = DateFormat('dd.MM.yyyy HH:mm');
    return formatter.format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final isCurrentUser = message.sender?.id ==
        Provider.of<AuthProvider>(context, listen: false)
            .userId;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Align(
        alignment:
        isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: isCurrentUser ? Colors.blue[100] : Colors.grey[200],
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Column(
            crossAxisAlignment: isCurrentUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Text(
                message.content,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                '${message.sender?.username ?? 'Неизвестный отправитель'}, ${_formatDateTime(message.createdAt)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              if (message.filePaths != null && message.filePaths!.isNotEmpty)
                ...message.filePaths!.map((e) => InkWell(
                  onTap: () async{
                    if (!await launchUrl(Uri.parse(e))) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Не удалось открыть файл $e')));
                    }
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min, //  ВАЖНО!
                    children: [
                      Icon(Icons.attach_file, size: 16), // Уменьшим иконку
                      SizedBox(width: 4),
                      Expanded( // Обернем текст в Expanded
                        child: Text(
                          _shortenFileName(e, 25), // Используем функцию сокращения
                          style: TextStyle(fontSize: 12, color: Colors.blue[800], decoration: TextDecoration.underline),
                          overflow: TextOverflow.ellipsis, // Добавляем эллипсис
                        ),
                      ),
                    ],
                  ),
                )),
            ],
          ),
        ),
      ),
    );
  }
}