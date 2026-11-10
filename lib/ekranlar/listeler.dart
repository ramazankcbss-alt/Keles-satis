import 'package:flutter/material.dart';

import '../bicim.dart';
import '../modeller.dart';
import '../servis/veri.dart';
import '../tema.dart';
import 'formlar.dart';

/// Her aşamanın yazı ve zemin rengi.
(Color, Color) asamaRenkleri(Asama a) => switch (a) {
      Asama.fiyat => (Renk.amber, Renk.amberAcik),
      Asama.teslim => (Renk.mavi, Renk.maviAcik),
      Asama.tahsilat => (Renk.turuncu, Renk.turuncuAcik),
      Asama.tamam => (Renk.yesil, Renk.yesilAcik),
    };

String asamaAdi(Asama a) => switch (a) {
      Asama.fiyat => 'Fiyat bekliyor',
      Asama.teslim => 'Teslim bekliyor',
      Asama.tahsilat => 'Tahsilat bekliyor',
      Asama.tamam => 'Tamamlandı',
    };

IconData asamaIkonu(Asama a) => switch (a) {
      Asama.fiyat => Icons.sell_outlined,
      Asama.teslim => Icons.local_shipping_outlined,
      Asama.tahsilat => Icons.payments_outlined,
      Asama.tamam => Icons.check_circle_outline,
    };

class AsamaEtiketi extends StatelessWidget {
  const AsamaEtiketi({super.key, required this.asama});
  final Asama asama;

  @override
  Widget build(BuildContext context) {
    final (r, z) = asamaRenkleri(asama);
    return DurumEtiketi(yazi: asamaAdi(asama), renk: r, zemin: z);
  }
}

/// Sipariş kartı: müşteri, ürün, tutarlar ve sıradaki işlem.
class SiparisKarti extends StatelessWidget {
  const SiparisKarti({super.key, required this.durum, required this.s});
  final Durum durum;
  final Siparis s;

  @override
  Widget build(BuildContext context) {
    final a = s.asama;
    final fiyatli = s.fiyat != null;

    final Widget? eylem = durum.saha
        ? (!s.teslim
            ? Buton(
                yazi: 'Teslim Edildi',
                ikon: Icons.check,
                yukseklik: 40,
                onTap: () => teslimEt(context, durum, s))
            : (s.fiyat != null && s.kalan > 0)
                ? Buton(
                    yazi: 'Tahsilat Gir',
                    ikon: Icons.payments_outlined,
                    yukseklik: 40,
                    onTap: () => tahsilEt(context, durum, s))
                : null)
        : switch (a) {
      Asama.fiyat => Buton(
          yazi: 'Fiyat Gir',
          ikon: Icons.sell_outlined,
          yukseklik: 40,
          onTap: () => fiyatGir(context, durum, s)),
      Asama.teslim => Buton(
          yazi: 'Teslim Edildi',
          ikon: Icons.check,
          yukseklik: 40,
          onTap: () => teslimEt(context, durum, s)),
      Asama.tahsilat => Buton(
          yazi: 'Tahsilat Gir',
          ikon: Icons.payments_outlined,
          yukseklik: 40,
          onTap: () => tahsilEt(context, durum, s)),
      Asama.tamam => null,
    };
    final sahaci = durum.firma?.saha.contains(s.olusturan) ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Renk.kart,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Renk.cizgi),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => detayGoster(context, durum, s),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text('#${s.no}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Renk.soluk)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(s.musteri,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Renk.yazi)),
                    ),
                    const SizedBox(width: 8),
                    AsamaEtiketi(asama: a),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                    '${s.urun} · ${sayi(s.miktar)} ${s.birim}'
                    '${s.araci.isEmpty ? '' : ' · Aracı: ${s.araci}'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, color: Renk.soluk)),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1),
                ),
                Row(
                  children: [
                    Expanded(
                        child: Cip(
                            ust: 'Birim fiyat',
                            deger: fiyatli ? tl(s.fiyat!) : '—')),
                    Expanded(
                        child: Cip(
                            ust: 'Toplam', deger: fiyatli ? tl(s.toplam) : '—')),
                    Expanded(
                        child: a == Asama.tamam
                            ? Cip(ust: 'Tahsil', deger: tl(s.odenen), durum: true)
                            : Cip(
                                ust: 'Kalan',
                                deger: fiyatli ? tl(s.kalan) : '—',
                                durum: fiyatli && s.kalan > 0 && s.teslim
                                    ? false
                                    : null)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 15, color: Renk.soluk),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${once(s.sonIslem)} · ${durum.isim(s.olusturan)}'
                        '${sahaci && !durum.saha ? ' (saha)' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, color: Renk.soluk),
                      ),
                    ),
                    if (eylem != null) ...[
                      const SizedBox(width: 8),
                      eylem,
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ana sayfadaki "Son hareketler" için tek satırlık sipariş.
class SiparisSatiri extends StatelessWidget {
  const SiparisSatiri({super.key, required this.durum, required this.s});
  final Durum durum;
  final Siparis s;

  @override
  Widget build(BuildContext context) {
    final (r, z) = asamaRenkleri(s.asama);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration:
            BoxDecoration(color: z, borderRadius: BorderRadius.circular(9)),
        child: Icon(asamaIkonu(s.asama), color: r, size: 20),
      ),
      title: Text(s.musteri,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: Text('${s.urun} · ${sayi(s.miktar)} ${s.birim} · ${once(s.sonIslem)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, color: Renk.soluk)),
      trailing: Text(s.fiyat == null ? '—' : tl0(s.toplam),
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: Renk.yazi)),
      onTap: () => detayGoster(context, durum, s),
    );
  }
}

