import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../bicim.dart';
import '../modeller.dart';
import '../servis/veri.dart';
import '../tema.dart';
import 'listeler.dart';

const _renkler = [
  Color(0xFF0E9E9B),
  Color(0xFF2563EB),
  Color(0xFFF59E0B),
  Color(0xFF8B5CF6),
  Color(0xFFEF4444),
  Color(0xFF10B981),
  Color(0xFFEC4899),
];
const _digerRengi = Color(0xFF94A3B8);

final _yuzde = NumberFormat('#0.#', 'tr_TR');
String yuzdeYaz(double oran) => '%${_yuzde.format(oran * 100)}';

class _Grup {
  _Grup(this.ad);
  final String ad;
  int adet = 0;
  double tutar = 0;
  double miktar = 0; // ortak birime çevrilmiş
  double deger = 0; // seçili ölçüye göre
  double odenen = 0, kalan = 0;
  final List<Siparis> siparisler = [];
}

enum _Donem { tumu, buAy, son3Ay, buYil }

const _donemAdlari = {
  _Donem.tumu: 'Tüm zamanlar',
  _Donem.buAy: 'Bu ay',
  _Donem.son3Ay: 'Son 3 ay',
  _Donem.buYil: 'Bu yıl',
};

/// Satışların hangi aracılar üzerinden yapıldığını yüzdesel gösterir.
class AraciPaneli extends StatefulWidget {
  const AraciPaneli({super.key, required this.durum, this.baslikGoster = true});
  final Durum durum;
  final bool baslikGoster;

  @override
  State<AraciPaneli> createState() => _AraciPaneliState();
}

class _AraciPaneliState extends State<AraciPaneli> {
  String _urun = ''; // boş: tüm ürünler
  _Donem _donem = _Donem.tumu;
  bool _miktarla = true;

  int _baslangic(_Donem d) {
    final n = DateTime.now();
    return switch (d) {
      _Donem.tumu => 0,
      _Donem.buAy => DateTime(n.year, n.month).millisecondsSinceEpoch,
      _Donem.son3Ay => DateTime(n.year, n.month - 2).millisecondsSinceEpoch,
      _Donem.buYil => DateTime(n.year).millisecondsSinceEpoch,
    };
  }

