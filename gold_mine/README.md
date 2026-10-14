# 골드 광산 키우기

작은 광산 하나와 인부 한 명으로 시작해서 골드를 캐고, 광산을 넓히고, 인부를 늘리는 방치형 게임입니다.
Flutter로 만들었고 안드로이드(원스토어) 출시를 목표로 합니다.

---

## 1. 게임 규칙

| 요소 | 설명 |
|---|---|
| **자동 채굴** | 인부 한 명이 1초에 1골드를 캡니다 (광산 레벨 배수 적용) |
| **터치 채굴** | 광산을 누르면 곡괭이 레벨만큼 골드를 얻습니다 |
| **인부 고용** | 생산량 증가. 비용은 한 명마다 1.15배씩 오릅니다 |
| **광산 확장** | 생산 1.6배, 인부 자리 +3칸. 인부가 가득 차면 확장해야 합니다 |
| **곡괭이 강화** | 터치당 골드 증가 |
| **오프라인 보상** | 앱을 꺼 둔 동안 최대 8시간, 생산량의 50%를 받습니다 |
| **광고 부스트** | 보상형 광고를 보면 5분간 채굴 2배 (최대 30분까지 쌓임) |
| **광고 보너스** | 오프라인 보상 팝업에서 광고를 보면 같은 양을 한 번 더 |
| **자동 저장** | 10초마다, 그리고 앱이 백그라운드로 갈 때 저장합니다 |

밸런스 숫자는 모두 `lib/game/game_config.dart` 한 파일에 있어요. 숫자만 바꿔서 난이도를 조절할 수 있습니다.

## 2. 폴더 구조

```
gold_mine/
├── lib/
│   ├── main.dart                 앱 시작점, 테마
│   ├── ads/                      ← 광고 (AdMob)
│   │   ├── ad_ids.dart           광고 단위 ID (테스트/실제)
│   │   └── ad_service.dart       보상형 광고, 배너, 개인정보 동의
│   ├── game/                     ← 게임 규칙 (화면과 분리)
│   │   ├── game_config.dart      밸런스 숫자와 계산식
│   │   ├── game_state.dart       저장되는 데이터
│   │   ├── game_controller.dart  채굴, 업그레이드, 오프라인 보상, 타이머
│   │   └── save_repository.dart  기기에 저장/불러오기
│   └── ui/                       ← 화면
│       ├── home_screen.dart      메인 화면, 앱 생명주기 처리
│       ├── number_format.dart    1.23K, 4.5M 같은 숫자 표시
│       └── widgets/              골드 표시, 광산, 업그레이드 버튼
├── test/                         자동 테스트
├── android/                      안드로이드 빌드 설정
└── pubspec.yaml                  앱 이름, 버전, 사용하는 패키지
```

게임 규칙(`game/`)과 화면(`ui/`)을 나눠 두었어요. 그래서 규칙은 화면 없이 테스트할 수 있고, 나중에 할 일 RPG에서 재화·저장 코드를 다시 쓰기도 쉽습니다.

---

## 3. 개발 환경 설치 (Windows 기준, 처음 한 번만)

### 3-1. Android Studio 설치
1. https://developer.android.com/studio 에서 내려받아 설치합니다 (설치 옵션은 기본값).
2. 처음 실행하면 나오는 설정 마법사에서 **Standard**를 고르면 Android SDK가 함께 설치됩니다.
3. **More Actions → SDK Manager → SDK Tools 탭**에서 아래 항목을 체크하고 Apply를 누릅니다.
   - Android SDK Command-line Tools (latest)
   - Android SDK Build-Tools
   - Android SDK Platform-Tools
4. **Plugins** 메뉴에서 `Flutter`를 검색해 설치합니다 (Dart 플러그인도 같이 설치됨).

### 3-2. Flutter SDK 설치
1. https://docs.flutter.dev/get-started/install/windows 에서 Flutter SDK zip을 내려받습니다.
2. `C:\dev\flutter` 처럼 **공백과 한글이 없는 경로**에 압축을 풉니다.
   (`C:\Program Files` 안은 권한 문제가 생기니 피하세요.)
3. 환경 변수 Path에 `C:\dev\flutter\bin`을 추가합니다.
   - 시작 메뉴에서 "환경 변수" 검색 → 사용자 변수의 `Path` → 편집 → 새로 만들기
