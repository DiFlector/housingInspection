import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/appeal_provider.dart';
import 'appeal_update_screen.dart';
import '../providers/category_provider.dart';
import '../providers/status_provider.dart';
import 'package:path/path.dart' as p;
import 'package:housing_inspection_client/providers/auth_provider.dart';
import 'dart:math';
import 'package:housing_inspection_client/providers/message_provider.dart';
import 'package:housing_inspection_client/models/message.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:io';

String _shortenFileName(String path, int maxLength) {
  if (path.isEmpty) return '';
  try {
    String fileName = p.basename(path);
    if (fileName.length <= maxLength) {
      return fileName;
    }
    final extension = p.extension(fileName);
    final nameWithoutExtension = p.basenameWithoutExtension(fileName);
    final charsToKeep = maxLength - extension.length - 3;
    if (charsToKeep <= 0) {
      return fileName.substring(0, min(fileName.length, maxLength - 3)) + "...";
    }
    return nameWithoutExtension.substring(0, charsToKeep) + "..." + extension;
  } catch (e) {
    return path.length > maxLength ? path.substring(0, maxLength - 3) + "..." : path;
  }
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
  List<String> _selectedFilePaths = [];
  String? _fileSelectionError;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messageProvider = Provider.of<MessageProvider>(context, listen: false);
      messageProvider.clearMessages();
      messageProvider.fetchMessages(widget.appealId).then((_) {
        _scrollToBottom(milliseconds: 300);
      });
      _startPolling();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _scrollToBottom({int milliseconds = 100}) {
    Future.delayed(Duration(milliseconds: milliseconds), () {
      if (mounted && _scrollController.hasClients && _scrollController.position.hasContentDimensions) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 5), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      Provider.of<MessageProvider>(context, listen: false)
          .fetchMessages(widget.appealId).then((_) {
        if (!mounted) return;
        final provider = Provider.of<MessageProvider>(context, listen: false);
        if (provider.hasNewMessages) {
          _scrollToBottom();
          provider.hasNewMessages = false;
        }
      });
    });
  }

  Future<void> _showAttachmentOptions() async {
    if (_isSending) return;
    if (mounted) {
      setState(() { _fileSelectionError = null; });
    }
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.photo_camera),
                title: Text('Сделать фото'),
                onTap: () async {
                  Navigator.pop(context);
                  await _takePicture();
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text('Выбрать фото из галереи'),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickImageFromGallery();
                },
              ),
              ListTile(
                leading: Icon(Icons.picture_as_pdf),
                title: Text('Выбрать PDF'),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickPdf();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImageFromGallery() async {
    if (!mounted) return;
    setState(() { _fileSelectionError = null; });
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );
      if (result != null && mounted) {
        setState(() {
          final newPaths = result.paths
              .where((path) => path != null && !_selectedFilePaths.contains(path))
              .map((path) => path!);
          _selectedFilePaths = [..._selectedFilePaths, ...newPaths];
        });
      }
    } catch (e) {
      print("Gallery image picking error: $e");
      if (mounted) setState(() { _fileSelectionError = "Ошибка выбора фото: $e"; });
    }
  }

  Future<void> _takePicture() async {
    if (!mounted) return;
    setState(() { _fileSelectionError = null; });
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(source: ImageSource.camera);
      if (photo != null && mounted) {
        setState(() {
          if (!_selectedFilePaths.contains(photo.path)) {
            _selectedFilePaths.add(photo.path);
          }
        });
      }
    } catch (e) {
      print("Camera error: $e");
      if (mounted) setState(() { _fileSelectionError = 'Ошибка камеры: $e'; });
    }
  }

  Future<void> _pickPdf() async {
    if (!mounted) return;
    setState(() { _fileSelectionError = null; });
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
      );
      if (result != null && mounted) {
        setState(() {
          final newPaths = result.paths
              .where((path) => path != null && !_selectedFilePaths.contains(path))
              .map((path) => path!);
          _selectedFilePaths = [..._selectedFilePaths, ...newPaths];
        });
      }
    } catch (e) {
      print("PDF picking error: $e");
      if (mounted) setState(() { _fileSelectionError = 'Ошибка при выборе PDF: $e'; });
    }
  }

  void _sendMessage() async {
    print("_sendMessage: Starting...");
    if (!mounted || _isSending) {
      print("_sendMessage: Exit - Not mounted or already sending");
      return;
    }

    final content = _messageController.text.trim();
    if (content.isEmpty && _selectedFilePaths.isEmpty) {
      print("_sendMessage: Exit - Content and files are empty");
      return;
    }

    setState(() { _isSending = true; });
    print("_sendMessage: Set _isSending = true");

    try {
      print("_sendMessage: Calling provider.sendMessage...");
      await Provider.of<MessageProvider>(context, listen: false)
          .sendMessage(widget.appealId, content, _selectedFilePaths);
      print("_sendMessage: provider.sendMessage finished.");

      if (mounted) {
        print("_sendMessage: Clearing inputs and scrolling");
        _messageController.clear();
        setState(() {
          _selectedFilePaths = [];
          _fileSelectionError = null;
        });
        _scrollToBottom();
      }
    } catch (e) {
      print("_sendMessage: Error caught: $e");
      if (mounted) {
        print("_sendMessage: Showing SnackBar for error");
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка отправки: $e'), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) {
        print("_sendMessage: Finally block, setting _isSending = false");
        setState(() { _isSending = false; });
      } else {
        print("_sendMessage: Finally block, but not mounted");
      }
    }
    print("_sendMessage: Finished.");
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
              onPressed: _isSending ? null : () {
                _timer?.cancel();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AppealUpdateScreen(appealId: widget.appealId),
                  ),
                ).then((_) {
                  if (mounted) _startPolling();
                });
              },
            ),
        ],
      ),
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          Consumer<AppealProvider>(
              builder: (context, appealProvider, child) {
                final appeal = appealProvider.getAppealById(widget.appealId);
                if (appeal == null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && !appealProvider.isLoading) {
                      appealProvider.refreshAppeal(widget.appealId);
                    }
                  });
                  return Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(
                          child: appealProvider.isLoading
                              ? CircularProgressIndicator()
                              : Text("Загрузка данных обращения...")
                      )
                  );
                }
                final categoryName = Provider.of<CategoryProvider>(context, listen: false).getCategoryName(appeal.categoryId);
                final statusName = Provider.of<StatusProvider>(context, listen: false).getStatusName(appeal.statusId);
                final filePaths = appeal.filePaths ?? [];
                final senderName = (appeal.user?.fullName?.isNotEmpty ?? false)
                    ? '${appeal.user!.fullName} (${appeal.user!.username})'
                    : appeal.user?.username ?? 'Неизвестный пользователь';

                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Адрес: ${appeal.address}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('Категория: $categoryName'),
                      const SizedBox(height: 8),
                      Text('Статус: $statusName'),
                      const SizedBox(height: 8),
                      Text("Описание: ${appeal.description?.isNotEmpty ?? false ? appeal.description : 'Нет описания'}"),
                      const SizedBox(height: 8),
                      Text('Создано: ${DateFormat('dd.MM.yyyy HH:mm', 'ru_RU').format(appeal.createdAt.toLocal())}'),
                      const SizedBox(height: 8),
                      Text('Обновлено: ${DateFormat('dd.MM.yyyy HH:mm', 'ru_RU').format(appeal.updatedAt.toLocal())}'),
                      const SizedBox(height: 8),
                      Text('Отправитель: $senderName'),
                      const SizedBox(height: 8),
                      if (filePaths.isNotEmpty) Text("Файлы обращения:", style: Theme.of(context).textTheme.titleSmall),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: filePaths.map((path) {
                          return InkWell(
                            onTap: () async {
                              final uri = Uri.tryParse(path);
                              if (uri == null) {
                                print('Invalid URL: $path');
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Некорректная ссылка на файл')));
                                return;
                              }
                              try {
                                bool launched = await launchUrl(uri);
                                if (!launched && mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось открыть ссылку: $path')));
                                }
                              } catch (e) {
                                print('Error launching URL $uri: $e');
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка при открытии ссылки: $e')));
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                children: [
                                  Icon(Icons.attach_file, size: 16, color: Colors.grey[700]),
                                  SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      _shortenFileName(path, 40),
                                      style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                );
              }
          ),
          const Divider(height: 1, thickness: 1),

          Expanded(
            child: Container(
              child: Builder(
                  builder: (context) {
                    final provider = context.watch<MessageProvider>();

                    if (provider.isLoading && provider.messages.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    else if (provider.error != null) {
                      return Center(child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text('Ошибка загрузки сообщений: ${provider.error}'),
                      ));
                    }
                    else if (provider.messages.isEmpty) {
                      return Center(child: Text("Нет сообщений в этом чате"));
                    }
                    else {
                      return ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                        itemCount: provider.messages.length,
                        itemBuilder: (context, index) {
                          final message = provider.messages[index];
                          return MessageBubble(message: message);
                        },
                      );
                    }
                  }
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1),

          if (_selectedFilePaths.isNotEmpty || _fileSelectionError != null)
            _buildSelectedFilesPreview(),

          Padding(
            padding: EdgeInsets.fromLTRB(
                8.0,
                8.0,
                8.0,
                MediaQuery.of(context).viewInsets.bottom > 0
                    ? 8.0
                    : MediaQuery.of(context).padding.bottom + 8.0
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(Icons.attach_file),
                  onPressed: _isSending ? null : _showAttachmentOptions,
                  tooltip: 'Прикрепить файл',
                ),
                Expanded(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: 150),
                    child: TextField(
                      enabled: !_isSending,
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Введите сообщение...',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20.0),
                            borderSide: BorderSide.none
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                      ),
                      maxLines: 3,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      keyboardType: TextInputType.multiline,
                      maxLength: 500,
                      maxLengthEnforcement: MaxLengthEnforcement.enforced,
                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                    ),
                  ),
                ),
                SizedBox(width: 5),
                _isSending
                    ? Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                )
                    : IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _sendMessage,
                  tooltip: 'Отправить',
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedFilesPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      constraints: BoxConstraints(maxHeight: 100),
      decoration: BoxDecoration(color: Colors.grey[100]),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_fileSelectionError != null)
            Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text(_fileSelectionError!, style: TextStyle(color: Colors.red, fontSize: 12))
            ),
          if (_selectedFilePaths.isNotEmpty)
            Expanded(
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _selectedFilePaths.map((path) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Container(
                          width: 60, height: 60,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: _buildMiniPreviewIcon(path),
                          alignment: Alignment.center,
                        ),
                        InkWell(
                          onTap: () {
                            if (!mounted || _isSending) return;
                            setState(() {
                              _selectedFilePaths.remove(path);
                            });
                          },
                          child: Container(
                            padding: EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.8),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.close, color: Colors.white, size: 12),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMiniPreviewIcon(String path) {
    try {
      final extension = p.extension(path).toLowerCase();
      if (['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'].contains(extension)) {
        if (kIsWeb) return Icon(Icons.image, size: 30, color: Colors.grey[600]);
        try {
          return ClipRRect(
              borderRadius: BorderRadius.circular(4.0),
              child: Image.file(
                  File(path),
                  width: 60, height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    print("Error loading image preview for $path: $error");
                    return Icon(Icons.broken_image, size: 30, color: Colors.grey[600]);
                  }
              )
          );
        } catch (e) {
          print("Error creating Image.file for $path: $e");
          return Icon(Icons.broken_image, size: 30, color: Colors.grey[600]);
        }
      }
      else if (extension == '.pdf') {
        return Icon(Icons.picture_as_pdf, size: 30, color: Colors.red[700]);
      }
      else {
        return Icon(Icons.insert_drive_file, size: 30, color: Colors.blue[700]);
      }
    } catch (e) {
      print("Error building mini preview for $path: $e");
      return Icon(Icons.error_outline, size: 30, color: Colors.orange[700]);
    }
  }

  String formatBytes(int? bytes, [int decimals = 2]) {
    if (bytes == null || bytes <= 0) return "0 Bytes";
    const suffixes = ["Bytes", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }
}

class MessageBubble extends StatelessWidget {
  final Message message;
  const MessageBubble({Key? key, required this.message}) : super(key: key);

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('dd.MM.yyyy HH:mm', 'ru_RU').format(dateTime.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final bool isCurrentUser = message.senderId == authProvider.userId;

    String senderName = 'Неизвестный';
    if (message.sender != null) {
      senderName = (message.sender!.fullName?.isNotEmpty ?? false)
          ? '${message.sender!.fullName} (${message.sender!.username})'
          : message.sender!.username;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Align(
        alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
          decoration: BoxDecoration(
              color: isCurrentUser ? Colors.blue[100] : Colors.grey[200],
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16.0),
                topRight: Radius.circular(16.0),
                bottomLeft: isCurrentUser ? Radius.circular(16.0) : Radius.circular(0),
                bottomRight: isCurrentUser ? Radius.circular(0) : Radius.circular(16.0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 2,
                  offset: Offset(1, 1),
                )
              ]
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isCurrentUser)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Text(
                    senderName,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                  ),
                ),
              if(message.content.isNotEmpty)
                SelectableText(
                  message.content,
                  style: const TextStyle(fontSize: 16),
                ),
              if (message.filePaths != null && message.filePaths!.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: message.content.isNotEmpty ? 8.0 : 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: message.filePaths!.map((filePath) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: InkWell(
                        onTap: () async {
                          final uri = Uri.tryParse(filePath);
                          if (uri == null) {
                            print('Invalid URL: $filePath');
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Некорректная ссылка на файл')));
                            return;
                          }
                          try {
                            bool launched = await launchUrl(uri);
                            if (!launched && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось открыть ссылку: $filePath')));
                            }
                          } catch (e) {
                            print('Error launching URL $uri: $e');
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка при открытии ссылки: $e')));
                          }
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_getFileIcon(filePath), size: 18, color: Colors.grey[700]),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                _shortenFileName(filePath, 25),
                                style: TextStyle(fontSize: 14, color: Colors.blue[800], decoration: TextDecoration.underline),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )).toList(),
                  ),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    _formatDateTime(message.createdAt),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getFileIcon(String filePath) {
    try {
      final extension = p.extension(filePath).toLowerCase();
      if (['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'].contains(extension)) return Icons.image;
      else if (extension == '.pdf') return Icons.picture_as_pdf;
      else if (['.doc', '.docx'].contains(extension)) return Icons.description;
      else if (['.xls', '.xlsx'].contains(extension)) return Icons.assessment;
      else if (['.ppt', '.pptx'].contains(extension)) return Icons.slideshow;
      else if (['.zip', '.rar', '.7z'].contains(extension)) return Icons.archive;
      else if (['.mp3', '.wav', '.ogg', '.aac', '.m4a'].contains(extension)) return Icons.audiotrack;
      else if (['.mp4', '.avi', '.mov', '.mkv', '.wmv'].contains(extension)) return Icons.video_library;
      else if (extension == '.txt') return Icons.article;
      else return Icons.insert_drive_file;
    } catch (e) {
      return Icons.insert_drive_file;
    }
  }
}