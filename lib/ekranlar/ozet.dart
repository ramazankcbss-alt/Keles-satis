import 'package:flutter/material.dart';

import '../bicim.dart';
import '../servis/veri.dart';
import '../tema.dart';
import 'birlestir.dart';
import 'formlar.dart';
import 'listeler.dart';

class _Grup {
  int adet = 0;
  double toplam = 0, alinan = 0, kalan = 0;
  final Map<String, double> miktar = {};

  /// Aynı kişinin farklı yazılışları ve kaç kez kullanıldıkları.
  final Map<String, int> yazilis = {};

  /// En çok kullanılan yazılış (ekranda gösterilen ad).
  String get ad => yazilis.isEmpty
      ? '—'
      : (yazilis.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
          .first
          .key;
}

/// Müşteri bakiyeleri ya da ürün bazında satış özeti.
class OzetEkrani extends StatelessWidget {
  const OzetEkrani({super.key, required this.durum, required this.musteri});
  final Durum durum;
  final bool musteri;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(musteri ? 'Müşteriler' : 'Ürünler'),
        actions: [
          if (musteri && durum.yonetici)
            ListenableBuilder(
              listenable: durum,
              builder: (context, _) {
                final n = birlestirmeOneriSayisi(durum);
                return IconButton(
                  tooltip: 'Müşteri birleştir',
                  icon: Badge(
                    isLabelVisible: n > 0,
                    label: Text('$n'),
                    backgroundColor: Renk.kirmizi,
                    child: const Icon(Icons.merge_type),
                  ),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => MusteriBirlestirEkrani(durum: durum))),
                );
              },
            ),
        ],
      ),
      body: ListenableBuilder(
        listenable: durum,
        builder: (context, _) {
          final g = <String, _Grup>{};
          for (final s in durum.siparisler) {
            final ham = (musteri ? s.musteri : s.urun).trim();
            final k = ham.isEmpty
                ? '—'
                : (musteri ? musteriAnahtari(ham) : ham);
            final x = g.putIfAbsent(k, _Grup.new);
            if (ham.isNotEmpty) x.yazilis[ham] = (x.yazilis[ham] ?? 0) + 1;
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
                Builder(builder: (context) {
                  final n = birlestirmeOneriSayisi(durum);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: n > 0 ? Renk.amberAcik : Renk.anaAcik,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: n > 0 ? const Color(0xFFFCD34D) : Renk.cizgi,
                          width: 1.5),
                    ),
                    child: ListTile(
                      leading: Text(n > 0 ? '🤔' : '🔗',
                          style: const TextStyle(fontSize: 24)),
                      title: Text(
                          n > 0
                              ? '$n grup benzer isim bulundu'
                              : 'Müşteri birleştir',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(n > 0
                          ? 'Aynı kişiyse birleştirin, değilse "Aynı değiller" deyin.'
                          : 'Aynı kişiyi farklı adlarla girdiyseniz tek müşteride toplayın.'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  MusteriBirlestirEkrani(durum: durum))),
                    ),
                  );
                }),
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
                                    baslik: e.value.ad,
                                    filtre: (s) => musteri
                                        ? musteriAnahtari(s.musteri) == e.key
                                        : s.urun.trim() == e.key,
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
                                          Text(e.value.ad,
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
                                            eskiAd: e.value.ad),
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
