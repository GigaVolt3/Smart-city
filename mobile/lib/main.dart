import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/providers.dart';
import 'core/theme/app_theme.dart';
import 'data/api_client.dart';
import 'features/auth/auth_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final storedBaseUrl = prefs.getString(ApiClient.prefsKey);
  runApp(
    ProviderScope(
      overrides: [
        if (storedBaseUrl != null && storedBaseUrl.trim().isNotEmpty)
          initialApiBaseUrlProvider.overrideWithValue(storedBaseUrl),
      ],
      child: const CivicAIApp(),
    ),
  );
}

class CivicAIApp extends StatelessWidget {
  const CivicAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CivicAI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AuthGate(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'IN'),
      ],
    );
  }
}
