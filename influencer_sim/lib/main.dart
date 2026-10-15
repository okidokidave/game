import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ads/ad_service.dart';
import 'game/game_controller.dart';
import 'game/save_repository.dart';
import 'ui/home_screen.dart';
import 'ui/palette.dart';
import 'ui/title_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final prefs = await SharedPreferences.getInstance();
  final game = GameController(SaveRepository(prefs));
  final ads = AdMobService();

  runApp(InfluencerApp(game: game, ads: ads));
  // 동의 창은 화면이 뜬 뒤에 띄워야 하므로 runApp 다음에 시작한다.
  ads.initialize();
}

class InfluencerApp extends StatelessWidget {
  const InfluencerApp({super.key, required this.game, required this.ads, this.liveDuration = const Duration(milliseconds: 2600)});

  final GameController game;
  final AdService ads;

  /// 방송 연출 길이 (테스트에서 줄인다)
  final Duration liveDuration;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '인플루언서 시뮬레이터',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Pal.accent, surface: Pal.surface),
        scaffoldBackgroundColor: Pal.bg,
        dialogTheme: const DialogThemeData(backgroundColor: Pal.surface),
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
