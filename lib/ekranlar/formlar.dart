import 'package:flutter/material.dart';

import '../bicim.dart';
import '../modeller.dart';
import '../servis/veri.dart';
import '../tema.dart';

const yontemler = ['Nakit', 'Havale/EFT', 'Kredi Kartı', 'Çek', 'Senet'];

/// Yazma işlemini çalıştırır; hata olursa gösterir. Başarılıysa true.
Future<bool> _calistir(BuildContext context, Future<void> Function() is_,
    {String? basari}) async {
  try {
    await is_();
    if (basari != null && context.mounted) bildir(context, basari);
    return true;
  } catch (e) {
    if (context.mounted) bildir(context, hataYazisi(e));
    return false;
  }
}

Widget _ikili(Widget a, Widget b) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 14, child: a),
        const SizedBox(width: 10),
        Expanded(flex: 10, child: b),
      ],
    );

Widget _birimSecici(
        List<String> birimler, String secili, ValueChanged<String> degisti) =>
    DropdownButtonFormField<String>(
      initialValue: birimler.contains(secili) ? secili : birimler.first,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Birim'),
      dropdownColor: Colors.white,
      items: [
        for (final b in birimler) DropdownMenuItem(value: b, child: Text(b)),
      ],
      onChanged: (v) => v == null ? null : degisti(v),
    );

Widget _butonlar(BuildContext context,
        {required String yazi,
        required ButonRenk renk,
        required bool mesgul,
        required VoidCallback onTap}) =>
    Row(
      children: [
        Expanded(
            child: Buton(
                yazi: 'Vazgeç',
                renk: ButonRenk.ikincil,
                onTap: mesgul ? null : () => Navigator.pop(context))),
        const SizedBox(width: 10),
        Expanded(
            flex: 2,
            child: Buton(
                yazi: yazi, renk: renk, mesgul: mesgul, onTap: onTap)),
      ],
    );

// ---------------------------------------------------------------- Yeni sipariş

