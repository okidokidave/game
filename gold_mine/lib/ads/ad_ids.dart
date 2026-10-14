import 'package:flutter/foundation.dart';

/// AdMob 광고 단위 ID.
///
/// 실제 ID를 비워 두면 구글 공식 테스트 광고가 나온다.
/// 디버그 빌드(flutter run)에서는 실제 ID를 채워도 항상 테스트 광고를 쓴다.
/// 개발 중에 내 광고를 직접 누르면 AdMob 계정이 정지될 수 있기 때문이다.
///
/// 앱 ID는 android/app/src/main/AndroidManifest.xml 에서 따로 바꾼다.
class AdIds {
  AdIds._();

  // 구글 공식 테스트 ID (https://developers.google.com/admob/android/test-ads)
  static const _testRewarded = 'ca-app-pub-3940256099942544/5224354917';
  static const _testBanner = 'ca-app-pub-3940256099942544/6300978111';

  // TODO(출시): AdMob 콘솔에서 만든 광고 단위 ID로 바꾼다.
  static const _realRewarded = '';
  static const _realBanner = '';

  static String get rewarded => _pick(_realRewarded, _testRewarded);
  static String get banner => _pick(_realBanner, _testBanner);

  static bool get isUsingTestAds =>
      rewarded == _testRewarded || banner == _testBanner;

  static String _pick(String real, String test) =>
      kReleaseMode && real.isNotEmpty ? real : test;
}
