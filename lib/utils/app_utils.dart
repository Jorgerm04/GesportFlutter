
String capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String deporteLabel(String? d) {
  const map = {
    'futbol': 'Fútbol', 'padel': 'Pádel',
    'baloncesto': 'Baloncesto', 'tenis': 'Tenis', 'voley': 'Voley',
  };
  return map[d] ?? (d ?? '');
}