/// Yeni sipariş. [hizli]: saha için "teslim edildi" ve tahsilat aynı formda
/// açık gelir (satış, teslim ve tahsilat tek seferde).
Future<void> yeniSiparis(BuildContext context, Durum d, {bool hizli = false}) {
  final f = d.firma!;
  final musteriler = {for (final s in d.siparisler) s.musteri.trim()}
    ..removeWhere((e) => e.isEmpty);
  final urunAdlari = {
    ...f.urunler.map((u) => u.ad),
    for (final s in d.siparisler) s.urun.trim()
  }..removeWhere((e) => e.isEmpty);
  final aracilar = araciListesi(d);

  return altSayfa(
    context,
    baslik: hizli ? 'Yeni satış' : 'Yeni sipariş',
    aciklama: hizli
        ? 'Satışı, teslimi ve tahsilatı tek seferde girin.'
        : 'Önce siparişi girin; fiyat bir sonraki adımda yazılır.',
    builder: (ctx) {
      final musteri = TextEditingController();
      final urun = TextEditingController();
      final hesap = FiyatHesap();
      final not = TextEditingController();
      final musteriOdak = FocusNode();
      final urunOdak = FocusNode();
      final araci = TextEditingController();
      final araciOdak = FocusNode();
      final tahsil = TextEditingController();
      var teslimEdildi = hizli;
      var yontem = yontemler.first;
      var birim = f.birimListesi.first;
      var birimler = [...f.birimListesi];
      var mesgul = false;
      var birimAnahtar = 0;

      return StatefulBuilder(builder: (ctx, set) {
        Urun? secili = f.urunBul(urun.text);

        void urunSec(Urun u) {
          set(() {
            urun.text = u.ad;
            if (u.birim.isNotEmpty) {
              if (!birimler.contains(u.birim)) birimler = [...birimler, u.birim];
              birim = u.birim;
              birimAnahtar++;
            }
            if (u.fiyat != null && hesap.fiyat.text.isEmpty) {
              hesap.fiyat.text = girdi(u.fiyat);
              hesap.fiyatDegisti();
            }
          });
        }

        Future<void> kaydet() async {
          final m = hesap.m;
          final fy = hesap.kaydedilecekFiyat;
          if (musteri.text.trim().isEmpty || urun.text.trim().isEmpty) {
            bildir(ctx, 'Müşteri ve ürünü yazın.');
            return;
          }
          if (m == null || m <= 0) {
            bildir(ctx, 'Geçerli bir miktar girin.');
            return;
          }
          if (!hesap.bos && (fy == null || fy < 0)) {
            bildir(ctx, 'Fiyat geçersiz.');
            return;
          }
          final tHam = teslimEdildi ? tahsil.text.trim() : '';
          final t = tHam.isEmpty ? 0.0 : sayiOku(tHam);
          if (t == null || t < 0) {
            bildir(ctx, 'Tahsil edilen tutar geçersiz.');
            return;
          }
          set(() => mesgul = true);
          final simdi = Veri.simdi;
          int? no;
          final ok = await _calistir(ctx, () async {
            no = await Veri.siparisEkle(d.fid, {
              'musteri': musteri.text.trim(),
              'araci': araci.text.trim(),
              'urun': urun.text.trim(),
              'miktar': m,
              'birim': birim,
              'not': not.text.trim(),
              'olusturan': d.uid,
              'olusturma': simdi,
              'guncelleme': simdi,
              'fiyat': fy,
              'fiyatlayan': fy != null ? d.uid : '',
              'fiyatTarih': fy != null ? simdi : 0,
              'teslim': teslimEdildi,
              'teslimEden': teslimEdildi ? d.uid : '',
              'teslimTarih': teslimEdildi ? simdi : 0,
              'teslimNot': '',
              'tahsilatlar': [
                if (t > 0)
                  Tahsilat(tutar: t, yontem: yontem, tarih: simdi, by: d.uid)
                      .toMap(),
              ],
            });
          });
          if (!ctx.mounted) return;
          if (ok) {
            Navigator.pop(ctx);
            bildir(
                context,
                hizli
                    ? '#$no satış kaydedildi${t > 0 ? ' · ${tl(t)} tahsil edildi' : ''}'
                    : '#$no sipariş kaydedildi');
          } else {
            set(() => mesgul = false);
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OneriliAlan(
              controller: musteri,
              focusNode: musteriOdak,
              secenekler: musteriler,
              etiket: 'Müşteri',
              ipucu: 'Firma veya kişi adı',
              buyukHarf: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            OneriliAlan(
              controller: araci,
              focusNode: araciOdak,
              secenekler: aracilar,
              etiket: 'Aracı (kimin aracılığıyla)',
              ipucu: 'Aracı yoksa boş bırakın',
              buyukHarf: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            if (f.urunler.isNotEmpty) ...[
              const Text('Ürün seçin', style: TextStyle(color: Renk.soluk)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final u in f.urunler)
                    ChoiceChip(
                      label: Text(u.ad),
                      selected: identical(secili, u),
                      labelStyle: TextStyle(
                          color: identical(secili, u) ? Renk.anaKoyu : Renk.yazi,
                          fontWeight: identical(secili, u)
                              ? FontWeight.w600
                              : FontWeight.w500),
                      side: BorderSide(
                          color: identical(secili, u) ? Renk.ana : Renk.cizgi),
                      onSelected: (_) => urunSec(u),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            OneriliAlan(
              controller: urun,
              focusNode: urunOdak,
              secenekler: urunAdlari,
              etiket: f.urunler.isEmpty ? 'Ürün' : 'veya ürün adı yazın',
              ipucu: 'Örn. Domates',
              onDegisti: (_) => set(() {}),
              onSecildi: (v) {
                final u = f.urunBul(v);
                if (u != null) {
                  urunSec(u);
                } else {
                  set(() {});
                }
              },
            ),
            const SizedBox(height: 12),
            _ikili(
              TextField(
                controller: hesap.miktar,
                onChanged: (_) => set(hesap.miktarDegisti),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Miktar', hintText: '0'),
              ),
              KeyedSubtree(
                key: ValueKey(birimAnahtar),
                child: _birimSecici(birimler, birim, (v) => set(() => birim = v)),
              ),
            ),
            const SizedBox(height: 12),
            ..._fiyatAlanlari(hesap, birim, set,
                ipucu: 'Biliyorsanız yazın, boş bırakılabilir'),
            TextField(
              controller: not,
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: 'Not (isteğe bağlı)',
                  hintText: 'Teslim adresi, tarih vb.'),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: teslimEdildi,
              onChanged: (v) => set(() => teslimEdildi = v ?? false),
              title: const Text('Ürün teslim edildi',
                  style: TextStyle(fontSize: 15, color: Renk.yazi)),
              subtitle: const Text('İşaretlerseniz teslimde alınan parayı da girebilirsiniz',
                  style: TextStyle(fontSize: 12.5, color: Renk.soluk)),
            ),
            if (teslimEdildi) ...[
              const SizedBox(height: 6),
              _ikili(
                TextField(
                  controller: tahsil,
                  onChanged: (_) => set(() {}),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Tahsil edilen ₺', hintText: 'Alınmadıysa boş'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: yontem,
                  isExpanded: true,
                  dropdownColor: Colors.white,
                  decoration: const InputDecoration(labelText: 'Yöntem'),
                  items: [
                    for (final y in yontemler)
                      DropdownMenuItem(value: y, child: Text(y))
                  ],
                  onChanged: (v) => yontem = v ?? yontem,
                ),
              ),
              if ((hesap.kaydedilecekFiyat ?? 0) > 0 && (hesap.m ?? 0) > 0)
                Align(
                  alignment: Alignment.centerLeft,
                  child: ActionChip(
                    label: Text(
                        'Tamamı alındı (${tl(hesap.m! * hesap.kaydedilecekFiyat!)})'),
                    onPressed: () => set(() => tahsil.text = girdi(double.parse(
                        (hesap.m! * hesap.kaydedilecekFiyat!).toStringAsFixed(2)))),
                  ),
                ),
            ],
            const SizedBox(height: 16),
            _butonlar(ctx,
                yazi: 'Kaydet',
                renk: ButonRenk.birincil,
                mesgul: mesgul,
                onTap: kaydet),
          ],
        );
      });
    },
  );
}

/// Miktar, birim fiyat ve toplam tutar kutularını birbirine bağlar:
/// fiyat yazılınca toplam, toplam yazılınca fiyat kendiliğinden hesaplanır.
class FiyatHesap {
  FiyatHesap({double? miktar, double? fiyat})
      : miktar = TextEditingController(text: girdi(miktar)),
        fiyat = TextEditingController(text: girdi(fiyat)) {
    _fiyattanToplam();
  }

  final TextEditingController miktar;
  final TextEditingController fiyat;
  final TextEditingController toplam = TextEditingController();

  /// Kullanıcı en son toplam tutarı mı yazdı?
  bool toplamGirildi = false;

  double? get m => sayiOku(miktar.text);
  bool get bos => fiyat.text.trim().isEmpty && toplam.text.trim().isEmpty;

  void miktarDegisti() => toplamGirildi ? _toplamdanFiyat() : _fiyattanToplam();

  void fiyatDegisti() {
    toplamGirildi = false;
    _fiyattanToplam();
  }

  void toplamDegisti() {
    toplamGirildi = toplam.text.trim().isNotEmpty;
    _toplamdanFiyat();
  }

  void _fiyattanToplam() {
    final m = this.m, p = sayiOku(fiyat.text);
    toplam.text = (m != null && m > 0 && p != null && p >= 0)
        ? girdi(double.parse((m * p).toStringAsFixed(2)))
        : '';
  }

  void _toplamdanFiyat() {
    final m = this.m, t = sayiOku(toplam.text);
    fiyat.text = (m != null && m > 0 && t != null && t >= 0)
        ? girdi(double.parse((t / m).toStringAsFixed(4)))
        : '';
  }

  /// Kaydedilecek birim fiyat. Toplam elle yazıldıysa tam bölüm kullanılır,
  /// böylece siparişin toplamı yazılan rakamla kuruşu kuruşuna aynı olur.
  double? get kaydedilecekFiyat {
    final m = this.m;
    if (toplamGirildi) {
      final t = sayiOku(toplam.text);
      if (m != null && m > 0 && t != null && t >= 0) return t / m;
    }
    return sayiOku(fiyat.text);
  }
}

List<Widget> _fiyatAlanlari(
    FiyatHesap h, String birim, StateSetter set,
    {String? ipucu, bool odak = false}) {
  final m = h.m, p = h.kaydedilecekFiyat;
  final hazir = m != null && m > 0 && p != null && p >= 0;
  final altin = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: const BorderSide(color: Renk.ana, width: 1.5),
  );
  return [
    TextField(
      controller: h.fiyat,
      autofocus: odak,
      onChanged: (_) => set(h.fiyatDegisti),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
          labelText: 'Birim fiyat (₺ / $birim)', hintText: ipucu ?? '0,00'),
    ),
    const SizedBox(height: 12),
    TextField(
      controller: h.toplam,
      onChanged: (_) => set(h.toplamDegisti),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(
          fontSize: 19, fontWeight: FontWeight.w700, color: Renk.anaKoyu),
      decoration: InputDecoration(
        labelText: 'Toplam tutar (₺)',
        hintText: 'Toplamı yazarsanız birim fiyat hesaplanır',
        prefixText: '₺ ',
        enabledBorder: altin,
        helperText: hazir ? '${sayi(m ?? 0)} $birim × ${tl(p ?? 0)} = ${tl((m ?? 0) * (p ?? 0))}' : null,
        helperStyle: const TextStyle(color: Renk.soluk, fontSize: 13),
      ),
    ),
    const SizedBox(height: 14),
  ];
}

// ---------------------------------------------------------------- Fiyat

Future<void> fiyatGir(BuildContext context, Durum d, Siparis s) {
  return altSayfa(
    context,
    baslik: 'Fiyat gir · Sipariş #${s.no}',
    aciklama: '${s.musteri} — ${s.urun}',
    builder: (ctx) {
      final varsayilan = s.fiyat ?? d.firma?.urunBul(s.urun)?.fiyat;
      final hesap = FiyatHesap(miktar: s.miktar, fiyat: varsayilan);
      final birimler = {...d.firma!.birimListesi, if (s.birim.isNotEmpty) s.birim}.toList();
      var birim = s.birim.isEmpty ? birimler.first : s.birim;
      var mesgul = false;
      return StatefulBuilder(builder: (ctx, set) {
        Future<void> kaydet() async {
          final m = hesap.m, p = hesap.kaydedilecekFiyat;
          if (m == null || m <= 0 || p == null || p < 0) {
            bildir(ctx, 'Miktar ve fiyatı kontrol edin.');
            return;
          }
          set(() => mesgul = true);
          final ok = await _calistir(
              ctx,
              () => Veri.siparisGuncelle(d.fid, s.id, {
                    'miktar': m,
                    'birim': birim,
                    'fiyat': p,
                    'fiyatlayan': d.uid,
                    'fiyatTarih': Veri.simdi,
                  }, islem: {
                    'tur': 'fiyat'
                  }));
          if (!ctx.mounted) return;
          if (ok) {
            Navigator.pop(ctx);
            bildir(context, '#${s.no} fiyatlandı: ${tl(m * p)}');
          } else {
            set(() => mesgul = false);
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ikili(
              TextField(
                controller: hesap.miktar,
                onChanged: (_) => set(hesap.miktarDegisti),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Miktar (kesin)'),
              ),
              _birimSecici(birimler, birim, (v) => set(() => birim = v)),
            ),
            const SizedBox(height: 12),
            ..._fiyatAlanlari(hesap, birim, set, odak: s.fiyat == null),
            _butonlar(ctx,
                yazi: 'Fiyatı Kaydet',
                renk: ButonRenk.birincil,
                mesgul: mesgul,
                onTap: kaydet),
          ],
        );
      });
    },
  );
}

// ---------------------------------------------------------------- Teslim

Future<void> teslimEt(BuildContext context, Durum d, Siparis s) {
  return altSayfa(
    context,
    baslik: 'Teslim · Sipariş #${s.no}',
    aciklama:
        '${s.musteri} — ${sayi(s.miktar)} ${s.birim} ${s.urun}'
        '${s.fiyat != null ? ' · ${tl(s.toplam)}' : ''}',
    builder: (ctx) {
      final not = TextEditingController();
      final tutar = TextEditingController();
      var yontem = yontemler.first;
      var mesgul = false;
      return StatefulBuilder(builder: (ctx, set) {
        Future<void> kaydet() async {
          final ham = tutar.text.trim();
          final t = ham.isEmpty ? 0.0 : sayiOku(ham);
          if (t == null || t < 0) {
            bildir(ctx, 'Tutar geçersiz.');
            return;
          }
          set(() => mesgul = true);
          final simdi = Veri.simdi;
          final ok = await _calistir(
              ctx,
              () => Veri.siparisGuncelle(d.fid, s.id, {
                    'teslim': true,
                    'teslimEden': d.uid,
                    'teslimTarih': simdi,
                    'teslimNot': not.text.trim(),
                    'tahsilatlar': [
                      ...s.tahsilatlar.map((e) => e.toMap()),
                      if (t > 0)
                        Tahsilat(tutar: t, yontem: yontem, tarih: simdi, by: d.uid)
                            .toMap(),
                    ],
                  }, islem: {
                    'tur': 'teslim',
                    'tutar': t,
                    'yontem': yontem,
                  }));
          if (!ctx.mounted) return;
          if (ok) {
            Navigator.pop(ctx);
            bildir(context, '#${s.no} teslim edildi');
          } else {
            set(() => mesgul = false);
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: not,
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: 'Teslim notu (isteğe bağlı)',
                  hintText: 'Teslim alan, irsaliye no vb.'),
            ),
            const SizedBox(height: 12),
            _ikili(
              TextField(
                controller: tutar,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Teslimde alınan ₺', hintText: 'Yoksa boş'),
              ),
              DropdownButtonFormField<String>(
                initialValue: yontem,
                isExpanded: true,
                dropdownColor: Colors.white,
                decoration: const InputDecoration(labelText: 'Yöntem'),
                items: [
                  for (final y in yontemler) DropdownMenuItem(value: y, child: Text(y))
                ],
                onChanged: (v) => yontem = v ?? yontem,
              ),
            ),
            const SizedBox(height: 6),
            if (s.kalan > 0)
              Align(
                alignment: Alignment.centerLeft,
                child: ActionChip(
                  label: Text('Tamamı alındı (${tl(s.kalan)})'),
                  onPressed: () => set(() => tutar.text = girdi(s.kalan)),
                ),
              ),
            const SizedBox(height: 14),
            _butonlar(ctx,
                yazi: '✓ Teslim Edildi',
                renk: ButonRenk.birincil,
                mesgul: mesgul,
                onTap: kaydet),
          ],
        );
      });
    },
  );
}

