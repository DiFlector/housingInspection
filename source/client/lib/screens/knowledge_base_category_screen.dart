import 'package:flutter/material.dart';
import 'package:housing_inspection_client/providers/knowledge_base_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as p;
import 'dart:io';
import 'package:flutter/foundation.dart'
    show kIsWeb, consolidateHttpClientResponseBytes;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart'; //  Импортируем
import 'package:http/http.dart' as http; //  ДОБАВЛЕНО
import 'dart:convert'; //  ДОБАВЛЕНО

class KnowledgeBaseCategoryScreen extends StatefulWidget {
  final String category;

  const KnowledgeBaseCategoryScreen({Key? key, required this.category})
      : super(key: key);

  @override
  State<KnowledgeBaseCategoryScreen> createState() =>
      _KnowledgeBaseCategoryScreenState();
}

class _KnowledgeBaseCategoryScreenState
    extends State<KnowledgeBaseCategoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<KnowledgeBaseProvider>(context, listen: false)
          .fetchCategoryFiles(widget.category);
    });
  }

  @override
  Widget build(BuildContext context) {
    String categoryName = '';
    if (widget.category == 'legislations') {
      categoryName = "Законодательство";
    } else if (widget.category == 'examples') {
      categoryName = "Примеры";
    } else if (widget.category == 'templates') {
      categoryName = "Шаблоны";
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(categoryName),
      ),
      body: Consumer<KnowledgeBaseProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (provider.error != null) {
            return Center(child: Text('Ошибка: ${provider.error}'));
          } else if (provider.fileUrls == null || provider.fileUrls!.isEmpty) {
            return const Center(child: Text('Файлы не найдены'));
          } else {
            return ListView.builder(
              //  ФИЛЬТРУЕМ СПИСОК:
              itemCount: provider.fileUrls!
                  .where((url) => !p.basename(url).endsWith('/'))
                  .length, //  Считаем длину отфильтрованного списка
              itemBuilder: (context, index) {
                //  ФИЛЬТРУЕМ СПИСОК ПЕРЕД ОТОБРАЖЕНИЕМ:
                final url = provider.fileUrls!
                    .where((url) => !p.basename(url).endsWith('/'))
                    .toList()[index]; //  Получаем URL из отфильтрованного списка
                final fileName = p.basename(url);
                final extension = p.extension(url).toLowerCase();

                return ListTile(
                  title: Text(fileName),
                  trailing:
                  _buildIcon(extension), //  Иконка в зависимости от расширения
                  onTap: () async {
                    //  УБИРАЕМ СКАЧИВАНИЕ:
                    // if (extension == '.docx') {
                    //   _downloadFile(url, fileName);
                    // } else {
                    //  ОТКРЫВАЕМ ВНУТРИ ПРИЛОЖЕНИЯ (MarkdownViewerScreen):
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MarkdownViewerScreen(url: url),
                      ),
                    );
                    // }
                  },
                );
              },
            );
          }
        },
      ),
    );
  }

  Widget _buildIcon(String extension) {
    switch (extension) {
      case '.pdf':
        return const Icon(Icons.picture_as_pdf);
      case '.docx':
        return const Icon(
            Icons.file_download); //  Иконка скачивания для docx (оставляем)
      case '.md': //  Добавили
        return const Icon(Icons.description); //  Иконка для Markdown
      default:
        return const Icon(Icons.insert_drive_file);
    }
  }

//  УДАЛЯЕМ _downloadFile, он больше не нужен

}

//  НОВЫЙ ВИДЖЕТ ДЛЯ ОТОБРАЖЕНИЯ MARKDOWN:
class MarkdownViewerScreen extends StatelessWidget {
  final String url;

  const MarkdownViewerScreen({Key? key, required this.url}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(p.basename(url)), //  Отображаем имя файла в заголовке
      ),
      body: FutureBuilder<String>(
        future: _loadMarkdown(url),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          } else if (snapshot.data == null || snapshot.data!.isEmpty) {
            return const Center(child: Text('Не удалось загрузить файл'));
          } else {
            return Markdown(data: snapshot.data!); //  Используем Markdown виджет
          }
        },
      ),
    );
  }

  Future<String> _loadMarkdown(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      return utf8.decode(response.bodyBytes);
    } else {
      throw Exception('Failed to load markdown file: ${response.statusCode}');
    }
  }
}