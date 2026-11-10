import 'package:intl/intl.dart';

final _tl = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2);
final _sayi = NumberFormat.decimalPattern('tr_TR')..maximumFractionDigits = 3;
final _kisa = NumberFormat.compact(locale: 'tr_TR');

final _tl0 = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 0);

String tl(num n) => _tl.format(n);

/// Kuruşsuz tutar (özet kartları için): ₺81.500
String tl0(num n) => _tl0.format(n);
String sayi(num n) => _sayi.format(n);

/// Üstteki sayaçlar için kısa gösterim: 2,3 Mn ₺
String kisaTl(num n) =>
    '${n.abs() >= 10000 ? _kisa.format(n) : _sayi.format(n.round())} ₺';

/// Formlardaki kutulara yazılacak sayı (binlik ayırıcısız, virgüllü).
String girdi(num? n) {
  if (n == null) return '';
  final s = n == n.roundToDouble() ? n.toInt().toString() : n.toString();
  return s.replaceAll('.', ',');
}

String once(int ms) {
  if (ms <= 0) return '-';
  final d = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
  if (d.inMinutes < 1) return 'şimdi';
  if (d.inHours < 1) return '${d.inMinutes}dk';
  if (d.inDays < 1) return '${d.inHours}sa';
  if (d.inDays < 30) return '${d.inDays}g';
  return DateFormat('dd.MM.yyyy', 'tr_TR')
      .format(DateTime.fromMillisecondsSinceEpoch(ms));
}

String tarihSaat(int ms) => ms <= 0
    ? '-'
    : DateFormat('dd.MM.yyyy HH:mm', 'tr_TR')
        .format(DateTime.fromMillisecondsSinceEpoch(ms));

/// Arama için sadeleştirilmiş metin: küçük harf, Türkçe harfler sade.
/// "Ilıcalı Şükrü" → "ilicali sukru"
String araMetni(String s) {
  const harita = {
    'ı': 'i', 'ş': 's', 'ğ': 'g', 'ü': 'u', 'ö': 'o', 'ç': 'c',
    'â': 'a', 'î': 'i', 'û': 'u',
  };

  var k = s.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();
  harita.forEach((a, b) => k = k.replaceAll(a, b));
  return k.replaceAll('\u0307', '').trim();
}

/// Aynı müşteriyi tek kişi saymak için ad anahtarı: büyük/küçük harf,
/// Türkçe harf ve fazladan boşluk farkları yok sayılır.
/// "Mesut  YAKUT " ile "mesut yakut" aynı müşteridir.
String musteriAnahtari(String s) =>
    araMetni(s).replaceAll(RegExp(r'\s+'), ' ');
