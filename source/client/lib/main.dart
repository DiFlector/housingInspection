import 'package:flutter/material.dart';
import 'package:housing_inspection_client/providers/appeal_provider.dart';
import 'package:housing_inspection_client/screens/appeal_list_screen.dart';
import 'package:housing_inspection_client/screens/auth_screen.dart';
import 'package:housing_inspection_client/screens/registration_screen.dart';
import 'package:provider/provider.dart';
import 'package:housing_inspection_client/providers/category_provider.dart';
import 'package:housing_inspection_client/providers/status_provider.dart';
import 'package:housing_inspection_client/providers/auth_provider.dart';

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
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: const Locale('ru', 'RU'),
      title: 'Housing Inspection Client',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          return authProvider.isLoggedIn ? const AppealListScreen() : const AuthScreen();
        },
      ),
      routes: {
        '/appeals': (context) => const AppealListScreen(),
        '/auth': (context) => const AuthScreen(),
        '/register': (context) => const RegistrationScreen(),
      },
    );
  }
}