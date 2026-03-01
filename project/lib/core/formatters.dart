String formatDateRu(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return '—';

  final ruMatch = RegExp(r'^(\d{2})\.(\d{2})\.(\d{4})').firstMatch(value);
  if (ruMatch != null) {
    return '${ruMatch.group(1)}.${ruMatch.group(2)}.${ruMatch.group(3)}';
  }

  final isoMatch = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(value);
  if (isoMatch != null) {
    return '${isoMatch.group(3)}.${isoMatch.group(2)}.${isoMatch.group(1)}';
  }

  final parsed = DateTime.tryParse(value);
  if (parsed != null) {
    final d = parsed.day.toString().padLeft(2, '0');
    final m = parsed.month.toString().padLeft(2, '0');
    final y = parsed.year.toString().padLeft(4, '0');
    return '$d.$m.$y';
  }

  return value;
}

String normalizeDateToIso(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return '';

  final ruMatch = RegExp(r'^(\d{2})\.(\d{2})\.(\d{4})').firstMatch(value);
  if (ruMatch != null) {
    return '${ruMatch.group(3)}-${ruMatch.group(2)}-${ruMatch.group(1)}';
  }

  final isoMatch = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(value);
  if (isoMatch != null) {
    return '${isoMatch.group(1)}-${isoMatch.group(2)}-${isoMatch.group(3)}';
  }

  final parsed = DateTime.tryParse(value);
  if (parsed != null) {
    final d = parsed.day.toString().padLeft(2, '0');
    final m = parsed.month.toString().padLeft(2, '0');
    final y = parsed.year.toString().padLeft(4, '0');
    return '$y-$m-$d';
  }

  return value;
}
