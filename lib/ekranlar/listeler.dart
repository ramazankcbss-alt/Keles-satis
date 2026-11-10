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

/// Küçük bilgi etiketi (satan, aracı, teslim, tahsil).
class _Etiket extends StatelessWidget {
  const _Etiket(this.ikon, this.yazi, this.renk, this.zemin);
  final IconData ikon;
  final String yazi;
  final Color renk;
  final Color zemin;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration:
            BoxDecoration(color: zemin, borderRadius: BorderRadius.circular(6)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ikon, size: 13, color: renk),
            const SizedBox(width: 4),
            Flexible(
              child: Text(yazi,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12, color: renk, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      );
}

/// Bir siparişin satan, aracı, teslim ve tahsilat bilgisi.
class SiparisDetaySatiri extends StatelessWidget {
  const SiparisDetaySatiri({super.key, required this.durum, required this.s});
  final Durum durum;
  final Siparis s;

  @override
  Widget build(BuildContext context) {
    final d = durum;
    const gri = Color(0xFFEFF3F5);
    final etiketler = <Widget>[
      _Etiket(Icons.person_outline, 'Satan: ${d.isim(s.olusturan)}', Renk.yazi, gri),
      _Etiket(Icons.handshake_outlined, 'Aracı: ${s.araciAdi}', Renk.anaKoyu,
          Renk.anaAcik),
      if (s.fiyat == null)
        const _Etiket(Icons.sell_outlined, 'Fiyat bekliyor', Renk.amber,
            Renk.amberAcik)
      else ...[
        s.teslim
            ? _Etiket(
                Icons.local_shipping_outlined,
                s.teslimEden.isEmpty
                    ? 'Teslim edildi'
                    : 'Teslim edildi · ${d.isim(s.teslimEden)}',
                Renk.yesil,
                Renk.yesilAcik)
            : const _Etiket(Icons.local_shipping_outlined, 'Teslim bekliyor',
                Renk.mavi, Renk.maviAcik),
        if (s.kalan <= 0)
          _Etiket(
              Icons.payments_outlined,
              s.tahsilatlar.isEmpty
                  ? 'Tahsil edildi'
                  : 'Tahsil edildi · ${d.isim(s.tahsilatlar.last.by)}',
              Renk.yesil,
              Renk.yesilAcik)
        else if (s.odenen > 0)
          _Etiket(Icons.payments_outlined,
              'Alınan ${tl0(s.odenen)} · kalan ${tl0(s.kalan)}', Renk.turuncu,
              Renk.turuncuAcik)
        else
          const _Etiket(Icons.payments_outlined, 'Tahsil edilmedi', Renk.turuncu,
              Renk.turuncuAcik),
      ],
    ];
    return InkWell(
      onTap: () => detayGoster(context, d, s),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                      '${s.urun} · ${sayi(s.miktar)} ${s.birim} · ${once(s.sonIslem)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13.5, color: Renk.yazi)),
                ),
                const SizedBox(width: 8),
                Text(s.fiyat == null ? '—' : tl0(s.toplam),
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Renk.yazi)),
              ],
            ),
            const SizedBox(height: 5),
            Wrap(spacing: 5, runSpacing: 4, children: etiketler),
          ],
        ),
      ),
    );
  }
}

/// "Son hareketler"de bir müşteri: aynı adla yapılan satışlar tek kartta,
/// müşterinin toplam tutarı ve kalan bakiyesiyle.
class MusteriHareketKarti extends StatelessWidget {
  const MusteriHareketKarti({
    super.key,
    required this.durum,
    required this.siparisler,
    this.gosterilecek = 3,
  });

  final Durum durum;

  /// Müşterinin bütün siparişleri, en yeni başta.
  final List<Siparis> siparisler;
  final int gosterilecek;

  @override
  Widget build(BuildContext context) {
    final ad = siparisler.first.musteri.trim();
    final anahtar = musteriAnahtari(ad);
    final toplam = siparisler.fold(0.0, (a, s) => a + s.toplam);
    final kalan = siparisler.fold(0.0, (a, s) => a + s.kalan);
    final fazla = siparisler.length - gosterilecek;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 2),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                    color: Renk.anaAcik, borderRadius: BorderRadius.circular(9)),
                child: const Icon(Icons.person_outline,
                    color: Renk.anaKoyu, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ad.isEmpty ? '—' : ad,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: Renk.yazi)),
                    Text('${siparisler.length} sipariş · toplam ${tl0(toplam)}',
                        style:
                            const TextStyle(fontSize: 12.5, color: Renk.soluk)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(kalan > 0 ? tl0(kalan) : 'Borç yok',
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: kalan > 0 ? Renk.kirmizi : Renk.yesil)),
                  if (kalan > 0)
                    const Text('kalan bakiye',
                        style: TextStyle(fontSize: 11.5, color: Renk.soluk)),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final s in siparisler.take(gosterilecek))
                SiparisDetaySatiri(durum: durum, s: s),
              if (fazla > 0)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 4)),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SiparisListesiEkrani(
                          durum: durum,
                          baslik: ad,
                          filtre: (s) => musteriAnahtari(s.musteri) == anahtar,
                          asamaSecimi: true,
                          bosIkon: Icons.list_alt,
                          bosYazi: 'Kayıt yok.',
                        ),
                      ),
                    ),
                    child: Text('+$fazla sipariş daha'),
                  ),
                ),
            ],
          ),
        ),
      ],
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
