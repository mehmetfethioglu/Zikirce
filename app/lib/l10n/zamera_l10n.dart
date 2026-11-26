import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';

/// Lightweight zero-codegen bilingual (TR / EN) localization helper.
class ZameraL10n {
  const ZameraL10n._();

  static const List<Locale> supportedLocales = <Locale>[
    Locale('tr'),
    Locale('en'),
  ];

  /// Resolves whether UI should render Turkish or English.
  ///
  /// When a host [MaterialApp] explicitly declares `tr` in `supportedLocales`,
  /// the resolved locale (`tr` vs `en`) governs all copy. Otherwise (e.g.
  /// isolated widget tests using `MaterialApp(home: ...)` without
  /// `supportedLocales`), defaults to Turkish to preserve deterministic tests
  /// unless an explicit non-Turkish `locale` was passed on `MaterialApp`.
  static bool isTurkish(BuildContext context) {
    final app = context.findAncestorWidgetOfExactType<MaterialApp>();
    if (app != null) {
      if (app.locale != null) {
        return app.locale!.languageCode.toLowerCase().startsWith('tr');
      }
      final supportsTr = app.supportedLocales.any(
        (l) => l.languageCode.toLowerCase() == 'tr',
      );
      if (supportsTr) {
        final resolved =
            Localizations.maybeLocaleOf(context)?.languageCode ??
            PlatformDispatcher.instance.locale.languageCode;
        return resolved.toLowerCase().startsWith('tr');
      }
      return true;
    }
    final resolved =
        Localizations.maybeLocaleOf(context)?.languageCode ??
        PlatformDispatcher.instance.locale.languageCode;
    return resolved.toLowerCase().startsWith('tr');
  }

  static String pick(BuildContext context, {required String tr, required String en}) {
    return isTurkish(context) ? tr : en;
  }
}
