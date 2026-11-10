import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../bicim.dart';
import '../modeller.dart';
import 'bildirim.dart';

/// Firestore yolları ve yazma işlemleri.
///
/// satis_kullanicilar/{uid}           : {ad, firmaId}
/// satis_kodlar/{kod}                 : {firmaId}   (davet kodu → firma)
/// satis_firmalar/{fid}               : firma ayarları, üyeler, sayaç
/// satis_firmalar/{fid}/siparisler/{id}
class Veri {
  Veri._();

  static final _db = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get kullanicilar =>
      _db.collection('satis_kullanicilar');
  static CollectionReference<Map<String, dynamic>> get kodlar =>
      _db.collection('satis_kodlar');
  static CollectionReference<Map<String, dynamic>> get firmalar =>
      _db.collection('satis_firmalar');
  static CollectionReference<Map<String, dynamic>> siparisler(String fid) =>
      firmalar.doc(fid).collection('siparisler');

  static int get simdi => DateTime.now().millisecondsSinceEpoch;

  static String yeniKod() {
    const harf = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(8, (_) => harf[r.nextInt(harf.length)]).join();
  }

  static Future<void> adKaydet(String uid, String ad) =>
      kullanicilar.doc(uid).set({'ad': ad.trim()}, SetOptions(merge: true));

  static DocumentReference<Map<String, dynamic>> gizli(String fid) =>
      firmalar.doc(fid).collection('gizli').doc('kodlar');

  static Future<void> firmaKur(String uid, String ad, String firmaAdi) async {
    final f = firmalar.doc();
    final kod = yeniKod(), sahaKod = yeniKod();
    final b = _db.batch();
    b.set(f, {
      'ad': firmaAdi.trim().toUpperCase(),
      'altyazi': 'SATIŞ & TİCARET',
      'sahip': uid,
      'uyeler': [uid],
      'yoneticiler': [uid],
      'saha': <String>[],
      'birimler': varsayilanBirimler,
      'urunler': <Map<String, dynamic>>[],
      'sayac': 0,
    });
    b.set(gizli(f.id), {'kod': kod, 'sahaKod': sahaKod});
    b.set(kodlar.doc(kod), {'firmaId': f.id, 'tur': 'ekip'});
    b.set(kodlar.doc(sahaKod), {'firmaId': f.id, 'tur': 'saha'});
    b.set(kullanicilar.doc(uid), {'ad': ad.trim(), 'firmaId': f.id},
        SetOptions(merge: true));
    await b.commit();
  }

