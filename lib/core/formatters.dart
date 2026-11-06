/// "4,2 MB", "830 KB"
String formatBytes(int bytes) {
  if (bytes <= 0) return '—';
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final text = unit < 2 ? value.round().toString() : value.toStringAsFixed(1).replaceAll('.', ',');
  return '$text ${units[unit]}';
}

/// "Hoje", "Ontem", "Há 3 dias", "12/03/2026"
String formatRelativeDay(DateTime date, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final d0 = DateTime(today.year, today.month, today.day);
  final d1 = DateTime(date.year, date.month, date.day);
  final days = d0.difference(d1).inDays;
  if (days <= 0) return 'Hoje';
  if (days == 1) return 'Ontem';
  if (days < 7) return 'Há $days dias';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year}';
}
