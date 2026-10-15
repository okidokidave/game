import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ads/ad_service.dart';
import 'audio/sound_service.dart';
import 'game/game_controller.dart';
import 'game/save_repository.dart';
import 'scene/sprites.dart';
import 'ui/home_screen.dart';
import 'ui/title_screen.dart';

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
    this.showTitle = true,
    this.dailyPopup = true,
  });

  final GameController controller;
  final AdService ads;
  final Sprites? sprites;
  final SoundService? sound;

  /// 메인 화면부터 보여 줄지 (테스트에서는 바로 게임 화면으로).
  final bool showTitle;

  /// 출석 보상판 자동 팝업 (테스트에서는 끈다).
  final bool dailyPopup;

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
      home: _Root(app: this),
    );
  }
}

/// 메인 화면 → (출발 버튼) → 게임 화면으로 부드럽게 넘어간다.
class _Root extends StatefulWidget {
  const _Root({required this.app});

  final GoldMineApp app;

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  late bool _playing = !widget.app.showTitle;

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: _playing
          ? HomeScreen(
              key: const ValueKey('home'),
              controller: app.controller,
              ads: app.ads,
              sprites: app.sprites,
              sound: app.sound,
              dailyPopup: app.dailyPopup,
            )
          : TitleScreen(
              key: const ValueKey('title'),
              game: app.controller,
              sprites: app.sprites,
              sound: app.sound,
              onStart: () => setState(() => _playing = true),
            ),
    );
  }
}
