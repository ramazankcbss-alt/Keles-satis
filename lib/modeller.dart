import 'package:cloud_firestore/cloud_firestore.dart';

double _d(Object? v) =>
    v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;
double? _dn(Object? v) =>
    v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));
int _i(Object? v) => v is num
    ? v.toInt()
    : v is Timestamp
        ? v.millisecondsSinceEpoch
        : 0;
String _s(Object? v) => v == null ? '' : '$v';
List<String> _ls(Object? v) =>
    v is List ? v.map((e) => '$e').toList() : <String>[];

const dogrudanSatis = 'Doğrudan satış';

const varsayilanBirimler = [
  'kg',
  'ton',
  'adet',
  'koli',
  'kasa',
  'çuval',
  'litre',
  'paket'
];

class Urun {
  const Urun({required this.ad, required this.birim, this.fiyat, this.em = '📦'});

  final String ad;
  final String birim;
  final double? fiyat;
  final String em;

  factory Urun.fromMap(Map m) => Urun(
        ad: _s(m['ad']),
        birim: _s(m['birim']),
        fiyat: _dn(m['fiyat']),
        em: _s(m['em']).isEmpty ? '📦' : _s(m['em']),
      );

  Map<String, dynamic> toMap() =>
      {'ad': ad, 'birim': birim, 'fiyat': fiyat, 'em': em};
}

class Tahsilat {
  const Tahsilat(
      {required this.tutar,
      required this.yontem,
      required this.tarih,
      required this.by});

  final double tutar;
  final String yontem;
  final int tarih;
  final String by;

  factory Tahsilat.fromMap(Map m) => Tahsilat(
        tutar: _d(m['tutar']),
        yontem: _s(m['yontem']),
        tarih: _i(m['tarih']),
        by: _s(m['by']),
      );

  Map<String, dynamic> toMap() =>
      {'tutar': tutar, 'yontem': yontem, 'tarih': tarih, 'by': by};
}

enum Asama { fiyat, teslim, tahsilat, tamam }

class AsamaBilgi {
  const AsamaBilgi(this.em, this.ad, this.isaret);
  final String em;
  final String ad;
  final String isaret;
}

const asamaBilgi = {
  Asama.fiyat: AsamaBilgi('🧾', 'Fiyat bekliyor', '!'),
  Asama.teslim: AsamaBilgi('📦', 'Teslim bekliyor', '⏳'),
  Asama.tahsilat: AsamaBilgi('🚚', 'Tahsilat bekliyor', '₺'),
  Asama.tamam: AsamaBilgi('✅', 'Tamamlandı', '✓'),
};

class Siparis {
  const Siparis({
    required this.id,
    required this.no,
    required this.musteri,
    required this.urun,
    required this.miktar,
    required this.birim,
    this.not = '',
    this.araci = '',
    required this.olusturan,
    required this.olusturma,
    this.guncelleme = 0,
    this.fiyat,
    this.fiyatlayan = '',
    this.fiyatTarih = 0,
    this.teslim = false,
    this.teslimEden = '',
    this.teslimTarih = 0,
    this.teslimNot = '',
    this.tahsilatlar = const [],
    this.sonIslemTur = '',
    this.sonIslemBy = '',
    this.sonIslemTarih = 0,
    this.sonIslemTutar = 0,
    this.sonIslemYontem = '',
    this.gorenler = const [],
  });

  final String id;
  final int no;
  final String musteri;
  final String urun;
  final double miktar;
  final String birim;
  final String not;

  /// Satışın kimin aracılığıyla yapıldığı; boşsa doğrudan satış.
  final String araci;
  final String olusturan;
  final int olusturma;
  final int guncelleme;
  final double? fiyat;
  final String fiyatlayan;
  final int fiyatTarih;
  final bool teslim;
  final String teslimEden;
  final int teslimTarih;
  final String teslimNot;
  final List<Tahsilat> tahsilatlar;

  /// Siparişte en son yapılan işlem (bildirimler için):
  /// siparis | fiyat | teslim | tahsilat | duzeltme
  final String sonIslemTur;
  final String sonIslemBy;
  final int sonIslemTarih;
  final double sonIslemTutar;
  final String sonIslemYontem;

  /// Bu satışı görebilen saha çalışanları (aracı olduğu satışlar).
  /// Yöneticinin uygulaması aracı adına göre kendiliğinden doldurur.
  final List<String> gorenler;

  double get toplam => fiyat == null ? 0 : miktar * fiyat!;
  double get odenen => tahsilatlar.fold(0.0, (a, t) => a + t.tutar);
  double get kalan {
    final k = ((toplam - odenen) * 100).round() / 100;
    return k > 0 ? k : 0;
  }

  Asama get asama => fiyat == null
      ? Asama.fiyat
      : !teslim
          ? Asama.teslim
          : kalan > 0
              ? Asama.tahsilat
              : Asama.tamam;

  int get sonIslem => guncelleme > 0 ? guncelleme : olusturma;

