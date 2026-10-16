import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ads/ad_service.dart';
import 'audio/sound_service.dart';
import 'game/game_controller.dart';
import 'game/save_repository.dart';
import 'ui/home_screen.dart';
import 'ui/palette.dart';
import 'ui/title_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // 상태 표시줄을 어두운 화면에 맞게 (흰 글씨, 투명 배경)
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Pal.surface,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  final prefs = await SharedPreferences.getInstance();
  final game = GameController(SaveRepository(prefs));
  final ads = AdMobService();
  final sound = GameSoundService(prefs);

  runApp(InfluencerApp(game: game, ads: ads, sound: sound));
  sound.initialize();
  // 동의 창은 화면이 뜬 뒤에 띄워야 하므로 runApp 다음에 시작한다.
  ads.initialize();
}

class InfluencerApp extends StatelessWidget {
  const InfluencerApp({super.key, required this.game, required this.ads, this.sound, this.liveDuration = const Duration(milliseconds: 4200)});

  final GameController game;
  final AdService ads;
  final SoundService? sound;

  /// 방송 연출 길이 (테스트에서 줄인다)
  final Duration liveDuration;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '스트리머 키우기',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Pretendard',
        colorScheme: ColorScheme.fromSeed(seedColor: Pal.pink, brightness: Brightness.dark, surface: Pal.surface),
        scaffoldBackgroundColor: Pal.bg,
        textSelectionTheme: const TextSelectionThemeData(cursorColor: Pal.pink, selectionColor: Color(0x55FF4D8D), selectionHandleColor: Pal.pink),
      ),
      home: _Root(app: this),
    );
  }
}

/// 시작 화면 → 게임 화면 → (엔딩 후) 시작 화면
class _Root extends StatefulWidget {
  const _Root({required this.app});
  final InfluencerApp app;

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  bool _playing = false;
  bool _isNew = false;
  int _run = 0;

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: _playing
          ? HomeScreen(
              key: ValueKey('home-$_run'),
              game: app.game,
              ads: app.ads,
              sound: app.sound,
              showIntro: _isNew,
              liveDuration: app.liveDuration,
              onExit: () => setState(() {
                _playing = false;
                _run++;
              }),
            )
          : TitleScreen(
              key: ValueKey('title-$_run'),
              game: app.game,
              onStart: (isNew) => setState(() {
                _playing = true;
                _isNew = isNew;
              }),
            ),
    );
  }
}