  /// Davet koduyla firmaya katılır: ekip kodu tam üye, saha kodu saha
  /// çalışanı yapar. Kod yanlışsa açıklayıcı hata atar.
  static Future<void> kodlaKatil(String uid, String ad, String kodYazi) async {
    final kod = kodYazi.trim().toUpperCase().replaceAll(' ', '');
    final k = await kodlar.doc(kod).get();
    final fid = k.data()?['firmaId'] as String?;
    if (!k.exists || fid == null) {
      throw 'Bu davet kodu bulunamadı. Kodu yöneticiden tekrar isteyin.';
    }
    final saha = k.data()?['tur'] == 'saha';

    // Zaten bu firmadaysa (ör. daha önce katılıp "başka firma" dediyse)
    // yeniden eklemeye çalışma; yalnızca profili bağla.
    var zatenVar = false;
    try {
      final f = await firmalar.doc(fid).get(const GetOptions(source: Source.server));
      final d = f.data() ?? {};
      zatenVar = ((d['uyeler'] as List?)?.contains(uid) ?? false) ||
          ((d['saha'] as List?)?.contains(uid) ?? false);
    } catch (_) {
      // Okuyamıyorsa üye değildir; normal katılıma devam.
    }

    if (!zatenVar) {
      final b = _db.batch();
      b.set(firmalar.doc(fid).collection('katilim').doc(uid), {'kod': kod});
      b.update(firmalar.doc(fid), {
        saha ? 'saha' : 'uyeler': FieldValue.arrayUnion([uid]),
      });
      try {
        // Sunucu onayını bekle; firma ekranı ancak üyelik kesinleşince açılsın.
        await b.commit();
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          throw 'Bu kod artık geçerli değil. Yöneticiden yeni kodu isteyin.';
        }
        rethrow;
      }
    }
    await kullanicilar
        .doc(uid)
        .set({'ad': ad.trim(), 'firmaId': fid}, SetOptions(merge: true));
  }

  /// Eski sürümden kalan, firma kaydındaki davet kodunu yalnızca
  /// yöneticilerin okuyabildiği yere taşır ve bir saha kodu üretir.
  static Future<void> kodlariTasi(Firma f) async {
    final g = await gizli(f.id).get();
    final b = _db.batch();
    if (!g.exists) {
      final kod = f.kod.isNotEmpty ? f.kod : yeniKod();
      final sahaKod = yeniKod();
      b.set(gizli(f.id), {'kod': kod, 'sahaKod': sahaKod});
      b.set(kodlar.doc(kod), {'firmaId': f.id, 'tur': 'ekip'});
      b.set(kodlar.doc(sahaKod), {'firmaId': f.id, 'tur': 'saha'});
    }
    b.update(firmalar.doc(f.id), {
      'kod': FieldValue.delete(),
      'katilKod': FieldValue.delete(),
    });
    await b.commit();
  }

  static Future<void> firmadanAyril(String uid) =>
      kullanicilar.doc(uid).set({'firmaId': ''}, SetOptions(merge: true));

  /// Sipariş numarasını firma sayacından artırarak yeni sipariş ekler.
  static Future<int> siparisEkle(String fid, Map<String, dynamic> veri) {
    final fRef = firmalar.doc(fid);
    final sRef = siparisler(fid).doc();
    return _db.runTransaction<int>((tx) async {
      final f = await tx.get(fRef);
      final sayac = ((f.data()?['sayac'] as num?) ?? 0).toInt() + 1;
      tx.update(fRef, {'sayac': sayac});
      tx.set(sRef, {
        ...veri,
        'no': sayac,
        'sonIslem': {
          'tur': 'siparis',
          'by': FirebaseAuth.instance.currentUser?.uid ?? '',
          'tarih': veri['guncelleme'] ?? simdi,
        },
      });
      return sayac;
    });
  }

  /// [islem]: bildirimler için ne yapıldığı, örn. {'tur': 'tahsilat', 'tutar': 500}
  static Future<void> siparisGuncelle(
      String fid, String id, Map<String, dynamic> veri,
      {Map<String, dynamic>? islem}) {
    final t = simdi;
    return siparisler(fid).doc(id).update({
      ...veri,
      'guncelleme': t,
      'sonIslem': {
        'tur': 'duzeltme',
        ...?islem,
        'by': FirebaseAuth.instance.currentUser?.uid ?? '',
        'tarih': t,
      },
    });
  }

  /// Birden çok siparişte tek bir alanı değiştirir (ör. müşteri adı düzeltme).
  static Future<void> alanDegistir(
      String fid, List<String> idler, String alan, Object deger) async {
    for (var i = 0; i < idler.length; i += 400) {
      final b = _db.batch();
      for (final id in idler.skip(i).take(400)) {
        b.update(siparisler(fid).doc(id), {alan: deger});
      }
      await b.commit();
    }
  }

  static Future<void> siparisSil(String fid, String id) =>
      siparisler(fid).doc(id).delete();

  static Future<void> firmaGuncelle(String fid, Map<String, dynamic> veri) =>
      firmalar.doc(fid).update(veri);

  /// Ekip ya da saha davet kodunu yeniler; eski kod çalışmaz olur.
  static Future<void> kodYenile(String fid,
      {required bool saha, required String eski}) async {
    final yeni = yeniKod();
    final b = _db.batch();
    b.set(kodlar.doc(yeni), {'firmaId': fid, 'tur': saha ? 'saha' : 'ekip'});
    b.set(gizli(fid), {saha ? 'sahaKod' : 'kod': yeni}, SetOptions(merge: true));
    if (eski.isNotEmpty) b.delete(kodlar.doc(eski));
    await b.commit();
  }
}

/// Bir firmanın canlı verisi: firma ayarları, siparişler ve kullanıcı adları.
class Durum extends ChangeNotifier {
  Durum({required this.fid, required this.uid}) {
    _firmayiDinle();
  }

  int _firmaDeneme = 0;
  bool _kapandi = false;

