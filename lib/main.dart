import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_credentials.dart';
import 'core/routes/app_routes.dart';
import 'core/services/auth_session.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _loadEnvironment();
  await Supabase.initialize(
    url: SupabaseCredentials.supabaseUrl,
    anonKey: SupabaseCredentials.supabaseAnonKey,
  );
  AuthSession.I.refreshCurrentUser();
  final session = Supabase.instance.client.auth.currentSession;
  final initialRoute = session == null ? AppRoutes.login : AppRoutes.home;

  runApp(MyApp(initialRoute: initialRoute));
}

Future<void> _loadEnvironment() async {
  if (dotenv.isInitialized) {
    return;
  }

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    await dotenv.load(fileName: '.env.example');
  }
}

class MyApp extends StatelessWidget {
  final String initialRoute;

  const MyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mi Aplicación BLE',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: initialRoute,
      routes: AppRoutes.routes,
    );
  }
}