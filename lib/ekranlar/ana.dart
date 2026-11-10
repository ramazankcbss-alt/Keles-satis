import 'package:flutter/material.dart';

import '../bicim.dart';
import '../modeller.dart';
import '../servis/bildirim.dart';
import '../servis/guncelleme.dart';
import '../servis/veri.dart';
import '../tema.dart';
import 'aracilar.dart';
import 'arama.dart';
import 'ayarlar.dart';
import 'formlar.dart';
import 'listeler.dart';
import 'ozet.dart';

/// Üst başlık + sekmeler + alt menü + "Yeni Sipariş" butonu.
class AnaKabuk extends StatefulWidget {
  const AnaKabuk({super.key, required this.durum});
  final Durum durum;

  @override
  State<AnaKabuk> createState() => _AnaKabukState();
}

class _AnaKabukState extends State<AnaKabuk> {
  int _sekme = 0; // 0 ana, 1 fiyat, 2 teslim, 3 tahsilat, 4 aracılar

  @override
  void initState() {
    super.initState();
    final d = widget.durum;
    Hareketler.oturum(d.fid, d.uid, d.yonetici);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Bildirim.izinIste();
      if (mounted) Guncelleme.kontrolEt(context);
    });
  }

  void _git(Widget ekran) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ekran));

  void _sekmeyeGit(int i) => setState(() => _sekme = i);

  @override
  Widget build(BuildContext context) {
    final d = widget.durum;
    return ListenableBuilder(
      listenable: d,
      builder: (context, _) {
        final f = d.firma!;
        final nF = d.sayi(Asama.fiyat),
            nT = d.sayi(Asama.teslim),
            nC = d.sayi(Asama.tahsilat);
        final bekleyen = nF + nT + nC;

        final Widget govde = switch (_sekme) {
          1 => SiparisListesi(
              key: const ValueKey('fiyat'),
              durum: d,
              baslik: 'Fiyat bekleyenler',
              filtre: (s) => s.asama == Asama.fiyat,
              bosIkon: Icons.sell_outlined,
              bosYazi: 'Fiyatı girilmemiş sipariş yok.'),
          2 => SiparisListesi(
              key: const ValueKey('teslim'),
              durum: d,
              baslik: 'Teslim bekleyenler',
              filtre: (s) => s.asama == Asama.teslim,
              bosIkon: Icons.local_shipping_outlined,
              bosYazi: 'Teslim edilecek sipariş yok.',
              ozet: (l) =>
                  '${l.length} sipariş · ${tl(l.fold(0.0, (a, s) => a + s.toplam))}'),
          3 => SiparisListesi(
              key: const ValueKey('tahsil'),
              durum: d,
              baslik: 'Tahsilat bekleyenler',
              filtre: (s) => s.asama == Asama.tahsilat,
              bosIkon: Icons.payments_outlined,
              bosYazi: 'Tahsil edilecek alacak yok.',
              ozet: (l) =>
                  'Toplam alacak ${tl(l.fold(0.0, (a, s) => a + s.kalan))}'),
          4 => AraciPaneli(key: const ValueKey('araci'), durum: d),
          _ => _AnaSayfa(durum: d, git: _git, sekmeyeGit: _sekmeyeGit),
        };

        Widget rozetli(IconData ikon, int n) => Badge(
              isLabelVisible: n > 0,
              label: Text('$n'),
              backgroundColor: Renk.kirmizi,
              child: Icon(ikon),
            );

        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 64,
            title: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.agriculture_outlined, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f.ad,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .3)),
                      if (f.altyazi.isNotEmpty)
                        Text(f.altyazi,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                letterSpacing: .8,
                                color: Colors.white.withValues(alpha: .85))),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Bul',
                icon: const Icon(Icons.search),
                onPressed: () => _git(AramaEkrani(durum: d)),
              ),
              IconButton(
                tooltip: 'Bekleyen işler',
                icon: Badge(
                  isLabelVisible: bekleyen > 0,
                  label: Text('$bekleyen'),
                  backgroundColor: Renk.kirmizi,
                  child: const Icon(Icons.notifications_outlined),
                ),
                onPressed: () => _sekmeyeGit(nF > 0
                    ? 1
                    : nT > 0
                        ? 2
                        : nC > 0
                            ? 3
                            : 0),
              ),
              IconButton(
                tooltip: 'Ayarlar',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => _git(AyarlarEkrani(durum: d)),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: govde,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => yeniSiparis(context, d),
            icon: const Icon(Icons.add),
            label: const Text('Yeni Sipariş',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          bottomNavigationBar: DecoratedBox(
            decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Renk.cizgi))),
            child: NavigationBar(
              selectedIndex: _sekme,
              onDestinationSelected: _sekmeyeGit,
              destinations: [
                const NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: 'Ana Sayfa'),
                NavigationDestination(
                    icon: rozetli(Icons.sell_outlined, nF),
                    selectedIcon: rozetli(Icons.sell, nF),
                    label: 'Fiyat'),
                NavigationDestination(
                    icon: rozetli(Icons.local_shipping_outlined, nT),
                    selectedIcon: rozetli(Icons.local_shipping, nT),
                    label: 'Teslim'),
                NavigationDestination(
                    icon: rozetli(Icons.payments_outlined, nC),
                    selectedIcon: rozetli(Icons.payments, nC),
                    label: 'Tahsilat'),
                const NavigationDestination(
                    icon: Icon(Icons.handshake_outlined),
                    selectedIcon: Icon(Icons.handshake),
                    label: 'Aracılar'),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AnaSayfa extends StatelessWidget {
  const _AnaSayfa(
      {required this.durum, required this.git, required this.sekmeyeGit});
  final Durum durum;
  final void Function(Widget) git;
  final ValueChanged<int> sekmeyeGit;

  @override
  Widget build(BuildContext context) {
    final d = durum;
    final ad = d.isim(d.uid);
    final ilkAd = ad.split(RegExp(r'\s+')).first;
    final ciro = d.ciro, tah = d.tahsil;
    final oran = ciro > 0 ? (tah / ciro).clamp(0.0, 1.0) : 0.0;
    final bugun = DateTime.now();
    final gun =
        DateTime(bugun.year, bugun.month, bugun.day).millisecondsSinceEpoch;
    final bugunku = d.siparisler.where((s) => s.olusturma >= gun).length;
    // Son hareketler: aynı müşterinin satışları tek kartta, en son işlem
    // yapılan müşteri en üstte. Kartın toplamı müşterinin bütün siparişleridir.
    final gruplar = <String, List<Siparis>>{};
    for (final s in d.siparisler) {
      final k = musteriAnahtari(s.musteri);
      final g = gruplar[k];
      if (g != null) {
        g.add(s);
      } else if (gruplar.length < 12) {
        gruplar[k] = [s];
      }
    }
    final musteriler = gruplar.values.toList();

    final musteriSayisi =
        {for (final s in d.siparisler) musteriAnahtari(s.musteri)}.length;
    final urunSayisi =
        {for (final s in d.siparisler) s.urun.trim().toLowerCase()}.length;

    Widget tumSiparisler() => SiparisListesiEkrani(
        durum: d,
        baslik: 'Tüm siparişler',
        filtre: (_) => true,
        asamaSecimi: true,
        bosIkon: Icons.list_alt,
        bosYazi: 'Kayıt bulunamadı.');

    final sayfa = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Karşılama
        Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: 'Merhaba, $ilkAd  ',
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Renk.yazi)),
                  TextSpan(
                      text: 'Bugün $bugunku yeni sipariş',
                      style: const TextStyle(fontSize: 13, color: Renk.soluk)),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DurumEtiketi(
              yazi: d.yonetici ? 'Yönetici' : 'Ekip üyesi',
              renk: Renk.anaKoyu,
              zemin: Renk.anaAcik,
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Özet hapları (2 x 2)
        Row(
          children: [
            Expanded(
              child: Hap(
                  emoji: '💰',
                  deger: tl0(ciro),
                  etiket: 'Toplam satış',
                  renk: Renk.anaKoyu,
                  zemin: Renk.anaAcik),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Hap(
                  emoji: '📥',
                  deger: tl0(tah),
                  etiket: 'Tahsil · %${(oran * 100).round()}',
                  renk: Renk.yesil,
                  zemin: Renk.yesilAcik),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Hap(
                  emoji: '⏳',
                  deger: tl0(d.alacak),
                  etiket: 'Kalan alacak',
                  renk: Renk.turuncu,
                  zemin: Renk.turuncuAcik,
                  onTap: () => sekmeyeGit(3)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Hap(
                  emoji: '🧾',
                  deger: sayi(d.siparisler.length),
                  etiket: 'Sipariş',
                  renk: Renk.mavi,
                  zemin: Renk.maviAcik,
                  onTap: () => git(tumSiparisler())),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Kısayollar (fiyat, teslim, tahsilat ve aracılar alttaki sekmelerde)
        Row(
          children: [
            Expanded(
              child: RenkliKutu(
                  ust: '${d.sayi(Asama.tamam)} sipariş',
                  emoji: '✅',
                  baslik: 'Tamamlanan',
                  renk: Renk.yesil,
                  zemin: const Color(0xFFF0FDF4),
                  onTap: () => git(SiparisListesiEkrani(
                      durum: d,
                      baslik: 'Tamamlanan siparişler',
                      filtre: (s) => s.asama == Asama.tamam,
                      bosIkon: Icons.check_circle_outline,
                      bosYazi: 'Henüz tamamlanan sipariş yok.',
                      ozet: (l) =>
                          'Tahsil edilen ${tl(l.fold(0.0, (a, s) => a + s.odenen))}'))),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: RenkliKutu(
                  ust: '${sayi(d.siparisler.length)} kayıt',
                  emoji: '📋',
                  baslik: 'Tüm siparişler',
                  renk: Renk.amber,
                  zemin: const Color(0xFFFFFBEB),
                  onTap: () => git(tumSiparisler())),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: RenkliKutu(
                  ust: '$musteriSayisi kişi',
                  emoji: '👥',
                  baslik: 'Müşteri bakiyeleri',
                  renk: Renk.anaKoyu,
                  zemin: const Color(0xFFF0FDFA),
                  onTap: () => git(OzetEkrani(durum: d, musteri: true))),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: RenkliKutu(
                  ust: '$urunSayisi ürün',
                  emoji: '📦',
                  baslik: 'Ürün satışları',
                  renk: Renk.mavi,
                  zemin: const Color(0xFFEFF6FF),
                  onTap: () => git(OzetEkrani(durum: d, musteri: false))),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Son hareketler: kalan alanı doldurur, kendi içinde kayar.
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Renk.kart,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Renk.cizgi, width: 2),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 6, 0),
                  child: Row(
                    children: [
                      const Text('🕒 ', style: TextStyle(fontSize: 18)),
                      const Expanded(
                        child: Text('Son hareketler',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Renk.yazi)),
                      ),
                      TextButton(
                          onPressed: () => git(tumSiparisler()),
                          child: const Text('Tümü')),
                    ],
                  ),
                ),
                Expanded(
                  child: !d.yuklendi
                      ? const Center(child: CircularProgressIndicator())
                      : musteriler.isEmpty
                          ? const SingleChildScrollView(
                              child: BosDurum(
                                  ikon: Icons.receipt_long_outlined,
                                  yazi:
                                      'Henüz sipariş yok.\n"Yeni Sipariş" ile ilk siparişi girin.'),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(10, 0, 10, 80),
                              itemCount: musteriler.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 14),
                              itemBuilder: (_, i) => MusteriHareketKarti(
                                  durum: d, siparisler: musteriler[i]),
                            ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    // Tek sayfa: kaydırma gerekmez. Çok kısa ekranlarda sayfa bütün olarak kayar.
    return LayoutBuilder(builder: (context, c) {
      const enAz = 640.0;
      final icerik = Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8), child: sayfa);
      if (c.maxHeight >= enAz) return icerik;
      return SingleChildScrollView(
          child: SizedBox(height: enAz, child: icerik));
    });
  }
}