  /// Katıldıktan hemen sonra sunucu üyeliği henüz görmemiş olabilir;
  /// "erişim yok" gelirse birkaç kez bekleyip yeniden dener.
  void _firmayiDinle() {
    _fAbone?.cancel();
    _fAbone = Veri.firmalar.doc(fid).snapshots().listen((s) {
      _firmaDeneme = 0;
      firma = s.exists ? Firma.fromMap(s.id, s.data()!) : null;
      firmaYok = !s.exists;
      firmaHata = null;
      _rolDegisti();
      if (yuklendi) _eslestirmeyiZamanla();
      notifyListeners();
    }, onError: (Object e) {
      if (_firmaDeneme < 4 && !_kapandi) {
        _firmaDeneme++;
        Future.delayed(Duration(seconds: 2 * _firmaDeneme), () {
          if (!_kapandi) _firmayiDinle();
        });
        return;
      }
      firmaHata = e;
      notifyListeners();
    });
  }

  int _siparisDeneme = 0;

  /// Rol: 'uye' (tam yetki), 'saha' (yalnızca kendi siparişleri) ya da null.
  String? _rol;
  bool _tasindi = false;

  void _rolDegisti() {
    final yeni = uye ? 'uye' : (saha ? 'saha' : null);
    if (yeni != _rol) {
      _rol = yeni;
      _sAbone?.cancel();
      _sAbone = null;
      _sAbone2?.cancel();
      _sAbone2 = null;
      siparisler = const [];
      yuklendi = false;
      if (yeni != null) _siparisleriDinle(yeni == 'saha');
    }
    final y = yonetici;
    if (y && _gAbone == null) {
      _gAbone = Veri.gizli(fid).snapshots().listen((g) {
        ekipKodu = (g.data()?['kod'] as String?) ?? '';
        sahaKodu = (g.data()?['sahaKod'] as String?) ?? '';
        notifyListeners();
      }, onError: (_) {});
    } else if (!y && _gAbone != null) {
      _gAbone?.cancel();
      _gAbone = null;
    }
    // Eski sürümden kalan davet kodunu güvenli yere taşı (bir kez).
    final f = firma;
    if (y && f != null && !_tasindi) {
      _tasindi = true;
      () async {
        try {
          final g = await Veri.gizli(fid).get();
          if (!g.exists || f.eskiKodVar) await Veri.kodlariTasi(f);
        } catch (e) {
          _tasindi = false;
          debugPrint('Kodlar taşınamadı: $e');
        }
      }();
    }
  }

  // Saha çalışanı için iki ayrı sorgu: kendi girdikleri ve aracı olduğu
  // (gorenler) satışlar. Kurallar yalnızca bunları okumaya izin verir.
  StreamSubscription? _sAbone2;
  Map<String, Siparis> _kendi = {};
  Map<String, Siparis> _bagli = {};

  void _sahaListesiniYay() {
    final l = {..._bagli, ..._kendi}.values.toList()
      ..sort((a, b) => b.sonIslem.compareTo(a.sonIslem));
    siparisler = l;
    yuklendi = true;
    siparisHata = null;
    notifyListeners();
    _isimleriGetir();
  }

  void _siparisHatasi(Object e) {
    if (_siparisDeneme < 4 && !_kapandi) {
      _siparisDeneme++;
      Future.delayed(Duration(seconds: 2 * _siparisDeneme), () {
        if (!_kapandi && _rol != null) {
          _sAbone?.cancel();
          _sAbone2?.cancel();
          _siparisleriDinle(_rol == 'saha');
        }
      });
      return;
    }
    siparisHata = e;
    yuklendi = true;
    notifyListeners();
  }

  void _siparisleriDinle(bool saha) {
    if (saha) {
      _kendi = {};
      _bagli = {};
      _sAbone = Veri.siparisler(fid)
          .where('olusturan', isEqualTo: uid)
          .limit(2000)
          .snapshots()
          .listen((s) {
        _siparisDeneme = 0;
        _kendi = {
          for (final d in s.docs) d.id: Siparis.fromMap(d.id, d.data())
        };
        _sahaListesiniYay();
      }, onError: _siparisHatasi);
      _sAbone2 = Veri.siparisler(fid)
          .where('gorenler', arrayContains: uid)
          .limit(2000)
          .snapshots()
          .listen((s) {
        _bagli = {
          for (final d in s.docs) d.id: Siparis.fromMap(d.id, d.data())
        };
        _sahaListesiniYay();
      }, onError: (Object e) => debugPrint('Aracı satışları okunamadı: $e'));
      return;
    }
    _sAbone = Veri.siparisler(fid)
        .orderBy('guncelleme', descending: true)
        .limit(2000)
        .snapshots()
        .listen((s) {
      _siparisDeneme = 0;
      siparisler =
          s.docs.map((d) => Siparis.fromMap(d.id, d.data())).toList();
      yuklendi = true;
      siparisHata = null;
      notifyListeners();
      _isimleriGetir();
      if (!s.metadata.isFromCache) {
        Hareketler.isle(fid, uid, siparisler, isimBul: _isimBekle);
        _eslestirmeyiZamanla();
      }
    }, onError: _siparisHatasi);
  }

