import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../modeller.dart';
import 'veri.dart';

/// Uygulama içi bildirimlerin "en son ne zaman bakıldı" bilgisi.
/// Zil simgesindeki sayı, bundan sonra başkalarının yaptığı işlemlerdir;
/// Bildirimler ekranı açılınca sıfırlanır.
class Okundu {
  static final deger = ValueNotifier<int>(0);
  static String _anahtar(String fid, String uid) => 'bildirim_okundu_${fid}_$uid';

  static Future<void> yukle(String fid, String uid) async {
    try {
      final p = await SharedPreferences.getInstance();
      final v = p.getInt(_anahtar(fid, uid));
      if (v == null) {
        // İlk kez: eski kayıtları "yeni" sayma.
        final n = DateTime.now().millisecondsSinceEpoch;
        await p.setInt(_anahtar(fid, uid), n);
        deger.value = n;
      } else {
        deger.value = v;
      }
    } catch (e) {
      debugPrint('Okundu bilgisi okunamadı: $e');
    }
  }

  static Future<void> isaretle(String fid, String uid) async {
    final n = DateTime.now().millisecondsSinceEpoch;
    deger.value = n;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt(_anahtar(fid, uid), n);
    } catch (_) {}
  }

  /// Başkalarının yaptığı işlemler (en yeni başta).
  static List<Siparis> hareketler(Durum d) => d.siparisler
      .where((s) =>
          s.sonIslemTarih > 0 && s.sonIslemBy.isNotEmpty && s.sonIslemBy != d.uid)
      .toList()
    ..sort((a, b) => b.sonIslemTarih.compareTo(a.sonIslemTarih));

  /// Okunmamış bildirim sayısı.
  static int sayi(Durum d) =>
      hareketler(d).where((s) => s.sonIslemTarih > deger.value).length;
}
