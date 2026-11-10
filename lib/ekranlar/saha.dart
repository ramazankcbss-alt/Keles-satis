import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../bicim.dart';
import '../modeller.dart';
import '../servis/bildirim.dart';
import '../servis/guncelleme.dart';
import '../servis/veri.dart';
import '../tema.dart';
import 'arama.dart';
import 'formlar.dart';
import 'listeler.dart';

/// Saha çalışanının ekranı: hızlı satış ve yalnızca kendi girdiği siparişler.
/// Firmanın cirosu, diğer siparişler, raporlar ve ayarlar burada yoktur
/// (Firestore kuralları da bunları okumaya izin vermez).
class SahaKabuk extends StatefulWidget {
  const SahaKabuk({super.key, required this.durum});
  final Durum durum;

  @override
  State<SahaKabuk> createState() => _SahaKabukState();
}

class _SahaKabukState extends State<SahaKabuk> {
  bool _sadeceBekleyen = true;

  @override
  void initState() {
    super.initState();
    // Saha çalışanı başkalarının işlemleri için bildirim almaz.
    Hareketler.oturumKapat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Guncelleme.kontrolEt(context);
    });
  }

  bool _bekliyor(Siparis s) => !s.teslim || s.fiyat == null || s.kalan > 0;

  Future<void> _adDegistir(Durum d) async {
    final c = TextEditingController(
        text: d.isim(d.uid) == '…' ? '' : d.isim(d.uid));
    final yeni = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adınız'),
        content: TextField(
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Ad Soyad'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('Kaydet')),
        ],
      ),
    );
    if (yeni == null || yeni.length < 2) return;
    try {
      await Veri.adKaydet(d.uid, yeni);
      d.isimTazele(d.uid);
      if (mounted) bildir(context, 'Adınız kaydedildi');
    } catch (e) {
      if (mounted) bildir(context, hataYazisi(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.durum;
    return ListenableBuilder(
      listenable: d,
      builder: (context, _) {
        final f = d.firma!;
        final ad = d.isim(d.uid);
        final bugun = DateTime.now();
        final gun =
            DateTime(bugun.year, bugun.month, bugun.day).millisecondsSinceEpoch;
        final bugunku = d.siparisler.where((s) => s.olusturma >= gun).toList();
        final bugunSatis = bugunku.fold(0.0, (a, s) => a + s.toplam);
        final bugunTahsil = d.siparisler.fold(
            0.0,
            (a, s) =>
                a +
                s.tahsilatlar
                    .where((t) => t.tarih >= gun && t.by == d.uid)
                    .fold(0.0, (b, t) => b + t.tutar));
        final liste = _sadeceBekleyen
            ? d.siparisler.where(_bekliyor).toList()
            : d.siparisler;
        final bekleyenSayisi = d.siparisler.where(_bekliyor).length;

        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 64,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.ad,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: .3)),
                Text('HIZLI SATIŞ',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: .8,
                        color: Colors.white.withValues(alpha: .85))),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Bul',
                icon: const Icon(Icons.search),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => AramaEkrani(durum: d))),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.account_circle_outlined),
                onSelected: (v) async {
                  if (v == 'ad') {
                    _adDegistir(d);
                  } else if (v == 'cikis') {
                    await FirebaseAuth.instance.signOut();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                      value: 'ad',
                      child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.badge_outlined),
                          title: Text('Adımı değiştir'))),
                  PopupMenuItem(
                      value: 'cikis',
                      child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.logout),
                          title: Text('Çıkış yap'))),
                ],
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Merhaba, ${ad.split(RegExp(r'\s+')).first}',
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Renk.yazi)),
                  ),
                  const DurumEtiketi(
                      yazi: 'Saha', renk: Renk.anaKoyu, zemin: Renk.anaAcik),
                ],
              ),
              const SizedBox(height: 14),
              Buton(
                yazi: 'Yeni Satış',
                ikon: Icons.add_shopping_cart,
                yukseklik: 58,
                onTap: () => yeniSiparis(context, d, hizli: true),
              ),
              const SizedBox(height: 14),
              Panel(
                child: Row(
                  children: [
                    Expanded(
                        child: Cip(
                            ust: 'Bugün satış', deger: '${bugunku.length} adet')),
                    Expanded(child: Cip(ust: 'Bugün tutar', deger: tl0(bugunSatis))),
                    Expanded(
                        child: Cip(
                            ust: 'Bugün tahsil',
                            deger: tl0(bugunTahsil),
                            durum: bugunTahsil > 0 ? true : null)),
                  ],
                ),
              ),
              Row(
                children: [
                  const Expanded(
                    child: Text('Satışlarım',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Renk.yazi)),
                  ),
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    segments: [
                      ButtonSegment(
                          value: true, label: Text('Bekleyen ($bekleyenSayisi)')),
                      const ButtonSegment(value: false, label: Text('Tümü')),
                    ],
                    selected: {_sadeceBekleyen},
                    onSelectionChanged: (v) =>
                        setState(() => _sadeceBekleyen = v.first),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (d.siparisHata != null)
                BosDurum(ikon: Icons.error_outline, yazi: hataYazisi(d.siparisHata!))
              else if (!d.yuklendi)
                const Padding(
                    padding: EdgeInsets.all(30),
                    child: Center(child: CircularProgressIndicator()))
              else if (liste.isEmpty)
                BosDurum(
                    ikon: Icons.receipt_long_outlined,
                    yazi: _sadeceBekleyen
                        ? 'Teslim ya da tahsilat bekleyen satışınız yok.'
                        : 'Henüz satış girmediniz.\n"Yeni Satış" ile başlayın.')
              else
                for (final s in liste) SiparisKarti(durum: d, s: s),
            ],
          ),
        );
      },
    );
  }
}