  /// Miktarları toplanabilir tek birime çevirir (kg/ton → kg).
  /// Toplanamıyorsa (ör. kg ile çuval karışık) null döner.
  static (String, double Function(Siparis))? _ortakBirim(List<Siparis> l) {
    final birimler = {for (final s in l) s.birim.trim().toLowerCase()};
    if (birimler.isEmpty) return null;
    if (birimler.every((b) => b == 'kg' || b == 'ton')) {
      return (
        'kg',
        (Siparis s) =>
            s.birim.trim().toLowerCase() == 'ton' ? s.miktar * 1000 : s.miktar
      );
    }
    if (birimler.length == 1) return (l.first.birim, (Siparis s) => s.miktar);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.durum,
      builder: (context, _) {
        final d = widget.durum;
        final urunler = <String, String>{};
        for (final s in d.siparisler) {
          final k = s.urun.trim().toLowerCase();
          if (k.isNotEmpty) urunler.putIfAbsent(k, () => s.urun.trim());
        }
        if (_urun.isNotEmpty && !urunler.containsKey(_urun)) _urun = '';
        final bas = _baslangic(_donem);
        final liste = d.siparisler
            .where((s) => s.olusturma >= bas)
            .where((s) => _urun.isEmpty || s.urun.trim().toLowerCase() == _urun)
            .toList();

        final ortak = _ortakBirim(liste);
        final miktarla = _miktarla && ortak != null;

        final gruplar = <String, _Grup>{};
        for (final s in liste) {
          final k = s.araciAdi.toLowerCase();
          final g = gruplar.putIfAbsent(k, () => _Grup(s.araciAdi));
          g.adet++;
          g.tutar += s.toplam;
          g.odenen += s.odenen;
          g.kalan += s.kalan;
          g.siparisler.add(s);
          if (ortak != null) g.miktar += ortak.$2(s);
        }
        for (final g in gruplar.values) {
          g.deger = miktarla ? g.miktar : g.tutar;
        }
        final satirlar = gruplar.values.toList()
          ..sort((a, b) => b.deger.compareTo(a.deger));
        final toplamDeger = satirlar.fold(0.0, (a, g) => a + g.deger);
        final toplamTutar = satirlar.fold(0.0, (a, g) => a + g.tutar);
        final toplamMiktar = satirlar.fold(0.0, (a, g) => a + g.miktar);
        final toplamKalan = satirlar.fold(0.0, (a, g) => a + g.kalan);

        Color renk(int i) => i < _renkler.length ? _renkler[i] : _digerRengi;

        // Grafikte en fazla 7 dilim; gerisi "Diğer".
        final dilimler = <(String, double, Color)>[];
        for (var i = 0; i < satirlar.length; i++) {
          if (i < _renkler.length) {
            dilimler.add((satirlar[i].ad, satirlar[i].deger, renk(i)));
          } else {
            final kalan = satirlar.skip(i).fold(0.0, (a, g) => a + g.deger);
            dilimler.add(('Diğer (${satirlar.length - i})', kalan, _digerRengi));
            break;
          }
        }

        String olcuYaz(double v) =>
            miktarla ? '${sayi(v.round())} ${ortak?.$1 ?? ''}' : tl0(v);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            if (widget.baslikGoster)
              const Padding(
                padding: EdgeInsets.fromLTRB(2, 0, 2, 4),
                child: Text('Aracı bazında satışlar',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700, color: Renk.yazi)),
              ),
            if (widget.baslikGoster)
              const Padding(
                padding: EdgeInsets.fromLTRB(2, 0, 2, 12),
                child: Text('Satışların hangi aracı üzerinden yapıldığı ve payları',
                    style: TextStyle(fontSize: 13.5, color: Renk.soluk)),
              ),

            // Filtreler
            _CipSatiri(
              secenekler: [
                ('', 'Tüm ürünler'),
                for (final e in urunler.entries) (e.key, e.value),
              ],
              secili: _urun,
              onSec: (v) => setState(() => _urun = v),
            ),
            const SizedBox(height: 8),
            _CipSatiri(
              secenekler: [
                for (final e in _donemAdlari.entries) (e.key.name, e.value),
              ],
              secili: _donem.name,
              onSec: (v) => setState(() => _donem = _Donem.values.byName(v)),
            ),
            const SizedBox(height: 14),

            if (!d.yuklendi)
              const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(child: CircularProgressIndicator()))
            else if (liste.isEmpty)
              const Panel(
                child: BosDurum(
                    ikon: Icons.handshake_outlined,
                    yazi: 'Bu seçimde satış yok.'),
              )
            else ...[
              // Özet kartları
              Row(
                children: [
                  Expanded(
                    child: _Kpi(
                        etiket: ortak == null ? 'Sipariş' : 'Toplam miktar',
                        deger: ortak == null
                            ? sayi(liste.length)
                            : '${sayi(toplamMiktar.round())} ${ortak.$1}'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: _Kpi(etiket: 'Toplam tutar', deger: tl0(toplamTutar))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _Kpi(etiket: 'Toplam alacak', deger: tl0(toplamKalan))),
                ],
              ),
              const SizedBox(height: 12),

              // Halka grafik
              Panel(
                baslik: 'Pay dağılımı',
                eylem: ortak == null
                    ? null
                    : SegmentedButton<bool>(
                        showSelectedIcon: false,
                        style: const ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                        segments: [
                          ButtonSegment(value: true, label: Text(ortak.$1)),
                          const ButtonSegment(value: false, label: Text('₺')),
                        ],
                        selected: {miktarla},
                        onSelectionChanged: (v) =>
                            setState(() => _miktarla = v.first),
                      ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (ortak == null)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: Text(
                          'Farklı birimler (kg, çuval…) karışık olduğu için paylar tutara (₺) göre hesaplandı. Tek ürün seçerek miktara göre görebilirsiniz.',
                          style: TextStyle(fontSize: 12.5, color: Renk.soluk),
                        ),
                      ),
                    Center(
                      child: SizedBox(
                        width: 190,
                        height: 190,
                        child: CustomPaint(
                          painter: _Halka(
                            [for (final x in dilimler) (x.$2, x.$3)],
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(miktarla ? 'Toplam miktar' : 'Toplam tutar',
                                    style: const TextStyle(
                                        fontSize: 12, color: Renk.soluk)),
                                const SizedBox(height: 2),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 120),
                                  child: FittedBox(
                                    child: Text(olcuYaz(toplamDeger),
                                        style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: Renk.yazi)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 14,
                      runSpacing: 8,
                      children: [
                        for (final x in dilimler)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                    color: x.$3,
                                    borderRadius: BorderRadius.circular(3)),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                  '${x.$1} ${toplamDeger > 0 ? yuzdeYaz(x.$2 / toplamDeger) : ''}',
                                  style: const TextStyle(
                                      fontSize: 13, color: Renk.yazi)),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Aracı kartları: satış, tahsil, alacak ve ürün ürün alacak
              for (var i = 0; i < satirlar.length; i++)
                _AraciKarti(
                  g: satirlar[i],
                  renk: renk(i),
                  oran: toplamDeger > 0 ? satirlar[i].deger / toplamDeger : 0,
                  miktar: ortak == null
                      ? '${satirlar[i].adet} sipariş'
                      : '${sayi(satirlar[i].miktar.round())} ${ortak.$1}',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SiparisListesiEkrani(
                        durum: d,
                        baslik: satirlar[i].ad,
                        filtre: (s) =>
                            s.araciAdi.toLowerCase() ==
                                satirlar[i].ad.toLowerCase() &&
                            s.olusturma >= bas &&
                            (_urun.isEmpty ||
                                s.urun.trim().toLowerCase() == _urun),
                        asamaSecimi: true,
                        bosIkon: Icons.list_alt,
                        bosYazi: 'Kayıt yok.',
                      ),
                    ),
                  ),
                ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Pay üstteki seçime (miktar ya da ₺) göre hesaplanır. Alacak, o aracının satışlarında henüz tahsil edilmemiş tutardır. Aracının adına dokunursanız siparişleri açılır. Aracısı girilmemiş siparişler "Doğrudan satış" olarak sayılır; aracıyı sipariş detayından ekleyebilirsiniz.',
                  style: TextStyle(fontSize: 12.5, color: Renk.soluk),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Bir aracının satışı, tahsil edileni, alacağı ve ürün ürün dökümü.
class _AraciKarti extends StatelessWidget {
  const _AraciKarti({
    required this.g,
    required this.renk,
    required this.oran,
    required this.miktar,
    required this.onTap,
  });
  final _Grup g;
  final Color renk;
  final double oran;
  final String miktar;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Widget kutu(String etiket, String deger, Color r, Color z) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
                color: z, borderRadius: BorderRadius.circular(10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(etiket,
                    style: TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w600, color: r)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(deger,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Renk.yazi)),
                ),
              ],
            ),
          ),
        );
    return Panel(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                        color: renk, borderRadius: BorderRadius.circular(4)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(g.ad,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Renk.yazi)),
                        Text('$miktar · ${g.adet} sipariş',
                            style: const TextStyle(
                                fontSize: 12.5, color: Renk.soluk)),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: Renk.anaAcik,
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(yuzdeYaz(oran),
                        style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Renk.anaKoyu)),
                  ),
                  const Icon(Icons.chevron_right, color: Renk.soluk),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: oran.clamp(0.0, 1.0),
              minHeight: 6,
              color: renk,
              backgroundColor: const Color(0xFFE8EEF1),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              kutu('Satış', tl0(g.tutar), Renk.anaKoyu, Renk.anaAcik),
              const SizedBox(width: 6),
              kutu('Tahsil edilen', tl0(g.odenen), Renk.yesil, Renk.yesilAcik),
              const SizedBox(width: 6),
              kutu('Alacak', tl0(g.kalan), Renk.kirmizi, Renk.kirmiziAcik),
            ],
          ),
          const SizedBox(height: 6),
          UrunAlacakListesi(urunler: urunOzetleri(g.siparisler)),
        ],
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.etiket, required this.deger});
  final String etiket;
  final String deger;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: Renk.kart,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Renk.cizgi),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(etiket,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Renk.soluk)),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(deger,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700, color: Renk.yazi)),
            ),
          ],
        ),
      );
}

