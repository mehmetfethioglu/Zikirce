import 'package:flutter/material.dart';

import 'features/pdks/presentation/screens/hasibu_login_screen.dart';
import 'features/pdks/presentation/screens/hasibu_settings_view.dart';
import 'features/pdks/presentation/screens/hasibu_shell_screen.dart';
import 'screens/mobil_arayuz_iyilestirme_screen.dart';

/// Hasibu Uygulama Rotaları
class HasibuRoutes {
  static const String home = '/';
  static const String mobileDashboard = '/mobile';
  static const String login = '/login';
  static const String settings = '/settings';
}

/// Hasibu Sayfa Rotalama ve Navigasyon Yöneticisi
class HasibuRouter {
  /// Named route üreticisi
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case HasibuRoutes.home:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const HasibuShellScreen(),
        );

      case HasibuRoutes.mobileDashboard:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const MobilArayuzIyilestirmeScreen(),
        );

      case HasibuRoutes.login:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const HasibuLoginScreen(),
        );

      case HasibuRoutes.settings:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const Scaffold(
            body: CompanyAndBranchesSettingsView(),
          ),
        );

      default:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const HasibuShellScreen(),
        );
    }
  }

  /// Mobil arayüz ekranına doğrudan geçiş
  static void navigateToMobile(BuildContext context) {
    Navigator.of(context).pushNamed(HasibuRoutes.mobileDashboard);
  }

  /// Ana kabuğa dönüş
  static void navigateToHome(BuildContext context) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      HasibuRoutes.home,
      (route) => false,
    );
  }
}
