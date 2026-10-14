#!/usr/bin/env bash
# 가상 안드로이드 폰에 APK를 설치하고 실행해서, 앱이 꺼지지 않고 열리는지 확인한다.
# GitHub Actions의 에뮬레이터 안에서 실행된다. 결과는 smoke/ 폴더에 남긴다.
set -u

APK="${1:-gold-mine.apk}"
PACKAGE=com.okidokidave.gold_mine
OUT=smoke
mkdir -p "$OUT"

adb install -r "$APK" || { echo "::error::APK 설치 실패"; exit 1; }
adb logcat -c

adb shell monkey -p "$PACKAGE" -c android.intent.category.LAUNCHER 1
sleep 25

adb exec-out screencap -p > "$OUT/screenshot.png"
adb logcat -d > "$OUT/logcat.txt"

echo "===== 오류 로그 ====="
grep -E "FATAL|AndroidRuntime|E flutter|Unhandled Exception|DEBUG   :|libc    :|$PACKAGE" "$OUT/logcat.txt" | head -150 || true

if adb shell pidof "$PACKAGE" > /dev/null; then
  echo "앱이 실행 중입니다."
else
  echo "::error::앱이 실행 직후 종료됐습니다. 위 오류 로그를 확인하세요."
  exit 1
fi
