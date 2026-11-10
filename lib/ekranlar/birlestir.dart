import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../bicim.dart';
import '../servis/benzer.dart';
import '../servis/veri.dart';
import '../tema.dart';

/// Bir müşteri adının (yazılışının) sipariş özeti.
class _Ad {
  int adet = 0;
  double toplam = 0, kalan = 0;
}

Map<String, _Ad> _adlar(Durum d) {
  final m = <String, _Ad>{};
  for (final s in d.siparisler) {
    final a = s.musteri.trim();
    if (a.isEmpty) continue;
    final x = m.putIfAbsent(a, _Ad.new);
    x.adet++;
    x.toplam += s.toplam;
    x.kalan += s.kalan;
  }
  return m;
}

/// Kaç grup birleştirme önerisi var (ana sayfa ve Müşteriler ekranı için).
int birlestirmeOneriSayisi(Durum d) => benzerGruplar(
        {for (final s in d.siparisler) s.musteri.trim()},
        d.firma?.ayriMusteriler ?? const {})
    .length;

/// Seçilen adları [hedef] adı altında birleştirir: o adlarla girilmiş bütün
/// siparişlerin müşteri adı [hedef] olur. Seçilmeyenler "aynı değil" sayılır.
Future<int> _birlestir(Durum d,
    {required String hedef,
    required Set<String> secilen,
    Set<String> haric = const {}}) async {
  final idler = [
    for (final s in d.siparisler)
      if (secilen.contains(s.musteri.trim()) && s.musteri != hedef) s.id
  ];
  await Veri.alanDegistir(d.fid, idler, 'musteri', hedef);
  if (haric.isNotEmpty) {
    await Veri.firmaGuncelle(d.fid, {
      'ayriMusteriler':
          FieldValue.arrayUnion([for (final h in haric) ciftAnahtari(h, hedef)])
    });
  }
  return idler.length;
}

/// Aynı kişi olabilecek müşteri adlarını gösterir; onaylanınca birleştirir.
class MusteriBirlestirEkrani extends StatefulWidget {
  const MusteriBirlestirEkrani({super.key, required this.durum});
  final Durum durum;

  @override
  State<MusteriBirlestirEkrani> createState() => _MusteriBirlestirEkraniState();
}

class _MusteriBirlestirEkraniState extends State<MusteriBirlestirEkrani> {
  bool _elle = false;
  final _secili = <String>{};
  final _ara = TextEditingController();

  @override
  void dispose() {
    _ara.dispose();
    super.dispose();
  }

  Future<void> _elleBirlestir(Map<String, _Ad> adlar) async {
    final l = _secili.toList()
      ..sort((a, b) => (adlar[b]?.adet ?? 0).compareTo(adlar[a]?.adet ?? 0));
    var hedef = l.first;
    final tamam = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Hangi ad kalsın?'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final a in l)
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    value: a,
                    groupValue: hedef,
                    onChanged: (v) => set(() => hedef = v!),
                    title: Text(a),
                    subtitle: Text('${adlar[a]?.adet ?? 0} sipariş'),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Vazgeç')),
            FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Birleştir')),
          ],
        ),
      ),
    );
    if (tamam != true || !mounted) return;
    try {
      final n = await _birlestir(widget.durum, hedef: hedef, secilen: _secili);
      if (!mounted) return;
      setState(_secili.clear);
      bildir(context, '"$hedef" altında birleştirildi ($n sipariş)');
    } catch (e) {
      if (mounted) bildir(context, hataYazisi(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.durum;
    return Scaffold(
      appBar: AppBar(title: const Text('Müşteri birleştir')),
      body: ListenableBuilder(
        listenable: d,
        builder: (context, _) {
          final adlar = _adlar(d);
          final gruplar =
              benzerGruplar(adlar.keys, d.firma?.ayriMusteriler ?? const {});
          _secili.removeWhere((a) => !adlar.containsKey(a));
          final q = araMetni(_ara.text);
          final tum = adlar.keys.where((a) => araMetni(a).contains(q)).toList()
            ..sort((a, b) => araMetni(a).compareTo(araMetni(b)));

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                        value: false, label: Text('Öneriler (${gruplar.length})')),
                    const ButtonSegment(value: true, label: Text('Elle seç')),
                  ],
                  selected: {_elle},
                  onSelectionChanged: (v) => setState(() => _elle = v.first),
                ),
              ),
              Expanded(
                child: !_elle
                    ? ListView(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 40),
                        children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
                            child: Text(
                              'Yazılışı aynı ya da çok benzeyen müşteri adları. Aynı kişiyse birleştirin; o adlarla girilmiş bütün siparişler ve satışlar tek müşteride toplanır. Aynı kişi olmayanların işaretini kaldırın.',
                              style: TextStyle(fontSize: 13, color: Renk.soluk),
                            ),
                          ),
                          if (gruplar.isEmpty)
                            const Panel(
                              child: BosDurum(
                                  ikon: Icons.verified_outlined,
                                  yazi:
                                      'Benzer isim bulunamadı.\nYine de birleştirmek istediğiniz kişiler varsa "Elle seç"i kullanın.'),
                            ),
                          for (final g in gruplar)
                            _GrupKarti(
                                key: ValueKey(g.join('|')),
                                durum: d,
                                adlar: {for (final a in g) a: adlar[a]!}),
                        ],
                      )
                    : Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                            child: TextField(
                              controller: _ara,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.search),
                                  hintText: 'Müşteri ara'),
                            ),
                          ),
                          Expanded(
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(4, 0, 4, 90),
                              children: [
                                for (final a in tum)
                                  CheckboxListTile(
                                    value: _secili.contains(a),
                                    onChanged: (v) => setState(() => v == true
                                        ? _secili.add(a)
                                        : _secili.remove(a)),
                                    title: Text(a),
                                    subtitle: Text(
                                        '${adlar[a]!.adet} sipariş · ${tl0(adlar[a]!.toplam)}'
                                        '${adlar[a]!.kalan > 0 ? ' · kalan ${tl0(adlar[a]!.kalan)}' : ''}'),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: _elle && _secili.length >= 2
          ? FloatingActionButton.extended(
              onPressed: () => _elleBirlestir(_adlar(d)),
              icon: const Icon(Icons.merge_type),
              label: Text('Seçilenleri birleştir (${_secili.length})'),
            )
          : null,
    );
  }
}