  /// Raporlarda gösterilecek aracı adı.
  String get araciAdi => araci.isEmpty ? dogrudanSatis : araci;

  factory Siparis.fromMap(String id, Map<String, dynamic> m) => Siparis(
        id: id,
        no: _i(m['no']),
        musteri: _s(m['musteri']),
        urun: _s(m['urun']),
        miktar: _d(m['miktar']),
        birim: _s(m['birim']),
        not: _s(m['not']),
        araci: _s(m['araci']).trim(),
        olusturan: _s(m['olusturan']),
        olusturma: _i(m['olusturma']),
        guncelleme: _i(m['guncelleme']),
        fiyat: _dn(m['fiyat']),
        fiyatlayan: _s(m['fiyatlayan']),
        fiyatTarih: _i(m['fiyatTarih']),
        teslim: m['teslim'] == true,
        teslimEden: _s(m['teslimEden']),
        teslimTarih: _i(m['teslimTarih']),
        teslimNot: _s(m['teslimNot']),
        tahsilatlar: (m['tahsilatlar'] is List)
            ? (m['tahsilatlar'] as List)
                .whereType<Map>()
                .map(Tahsilat.fromMap)
                .toList()
            : const [],
        sonIslemTur: _s((m['sonIslem'] as Map?)?['tur']),
        sonIslemBy: _s((m['sonIslem'] as Map?)?['by']),
        sonIslemTarih: _i((m['sonIslem'] as Map?)?['tarih']),
        sonIslemTutar: _d((m['sonIslem'] as Map?)?['tutar']),
        sonIslemYontem: _s((m['sonIslem'] as Map?)?['yontem']),
        gorenler: _ls(m['gorenler']),
      );
}

class Firma {
  const Firma({
    required this.id,
    required this.ad,
    required this.altyazi,
    required this.sahip,
    required this.uyeler,
    required this.yoneticiler,
    this.saha = const [],
    this.sahaAraci = const {},
    required this.birimler,
    required this.urunler,
    required this.kod,
    required this.sayac,
    this.eskiKodVar = false,
  });

  final String id;
  final String ad;
  final String altyazi;
  final String sahip;
  final List<String> uyeler;
  final List<String> yoneticiler;

  /// Saha çalışanları: yalnızca hızlı satış ekranını ve kendi girdiklerini görür.
  final List<String> saha;

  /// Saha çalışanı → ona ait sayılan aracı adları (yöneticinin seçtikleri).
  /// Çalışanın kendi adıyla yazılmış aracı satışları ayrıca kendiliğinden eşleşir.
  final Map<String, List<String>> sahaAraci;
  final List<String> birimler;
  final List<Urun> urunler;
  /// Eski sürümlerde davet kodu firma kaydındaydı; artık gizli/kodlar'da.
  final String kod;
  final int sayac;

  /// Firma kaydında eski sürümden kalan kod alanları var mı (taşınmalı).
  final bool eskiKodVar;

  bool yonetici(String uid) => yoneticiler.contains(uid);
  List<String> get birimListesi =>
      birimler.isEmpty ? varsayilanBirimler : birimler;

  Urun? urunBul(String ad) {
    final a = ad.trim().toLowerCase();
    for (final u in urunler) {
      if (u.ad.trim().toLowerCase() == a) return u;
    }
    return null;
  }

  factory Firma.fromMap(String id, Map<String, dynamic> m) => Firma(
        id: id,
        ad: _s(m['ad']),
        altyazi: _s(m['altyazi']),
        sahip: _s(m['sahip']),
        uyeler: _ls(m['uyeler']),
        yoneticiler: _ls(m['yoneticiler']),
        saha: _ls(m['saha']),
        sahaAraci: (m['sahaAraci'] is Map)
            ? {
                for (final e in (m['sahaAraci'] as Map).entries)
                  '${e.key}': _ls(e.value)
              }
            : const {},
        birimler: _ls(m['birimler']),
        urunler: (m['urunler'] is List)
            ? (m['urunler'] as List).whereType<Map>().map(Urun.fromMap).toList()
            : const [],
        kod: _s(m['kod']),
        sayac: _i(m['sayac']),
        eskiKodVar: m.containsKey('kod') || m.containsKey('katilKod'),
      );
}

/// "1.234,5" / "3.125" / "12.5" / "1 234" gibi yazımları sayıya çevirir.
/// Virgül yoksa ve noktalar üçlü gruplar ayırıyorsa binlik ayırıcı sayılır.
double? sayiOku(String? v) {
  if (v == null) return null;
  var s = v.trim().replaceAll(' ', '').replaceAll('₺', '');
  if (s.isEmpty) return null;
  if (s.contains(',')) {
    s = s.replaceAll('.', '').replaceAll(',', '.');
  } else if (RegExp(r'^-?\d{1,3}(\.\d{3})+$').hasMatch(s)) {
    // "3.125" / "1.250.000": Türkçe binlik ayırıcı
    s = s.replaceAll('.', '');
  }
  return double.tryParse(s);
}
