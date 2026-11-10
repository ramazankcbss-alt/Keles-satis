import 'dart:math';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../bicim.dart';
import '../firebase_options.dart';
import '../modeller.dart';
import 'veri.dart';

/// Telefon bildirimleri: izin isteme ve anlık bildirim gösterme.
class Bildirim {
  Bildirim._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _hazir = false;

  static const _kanal = AndroidNotificationDetails(
    'satis_hareketleri',
    'Satış hareketleri',
    channelDescription:
        'Başka kullanıcıların girdiği sipariş, fiyat, teslim ve tahsilatlar',
    importance: Importance.high,
    priority: Priority.high,
    color: Color(0xFF0E9E9B),
  );

  static Future<void> init() async {
    if (_hazir) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      _hazir = true;
    } catch (e) {
      debugPrint('Bildirim başlatılamadı: $e');
    }
  }

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  /// Android 13 ve üzerinde bildirim iznini sorar.
  static Future<bool> izinIste() async {
    if (!_hazir) return false;
    try {
      return await _android?.requestNotificationsPermission() ?? false;
    } catch (e) {
      debugPrint('Bildirim izni istenemedi: $e');
      return false;
    }
  }

  static Future<void> goster(int id, String baslik, String metin) async {
    if (!_hazir) return;
    try {
      await _plugin.show(
        id: id,
        title: baslik,
        body: metin,
        notificationDetails: const NotificationDetails(android: _kanal),
      );
    } catch (e) {
      debugPrint('Bildirim gösterilemedi: $e');
    }
  }

  /// Aynı olay için hep aynı numarayı üretir; olay iki kez işlense de
  /// telefonda tek bildirim görünür.
  static int kimlik(String anahtar) {
    var h = 0x811c9dc5;
    for (final c in anahtar.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h & 0x7fffffff;
  }
}

/// Başka kullanıcıların yaptığı işlemleri bulur ve bildirir.
/// Hem uygulama açıkken (canlı) hem de arka plandaki periyodik
/// kontrolde aynı kurallar kullanılır.
class Hareketler {
  Hareketler._();

  static const turler = ['siparis', 'fiyat', 'teslim', 'tahsilat'];
  static const turAdlari = {
    'siparis': 'Yeni sipariş',
    'fiyat': 'Fiyat girildi',
    'teslim': 'Teslim edildi',
    'tahsilat': 'Tahsilat yapıldı',
  };

  static String _tercihAnahtari(String tur) => 'bildirim_$tur';
  static String _sonAnahtari(String fid) => 'bildirim_son_$fid';

  static Future<SharedPreferences> _tercihler() async {
    final p = await SharedPreferences.getInstance();
    await p.reload(); // arka plandaki görevin yazdıklarını da gör
    return p;
  }

  /// Hangi işlemler için bildirim istendiği. Varsayılan: yöneticiye
  /// sipariş, teslim ve tahsilat açık; fiyat kapalı. Ekip üyelerine kapalı.
  static Future<Map<String, bool>> tercihleriOku() async {
    final p = await _tercihler();
    final yonetici = p.getBool('bildirim_yonetici') ?? false;
    return {
      for (final t in turler)
        t: p.getBool(_tercihAnahtari(t)) ?? (yonetici && t != 'fiyat'),
    };
  }

  static Future<void> tercihKaydet(String tur, bool acik) async {
    final p = await _tercihler();
    await p.setBool(_tercihAnahtari(tur), acik);
  }

  /// Uygulama açılınca hangi firma/kullanıcı için izleneceğini kaydeder.
  static Future<void> oturum(String fid, String uid, bool yonetici) async {
    final p = await _tercihler();
    await p.setString('bildirim_fid', fid);
    await p.setString('bildirim_uid', uid);
    await p.setBool('bildirim_yonetici', yonetici);
  }

  static Future<void> oturumKapat() async {
    final p = await _tercihler();
    await p.remove('bildirim_fid');
    await p.remove('bildirim_uid');
  }

  static final Map<String, String> _isimler = {};

  static Future<String> _isim(String id) async {
    final v = _isimler[id];
    if (v != null) return v;
    try {
      final d = await Veri.kullanicilar.doc(id).get();
      final ad = (d.data()?['ad'] as String?)?.trim();
      if (ad != null && ad.isNotEmpty) return _isimler[id] = ad;
    } catch (_) {}
    return 'Bir kullanıcı';
  }

  static Future<void> _sira = Future.value();

  /// [liste] içindeki, son bakıştan sonra başkalarınca yapılmış işlemleri
  /// bildirir ve "son bakış" zamanını ilerletir. Çağrılar sırayla işlenir.
  static Future<void> isle(String fid, String uid, Iterable<Siparis> liste,
      {Future<String> Function(String)? isimBul}) {
    final kopya = liste.toList();
    return _sira = _sira.then((_) => _isle(fid, uid, kopya, isimBul));
  }