// ---------------------------------------------------------------- Tahsilat

Future<void> tahsilEt(BuildContext context, Durum d, Siparis s) {
  final kalan = s.kalan;
  return altSayfa(
    context,
    baslik: 'Tahsilat · Sipariş #${s.no}',
    aciklama: '${s.musteri} — Toplam ${tl(s.toplam)} · Alınan ${tl(s.odenen)}',
    builder: (ctx) {
      final tutar = TextEditingController(text: girdi(kalan));
      var yontem = yontemler.first;
      var mesgul = false;
      var fazlaOnay = false;
      return StatefulBuilder(builder: (ctx, set) {
        Future<void> kaydet() async {
          final t = sayiOku(tutar.text);
          if (t == null || t <= 0) {
            bildir(ctx, 'Tutar geçersiz.');
            return;
          }
          if (t > kalan + 0.009 && !fazlaOnay) {
            set(() => fazlaOnay = true);
            bildir(ctx, 'Tutar kalandan fazla. Yine de kaydetmek için tekrar basın.');
            return;
          }
          set(() => mesgul = true);
          final ok = await _calistir(
              ctx,
              () => Veri.siparisGuncelle(d.fid, s.id, {
                    'tahsilatlar': [
                      ...s.tahsilatlar.map((e) => e.toMap()),
                      Tahsilat(
                              tutar: t,
                              yontem: yontem,
                              tarih: Veri.simdi,
                              by: d.uid)
                          .toMap(),
                    ],
                  }, islem: {
                    'tur': 'tahsilat',
                    'tutar': t,
                    'yontem': yontem,
                  }));
          if (!ctx.mounted) return;
          if (ok) {
            Navigator.pop(ctx);
            bildir(
                context,
                t >= kalan
                    ? '#${s.no} tamamen tahsil edildi'
                    : '${tl(t)} tahsil edildi');
          } else {
            set(() => mesgul = false);
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ToplamKutusu(etiket: 'Kalan alacak', deger: tl(kalan)),
            _ikili(
              TextField(
                controller: tutar,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Tahsil edilen ₺'),
              ),
              DropdownButtonFormField<String>(
                initialValue: yontem,
                isExpanded: true,
                dropdownColor: Colors.white,
                decoration: const InputDecoration(labelText: 'Yöntem'),
                items: [
                  for (final y in yontemler) DropdownMenuItem(value: y, child: Text(y))
                ],
                onChanged: (v) => yontem = v ?? yontem,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                    label: const Text('Tamamı'),
                    onPressed: () => set(() => tutar.text = girdi(kalan))),
                ActionChip(
                    label: const Text('Yarısı'),
                    onPressed: () => set(() =>
                        tutar.text = girdi((kalan / 2 * 100).round() / 100))),
              ],
            ),
            const SizedBox(height: 14),
            _butonlar(ctx,
                yazi: 'Tahsil Et',
                renk: ButonRenk.birincil,
                mesgul: mesgul,
                onTap: kaydet),
          ],
        );
      });
    },
  );
}

