import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/app_localizations.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

/// Root widget of the Hidavo application.
///
/// Responsibilities:
///   • Provides [MaterialApp.router] wired to [appRouter] (GoRouter).
///   • Applies [AppTheme.lightTheme] as the global theme.
///   • Declares localisation delegates and supported locales (ru + en).
///   • Keeps the widget tree const-constructible; all mutable state lives in
///     Riverpod providers below [ProviderScope] (set up in main.dart).
class HidavoApp extends ConsumerWidget {
  const HidavoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      // ── Identity ──────────────────────────────────────────────────────────
      title: 'Hidavo',
      debugShowCheckedModeBanner: false,

      // ── Navigation ────────────────────────────────────────────────────────
      routerConfig: appRouter,

      // ── Theme ─────────────────────────────────────────────────────────────
      theme: AppTheme.lightTheme,

      // Disable the system-generated dark theme so the app always uses the
      // custom light design spec.
      darkTheme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,

      // ── Localisation ──────────────────────────────────────────────────────
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,

      // Device English → English, device Russian → Russian.
      // Any other language (or missing device locale) → English.
      localeResolutionCallback: (deviceLocale, supportedLocales) {
        if (deviceLocale != null) {
          final code = deviceLocale.languageCode;
          if (code == 'en' || code == 'ru') {
            return Locale(code);
          }
        }
        return const Locale('en');
      },

      // ── Scroll behaviour ──────────────────────────────────────────────────
      // Use the Material "stretch" overscroll on all platforms for a modern
      // feel consistent with the youth-oriented design spec.
      scrollBehavior: const _HidavoScrollBehaviour(),
    );
  }
}

/// Custom [ScrollBehavior] that enables the stretch overscroll effect on both
/// iOS and Android without changing any other default behaviours.
class _HidavoScrollBehaviour extends ScrollBehavior {
  const _HidavoScrollBehaviour();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      );

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // Suppress the default glow / stretch indicator so custom animations in
    // individual screens can take over.
    return child;
  }
}
