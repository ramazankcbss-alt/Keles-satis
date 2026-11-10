import 'dart:math';

import '../bicim.dart';

/// Benzer müşteri adlarını bulur (aynı kişi olabilecekler).

int _mesafe(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var onceki = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final simdi = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final m = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      simdi[j] = min(min(simdi[j - 1] + 1, onceki[j] + 1), onceki[j - 1] + m);
    }
    onceki = simdi;
  }
  return onceki[b.length];
}

/// 0..1 arası benzerlik (1: aynı). Türkçe harf ve büyük/küçük harf farkı yok sayılır.
double benzerlik(String a, String b) {
  final x = musteriAnahtari(a), y = musteriAnahtari(b);
  final n = max(x.length, y.length);
  if (n == 0) return 1;
  return 1 - _mesafe(x, y) / n;
}

/// İki adın "aynı değil" kaydı için sırası önemsiz anahtar.
String ciftAnahtari(String a, String b) {
  final l = [musteriAnahtari(a), musteriAnahtari(b)]..sort();
  return l.join('|');
}

/// İki ad aynı kişi olabilir mi?
bool benzerMi(String a, String b) {
  final x = musteriAnahtari(a), y = musteriAnahtari(b);
  if (x.isEmpty || y.isEmpty) return false;
  if (x == y) return true;
  // Yazım hatası düzeyinde fark: "Mesut Yakut" / "Mesut Yakt".
  // (Gerçek verilerde 0,85 altı "Derya Abla" / "Derya Abla Kaynanası" gibi
  // farklı kişileri yakalıyordu; onları kullanıcı elle birleştirir.)
  return benzerlik(x, y) >= 0.85;
}

/// Aynı kişi olabilecek ad grupları (her grupta en az 2 farklı yazılış).
/// [ayri]: kullanıcının "aynı değil" dediği ad çiftleri ([ciftAnahtari]).
List<List<String>> benzerGruplar(Iterable<String> adlar, Set<String> ayri) {
  final l = {for (final a in adlar) if (a.trim().isNotEmpty) a.trim()}.toList()
    ..sort();
  final ust = List<int>.generate(l.length, (i) => i);
  int bul(int i) => ust[i] == i ? i : (ust[i] = bul(ust[i]));
  for (var i = 0; i < l.length; i++) {
    for (var j = i + 1; j < l.length; j++) {
      if (ayri.contains(ciftAnahtari(l[i], l[j]))) continue;
      if (benzerMi(l[i], l[j])) ust[bul(i)] = bul(j);
    }
  }
  final g = <int, List<String>>{};
  for (var i = 0; i < l.length; i++) {
    g.putIfAbsent(bul(i), () => []).add(l[i]);
  }
  return g.values.where((x) => x.length > 1).toList();
}