// ---------------------------------------------------------------- Detay

Future<void> detayGoster(BuildContext context, Durum d, Siparis s0) {
  return altSayfa(
    context,
    baslik: 'Sipariş #${s0.no}',
    aciklama: '${s0.musteri} · ${s0.urun}',
    builder: (ctx) => ListenableBuilder(
      listenable: d,
      builder: (ctx, _) {
        final s = d.siparisler.firstWhere((x) => x.id == s0.id,
            orElse: () => s0);
        final silinebilir = !d.saha && (d.yonetici || s.olusturan == d.uid);
        Widget satir(IconData ikon, String yazi, String kim, int t,
                {Widget? sag}) =>
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(ikon, size: 19, color: Renk.ana),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(yazi, style: const TextStyle(fontSize: 14.5, color: Renk.yazi)),
                        Text('${d.isim(kim)} · ${tarihSaat(t)}',
                            style: const TextStyle(color: Renk.soluk, fontSize: 12.5)),
                      ],
                    ),
                  ),
                  if (sag != null) sag,
                ],
              ),
            );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
              decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Renk.cizgi)),
              child: Row(
                children: [
                  const Icon(Icons.person_outline, size: 19, color: Renk.soluk),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Müşteri: ${s.musteri}',
                        style: const TextStyle(
                            color: Renk.yazi, fontWeight: FontWeight.w600)),
                  ),
                  TextButton(
                      onPressed: () => musteriDuzelt(ctx, d, siparis: s),
                      child: const Text('Düzelt')),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
              decoration: BoxDecoration(
                  color: Renk.anaAcik, borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  const Icon(Icons.handshake_outlined, size: 19, color: Renk.anaKoyu),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        s.araci.isEmpty ? 'Aracı: yok (doğrudan satış)' : 'Aracı: ${s.araci}',
                        style: const TextStyle(
                            color: Renk.anaKoyu, fontWeight: FontWeight.w600)),
                  ),
                  TextButton(
                      onPressed: () => araciDegistir(ctx, d, s),
                      child: Text(s.araci.isEmpty ? 'Ekle' : 'Değiştir')),
                ],
              ),
            ),
            if (s.not.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Renk.cizgi)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.notes, size: 18, color: Renk.soluk),
                    const SizedBox(width: 8),
                    Expanded(child: Text(s.not)),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                    child: Cip(
                        ust: 'Toplam',
                        deger: s.fiyat == null ? '—' : tl(s.toplam))),
                const SizedBox(width: 6),
                Expanded(child: Cip(ust: 'Alınan', deger: tl(s.odenen), durum: true)),
                const SizedBox(width: 6),
                Expanded(
                    child: Cip(
                        ust: 'Kalan',
                        deger: tl(s.kalan),
                        durum: s.kalan > 0 ? false : null)),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.only(left: 12),
              decoration: const BoxDecoration(
                  border: Border(left: BorderSide(color: Renk.cizgi, width: 2))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  satir(Icons.add_shopping_cart, 'Sipariş girildi — ${sayi(s.miktar)} ${s.birim}',
                      s.olusturan, s.olusturma),
                  if (s.fiyat != null)
                    satir(Icons.sell_outlined, 'Fiyat: ${tl(s.fiyat!)} / ${s.birim} = ${tl(s.toplam)}',
                        s.fiyatlayan, s.fiyatTarih),
                  if (s.teslim)
                    satir(
                        Icons.local_shipping_outlined,
                        'Teslim edildi${s.teslimNot.isEmpty ? '' : ' — ${s.teslimNot}'}',
                        s.teslimEden,
                        s.teslimTarih),
                  for (var i = 0; i < s.tahsilatlar.length; i++)
                    satir(
                      Icons.payments_outlined,
                      '${tl(s.tahsilatlar[i].tutar)} tahsil edildi (${s.tahsilatlar[i].yontem})',
                      s.tahsilatlar[i].by,
                      s.tahsilatlar[i].tarih,
                      sag: (d.yonetici || s.tahsilatlar[i].by == d.uid)
                          ? SizedBox(
                              height: 32,
                              child: PopupMenuButton<String>(
                                tooltip: 'Tahsilatı düzelt veya sil',
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.more_vert,
                                    size: 20, color: Renk.soluk),
                                onSelected: (v) => v == 'sil'
                                    ? _tahsilatSil(ctx, d, s, i)
                                    : _tahsilatDuzelt(ctx, d, s, i),
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'duzelt',
                                    child: ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      leading: Icon(Icons.edit_outlined),
                                      title: Text('Tutarı düzelt'),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'sil',
                                    child: ListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      leading: Icon(Icons.delete_outline,
                                          color: Renk.kirmizi),
                                      title: Text('Tahsilatı sil',
                                          style: TextStyle(color: Renk.kirmizi)),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : null,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (s.fiyat != null && !d.saha)
                  _kucuk('Fiyatı düzelt', ButonRenk.ikincil, () {
                    Navigator.pop(ctx);
                    fiyatGir(context, d, s);
                  }),
                if (s.asama == Asama.teslim || (d.saha && !s.teslim))
                  _kucuk('Teslim edildi', ButonRenk.birincil, () {
                    Navigator.pop(ctx);
                    teslimEt(context, d, s);
                  }),
                if (s.fiyat != null && s.kalan > 0)
                  _kucuk('Tahsilat gir', ButonRenk.birincil, () {
                    Navigator.pop(ctx);
                    tahsilEt(context, d, s);
                  }),
                if (s.teslim)
                  _kucuk('Teslimi geri al', ButonRenk.ikincil, () async {
                    final ok = await _calistir(
                        ctx,
                        () => Veri.siparisGuncelle(d.fid, s.id, {
                              'teslim': false,
                              'teslimEden': '',
                              'teslimTarih': 0,
                            }),
                        basari: 'Teslim geri alındı');
                    if (ok && ctx.mounted) Navigator.pop(ctx);
                  }),
                if (silinebilir)
                  _kucuk('Sil', ButonRenk.tehlike, () async {
                    final evet = await showDialog<bool>(
                      context: ctx,
                      builder: (c) => AlertDialog(
                        title: Text('#${s.no} silinsin mi?'),
                        content: const Text('Bu sipariş ve tahsilat kayıtları silinir.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: const Text('Vazgeç')),
                          FilledButton(
                              style: FilledButton.styleFrom(
                                  backgroundColor: Renk.kirmizi),
                              onPressed: () => Navigator.pop(c, true),
                              child: const Text('Sil')),
                        ],
                      ),
                    );
                    if (evet != true || !ctx.mounted) return;
                    final ok = await _calistir(
                        ctx, () => Veri.siparisSil(d.fid, s.id));
                    if (ok && ctx.mounted) {
                      Navigator.pop(ctx);
                      bildir(context, '#${s.no} silindi');
                    }
                  }),
              ],
            ),
            const SizedBox(height: 12),
            Buton(
                yazi: 'Kapat',
                renk: ButonRenk.ikincil,
                onTap: () => Navigator.pop(ctx)),
          ],
        );
      },
    ),
  );
}

