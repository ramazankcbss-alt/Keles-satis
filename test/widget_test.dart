import 'package:flutter_test/flutter_test.dart';
import 'package:keles_satis/bicim.dart';
import 'package:keles_satis/ekranlar/arama.dart';
import 'package:keles_satis/ekranlar/formlar.dart';
import 'package:keles_satis/modeller.dart';
import 'package:keles_satis/servis/bildirim.dart';

Siparis _s({double? fiyat, bool teslim = false, List<double> odemeler = const []}) =>
    Siparis(
      id: '1',
      no: 1,
      musteri: 'Ahmet',
      urun: 'Domates',
      miktar: 100,
      birim: 'kg',
      olusturan: 'u',
      olusturma: 1,
      fiyat: fiyat,
      teslim: teslim,
      tahsilatlar: [
        for (final o in odemeler) Tahsilat(tutar: o, yontem: 'Nakit', tarih: 1, by: 'u')
      ],
    );

void main() {
  test('Aşamalar sırayla ilerler', () {
    expect(_s().asama, Asama.fiyat);
    expect(_s(fiyat: 12.5).asama, Asama.teslim);
    expect(_s(fiyat: 12.5, teslim: true).asama, Asama.tahsilat);
    expect(_s(fiyat: 12.5, teslim: true, odemeler: [1250]).asama, Asama.tamam);
  });

  test('Kısmi tahsilat ve kalan', () {
    final s = _s(fiyat: 12.5, teslim: true, odemeler: [500, 250.25]);
    expect(s.toplam, 1250);
    expect(s.odenen, 750.25);
    expect(s.kalan, 499.75);
    expect(s.asama, Asama.tahsilat);
  });

  test('Fazla ödeme kalanı eksiye düşürmez', () {
    final s = _s(fiyat: 10, teslim: true, odemeler: [1500]);
    expect(s.kalan, 0);
    expect(s.asama, Asama.tamam);
  });

  test('Sayı okuma (Türkçe yazım)', () {
    expect(sayiOku('1.234,5'), 1234.5);
    expect(sayiOku('12,75'), 12.75);
    expect(sayiOku('15.5'), 15.5);
    expect(sayiOku('3.125'), 3125);
    expect(sayiOku('1.250.000'), 1250000);
    expect(sayiOku('2.50'), 2.5);
    expect(sayiOku(' 2 500 '), 2500);
    expect(sayiOku(''), isNull);
    expect(sayiOku('abc'), isNull);
  });

  test('Firma ürün bulma büyük/küçük harf duyarsız', () {
    const f = Firma(
      id: 'f',
      ad: 'KELEŞ TARIM',
      altyazi: '',
      sahip: 'u',
      uyeler: ['u'],
      yoneticiler: ['u'],
      birimler: [],
      urunler: [Urun(ad: 'Domates', birim: 'kasa', fiyat: 150, em: '🍅')],
      kod: 'X',
      sayac: 0,
    );
    expect(f.urunBul(' domates ')?.birim, 'kasa');
    expect(f.birimListesi, varsayilanBirimler);
    expect(f.yonetici('u'), isTrue);
  });

  test('Toplam yazılınca birim fiyat hesaplanır', () {
    final h = FiyatHesap();
    h.miktar.text = '250';
    h.miktarDegisti();
    h.toplam.text = '3.125';
    h.toplamDegisti();
    expect(h.fiyat.text, '12,5');
    expect(h.kaydedilecekFiyat, 12.5);

    // Miktar değişince, son yazılan toplam sabit kalır, fiyat yeniden hesaplanır.
    h.miktar.text = '500';
    h.miktarDegisti();
    expect(h.fiyat.text, '6,25');

    // Bölünmeyen tutarda kaydedilen fiyat toplamı birebir tutturur.
    h.miktar.text = '3';
    h.toplam.text = '1000';
    h.toplamDegisti();
    expect(h.fiyat.text, '333,3333');
    expect((h.kaydedilecekFiyat! * 3).toStringAsFixed(2), '1000.00');
  });

  test('Fiyat yazılınca toplam hesaplanır', () {
    final h = FiyatHesap(miktar: 120, fiyat: null);
    h.fiyat.text = '17,75';
    h.fiyatDegisti();
    expect(h.toplam.text, '2130');
    expect(h.toplamGirildi, isFalse);
    h.toplam.text = '';
    h.toplamDegisti();
    expect(h.fiyat.text, '');
    expect(h.bos, isTrue);
  });

  test('Son işlem okunur ve bildirim metni oluşur', () {
    final s = Siparis.fromMap('x', {
      'no': 7,
      'musteri': 'Ahmet',
      'urun': 'Çekirdek',
      'miktar': 250,
      'birim': 'kg',
      'olusturan': 'a',
      'olusturma': 1,
      'fiyat': 10,
      'teslim': true,
      'tahsilatlar': [
        {'tutar': 1000, 'yontem': 'Nakit', 'tarih': 2, 'by': 'b'}
      ],
      'sonIslem': {'tur': 'tahsilat', 'by': 'b', 'tarih': 5, 'tutar': 1000, 'yontem': 'Nakit'},
    });
    expect(s.sonIslemTur, 'tahsilat');
    expect(s.sonIslemBy, 'b');
    expect(s.sonIslemTarih, 5);
    final (baslik, metin) = Hareketler.metinOlustur(s, 'Mehmet');
    expect(baslik, contains('Tahsilat #7'));
    expect(metin, contains('Mehmet'));
    expect(metin, contains('Nakit'));
    expect(metin, contains('Kalan'));
  });

  test('Aracı okunur; boşsa doğrudan satış sayılır', () {
    final a = Siparis.fromMap('1', {'musteri': 'A', 'urun': 'Çekirdek', 'miktar': 1, 'araci': ' Mehmet '});
    final b = Siparis.fromMap('2', {'musteri': 'B', 'urun': 'Çekirdek', 'miktar': 1});
    expect(a.araci, 'Mehmet');
    expect(a.araciAdi, 'Mehmet');
    expect(b.araciAdi, dogrudanSatis);
  });

  test('Arama Türkçe harf farklarını önemsemez, sipariş no ile bulur', () {
    expect(araMetni('Ilıcalı Şükrü ÇİFTÇİ'), 'ilicali sukru ciftci');
    final s = Siparis.fromMap('1', {
      'no': 42,
      'musteri': 'Şükrü Ilıcalı',
      'urun': 'Çekirdek',
      'miktar': 10,
      'araci': 'Mehmet Öz',
    });
    expect(aramadaEslesir(s, 'sukru'), isTrue);
    expect(aramadaEslesir(s, 'ILICALI'), isTrue);
    expect(aramadaEslesir(s, 'cekirdek'), isTrue);
    expect(aramadaEslesir(s, 'mehmet oz'), isTrue);
    expect(aramadaEslesir(s, '#42'), isTrue);
    expect(aramadaEslesir(s, '42'), isTrue);
    expect(aramadaEslesir(s, 'ahmet'), isFalse);
  });

  test('Saha bağlantıları okunur', () {
    final s = Siparis.fromMap('1', {
      'musteri': 'A', 'urun': 'Çekirdek', 'miktar': 1,
      'araci': 'Halime', 'gorenler': ['h1'],
    });
    expect(s.gorenler, ['h1']);
    final f = Firma.fromMap('f', {
      'ad': 'X', 'sahip': 'u', 'uyeler': ['u'], 'yoneticiler': ['u'],
      'saha': ['h1'], 'sahaAraci': {'h1': ['Halime', 'Halime Hanım']},
    });
    expect(f.saha, ['h1']);
    expect(f.sahaAraci['h1'], ['Halime', 'Halime Hanım']);
    expect(araMetni('Halime Hanım'), araMetni('HALİME HANIM'));
  });
}
