// REF: VIGILO-MVP-R41Y-2025-08-17
// Changes vs R41X ONLY:
// 1) Home screen empty state: shows icon + "No exams yet" when there are no cards.
// 2) Officer Tools → Messages: "Edit presets" added for Quick Messages (persisted in localStorage).

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'utils/app_themes.dart';
import 'views/home_screen.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  if (kIsWeb) {
    await Hive.initFlutter();
  } else {
    final dir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(dir.path);
  }

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(const VigiloApp());
}

class VigiloApp extends StatefulWidget {
  const VigiloApp({super.key});

  @override
  State<VigiloApp> createState() => _VigiloAppState();
}

class _VigiloAppState extends State<VigiloApp> {
  bool dark = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vigilo ERC',
      debugShowCheckedModeBanner: false,
      theme: dark ? darkTheme() : lightTheme(),
      home: HomeScreen(
        dark: dark,
        onToggleTheme: () {
          setState(() => dark = !dark);
        },
      ),
    );
  }
}
