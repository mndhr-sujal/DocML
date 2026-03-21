import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'pages/home_page.dart';
import 'services/ai_backend_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  windowManager.waitUntilReadyToShow(
    const WindowOptions(minimumSize: Size(1200, 700)),
    () async {
      await windowManager.show();
      await windowManager.focus();
      await windowManager.maximize();
    },
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ValueNotifier<ThemeMode> _themeMode = ValueNotifier(ThemeMode.light);

  @override
  void dispose() {
    AiBackendService().dispose();
    _themeMode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'DocML',
          themeMode: mode,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFC4B5D9),
              brightness: Brightness.light,
            ).copyWith(
              surfaceVariant: const Color(0xFFC4B5D9),
              secondaryContainer: const Color(0xFFF1E9FD),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFC4B5D9),
              brightness: Brightness.dark,
            ).copyWith(
              surface: const Color(0xFF1E1E1E),
              surfaceContainerLowest: Colors.black,
            ),
            scaffoldBackgroundColor: Colors.black,
          ),
          home: HomePage(themeMode: _themeMode),
        );
      },
    );
  }
}
