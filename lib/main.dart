import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/onboarding_screen.dart';
import 'screens/root_shell.dart';
import 'services/library_service.dart';
import 'services/player_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final onboarded = prefs.getBool('onboarded') ?? false;

  final library = LibraryService();
  final player = PlayerService(library);

  runApp(VidHiveApp(library: library, player: player, onboarded: onboarded));
}

class VidHiveApp extends StatelessWidget {
  const VidHiveApp({
    super.key,
    required this.library,
    required this.player,
    required this.onboarded,
  });

  final LibraryService library;
  final PlayerService player;
  final bool onboarded;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<LibraryService>.value(value: library),
        ChangeNotifierProvider<PlayerService>.value(value: player),
      ],
      child: MaterialApp(
        title: 'VidHive',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        home: onboarded ? const RootShell() : const OnboardingScreen(),
      ),
    );
  }
}