  // ---- Yönetici: aracı satışlarını saha çalışanlarına bağlama ----
  Timer? _eslestirmeZamani;
  bool _eslestiriliyor = false;

  void _eslestirmeyiZamanla() {
    if (!yonetici) return;
    _eslestirmeZamani?.cancel();
    _eslestirmeZamani = Timer(const Duration(seconds: 3), () {
      _sahaEslestir();
      _araciOzetiYaz();
    });
  }

  bool _ozetYaziliyor = false;

  /// Saha çalışanları için aracı sıralamasını firma kaydına yazar. Saha
  /// çalışanı başkalarının siparişlerini okuyamaz; yalnızca bu özeti görür
  /// (aracı adı, kilogram ve sipariş sayısı; tutar yok). Değişmediyse yazmaz.
  Future<void> _araciOzetiYaz() async {
    final f = firma;
    if (f == null || !yonetici || !yuklendi || _kapandi || _ozetYaziliyor) return;
    if (f.saha.isEmpty) return;
    final o = AraciOzeti.hesapla(siparisler, DateTime.now());
    if (f.araciOzeti?.imza == o.imza) return;
    _ozetYaziliyor = true;
    try {
      await Veri.firmalar
          .doc(fid)
          .update({'araciOzet': o.toMap(DateTime.now().millisecondsSinceEpoch)});
    } catch (e) {
      debugPrint('Aracı özeti yazılamadı: $e');
    } finally {
      _ozetYaziliyor = false;
    }
  }

  /// Bir siparişin aracısı hangi saha çalışanlarına ait?
  Future<Map<String, Set<String>>> _sahaAdlari(Firma f) async {
    final adlar = <String, Set<String>>{};
    for (final u in f.saha) {
      final k = <String>{};
      final ad = await _isimBekle(u);
      if (ad.isNotEmpty && ad != 'Bir kullanıcı' && ad != '…') k.add(araMetni(ad));
      for (final a in f.sahaAraci[u] ?? const <String>[]) {
        if (a.trim().isNotEmpty) k.add(araMetni(a));
      }
      adlar[u] = k;
    }
    return adlar;
  }

  /// Aracı adı bir saha çalışanına ait satışların "gorenler" listesini
  /// günceller; böylece o satışlar çalışanın Hızlı Satış sayfasında görünür.
  /// Sıralamayı ve bildirimleri etkilemez.
  Future<void> _sahaEslestir() async {
    final f = firma;
    if (f == null || !yonetici || _eslestiriliyor || _kapandi) return;
    _eslestiriliyor = true;
    try {
      final adlar = await _sahaAdlari(f);
      final degisecek = <String, List<String>>{};
      for (final s in siparisler) {
        final a = araMetni(s.araci);
        final istenen = <String>[
          if (a.isNotEmpty)
            for (final e in adlar.entries)
              if (e.value.contains(a)) e.key
        ]..sort();
        final simdiki = [...s.gorenler]..sort();
        if (istenen.join(',') != simdiki.join(',')) degisecek[s.id] = istenen;
      }
      if (degisecek.isEmpty) return;
      final ids = degisecek.keys.toList();
      for (var i = 0; i < ids.length; i += 400) {
        final b = FirebaseFirestore.instance.batch();
        for (final id in ids.skip(i).take(400)) {
          b.update(Veri.siparisler(fid).doc(id), {'gorenler': degisecek[id]});
        }
        await b.commit();
      }
    } catch (e) {
      debugPrint('Saha eşleştirmesi yapılamadı: $e');
    } finally {
      _eslestiriliyor = false;
    }
  }

  /// Ayarlar ekranı için: bu saha çalışanına bağlı aracı satışı sayısı.
  int bagliSatisSayisi(String sahaUid) =>
      siparisler.where((s) => s.gorenler.contains(sahaUid)).length;