4. 새 명령 프롬프트(또는 PowerShell)를 열고 확인합니다.
   ```
   flutter --version
   ```

> **VS Code를 쓰고 싶다면**: VS Code에 `Flutter` 확장을 설치해도 됩니다. Android SDK 때문에 Android Studio 설치는 어차피 필요해요.

### 3-3. 설치 점검
```
flutter doctor --android-licenses     (모든 질문에 y)
flutter doctor
```
`Flutter`와 `Android toolchain` 항목에 초록색 체크(✓)가 뜨면 준비 끝입니다.
Windows 데스크톱, Chrome, iOS 관련 경고는 무시해도 됩니다.

---

## 4. 휴대폰에서 실행해 보기

### 4-1. 휴대폰 준비 (갤럭시 기준)
1. **설정 → 휴대전화 정보 → 소프트웨어 정보 → 빌드번호**를 7번 연속 누르면 "개발자 모드가 켜졌습니다"가 나옵니다.
2. **설정 → 개발자 옵션 → USB 디버깅**을 켭니다.
3. USB로 PC와 연결하고, 휴대폰에 뜨는 "USB 디버깅 허용"에서 **허용**을 누릅니다.

휴대폰이 없으면 Android Studio의 **Device Manager**에서 가상 기기(에뮬레이터)를 만들어 써도 됩니다.

### 4-2. 실행
```
git clone https://github.com/okidokidave/game.git
cd game/gold_mine
flutter pub get        (필요한 패키지 내려받기)
flutter devices        (연결된 휴대폰이 보이는지 확인)
flutter run            (빌드 후 휴대폰에서 실행)
```
실행 중인 터미널에서 코드를 고치고 **`r`**을 누르면 1초 만에 바뀐 화면이 반영됩니다 (Hot Reload).
**`R`**은 앱을 처음부터 다시 시작, **`q`**는 종료입니다.

### 4-3. 코드 점검과 테스트
```
flutter analyze        (코드 문제 검사)
flutter test           (자동 테스트 실행)
```

---

## 5. APK 빌드하기

### 5-1. 테스트용 APK (서명 키 없이)
```
flutter build apk
```
결과 파일: `build/app/outputs/flutter-apk/app-release.apk`

이 APK는 **디버그 키로 서명**되어서 친구 폰에 설치해 보는 용도로만 쓸 수 있어요. **스토어에는 올릴 수 없습니다.**
설치는 `flutter install`을 쓰거나, APK 파일을 휴대폰에 복사해서 열면 됩니다 ("출처를 알 수 없는 앱" 허용 필요).

### 5-2. 출시용 서명 키 만들기 (딱 한 번)

스토어는 "이 앱을 만든 사람이 맞는지"를 서명 키로 확인합니다.
**업데이트할 때마다 같은 키로 서명해야 하므로, 키를 잃어버리면 앱을 더 이상 업데이트할 수 없어요.**

1. 키를 보관할 폴더를 만듭니다. **프로젝트 폴더 밖**에 두세요. 예: `C:\Users\내이름\keys`
2. 명령 프롬프트에서 실행합니다 (Android Studio에 들어 있는 keytool 사용):
   ```
   "C:\Program Files\Android\Android Studio\jbr\bin\keytool" -genkey -v ^
     -keystore C:\Users\내이름\keys\gold_mine-upload.jks ^
     -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
   - 비밀번호를 두 번 입력하고, 이름·조직 등은 적당히 입력합니다 (영문 권장).
   - macOS라면: `keytool -genkey -v -keystore ~/keys/gold_mine-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
3. **`.jks` 파일과 비밀번호를 안전한 곳 두 군데 이상에 백업하세요** (USB, 클라우드 비공개 폴더 등).

### 5-3. 키 정보 연결

