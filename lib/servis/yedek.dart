import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'veri.dart';

/// Firmanın bütün verisini tek bir JSON dosyasına yazar ve paylaşım ekranını
/// açar; "Drive'a kaydet" seçilerek Google Drive'a konur.
class Yedek {
  static Object? _deger(Object? v) {
    if (v is Timestamp) return v.toDate().toIso8601String();
    if (v is GeoPoint) return {'lat': v.latitude, 'lng': v.longitude};
    if (v is DocumentReference) return v.path;
    if (v is List) return v.map(_deger).toList();
    if (v is Map) return v.map((k, e) => MapEntry('$k', _deger(e)));
    return v;
  }

  static Map<String, Object?> _belge(DocumentSnapshot<Map<String, dynamic>> d) =>
      {'id': d.id, ...(_deger(d.data() ?? {}) as Map<String, Object?>)};

  /// Yedeği hazırlar ve paylaşır. Kaç sipariş yedeklendiğini döndürür.
  static Future<int> alVePaylas(Durum d) async {
    final firma = await Veri.firmalar.doc(d.fid).get();
    final siparisler = await Veri.siparisler(d.fid).get();
    final uyeler = {
      ...?d.firma?.uyeler,
      ...?d.firma?.saha,
    };
    final kisiler = <Map<String, Object?>>[];
    for (final u in uyeler) {
      try {
        final k = await Veri.kullanicilar.doc(u).get();
        if (k.exists) kisiler.add(_belge(k));
      } catch (_) {}
    }

    final veri = {
      'uygulama': 'Keleş Satış',
      'tarih': DateTime.now().toIso8601String(),
      'firma': _belge(firma),
      'kullanicilar': kisiler,
      'siparisler': siparisler.docs.map(_belge).toList(),
    };

    final t = DateTime.now();
    String iki(int n) => n.toString().padLeft(2, '0');
    final ad = 'keles-satis-yedek-${t.year}-${iki(t.month)}-${iki(t.day)}'
        '-${iki(t.hour)}${iki(t.minute)}.json';
    final klasor = await getTemporaryDirectory();
    final dosya = File('${klasor.path}/$ad');
    await dosya.writeAsString(const JsonEncoder.withIndent('  ').convert(veri));
    await SharePlus.instance.share(ShareParams(
      files: [XFile(dosya.path, mimeType: 'application/json')],
      subject: 'Keleş Satış yedeği',
      text: 'Keleş Satış yedeği (${siparisler.docs.length} sipariş)',
    ));
    return siparisler.docs.length;
  }
}
