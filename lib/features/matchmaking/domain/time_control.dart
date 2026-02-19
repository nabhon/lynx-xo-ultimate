enum TimeControl {
  thirtySeconds(seconds: 30, label: '30s'),
  oneMinute(seconds: 60, label: '1m'),
  twoMinutes(seconds: 120, label: '2m');

  const TimeControl({required this.seconds, required this.label});

  final int seconds;
  final String label;
}
