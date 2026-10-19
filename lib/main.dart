import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/database/hasibu_database.dart';
import 'features/pdks/presentation/providers/pdks_providers.dart';
import 'features/pdks/presentation/screens/hasibu_shell_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await HasibuDatabase.openDefault();

  runApp(
    ProviderScope(
      overrides: [
        hasibuDatabaseProvider.overrideWithValue(db),
      ],
      child: const HasibuApp(),
    ),
  );
}

class HasibuApp extends StatelessWidget {
  const HasibuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hasibu • Yalın Üretim, PDKS & İK',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('tr', 'TR'),
        Locale('en', 'US'),
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0284C7),
          brightness: Brightness.light,
        ),
      ),
      home: const HasibuShellScreen(),
    );
  }
}