  final String fid;
  final String uid;
  Firma? firma;
  bool firmaYok = false;
  Object? firmaHata;
  Object? siparisHata;
  List<Siparis> siparisler = const [];
  bool yuklendi = false;
  final Map<String, String> _isimler = {};
  final Set<String> _istenen = {};
  StreamSubscription? _fAbone;
  StreamSubscription? _sAbone;
  StreamSubscription? _gAbone;

  /// Yalnızca yöneticide dolar.
  String ekipKodu = '';
  String sahaKodu = '';

  bool get uye => firma != null && firma!.uyeler.contains(uid);

  /// Saha çalışanı (tam üye değilse).
  bool get saha => firma != null && !uye && firma!.saha.contains(uid);
  bool get yonetici => firma?.yonetici(uid) ?? false;

  List<Siparis> asamada(Asama a) =>
      siparisler.where((s) => s.asama == a).toList();
  int sayi(Asama a) => siparisler.where((s) => s.asama == a).length;

  double get ciro => siparisler.fold(0.0, (a, s) => a + s.toplam);
  double get tahsil => siparisler.fold(0.0, (a, s) => a + min(s.odenen, s.toplam));
  double get alacak => siparisler.fold(0.0, (a, s) => a + s.kalan);

  String isim(String id) {
    if (id.isEmpty) return '—';
    final v = _isimler[id];
    if (v != null) return v;
    _isimGetir([id]);
    return '…';
  }

  void _isimleriGetir() {
    final ids = <String>{...?firma?.uyeler, ...?firma?.saha};
    for (final s in siparisler) {
      ids.addAll([s.olusturan, s.fiyatlayan, s.teslimEden]);
      for (final t in s.tahsilatlar) {
        ids.add(t.by);
      }
    }
    _isimGetir(ids.where((e) => e.isNotEmpty));
  }

  Future<void> _isimGetir(Iterable<String> ids) async {
    final yeni = ids.where((i) => !_istenen.contains(i)).toList();
    if (yeni.isEmpty) return;
    _istenen.addAll(yeni);
    await Future.wait(yeni.map((i) async {
      try {
        final d = await Veri.kullanicilar.doc(i).get();
        final ad = (d.data()?['ad'] as String?)?.trim();
        _isimler[i] = (ad == null || ad.isEmpty) ? 'Kullanıcı' : ad;
      } catch (_) {
        _isimler[i] = 'Kullanıcı';
      }
    }));
    notifyListeners();
  }

  Future<String> _isimBekle(String id) async {
    final v = _isimler[id];
    if (v != null) return v;
    try {
      final d = await Veri.kullanicilar.doc(id).get();
      final ad = (d.data()?['ad'] as String?)?.trim();
      if (ad != null && ad.isNotEmpty) return _isimler[id] = ad;
    } catch (_) {}
    return 'Bir kullanıcı';
  }

  /// Ad değişince önbelleği tazeler.
  void isimTazele(String id) {
    _istenen.remove(id);
    _isimler.remove(id);
    _isimGetir([id]);
  }

  @override
  void dispose() {
    _kapandi = true;
    _eslestirmeZamani?.cancel();
    _sAbone2?.cancel();
    _fAbone?.cancel();
    _sAbone?.cancel();
    _gAbone?.cancel();
    super.dispose();
  }
}

String hataYazisi(Object e) {
  if (e is String) return e;
  if (e is FirebaseException) {
    switch (e.code) {
      case 'permission-denied':
        return 'Bu işlem için yetkiniz yok.';
      case 'unavailable':
        return 'İnternet bağlantısı yok gibi görünüyor. Biraz sonra tekrar deneyin.';
      case 'invalid-email':
        return 'E-posta adresi geçersiz.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-posta veya şifre hatalı.';
      case 'email-already-in-use':
        return 'Bu e-posta ile zaten bir hesap var. Giriş yapın.';
      case 'weak-password':
        return 'Şifre çok zayıf, en az 6 karakter olmalı.';
      case 'too-many-requests':
        return 'Çok fazla deneme yapıldı. Biraz bekleyip tekrar deneyin.';
      case 'network-request-failed':
        return 'İnternet bağlantınızı kontrol edin.';
    }
    return e.message ?? e.code;
  }
  return '$e';
}
