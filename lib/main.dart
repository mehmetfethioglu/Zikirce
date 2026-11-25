import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/reading_notification_service.dart';
import 'core/theme/tahrir_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/analytics_and_habits/presentation/screens/insights_screen.dart';
import 'features/bookshelf/presentation/providers/bookshelf_provider.dart';
import 'features/bookshelf/presentation/screens/bookshelf_screen.dart';
import 'features/marginalia/presentation/screens/highlights_screen.dart';
import 'features/onboarding/presentation/widgets/tahrir_onboarding_dialog.dart';
import 'features/reader/presentation/screens/reader_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/speed_reading/presentation/screens/speed_reading_academy_screen.dart';
import 'features/subscription/presentation/providers/subscription_provider.dart';
import 'features/subscription/presentation/widgets/tahrir_pro_sheet.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Çevrimdışı OCR tashih sözlüğü kaynağı (Apache 2.0) lisans bildirimi
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(
      ['zemberek-nlp (Türkçe sözlük verisi)'],
      'Copyright 2018 Ahmet A. Akın, Mehmet D. Akın\n\n'
      'Licensed under the Apache License, Version 2.0 (the "License"); you may not use this '
      'file except in compliance with the License. You may obtain a copy of the License at\n\n'
      'http://www.apache.org/licenses/LICENSE-2.0\n\n'
      'Unless required by applicable law or agreed to in writing, software distributed under '
      'the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY '
      'KIND, either express or implied. See the License for the specific language governing '
      'permissions and limitations under the License.\n\n'
      'Tahrir, https://github.com/ahmetaa/zemberek-nlp deposundaki sözlük dosyalarından '
      'türetilmiş bir kelime listesi içerir (tool/build_turkish_lexicon.py).',
    );
  });

  // Set immersive edge-to-edge transparent system overlay
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  runApp(
    const ProviderScope(
      child: TahrirApp(),
    ),
  );
}

class TahrirApp extends ConsumerWidget {
  const TahrirApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (preset, themeMode) = ref.watch(
      readerThemeProvider.select((s) => (s.preset, s.themeMode)),
    );

    return MaterialApp(
      title: 'Tahrir',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: TahrirTheme.getThemeForPreset(preset, isDark: false),
      darkTheme: TahrirTheme.getThemeForPreset(preset, isDark: true),
      home: const MainNavigationShell(),
    );
  }
}

class MainNavigationShell extends ConsumerStatefulWidget {
  const MainNavigationShell({super.key});

  @override
  ConsumerState<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _isEntryPaywallOpen = false;
  bool _hasShownEntryPaywallThisSession = false;

  final List<Widget> _screens = const [
    BookshelfScreen(),
    SpeedReadingAcademyScreen(),
    HighlightsScreen(),
    InsightsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await TahrirOnboardingDialog.checkAndShow(context, ref);
      if (!mounted) return;
      await ref.read(subscriptionProvider.notifier).ensureLoaded();
      await _showEntryPaywallIfRequired();
      await _checkIncomingFile();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(subscriptionProvider.notifier).refreshEntitlementClock();
      unawaited(_showEntryPaywallIfRequired());
      _checkIncomingFile();
    }
  }

  Future<void> _showEntryPaywallIfRequired() async {
    if (!mounted ||
        _isEntryPaywallOpen ||
        _hasShownEntryPaywallThisSession) {
      return;
    }
    final subState = ref.read(subscriptionProvider);
    if (!subState.shouldShowEntryPaywall) return;

    _isEntryPaywallOpen = true;
    _hasShownEntryPaywallThisSession = true;
    try {
      await TahrirProSheet.show(context, isEntryPrompt: true);
    } finally {
      _isEntryPaywallOpen = false;
    }
  }

  Future<void> _checkIncomingFile() async {
    final incomingPath = await ref
        .read(readingNotificationProvider.notifier)
        .consumeIncomingFile();
    if (incomingPath == null || !mounted) return;

    final importedBook = await ref
        .read(bookshelfProvider.notifier)
        .importBookFromPath(incomingPath);
    if (importedBook != null && mounted) {
      final isPro = ref.read(subscriptionProvider).isPro;
      if (!isPro && importedBook.format.name != 'pdf') {
        await TahrirProSheet.show(context);
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReaderScreen(book: importedBook),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(
      subscriptionProvider.select((s) => s.shouldShowEntryPaywall),
      (previous, next) {
        if (!next) {
          _hasShownEntryPaywallThisSession = false;
          return;
        }
        if (!_hasShownEntryPaywallThisSession &&
            !_isEntryPaywallOpen &&
            mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            unawaited(_showEntryPaywallIfRequired());
          });
        }
      },
    );

    final theme = Theme.of(context);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        backgroundColor: theme.colorScheme.surface,
        indicatorColor: theme.colorScheme.primary.withOpacity(0.18),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.book_outlined),
            selectedIcon: Icon(Icons.book),
            label: 'Kitaplık',
          ),
          NavigationDestination(
            icon: Icon(Icons.speed_outlined),
            selectedIcon: Icon(Icons.speed_rounded),
            label: 'Hızlı Okuma',
          ),
          NavigationDestination(
            icon: Icon(Icons.edit_note_outlined),
            selectedIcon: Icon(Icons.edit_note),
            label: 'Notlar',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'İstatistik',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Ayarlar',
          ),
        ],
      ),
    );
  }
}
