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
import 'package:housing_inspection_client/providers/message_provider.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:housing_inspection_client/screens/appeal_detail_screen.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel',
  'High Importance Notifications',
  description: 'This channel is used for important notifications.',
  importance: Importance.high,
);

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      IOSFlutterLocalNotificationsPlugin>()
      ?.requestPermissions(
    alert: true,
    badge: true,
    sound: true,
  );

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
        ChangeNotifierProvider(create: (context) => MessageProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  static final navigatorKey = GlobalKey<NavigatorState>();

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  @override
  void initState() {
    super.initState();
    _setupFirebaseMessagingListeners();
    _handleInitialMessage();
  }

  void _setupFirebaseMessagingListeners() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        flutterLocalNotificationsPlugin.show(
            notification.hashCode,
            notification.title,
            notification.body,
            NotificationDetails(
              android: AndroidNotificationDetails(
                channel.id,
                channel.name,
                channelDescription: channel.description,
                icon: android.smallIcon ?? '@mipmap/ic_launcher',
              ),
            ),
            payload: message.data['appeal_id']
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('A new onMessageOpenedApp event was published!');
      _handleNotificationTap(message.data);
    });

    _configureLocalNotifications();
  }

  void _configureLocalNotifications() {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    flutterLocalNotificationsPlugin.initialize(initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse notificationResponse) async {
        final String? payload = notificationResponse.payload;
        if (payload != null) {
          print('notification payload: $payload');
          _handleNotificationTap({'appeal_id': payload});
        }
      },
    );
  }

  void _handleInitialMessage() async {
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      print('App launched from terminated state by notification!');
      _handleNotificationTap(initialMessage.data);
    }
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    final String? appealIdString = data['appeal_id'];
    if (appealIdString != null) {
      final int? appealId = int.tryParse(appealIdString);
      if (appealId != null) {
        print("Navigating to appeal: $appealId");
        MyApp.navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => AppealDetailScreen(appealId: appealId),
          ),
        );
      } else {
        print("Error parsing appeal_id from notification data: $appealIdString");
      }
    } else {
      print("No appeal_id found in notification data");
    }
  }


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: MyApp.navigatorKey,
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