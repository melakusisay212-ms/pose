import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'diag/breadcrumbs.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Breadcrumbs.instance.init();
  FlutterError.onError = (FlutterErrorDetails details) {
    Breadcrumbs.instance.add('Flutter error: ${details.exceptionAsString()}');
    FlutterError.presentError(details);
  };
  WidgetsBinding.instance.platformDispatcher.onError =
      (Object error, StackTrace stack) {
    Breadcrumbs.instance.add('Uncaught error: $error');
    return true;
  };
  await SystemChrome.setPreferredOrientations(
    <DeviceOrientation>[DeviceOrientation.portraitUp],
  );
  runApp(const PoseRunnerApp());
}

class PoseRunnerApp extends StatelessWidget {
  const PoseRunnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pose Runner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFFFFC107),
      ),
      home: const HomeScreen(),
    );
  }
}
