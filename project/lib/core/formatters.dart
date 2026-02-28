String formatDateRu(String iso) {
  if (iso.isEmpty) return '—';
  final parts = iso.split('-');
  if (parts.length != 3) return iso;
  return '${parts[2]}.${parts[1]}.${parts[0]}';
}