/// Arama kutulu sipariş listesi (sekme içinde ya da ayrı ekranda).
class SiparisListesi extends StatefulWidget {
  const SiparisListesi({
    super.key,
    required this.durum,
    required this.baslik,
    required this.filtre,
    required this.bosIkon,
    required this.bosYazi,
    this.ozet,
    this.asamaSecimi = false,
    this.baslikGoster = true,
    this.ilkArama = '',
  });

  final Durum durum;
  final String baslik;
  final bool Function(Siparis) filtre;
  final IconData bosIkon;
  final String bosYazi;
  final String Function(List<Siparis>)? ozet;
  final bool asamaSecimi;
  final bool baslikGoster;
  final String ilkArama;

  @override
  State<SiparisListesi> createState() => _SiparisListesiState();
}

class _SiparisListesiState extends State<SiparisListesi> {
  late final _ara = TextEditingController(text: widget.ilkArama);
  Asama? _asama;

  @override
  void dispose() {
    _ara.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.durum,
      builder: (context, _) {
        final d = widget.durum;
        final q = araMetni(_ara.text);
        final l = d.siparisler
            .where(widget.filtre)
            .where((s) => _asama == null || s.asama == _asama)
            .where((s) =>
                q.isEmpty ||
                araMetni('${s.musteri} ${s.urun} ${s.no} ${s.not} ${s.araci}')
                    .contains(q))
            .toList();
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            if (widget.baslikGoster)
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 0, 2, 12),
                child: Text(widget.baslik,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Renk.yazi)),
              ),
            TextField(
              controller: _ara,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Müşteri, ürün veya sipariş no ara',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                suffixIcon: _ara.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(_ara.clear)),
              ),
            ),
            if (widget.asamaSecimi) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final (Asama? k, String ad) in [
                      (null, 'Tümü'),
                      (Asama.fiyat, 'Fiyat'),
                      (Asama.teslim, 'Teslim'),
                      (Asama.tahsilat, 'Tahsilat'),
                      (Asama.tamam, 'Tamamlanan'),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(ad),
                          selected: _asama == k,
                          labelStyle: TextStyle(
                              color: _asama == k ? Renk.anaKoyu : Renk.yazi,
                              fontWeight:
                                  _asama == k ? FontWeight.w600 : FontWeight.w500),
                          side: BorderSide(
                              color: _asama == k ? Renk.ana : Renk.cizgi),
                          onSelected: (_) => setState(() => _asama = k),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (widget.ozet != null && l.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
                child: Text(widget.ozet!(l),
                    style: const TextStyle(color: Renk.soluk, fontSize: 13.5)),
              ),
            if (d.siparisHata != null)
              BosDurum(ikon: Icons.error_outline, yazi: hataYazisi(d.siparisHata!))
            else if (!d.yuklendi)
              const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(child: CircularProgressIndicator()))
            else if (l.isEmpty)
              BosDurum(ikon: widget.bosIkon, yazi: widget.bosYazi)
            else
              for (final s in l) SiparisKarti(durum: d, s: s),
          ],
        );
      },
    );
  }
}

class SiparisListesiEkrani extends StatelessWidget {
  const SiparisListesiEkrani({
    super.key,
    required this.durum,
    required this.baslik,
    required this.filtre,
    required this.bosIkon,
    required this.bosYazi,
    this.ozet,
    this.asamaSecimi = false,
    this.ilkArama = '',
  });

  final Durum durum;
  final String baslik;
  final bool Function(Siparis) filtre;
  final IconData bosIkon;
  final String bosYazi;
  final String Function(List<Siparis>)? ozet;
  final bool asamaSecimi;
  final String ilkArama;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(baslik)),
        body: SiparisListesi(
          durum: durum,
          baslik: baslik,
          filtre: filtre,
          bosIkon: bosIkon,
          bosYazi: bosYazi,
          ozet: ozet,
          asamaSecimi: asamaSecimi,
          baslikGoster: false,
          ilkArama: ilkArama,
        ),
      );
}