/// Yanlış yazılmış müşteri adını düzeltir. [siparis] verilirse o siparişten,
/// verilmezse (Müşteriler ekranı) [eskiAd] ile o müşterinin tüm siparişlerinde.
Future<void> musteriDuzelt(BuildContext ctx, Durum d,
    {Siparis? siparis, String? eskiAd}) {
  final eski = (siparis?.musteri ?? eskiAd ?? '').trim();
  final ayni = d.siparisler
      .where((x) => musteriAnahtari(x.musteri) == musteriAnahtari(eski))
      .toList();
  final digerleri = {for (final x in d.siparisler) x.musteri.trim()}
    ..removeWhere(
        (e) => e.isEmpty || musteriAnahtari(e) == musteriAnahtari(eski));
  return altSayfa(
    ctx,
    baslik: 'Müşteri adını düzelt',
    aciklama: siparis == null
        ? '"$eski" adıyla girilmiş ${ayni.length} sipariş'
        : 'Sipariş #${siparis.no} · şu an: "$eski"',
    builder: (c) {
      final ad = TextEditingController(text: eski);
      final odak = FocusNode();
      var tumu = siparis == null || ayni.length > 1;
      var mesgul = false;
      return StatefulBuilder(builder: (c, set) {
        final yeni = ad.text.trim();
        final birlesir = digerleri
            .where((e) => musteriAnahtari(e) == musteriAnahtari(yeni))
            .firstOrNull;
        Future<void> kaydet() async {
          if (yeni.isEmpty) {
            bildir(c, 'Müşteri adını yazın.');
            return;
          }
          if (yeni == eski) {
            Navigator.pop(c);
            return;
          }
          final idler = siparis != null && !tumu
              ? [siparis.id]
              : ayni.map((x) => x.id).toList();
          set(() => mesgul = true);
          final ok = await _calistir(
              c, () => Veri.alanDegistir(d.fid, idler, 'musteri', yeni),
              basari: idler.length == 1
                  ? 'Müşteri adı düzeltildi'
                  : '${idler.length} siparişte müşteri adı düzeltildi');
          if (!c.mounted) return;
          if (ok) {
            Navigator.pop(c);
          } else {
            set(() => mesgul = false);
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OneriliAlan(
              controller: ad,
              focusNode: odak,
              secenekler: digerleri,
              etiket: 'Doğru müşteri adı',
              buyukHarf: TextCapitalization.words,
              onDegisti: (_) => set(() {}),
              onSecildi: (_) => set(() {}),
            ),
            if (siparis != null && ayni.length > 1) ...[
              const SizedBox(height: 6),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: tumu,
                onChanged: (v) => set(() => tumu = v ?? false),
                title: Text(
                    '"$eski" adlı ${ayni.length} siparişin hepsinde düzelt',
                    style: const TextStyle(fontSize: 14.5)),
              ),
            ],
            if (birlesir != null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Renk.amberAcik,
                    borderRadius: BorderRadius.circular(10)),
                child: Text(
                    '"$birlesir" adında zaten bir müşteri var. Kaydederseniz bu siparişler onunla birleşir.',
                    style: const TextStyle(color: Renk.amber, fontSize: 13.5)),
              ),
            const SizedBox(height: 16),
            _butonlar(c,
                yazi: 'Kaydet',
                renk: ButonRenk.birincil,
                mesgul: mesgul,
                onTap: kaydet),
          ],
        );
      });
    },
  );
}