  static Future<void> _isle(String fid, String uid, List<Siparis> liste,
      Future<String> Function(String)? isimBul) async {
    try {
      final p = await _tercihler();
      final anahtar = _sonAnahtari(fid);
      final son = p.getInt(anahtar);
      var enYeni = son ?? 0;
      for (final s in liste) {
        enYeni = max(enYeni, s.sonIslemTarih);
      }
      if (son == null) {
        // İlk kez: eski kayıtlar için bildirim yağdırma, bundan sonrasını izle.
        await p.setInt(anahtar, max(enYeni, DateTime.now().millisecondsSinceEpoch));
        return;
      }
      if (enYeni <= son) return;
      await p.setInt(anahtar, enYeni);

      final tercih = await tercihleriOku();
      final yeniler = liste
          .where((s) =>
              s.sonIslemTarih > son &&
              s.sonIslemBy.isNotEmpty &&
              s.sonIslemBy != uid &&
              (tercih[s.sonIslemTur] ?? false))
          .toList()
        ..sort((a, b) => a.sonIslemTarih.compareTo(b.sonIslemTarih));
      if (yeniler.isEmpty) return;

      await Bildirim.init();
      // Çok sayıda birikmişse en yeni 8 tanesi tek tek, gerisi özetle.
      final gosterilecek = yeniler.length > 8
          ? yeniler.sublist(yeniler.length - 8)
          : yeniler;
      for (final s in gosterilecek) {
        final kim = await (isimBul ?? _isim)(s.sonIslemBy);
        final (baslik, metin) = metinOlustur(s, kim);
        await Bildirim.goster(
            Bildirim.kimlik('${s.id}-${s.sonIslemTarih}'), baslik, metin);
      }
      if (yeniler.length > 8) {
        await Bildirim.goster(Bildirim.kimlik('ozet-$enYeni'),
            '${yeniler.length - 8} hareket daha',
            'Ayrıntılar için uygulamayı açın.');
      }
    } catch (e) {
      debugPrint('Hareketler işlenemedi: $e');
    }
  }

  static (String, String) metinOlustur(Siparis s, String kim) {
    final urun = '${s.urun} ${sayi(s.miktar)} ${s.birim}';
    switch (s.sonIslemTur) {
      case 'siparis':
        return (
          '${s.teslim ? 'Yeni satış' : 'Yeni sipariş'} #${s.no} · ${s.musteri}',
          '$kim girdi: $urun${s.fiyat != null ? ' · ${tl(s.toplam)}' : ''}'
              '${s.teslim ? ' · teslim edildi' : ''}'
              '${s.odenen > 0 ? ' · ${tl(s.odenen)} tahsil edildi' : ''}'
        );
      case 'fiyat':
        return (
          'Fiyat girildi #${s.no} · ${s.musteri}',
          '$kim: $urun × ${tl(s.fiyat ?? 0)} = ${tl(s.toplam)}'
        );
      case 'teslim':
        return (
          'Teslim edildi #${s.no} · ${s.musteri}',
          '$kim teslim etti: $urun'
              '${s.sonIslemTutar > 0 ? ' · ${tl(s.sonIslemTutar)} tahsil edildi' : ''}'
        );
      case 'tahsilat':
        return (
          'Tahsilat #${s.no} · ${s.musteri}',
          '$kim ${tl(s.sonIslemTutar)} tahsil etti'
              '${s.sonIslemYontem.isNotEmpty ? ' (${s.sonIslemYontem})' : ''}'
              '${s.kalan > 0 ? ' · Kalan ${tl(s.kalan)}' : ' · Borç kapandı'}'
        );
    }
    return ('Sipariş #${s.no} · ${s.musteri}', '$kim güncelledi');
  }
}

const _gorevAdi = 'satis-hareket-kontrol';

/// Uygulama kapalıyken ~15 dakikada bir çalışan kontrolü kurar.
Future<void> arkaPlanKontrolunuBaslat() async {
  try {
    await Workmanager().initialize(arkaPlanGorevi);
    await Workmanager().registerPeriodicTask(
      _gorevAdi,
      _gorevAdi,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
    );
  } catch (e) {
    debugPrint('Arka plan kontrolü kurulamadı: $e');
  }
}

@pragma('vm:entry-point')
void arkaPlanGorevi() {
  Workmanager().executeTask((gorev, girdi) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      DartPluginRegistrant.ensureInitialized();
      try {
        await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform);
      } catch (_) {
        // Uygulama zaten açıksa Firebase hazırdır.
      }
      final p = await SharedPreferences.getInstance();
      await p.reload();
      final fid = p.getString('bildirim_fid');
      final uid = p.getString('bildirim_uid');
      final son = fid == null ? null : p.getInt('bildirim_son_$fid');
      if (fid == null || uid == null || son == null) return true;

      final kullanici = FirebaseAuth.instance.currentUser ??
          await FirebaseAuth.instance
              .authStateChanges()
              .first
              .timeout(const Duration(seconds: 15), onTimeout: () => null);
      if (kullanici == null || kullanici.uid != uid) return true;

      final q = await Veri.siparisler(fid)
          .where('guncelleme', isGreaterThan: son)
          .orderBy('guncelleme')
          .limit(100)
          .get();
      final liste =
          q.docs.map((d) => Siparis.fromMap(d.id, d.data())).toList();
      await Hareketler.isle(fid, uid, liste);
    } catch (e) {
      debugPrint('Arka plan kontrolü hatası: $e');
    }
    return true;
  });
}
