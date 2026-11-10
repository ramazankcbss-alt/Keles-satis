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

class _OzetKart extends StatelessWidget {
  const _OzetKart({
    required this.ikon,
    required this.etiket,
    required this.deger,
    required this.renk,
    required this.zemin,
  });
  final IconData ikon;
  final String etiket;
  final String deger;
  final Color renk;
  final Color zemin;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Renk.kart,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Renk.cizgi),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: zemin, borderRadius: BorderRadius.circular(10)),
              child: Icon(ikon, color: renk, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(etiket,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: Renk.soluk)),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(deger,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Renk.yazi)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
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
    final son = d.siparisler.take(5).toList();

    Widget satir(IconData ikon, Color renk, Color zemin, String ad, int sayi,
            VoidCallback onTap,
            {bool vurgulu = false, bool cizgi = true}) =>
        Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    color: zemin, borderRadius: BorderRadius.circular(9)),
                child: Icon(ikon, color: renk, size: 21),
              ),
              title: Text(ad,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500, color: Renk.yazi)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SayiRozeti(sayi: sayi, vurgulu: vurgulu),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: Renk.soluk),
                ],
              ),
              onTap: onTap,
            ),
            if (cizgi) const Divider(height: 1, indent: 54),
          ],
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // Karşılama
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Merhaba, $ilkAd',
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Renk.yazi)),
                    const SizedBox(height: 2),
                    Text('Bugün $bugunku yeni sipariş girildi',
                        style: const TextStyle(fontSize: 14, color: Renk.soluk)),
                  ],
                ),
              ),
              DurumEtiketi(
                yazi: d.yonetici ? 'Yönetici' : 'Ekip üyesi',
                renk: Renk.anaKoyu,
                zemin: Renk.anaAcik,
              ),
            ],
          ),
        ),

        // Özet kartları
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.15,
          children: [
            _OzetKart(
                ikon: Icons.trending_up,
                etiket: 'Toplam satış',
                deger: tl0(ciro),
                renk: Renk.anaKoyu,
                zemin: Renk.anaAcik),
            _OzetKart(
                ikon: Icons.account_balance_wallet_outlined,
                etiket: 'Tahsil edilen',
                deger: tl0(tah),
                renk: Renk.yesil,
                zemin: Renk.yesilAcik),
            _OzetKart(
                ikon: Icons.schedule,
                etiket: 'Kalan alacak',
                deger: tl0(d.alacak),
                renk: Renk.turuncu,
                zemin: Renk.turuncuAcik),
            _OzetKart(
                ikon: Icons.receipt_long_outlined,
                etiket: 'Sipariş',
                deger: sayi(d.siparisler.length),
                renk: Renk.mavi,
                zemin: Renk.maviAcik),
          ],
        ),
        const SizedBox(height: 12),

        // Tahsilat oranı
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Tahsilat oranı',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Renk.yazi)),
                  ),
                  Text('%${(oran * 100).round()}',
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Renk.anaKoyu)),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: oran,
                  minHeight: 10,
                  backgroundColor: const Color(0xFFE8EEF1),
                ),
              ),
              const SizedBox(height: 8),
              Text('${tl0(tah)} / ${tl0(ciro)} tahsil edildi',
                  style: const TextStyle(fontSize: 13, color: Renk.soluk)),
            ],
          ),
        ),

        // İş akışı
        Panel(
          baslik: 'İş akışı',
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
          child: Column(
            children: [
              satir(Icons.sell_outlined, Renk.amber, Renk.amberAcik,
                  'Fiyat bekleyen', d.sayi(Asama.fiyat), () => sekmeyeGit(1),
                  vurgulu: true),
              satir(Icons.local_shipping_outlined, Renk.mavi, Renk.maviAcik,
                  'Teslim bekleyen', d.sayi(Asama.teslim), () => sekmeyeGit(2),
                  vurgulu: true),
              satir(Icons.payments_outlined, Renk.turuncu, Renk.turuncuAcik,
                  'Tahsilat bekleyen', d.sayi(Asama.tahsilat), () => sekmeyeGit(3),
                  vurgulu: true),
              satir(
                  Icons.check_circle_outline,
                  Renk.yesil,
                  Renk.yesilAcik,
                  'Tamamlanan',
                  d.sayi(Asama.tamam),
                  () => git(SiparisListesiEkrani(
                      durum: d,
                      baslik: 'Tamamlanan siparişler',
                      filtre: (s) => s.asama == Asama.tamam,
                      bosIkon: Icons.check_circle_outline,
                      bosYazi: 'Henüz tamamlanan sipariş yok.',
                      ozet: (l) =>
                          'Tahsil edilen ${tl(l.fold(0.0, (a, s) => a + s.odenen))}'))),
              satir(
                  Icons.list_alt,
                  Renk.soluk,
                  const Color(0xFFEFF3F5),
                  'Tüm siparişler',
                  d.siparisler.length,
                  () => git(SiparisListesiEkrani(
                      durum: d,
                      baslik: 'Tüm siparişler',
                      filtre: (_) => true,
                      asamaSecimi: true,
                      bosIkon: Icons.list_alt,
                      bosYazi: 'Kayıt bulunamadı.')),
                  cizgi: false),
            ],
          ),
        ),

        // Raporlar
        Panel(
          baslik: 'Raporlar',
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
          child: Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: const Icon(Icons.handshake_outlined, color: Renk.anaKoyu),
                title: const Text('Aracı bazında satışlar'),
                trailing: const Icon(Icons.chevron_right, color: Renk.soluk),
                onTap: () => sekmeyeGit(4),
              ),
              const Divider(height: 1, indent: 54),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: const Icon(Icons.people_outline, color: Renk.anaKoyu),
                title: const Text('Müşteri bakiyeleri'),
                trailing: const Icon(Icons.chevron_right, color: Renk.soluk),
                onTap: () => git(OzetEkrani(durum: d, musteri: true)),
              ),
              const Divider(height: 1, indent: 54),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: const Icon(Icons.inventory_2_outlined, color: Renk.anaKoyu),
                title: const Text('Ürün bazında satışlar'),
                trailing: const Icon(Icons.chevron_right, color: Renk.soluk),
                onTap: () => git(OzetEkrani(durum: d, musteri: false)),
              ),
            ],
          ),
        ),

        // Son hareketler
        Panel(
          baslik: 'Son hareketler',
          eylem: d.siparisler.length > son.length
              ? TextButton(
                  onPressed: () => git(SiparisListesiEkrani(
                      durum: d,
                      baslik: 'Tüm siparişler',
                      filtre: (_) => true,
                      asamaSecimi: true,
                      bosIkon: Icons.list_alt,
                      bosYazi: 'Kayıt bulunamadı.')),
                  child: const Text('Tümü'))
              : null,
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
          child: !d.yuklendi
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()))
              : son.isEmpty
                  ? const BosDurum(
                      ikon: Icons.receipt_long_outlined,
                      yazi: 'Henüz sipariş yok.\n"Yeni Sipariş" ile ilk siparişi girin.')
                  : Column(
                      children: [
                        for (var i = 0; i < son.length; i++) ...[
                          SiparisSatiri(durum: d, s: son[i]),
                          if (i < son.length - 1) const Divider(height: 1),
                        ],
                      ],
                    ),
        ),
      ],
    );
  }
}
