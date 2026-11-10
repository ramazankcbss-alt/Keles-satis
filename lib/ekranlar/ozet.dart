import 'package:flutter/material.dart';

import '../bicim.dart';
import '../modeller.dart';
import '../servis/veri.dart';
import '../tema.dart';
import 'formlar.dart';
import 'listeler.dart';

class _Grup {
  int adet = 0;
  double toplam = 0, alinan = 0, kalan = 0;
  final Map<String, double> miktar = {};
}

/// Müşteri bakiyeleri ya da ürün bazında satış özeti.
class OzetEkrani extends StatelessWidget {
  const OzetEkrani({super.key, required this.durum, required this.musteri});
  final Durum durum;
  final bool musteri;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(musteri ? 'Müşteriler' : 'Ürünler')),
      body: ListenableBuilder(
        listenable: durum,
        builder: (context, _) {
          final g = <String, _Grup>{};
          for (final s in durum.siparisler) {
            final k = (musteri ? s.musteri : s.urun).trim();
            final x = g.putIfAbsent(k.isEmpty ? '—' : k, _Grup.new);
            x.adet++;
            x.toplam += s.toplam;
            x.alinan += s.odenen;
            x.kalan += s.kalan;
            x.miktar[s.birim] = (x.miktar[s.birim] ?? 0) + s.miktar;
          }
          final satirlar = g.entries.toList()
            ..sort((a, b) => musteri
                ? (b.value.kalan.compareTo(a.value.kalan) != 0
                    ? b.value.kalan.compareTo(a.value.kalan)
                    : b.value.toplam.compareTo(a.value.toplam))
                : b.value.toplam.compareTo(a.value.toplam));
          final toplamKalan = g.values.fold(0.0, (a, x) => a + x.kalan);

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 40),
            children: [
              if (musteri && satirlar.isNotEmpty)
                ToplamKutusu(etiket: 'Toplam alacak', deger: tl(toplamKalan)),
              if (musteri && durum.yonetici && satirlar.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
                  child: Text(
                      'Yanlış yazılmış bir müşteri adını düzeltmek için yanındaki kalem simgesine dokunun; o adla girilmiş bütün siparişler düzelir.',
                      style: TextStyle(fontSize: 12.5, color: Renk.soluk)),
                ),
              Panel(
                child: satirlar.isEmpty
                    ? BosDurum(
                        ikon: musteri ? Icons.people_outline : Icons.inventory_2_outlined,
                        yazi: 'Henüz kayıt yok.')
                    : Column(
                        children: [
                          for (final e in satirlar)
                            InkWell(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SiparisListesiEkrani(
                                    durum: durum,
                                    baslik: e.key,
                                    filtre: (s) =>
                                        (musteri ? s.musteri : s.urun).trim() ==
                                        e.key,
                                    asamaSecimi: true,
                                    bosIkon: Icons.list_alt,
                                    bosYazi: 'Kayıt yok.',
                                  ),
                                ),
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                                decoration: const BoxDecoration(
                                    border: Border(
                                        bottom: BorderSide(color: Renk.cizgi))),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 38,
                                      height: 38,
                                      decoration: BoxDecoration(
                                          color: Renk.anaAcik,
                                          borderRadius: BorderRadius.circular(9)),
                                      child: Icon(
                                          musteri
                                              ? Icons.person_outline
                                              : Icons.inventory_2_outlined,
                                          color: Renk.anaKoyu,
                                          size: 20),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(e.key,
                                              style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700)),
                                          Text(
                                            '${e.value.adet} sipariş · ${e.value.miktar.entries.map((m) => '${sayi(m.value)} ${m.key}').join(', ')}',
                                            style: const TextStyle(
                                                color: Renk.soluk, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(tl(e.value.toplam),
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700)),
                                        Text(
                                          e.value.kalan > 0
                                              ? 'Kalan ${tl(e.value.kalan)}'
                                              : 'Borç yok',
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: e.value.kalan > 0
                                                  ? Renk.kirmizi
                                                  : Renk.yesil),
                                        ),
                                      ],
                                    ),
                                    if (musteri && durum.yonetici)
                                      IconButton(
                                        tooltip: 'Adını düzelt',
                                        visualDensity: VisualDensity.compact,
                                        icon: const Icon(Icons.edit_outlined,
                                            size: 20, color: Renk.soluk),
                                        onPressed: () => musteriDuzelt(
                                            context, durum,
                                            eskiAd: e.key),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