/// Daha önce kullanılmış aracı adları (öneri listesi için).
Set<String> araciListesi(Durum d) =>
    {for (final s in d.siparisler) s.araci.trim()}..removeWhere((e) => e.isEmpty);

/// Siparişin aracısını ekler / değiştirir / kaldırır.
Future<void> araciDegistir(BuildContext ctx, Durum d, Siparis s) {
  final aracilar = araciListesi(d);
  return altSayfa(
    ctx,
    baslik: 'Aracı · Sipariş #${s.no}',
    aciklama: '${s.musteri} · ${s.urun} ${sayi(s.miktar)} ${s.birim}',
    builder: (c) {
      final araci = TextEditingController(text: s.araci);
      final odak = FocusNode();
      var mesgul = false;
      return StatefulBuilder(builder: (c, set) {
        Future<void> kaydet(String yeni) async {
          set(() => mesgul = true);
          final ok = await _calistir(
              c,
              () => Veri.siparisGuncelle(d.fid, s.id, {'araci': yeni.trim()},
                  islem: {'tur': 'duzeltme'}),
              basari: yeni.trim().isEmpty
                  ? 'Aracı kaldırıldı'
                  : 'Aracı kaydedildi: ${yeni.trim()}');
          if (!c.mounted) return;
          if (ok) {
            Navigator.pop(c);
          } else {
            set(() => mesgul = false);
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OneriliAlan(
              controller: araci,
              focusNode: odak,
              secenekler: aracilar,
              etiket: 'Aracı adı',
              ipucu: 'Kimin aracılığıyla satıldı?',
              buyukHarf: TextCapitalization.words,
            ),
            if (aracilar.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in aracilar.take(12))
                    ActionChip(
                        label: Text(a),
                        onPressed: () => set(() => araci.text = a)),
                ],
              ),
            ],
            const SizedBox(height: 16),
            _butonlar(c,
                yazi: 'Kaydet',
                renk: ButonRenk.birincil,
                mesgul: mesgul,
                onTap: () => kaydet(araci.text)),
            if (s.araci.isNotEmpty) ...[
              const SizedBox(height: 6),
              TextButton(
                  onPressed: mesgul ? null : () => kaydet(''),
                  child: const Text('Aracıyı kaldır (doğrudan satış)')),
            ],
          ],
        );
      });
    },
  );
}

