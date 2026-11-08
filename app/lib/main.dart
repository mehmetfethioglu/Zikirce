import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'constants/camera_colors.dart';
import 'screens/camera_home_screen.dart';
import 'services/version_tracking_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF000000),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  VersionTrackingService? versionService;
  try {
    versionService = await VersionTrackingService.initialize();
  } catch (e, stackTrace) {
    debugPrint('Zamera VersionTrackingService initialization failed: $e\n$stackTrace');
    versionService = null;
  }

  runApp(ZameraApp(versionService: versionService));
}

class ZameraApp extends StatelessWidget {
  final VersionTrackingService? versionService;

  const ZameraApp({super.key, this.versionService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zamera',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kObsidianBg,
        colorScheme: const ColorScheme.dark(
          primary: kIosYellow,
          secondary: kZameraCyan,
          surface: Color(0xFF101218),
        ),
        useMaterial3: true,
      ),
      home: ZameraHomeScreen(versionService: versionService),
    );
  }
}
