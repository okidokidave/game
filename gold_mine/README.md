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
| **자동 저장** | 10초마다, 그리고 앱이 백그라운드로 갈 때 저장합니다 |

밸런스 숫자는 모두 `lib/game/game_config.dart` 한 파일에 있어요. 숫자만 바꿔서 난이도를 조절할 수 있습니다.

## 2. 폴더 구조

```
gold_mine/
├── lib/
│   ├── main.dart                 앱 시작점, 테마
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

## 6. 원스토어 등록 전 체크리스트

- [ ] 원스토어 개발자센터 가입 (검색: "원스토어 개발자센터")
- [ ] 앱 아이콘 교체 (`flutter_launcher_icons` 패키지로 한 번에 생성 가능)
- [ ] `applicationId` 최종 확인 (`android/app/build.gradle.kts`, 현재 `com.okidokidave.gold_mine`). **출시 후에는 바꿀 수 없어요.**
- [ ] 스크린샷 (휴대폰에서 캡처)
- [ ] 개인정보처리방침 URL (기존 게임북 사이트의 `privacy.html` 형식을 참고해 앱용으로 작성)
- [ ] 게임 등급 분류 (스토어 등록 과정에서 함께 진행)
- [ ] 출시용 키로 서명한 APK (5-5)
- [ ] 서명 키 백업 완료

## 7. 다음에 추가할 만한 것

- 광산 레벨별 배경 그림과 사운드
- 업적, 통계 화면 (`totalEarned` 값은 이미 저장 중)
- 환생(프레스티지): 처음부터 다시 시작하는 대신 영구 보너스
- 광고 보고 오프라인 보상 2배 (AdMob)
- 설정 화면 (소리 끄기, 데이터 초기화: `GameController.reset()` 준비됨)
