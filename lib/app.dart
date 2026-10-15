import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/config/app_config.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_mode_provider.dart';

class StockFlowApp extends StatefulWidget {
  const StockFlowApp({super.key, required this.prefs});
  final SharedPreferences prefs;

  @override
  State<StockFlowApp> createState() => _StockFlowAppState();
}

class _StockFlowAppState extends State<StockFlowApp> {
  late final ThemeModeProvider _theme = ThemeModeProvider(widget.prefs);
  late final AuthProvider _auth = AuthProvider()..bootstrap();
  late final _router = buildRouter(_auth);
  late final _light = buildTheme(Brightness.light);
  late final _dark = buildTheme(Brightness.dark);

  @override
  void dispose() {
    _theme.dispose();
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _theme),
        ChangeNotifierProvider.value(value: _auth),
      ],
      child: Consumer<ThemeModeProvider>(
        builder: (_, theme, _) => MaterialApp.router(
          title: AppConfig.brandName,
          debugShowCheckedModeBanner: false,
          theme: _light,
          darkTheme: _dark,
          themeMode: theme.mode,
          routerConfig: _router,
        ),
      ),
    );
  }
}
