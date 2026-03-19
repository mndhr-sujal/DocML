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
  @override
  void dispose() {
    AiBackendService().dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(),
    );
  }
}