class _CipSatiri extends StatelessWidget {
  const _CipSatiri(
      {required this.secenekler, required this.secili, required this.onSec});
  final List<(String, String)> secenekler;
  final String secili;
  final ValueChanged<String> onSec;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 38,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final (k, ad) in secenekler)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(ad),
                  selected: secili == k,
                  labelStyle: TextStyle(
                      color: secili == k ? Renk.anaKoyu : Renk.yazi,
                      fontWeight: secili == k ? FontWeight.w600 : FontWeight.w500),
                  side: BorderSide(color: secili == k ? Renk.ana : Renk.cizgi),
                  onSelected: (_) => onSec(k),
                ),
              ),
          ],
        ),
      );
}

/// Halka (donut) grafik.
class _Halka extends CustomPainter {
  _Halka(this.dilimler);
  final List<(double, Color)> dilimler;

  @override
  void paint(Canvas canvas, Size size) {
    const kalinlik = 28.0;
    final r = min(size.width, size.height) / 2 - kalinlik / 2;
    final merkez = size.center(Offset.zero);
    final alan = Rect.fromCircle(center: merkez, radius: r);
    final toplam = dilimler.fold(0.0, (a, d) => a + d.$1);
    final kalem = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = kalinlik;
    if (toplam <= 0) {
      canvas.drawArc(alan, 0, 2 * pi, false, kalem..color = const Color(0xFFE8EEF1));
      return;
    }
    final dolu = dilimler.where((d) => d.$1 > 0).length;
    final bosluk = dolu > 1 ? 0.025 : 0.0;
    var aci = -pi / 2;
    for (final (deger, renk) in dilimler) {
      if (deger <= 0) continue;
      final dilim = deger / toplam * 2 * pi;
      canvas.drawArc(alan, aci + bosluk / 2, max(0, dilim - bosluk), false,
          kalem..color = renk);
      aci += dilim;
    }
  }

  @override
  bool shouldRepaint(_Halka eski) => true;
}
