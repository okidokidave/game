import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ads/ad_service.dart';
import 'audio/sound_service.dart';
import 'game/game_controller.dart';
import 'game/save_repository.dart';
import 'scene/sprites.dart';
import 'ui/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final prefs = await SharedPreferences.getInstance();
  final controller = GameController(SaveRepository(prefs));

  final sprites = await Sprites.load();
  final ads = AdMobService();
  final sound = GameSoundService(prefs);

  runApp(
    GoldMineApp(
      controller: controller,
      ads: ads,
      sprites: sprites,
      sound: sound,
    ),
  );
  sound.initialize();
  // 동의 창은 화면이 뜬 뒤에 띄워야 하므로 runApp 다음에 시작한다.
  ads.initialize();
}

class GoldMineApp extends StatelessWidget {
  const GoldMineApp({
    super.key,
    required this.controller,
    required this.ads,
    this.sprites,
    this.sound,
  });

  final GameController controller;
  final AdService ads;
  final Sprites? sprites;
  final SoundService? sound;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '골드 광산 키우기',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFB300),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF1E1610),
      ),
      home: HomeScreen(
        controller: controller,
        ads: ads,
        sprites: sprites,
        sound: sound,
      ),
    );
  }
}