/// "Bu kişiler aynı mı?" kartı.
class _GrupKarti extends StatefulWidget {
  const _GrupKarti(
      {super.key, required this.durum, required this.adlar});
  final Durum durum;
  final Map<String, _Ad> adlar;

  @override
  State<_GrupKarti> createState() => _GrupKartiState();
}

class _GrupKartiState extends State<_GrupKarti> {
  late final Set<String> _secili = widget.adlar.keys.toSet();
  late String _hedef = (widget.adlar.entries.toList()
        ..sort((a, b) => b.value.adet.compareTo(a.value.adet)))
      .first
      .key;
  bool _mesgul = false;

  Future<void> _calistir(Future<void> Function() is_) async {
    setState(() => _mesgul = true);
    try {
      await is_();
    } catch (e) {
      if (mounted) bildir(context, hataYazisi(e));
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.durum;
    final adlar = widget.adlar;
    if (!_secili.contains(_hedef) && _secili.isNotEmpty) _hedef = _secili.first;
    final birlesecek = adlar.entries
        .where((e) => _secili.contains(e.key))
        .fold(0, (a, e) => a + e.value.adet);
    return Panel(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('🤔 Bu kişiler aynı mı?',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: Renk.yazi)),
          const SizedBox(height: 6),
          for (final e in adlar.entries)
            Container(
              decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Renk.cizgi))),
              child: Row(
                children: [
                  Checkbox(
                    value: _secili.contains(e.key),
                    onChanged: _mesgul
                        ? null
                        : (v) => setState(() =>
                            v == true ? _secili.add(e.key) : _secili.remove(e.key)),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.key,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: _secili.contains(e.key)
                                    ? Renk.yazi
                                    : Renk.soluk,
                                decoration: _secili.contains(e.key)
                                    ? null
                                    : TextDecoration.lineThrough)),
                        Text(
                            '${e.value.adet} sipariş · ${tl0(e.value.toplam)}'
                            '${e.value.kalan > 0 ? ' · kalan ${tl0(e.value.kalan)}' : ''}',
                            style: const TextStyle(
                                fontSize: 12.5, color: Renk.soluk)),
                      ],
                    ),
                  ),
                  if (_secili.contains(e.key))
                    ChoiceChip(
                      label: const Text('Bu ad kalsın'),
                      selected: _hedef == e.key,
                      onSelected: _mesgul
                          ? null
                          : (_) => setState(() => _hedef = e.key),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Buton(
                  yazi: 'Aynı değiller',
                  renk: ButonRenk.ikincil,
                  onTap: _mesgul
                      ? null
                      : () => _calistir(() async {
                            final l = adlar.keys.toList();
                            await Veri.firmaGuncelle(d.fid, {
                              'ayriMusteriler': FieldValue.arrayUnion([
                                for (var i = 0; i < l.length; i++)
                                  for (var j = i + 1; j < l.length; j++)
                                    ciftAnahtari(l[i], l[j])
                              ])
                            });
                            if (mounted) bildir(context, 'Bir daha sorulmayacak');
                          }),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Buton(
                  yazi: 'Birleştir',
                  ikon: Icons.merge_type,
                  mesgul: _mesgul,
                  onTap: _mesgul || _secili.length < 2
                      ? null
                      : () => _calistir(() async {
                            final n = await _birlestir(d,
                                hedef: _hedef,
                                secilen: _secili,
                                haric: adlar.keys
                                    .where((a) => !_secili.contains(a))
                                    .toSet());
                            if (mounted) {
                              bildir(context,
                                  '"$_hedef" altında birleştirildi ($n sipariş)');
                            }
                          }),
                ),
              ),
            ],
          ),
          if (_secili.length >= 2)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                  '$birlesecek sipariş "$_hedef" adında toplanacak.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12.5, color: Renk.soluk)),
            ),
        ],
      ),
    );
  }
}