/// Yanlış girilen tahsilatı siler; sipariş yeniden "tahsilat bekliyor"a düşer.
Future<void> _tahsilatSil(BuildContext ctx, Durum d, Siparis s, int i) async {
  final t = s.tahsilatlar[i];
  final evet = await showDialog<bool>(
    context: ctx,
    builder: (c) => AlertDialog(
      title: const Text('Tahsilat silinsin mi?'),
      content: Text(
          '${tl(t.tutar)} (${t.yontem}) · ${tarihSaat(t.tarih)}\n\n'
          'Bu tahsilat kaydı silinir, tutar yeniden alacak olarak görünür.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Vazgeç')),
        FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Renk.kirmizi),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Sil')),
      ],
    ),
  );
  if (evet != true || !ctx.mounted) return;
  final liste = [...s.tahsilatlar]..removeAt(i);
  await _calistir(
      ctx,
      () => Veri.siparisGuncelle(
          d.fid, s.id, {'tahsilatlar': liste.map((e) => e.toMap()).toList()},
          islem: {'tur': 'duzeltme'}),
      basari: '${tl(t.tutar)} tutarındaki tahsilat silindi');
}

/// Tahsilatın tutarını ya da ödeme yöntemini düzeltir.
Future<void> _tahsilatDuzelt(BuildContext ctx, Durum d, Siparis s, int i) {
  final eski = s.tahsilatlar[i];
  return altSayfa(
    ctx,
    baslik: 'Tahsilatı düzelt · Sipariş #${s.no}',
    aciklama: '${s.musteri} · ${tarihSaat(eski.tarih)} tarihli kayıt',
    builder: (c) {
      final tutar = TextEditingController(text: girdi(eski.tutar));
      var yontem = yontemler.contains(eski.yontem) ? eski.yontem : yontemler.first;
      var mesgul = false;
      return StatefulBuilder(builder: (c, set) {
        Future<void> kaydet() async {
          final t = sayiOku(tutar.text);
          if (t == null || t <= 0) {
            bildir(c, 'Tutar geçersiz. Kaydı kaldırmak için "Tahsilatı sil"i kullanın.');
            return;
          }
          set(() => mesgul = true);
          final liste = [...s.tahsilatlar];
          liste[i] = Tahsilat(tutar: t, yontem: yontem, tarih: eski.tarih, by: eski.by);
          final ok = await _calistir(
              c,
              () => Veri.siparisGuncelle(d.fid, s.id,
                  {'tahsilatlar': liste.map((e) => e.toMap()).toList()},
                  islem: {'tur': 'duzeltme'}),
              basari: 'Tahsilat düzeltildi: ${tl(t)}');
          if (!c.mounted) return;
          if (ok) {
            Navigator.pop(c);
          } else {
            set(() => mesgul = false);
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ikili(
              TextField(
                controller: tutar,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Doğru tutar ₺'),
              ),
              DropdownButtonFormField<String>(
                initialValue: yontem,
                isExpanded: true,
                dropdownColor: Colors.white,
                decoration: const InputDecoration(labelText: 'Yöntem'),
                items: [
                  for (final y in yontemler) DropdownMenuItem(value: y, child: Text(y))
                ],
                onChanged: (v) => yontem = v ?? yontem,
              ),
            ),
            const SizedBox(height: 16),
            _butonlar(c,
                yazi: 'Kaydet',
                renk: ButonRenk.birincil,
                mesgul: mesgul,
                onTap: kaydet),
          ],
        );
      });
    },
  );
}

