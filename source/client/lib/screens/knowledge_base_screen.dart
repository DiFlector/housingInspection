import 'package:flutter/material.dart';
import 'package:housing_inspection_client/screens/knowledge_base_category_screen.dart';

class KnowledgeBaseScreen extends StatelessWidget {
  const KnowledgeBaseScreen({Key? key}) : super(key: key);

  final List<String> categories = const [
    'legislations',
    'examples',
    'templates',
  ];

  final List<String> categories_ru = const [
    'Законодательство',
    'Примеры',
    'Шаблоны',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('База знаний'),
      ),
      body: ListView.builder(
        itemCount: categories.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        KnowledgeBaseCategoryScreen(category: categories[index]),
                  ),
                );
              },
              child: Text(categories_ru[index]),
            ),
          );
        },
      ),
    );
  }
}