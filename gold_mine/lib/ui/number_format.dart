const _suffixes = ['', 'K', 'M', 'B', 'T', 'Qa', 'Qi', 'Sx', 'Sp', 'Oc'];

/// 큰 숫자를 1.23K, 4.5M 처럼 짧게 표시한다.
String formatGold(double value) {
  if (value < 1000) return value.floor().toString();

  var tier = 0;
  var scaled = value;
  while (scaled >= 1000 && tier < _suffixes.length - 1) {
    scaled /= 1000;
    tier++;
  }
  if (scaled >= 1000) return value.toStringAsExponential(2);

  final digits = scaled >= 100 ? 0 : (scaled >= 10 ? 1 : 2);
  return '${scaled.toStringAsFixed(digits)}${_suffixes[tier]}';
}

/// 초당 생산량처럼 소수점이 의미 있는 작은 값용.
String formatRate(double value) {
  if (value < 10) return value.toStringAsFixed(1);
  return formatGold(value);
}
