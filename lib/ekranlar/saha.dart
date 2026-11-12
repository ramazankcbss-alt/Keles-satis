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
  /// 0: bekleyen, 1: tümü, 2: müşterilere göre
  int _gorunum = 0;
  bool _buAy = true;

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
        final bekleyenler = d.siparisler.where(_bekliyor).toList();
        final liste = _gorunum == 0 ? bekleyenler : d.siparisler;
        final bekleyenSayisi = bekleyenler.length;

        // Toplamlarım (kendi girdiğim ve aracı olduğum satışlar)
        final toplamKg =
            d.siparisler.fold(0.0, (a, s) => a + AraciOzeti.kgKarsiligi(s));
        final toplamTutar = d.siparisler.fold(0.0, (a, s) => a + s.toplam);
        final toplamAlinan = d.siparisler.fold(0.0, (a, s) => a + s.odenen);
        final toplamAlacak = d.siparisler.fold(0.0, (a, s) => a + s.kalan);
        final urunler = urunOzetleri(d.siparisler);
        final musteriler = <String, List<Siparis>>{};
        for (final s in d.siparisler) {
          musteriler.putIfAbsent(musteriAnahtari(s.musteri), () => []).add(s);
        }

        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 64,
            leading: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Image.asset('assets/logo.png', width: 40, height: 40),
            ),
            leadingWidth: 56,
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
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Hap(
                        emoji: '⚖️',
                        deger: '${sayi(toplamKg)} kg',
                        etiket: 'Toplam miktarım',
                        renk: Renk.anaKoyu,
                        zemin: Renk.anaAcik),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Hap(
                        emoji: '💰',
                        deger: tl0(toplamTutar),
                        etiket: '${musteriler.length} müşteri',
                        renk: Renk.mavi,
                        zemin: Renk.maviAcik),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Hap(
                        emoji: '⏳',
                        deger: tl0(toplamAlacak),
                        etiket: 'Alacağım',
                        renk: Renk.kirmizi,
                        zemin: Renk.kirmiziAcik,
                        onTap: () => setState(() => _gorunum = 0)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Hap(
                        emoji: '📥',
                        deger: tl0(toplamAlinan),
                        etiket: 'Tahsil edilen',
                        renk: Renk.yesil,
                        zemin: Renk.yesilAcik),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                  'Bugün: ${bugunku.length} satış · ${tl0(bugunSatis)} · tahsil ${tl0(bugunTahsil)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Renk.soluk)),
              const SizedBox(height: 12),
              Buton(
                yazi: 'Yeni Satış',
                ikon: Icons.add_shopping_cart,
                yukseklik: 58,
                onTap: () => yeniSiparis(context, d, hizli: true),
              ),
              const SizedBox(height: 12),
              _Siralama(
                durum: d,
                buAy: _buAy,
                degistir: (v) => setState(() => _buAy = v),
              ),
              if (urunler.isNotEmpty)
                Panel(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          Text('📦 ', style: TextStyle(fontSize: 18)),
                          Expanded(
                            child: Text('Ürünlerime göre satış ve alacak',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Renk.yazi)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      UrunAlacakListesi(urunler: urunler),
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
                  SegmentedButton<int>(
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    segments: [
                      ButtonSegment(value: 0, label: Text('Bekleyen ($bekleyenSayisi)')),
                      const ButtonSegment(value: 1, label: Text('Tümü')),
                      const ButtonSegment(value: 2, label: Text('Kime')),
                    ],
                    selected: {_gorunum},
                    onSelectionChanged: (v) => setState(() => _gorunum = v.first),
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
                    yazi: _gorunum == 0
                        ? 'Teslim ya da tahsilat bekleyen satışınız yok.'
                        : 'Henüz satış girmediniz.\n"Yeni Satış" ile başlayın.')
              else if (_gorunum == 2)
                for (final m in musteriler.values)
                  Panel(
                    padding: const EdgeInsets.fromLTRB(10, 2, 10, 6),
                    margin: const EdgeInsets.only(bottom: 10),
                    child: MusteriHareketKarti(
                        durum: d, siparisler: m, gosterilecek: 50),
                  )
              else
                for (final s in liste) SiparisKarti(durum: d, s: s),
            ],
          ),
        );
      },
    );
  }
}