Widget _kucuk(String yazi, ButonRenk r, VoidCallback onTap) => SizedBox(
    width: 160,
    child: Buton(yazi: yazi, renk: r, yukseklik: 42, onTap: onTap));

// ---------------------------------------------------------------- Ürün düzenle


Future<void> urunDuzenle(BuildContext context, Durum d, int index) {
  final f = d.firma!;
  final eski = index >= 0 ? f.urunler[index] : null;
  return altSayfa(
    context,
    baslik: eski == null ? 'Yeni ürün' : 'Ürünü düzenle',
    aciklama: 'Sipariş girerken bu ürün hazır kutucuk olarak çıkar.',
    builder: (ctx) {
      final ad = TextEditingController(text: eski?.ad ?? '');
      final fiyat = TextEditingController(text: girdi(eski?.fiyat));
      final em = eski?.em ?? '📦';
      var birim = eski?.birim ?? f.birimListesi.first;
      var mesgul = false;
      return StatefulBuilder(builder: (ctx, set) {
        Future<void> kaydet() async {
          final a = ad.text.trim();
          if (a.isEmpty) {
            bildir(ctx, 'Ürün adını yazın.');
            return;
          }
          final ham = fiyat.text.trim();
          final p = ham.isEmpty ? null : sayiOku(ham);
          if (ham.isNotEmpty && (p == null || p < 0)) {
            bildir(ctx, 'Fiyat geçersiz.');
            return;
          }
          set(() => mesgul = true);
          final yeni = Urun(ad: a, birim: birim, fiyat: p, em: em);
          final liste = [...f.urunler];
          if (index >= 0) {
            liste[index] = yeni;
          } else {
            liste.add(yeni);
          }
          final ok = await _calistir(
              ctx,
              () => Veri.firmaGuncelle(
                  d.fid, {'urunler': liste.map((u) => u.toMap()).toList()}));
          if (!ctx.mounted) return;
          if (ok) {
            Navigator.pop(ctx);
          } else {
            set(() => mesgul = false);
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: ad,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Ürün adı'),
            ),
            const SizedBox(height: 12),
            _ikili(
              TextField(
                controller: fiyat,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Varsayılan fiyat ₺', hintText: 'İsteğe bağlı'),
              ),
              _birimSecici(f.birimListesi, birim, (v) => birim = v),
            ),
            const SizedBox(height: 16),
            _butonlar(ctx,
                yazi: 'Kaydet',
                renk: ButonRenk.birincil,
                mesgul: mesgul,
                onTap: kaydet),
          ],
        );
      });
    },
  );
}
