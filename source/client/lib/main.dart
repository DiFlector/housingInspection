import 'package:flutter/material.dart';
import 'package:housing_inspection_client/providers/appeal_provider.dart';
import 'package:housing_inspection_client/screens/appeal_list_screen.dart';
import 'package:housing_inspection_client/screens/auth_screen.dart';
import 'package:housing_inspection_client/screens/registration_screen.dart';
import 'package:housing_inspection_client/screens/user_list_screen.dart';
import 'package:provider/provider.dart';
import 'package:housing_inspection_client/providers/category_provider.dart';
import 'package:housing_inspection_client/providers/status_provider.dart';
import 'package:housing_inspection_client/providers/auth_provider.dart';
import 'package:housing_inspection_client/providers/user_provider.dart';
import 'package:housing_inspection_client/screens/category_edit_screen.dart';
import 'package:housing_inspection_client/screens/category_list_screen.dart';
import 'package:housing_inspection_client/screens/status_edit_screen.dart';
import 'package:housing_inspection_client/screens/status_list_screen.dart';
import 'package:housing_inspection_client/screens/appeal_create_wizard_screen.dart';
import 'package:housing_inspection_client/providers/knowledge_base_provider.dart';
import 'package:housing_inspection_client/screens/knowledge_base_category_screen.dart';
import 'package:housing_inspection_client/screens/knowledge_base_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final categoryProvider = CategoryProvider();
  await categoryProvider.fetchCategories();
  final statusProvider = StatusProvider();
  await statusProvider.fetchStatuses();
  final authProvider = AuthProvider();
  await authProvider.loadToken();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AppealProvider()),
        ChangeNotifierProvider(create: (context) => categoryProvider),
        ChangeNotifierProvider(create: (context) => statusProvider),
        ChangeNotifierProvider(create: (context) => authProvider),
        ChangeNotifierProvider(create: (context) => UserProvider()),
        ChangeNotifierProvider(create: (context) => KnowledgeBaseProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static final navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('ru', 'RU'),
      title: 'Жилищная инспекция',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          return authProvider.isLoggedIn
              ? const AppealListScreen()
              : const AuthScreen();
        },
      ),
      routes: {
        '/appeals': (context) => const AppealListScreen(),
        '/auth': (context) => const AuthScreen(),
        '/register': (context) => const RegistrationScreen(),
        '/users': (context) => const UserListScreen(),
        '/categories': (context) => const CategoryListScreen(),
        '/categories/edit': (context) => const CategoryEditScreen(category: null),
        '/statuses': (context) => const StatusListScreen(),
        '/statuses/edit': (context) => const StatusEditScreen(status: null),
        '/appeals/create': (context) => const AppealCreateWizardScreen(),
        '/knowledge_base': (context) => const KnowledgeBaseScreen(),
        '/knowledge_base_category': (context) => const KnowledgeBaseCategoryScreen(category: '',),
      },
    );
  }
}