`android/key.properties.example`을 복사해서 `android/key.properties`를 만들고 값을 채웁니다.
```
storePassword=키스토어_비밀번호
keyPassword=키_비밀번호
keyAlias=upload
storeFile=C:/Users/내이름/keys/gold_mine-upload.jks
```
- Windows 경로도 **슬래시(`/`)**로 적으세요. 역슬래시(`\`)를 쓰려면 `\\`로 두 번 적어야 합니다.
- `key.properties`와 `.jks`는 `.gitignore`에 등록돼 있어서 GitHub에 올라가지 않습니다.
  **절대 커밋하지 마세요.**

`android/app/build.gradle.kts`에는 이미 이 파일을 읽어서 서명하는 설정이 들어 있습니다.
`key.properties`가 있으면 출시용 키로, 없으면 디버그 키로 서명해요.

### 5-4. 버전 정하기

`pubspec.yaml`의 이 줄이 앱 버전입니다.
```yaml
version: 1.0.0+1
```
- `1.0.0` = 사용자에게 보이는 버전 (versionName)
- `+1` = 스토어가 구분하는 번호 (versionCode). **업데이트를 올릴 때마다 반드시 1 이상 올려야 합니다.**
  예: `1.0.1+2`, `1.1.0+3`

### 5-5. 출시용 APK 빌드
```
flutter clean
flutter build apk --release
```
결과 파일: `build/app/outputs/flutter-apk/app-release.apk` ← **이 파일을 원스토어에 올립니다.**

출시용 키로 서명됐는지 확인하려면:
```
"C:\Program Files\Android\Android Studio\jbr\bin\keytool" -printcert -jarfile build\app\outputs\flutter-apk\app-release.apk
```
출력에 `CN=Android Debug`가 보이면 **디버그 키로 서명된 것**이니 5-3을 다시 확인하세요.

> 참고: `flutter build appbundle`은 Google Play용 AAB 파일을 만듭니다. 원스토어는 APK 등록이 기본이니, AAB 지원 여부는 원스토어 개발자센터 안내를 확인하세요.

### 5-6. 자주 만나는 오류

| 증상 | 해결 |
|---|---|
| `flutter`를 찾을 수 없음 | Path 환경 변수 확인 후 **새 터미널**을 엽니다 |
| `Android license status unknown` | `flutter doctor --android-licenses` 실행 |
| `flutter devices`에 폰이 안 보임 | USB 디버깅 허용 팝업 확인, 케이블을 데이터용으로 교체 |
| `Keystore file not found` | `key.properties`의 `storeFile` 경로 확인 (슬래시 사용) |
| `Keystore was tampered with, or password was incorrect` | 비밀번호 오타 |
| Gradle 빌드가 매우 오래 걸림 | 첫 빌드는 원래 5~10분 걸립니다. 두 번째부터 빨라져요 |

---

## 6. 광고 (AdMob)

### 6-1. 지금 들어 있는 광고

| 광고 | 위치 | 동작 |
|---|---|---|
| 보상형 | 골드 아래 "광고 보고 5분간 채굴 ×2" 버튼 | 끝까지 보면 부스트 5분 추가 |
| 보상형 | "돌아오셨군요!" 팝업의 "광고 보고 2배" 버튼 | 오프라인 보상만큼 한 번 더 지급 |
| 배너 | 화면 맨 아래 | 항상 표시 |

**지금은 구글 공식 테스트 광고가 나옵니다.** "Test Ad" 표시가 붙은 광고가 보이면 정상이에요.
테스트 광고는 마음껏 눌러도 됩니다.

> ⚠️ **실제 광고를 넣은 뒤에는 내 광고를 절대 직접 누르지 마세요.** 부정 클릭으로 AdMob 계정이 정지될 수 있어요.
> 그래서 이 프로젝트는 디버그 빌드(`flutter run`)에서는 실제 ID를 넣어도 항상 테스트 광고를 씁니다.

### 6-2. 출시 단계별 광고 상태

| 단계 | AdMob 상태 |
|---|---|
| 원스토어만 출시 | AdMob이 원스토어를 지원하지 않아 앱 검토를 받을 수 없고, **광고가 제한적으로만 나갑니다** |
| Google Play 출시 후 | AdMob 앱을 Play 스토어 등록 정보와 연결 → 앱 준비 상태 검토(보통 며칠) → 광고 정상 게재 |

원스토어 기간에는 광고 수익보다 **사용자와 테스터를 모으는 데** 집중하는 걸 추천해요.

### 6-3. 실제 광고로 바꾸는 방법

1. https://admob.google.com 에서 AdMob 계정을 만듭니다 (구글 계정 사용).
2. **앱 → 앱 추가 → Android**를 고릅니다.
   - "지원되는 스토어에 등록되어 있나요?"에는 Google Play 출시 전이면 **아니요**를 고릅니다 (미게시 앱으로 등록). Play 출시 후에 스토어를 연결해요.
3. 만든 앱에서 **광고 단위**를 두 개 만듭니다: **보상형**, **배너**.
4. ID 세 개를 프로젝트에 넣습니다.

| 값 | 생김새 | 넣을 곳 |
|---|---|---|
| 앱 ID | `ca-app-pub-1234...~5678...` (물결 `~`) | `android/app/src/main/AndroidManifest.xml`의 `APPLICATION_ID` |
| 보상형 광고 단위 ID | `ca-app-pub-1234.../5678...` (슬래시 `/`) | `lib/ads/ad_ids.dart`의 `_realRewarded` |
| 배너 광고 단위 ID | `ca-app-pub-1234.../5678...` | `lib/ads/ad_ids.dart`의 `_realBanner` |

5. 출시용 APK를 빌드합니다 (5-5). 출시용 빌드에서만 실제 ID가 쓰입니다.

### 6-4. app-ads.txt (권장)

광고주에게 "이 앱의 광고 판매자가 맞다"고 알려 주는 파일이에요. 없어도 광고는 나오지만, 있으면 광고 단가에 도움이 됩니다.

1. AdMob **설정 → 계정 정보**에서 게시자 ID(`pub-`로 시작)를 확인합니다.
2. 기존 게임북 웹사이트의 **최상위 폴더**에 `app-ads.txt` 파일을 만들고 한 줄을 넣습니다.
   ```
   google.com, pub-0000000000000000, DIRECT, f08c47fec0942fa0
   ```
3. 스토어 등록 정보의 **개발자 웹사이트**에 그 사이트 주소를 적습니다.

### 6-5. 광고를 넣으면 추가로 해야 할 것

- **개인정보처리방침**에 광고 내용을 추가합니다: Google AdMob을 사용하며, 맞춤 광고를 위해 광고 ID 등 기기 정보가 수집될 수 있다는 내용.
- **Google Play Console**에서 "광고 포함" 표시, "광고 ID 사용" 선언을 합니다.
- 유럽 등 동의가 필요한 지역 사용자에게는 앱이 시작할 때 동의 창이 자동으로 뜹니다 (`ad_service.dart`의 `_gatherConsent`). AdMob 콘솔 **개인정보 보호 및 메시지**에서 GDPR 메시지를 만들어 두세요. 한국 사용자에게는 보통 뜨지 않습니다.

## 7. 출시 체크리스트

### 원스토어

- [ ] 원스토어 개발자센터 가입 (검색: "원스토어 개발자센터")
- [ ] 앱 아이콘 교체 (`flutter_launcher_icons` 패키지로 한 번에 생성 가능)
- [ ] `applicationId` 최종 확인 (`android/app/build.gradle.kts`, 현재 `com.okidokidave.gold_mine`). **출시 후에는 바꿀 수 없어요.**
- [ ] 스크린샷 (휴대폰에서 캡처)
- [ ] 개인정보처리방침 URL (기존 게임북 사이트의 `privacy.html` 형식을 참고해 앱용으로 작성, 광고 내용 포함: 6-5)
- [ ] 게임 등급 분류 (스토어 등록 과정에서 함께 진행)
- [ ] 출시용 키로 서명한 APK (5-5)
- [ ] 서명 키 백업 완료

### Google Play (나중에)

- [ ] Google Play Console 개발자 등록 (등록비 1회 25달러)
- [ ] **개인 계정은 비공개 테스트 필수**: 2024년 기준, 새 개인 개발자 계정은 테스터 12명 이상이 14일 연속 참여하는 비공개 테스트를 거쳐야 정식 출시할 수 있어요. 원스토어에서 모은 테스터를 여기에 활용하면 됩니다 (조건은 Play Console에서 다시 확인).
- [ ] Google Play는 APK가 아니라 **AAB**로 올립니다: `flutter build appbundle --release`
- [ ] AdMob 앱을 Play 스토어 등록 정보와 연결 (6-2)
- [ ] 광고 관련 선언 (6-5)

## 8. 다음에 추가할 만한 것

- 광산 레벨별 배경 그림과 사운드
- 업적, 통계 화면 (`totalEarned` 값은 이미 저장 중)
- 환생(프레스티지): 처음부터 다시 시작하는 대신 영구 보너스
- 전면 광고 (광산 확장 직후처럼 가끔만)
- 설정 화면 (소리 끄기, 데이터 초기화: `GameController.reset()` 준비됨)