/// Aracıların satış sıralaması: kim kaç kilo sattı, payı yüzde kaç.
/// Tutarlar gösterilmez; özet yöneticinin uygulaması tarafından yazılır.
class _Siralama extends StatelessWidget {
  const _Siralama(
      {required this.durum, required this.buAy, required this.degistir});
  final Durum durum;
  final bool buAy;
  final ValueChanged<bool> degistir;

  @override
  Widget build(BuildContext context) {
    final d = durum;
    final f = d.firma!;
    final o = f.araciOzeti;
    final buAyGecerli = o != null && o.ay == AraciOzeti.ayAnahtari(DateTime.now());
    final satirlar = o == null
        ? const <AraciSatir>[]
        : (buAy ? (buAyGecerli ? o.buAy : const <AraciSatir>[]) : o.tum);
    final toplamKg = satirlar.fold(0.0, (a, x) => a + x.kg);
    final toplamN = satirlar.fold(0, (a, x) => a + x.siparis);
    double pay(AraciSatir x) => toplamKg > 0
        ? x.kg / toplamKg
        : (toplamN > 0 ? x.siparis / toplamN : 0);
    final benim = <String>{
      araMetni(d.isim(d.uid)),
      for (final a in f.sahaAraci[d.uid] ?? const <String>[]) araMetni(a),
    }..removeWhere((e) => e.isEmpty || e == '…');
    const madalya = ['🥇', '🥈', '🥉'];

    return Panel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('🏆 ', style: TextStyle(fontSize: 18)),
              const Expanded(
                child: Text('Aracı sıralaması',
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
                segments: const [
                  ButtonSegment(value: true, label: Text('Bu ay')),
                  ButtonSegment(value: false, label: Text('Tümü')),
                ],
                selected: {buAy},
                onSelectionChanged: (v) => degistir(v.first),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (satirlar.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                  o == null
                      ? 'Sıralama, yönetici uygulamayı açtığında hazırlanır.'
                      : 'Bu ay henüz satış yok.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Renk.soluk, fontSize: 13.5)),
            )
          else
            for (var i = 0; i < satirlar.length; i++)
              Builder(builder: (context) {
                final x = satirlar[i];
                final ben = benim.contains(araMetni(x.ad));
                final p = pay(x);
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.fromLTRB(8, 6, 10, 7),
                  decoration: BoxDecoration(
                    color: ben ? Renk.amberAcik : const Color(0xFFF8FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: ben ? const Color(0xFFFCD34D) : Renk.cizgi,
                        width: ben ? 2 : 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 30,
                            child: Text(i < 3 ? madalya[i] : '${i + 1}.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: i < 3 ? 18 : 14,
                                    fontWeight: FontWeight.w700,
                                    color: Renk.soluk)),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(ben ? '${x.ad} (siz)' : x.ad,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight:
                                        ben ? FontWeight.w800 : FontWeight.w600,
                                    color: Renk.yazi)),
                          ),
                          Text(
                              '${sayi(x.kg)} kg · %${(p * 100).toStringAsFixed(p < .1 ? 1 : 0)}',
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: Renk.yazi)),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Padding(
                        padding: const EdgeInsets.only(left: 34),
                        child: Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: p.clamp(0.0, 1.0).toDouble(),
                                  minHeight: 7,
                                  backgroundColor: const Color(0xFFE8EEF1),
                                  color: ben ? Renk.amber : Renk.ana,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('${x.siparis} satış',
                                style: const TextStyle(
                                    fontSize: 12, color: Renk.soluk)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
          if (o != null && o.tarih > 0)
            Text('Güncellendi: ${once(o.tarih)}',
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 11.5, color: Renk.soluk)),
        ],
      ),
    );
  }
}
