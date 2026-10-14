import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_ids.dart';

/// 게임 화면이 쓰는 광고 기능.
///
/// 화면은 이 인터페이스만 알고, 실제 광고 SDK는 [AdMobService]가 다룬다.
/// 테스트에서는 가짜 구현을 넘겨서 광고 없이 게임을 확인할 수 있다.
abstract class AdService {
  /// 보상형 광고를 바로 보여 줄 수 있는지.
  ValueListenable<bool> get rewardedReady;

  /// 보상형 광고를 보여 준다. 끝까지 봐서 보상을 받을 수 있으면 true.
  Future<bool> showRewarded();

  /// 화면 하단 배너. 광고를 쓸 수 없으면 빈 위젯.
  Widget buildBanner();
}

/// 광고를 전혀 보여 주지 않는 구현 (테스트, 광고 끄기용).
class NoAdService implements AdService {
  @override
  final ValueListenable<bool> rewardedReady = ValueNotifier(false);

  @override
  Future<bool> showRewarded() async => false;

  @override
  Widget buildBanner() => const SizedBox.shrink();
}

/// Google AdMob 구현.
class AdMobService implements AdService {
  static const _retryDelay = Duration(seconds: 30);

  final ValueNotifier<bool> _rewardedReady = ValueNotifier(false);
  final ValueNotifier<bool> _canRequestAds = ValueNotifier(false);
  RewardedAd? _rewardedAd;

  @override
  ValueListenable<bool> get rewardedReady => _rewardedReady;

  /// 개인정보 동의를 받고 광고 SDK를 시작한다. 앱 시작 시 한 번 호출한다.
  Future<void> initialize() async {
    await _gatherConsent();
    if (!await ConsentInformation.instance.canRequestAds()) return;

    await MobileAds.instance.initialize();
    _canRequestAds.value = true;
    _loadRewarded();
  }

  /// 유럽 등 동의가 필요한 지역 사용자에게만 동의 창을 띄운다.
  /// 한국 사용자는 보통 아무 창도 뜨지 않는다.
  Future<void> _gatherConsent() {
    final done = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => ConsentForm.loadAndShowConsentFormIfRequired((_) {
        if (!done.isCompleted) done.complete();
      }),
      (_) {
        if (!done.isCompleted) done.complete();
      },
    );
    return done.future;
  }

  void _loadRewarded() {
    RewardedAd.load(
      adUnitId: AdIds.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _rewardedReady.value = true;
        },
        onAdFailedToLoad: (error) {
          debugPrint('보상형 광고 로드 실패: $error');
          _rewardedAd = null;
          _rewardedReady.value = false;
          Timer(_retryDelay, _loadRewarded);
        },
      ),
    );
  }

  @override
  Future<bool> showRewarded() {
    final ad = _rewardedAd;
    if (ad == null) return Future.value(false);
    _rewardedAd = null;
    _rewardedReady.value = false;

    final result = Completer<bool>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        result.complete(earned);
        _loadRewarded();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        result.complete(false);
        _loadRewarded();
      },
    );
    ad.show(onUserEarnedReward: (_, _) => earned = true);
    return result.future;
  }

  @override
  Widget buildBanner() => ValueListenableBuilder<bool>(
    valueListenable: _canRequestAds,
    builder: (context, canRequest, _) =>
        canRequest ? const _BannerAdView() : const SizedBox.shrink(),
  );
}

class _BannerAdView extends StatefulWidget {
  const _BannerAdView();

  @override
  State<_BannerAdView> createState() => _BannerAdViewState();
}

class _BannerAdViewState extends State<_BannerAdView> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _ad = BannerAd(
      adUnitId: AdIds.banner,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('배너 광고 로드 실패: $error');
          ad.dispose();
          _ad = null;
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );
  }
}
