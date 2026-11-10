import 'package:flutter/material.dart';

import '../bicim.dart';
import '../modeller.dart';
import '../servis/veri.dart';
import '../tema.dart';
import 'listeler.dart';

/// Üst çubuktaki "Bul": müşteri, ürün, aracı, sipariş no ya da notta arar.
class AramaEkrani extends StatefulWidget {
  const AramaEkrani({super.key, required this.durum});
  final Durum durum;

  @override
  State<AramaEkrani> createState() => _AramaEkraniState();
}

class _AramaEkraniState extends State<AramaEkrani> {
  final _ara = TextEditingController();

  @override
  void dispose() {
    _ara.dispose();
    super.dispose();
  }

  void _yaz(String v) {
    _ara.text = v;
    _ara.selection = TextSelection.collapsed(offset: v.length);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _ara,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          textInputAction: TextInputAction.search,
          cursorColor: Colors.white,
          style: const TextStyle(color: Colors.white, fontSize: 17),
          decoration: InputDecoration(
            hintText: 'Müşteri, ürün, aracı, sipariş no…',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: .75)),
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        actions: [
          if (_ara.text.isNotEmpty)
            IconButton(
              tooltip: 'Temizle',
              icon: const Icon(Icons.close),
              onPressed: () => _yaz(''),
            ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.durum,
        builder: (context, _) {
          final d = widget.durum;
          final q = araMetni(_ara.text);

          if (q.isEmpty) {
            // Son çalışılan müşteriler ve aracılar: dokununca aranır.
            final musteriler = <String>[];
            final aracilar = <String>[];
            for (final s in d.siparisler) {
              final m = s.musteri.trim();
              if (m.isNotEmpty && !musteriler.contains(m) && musteriler.length < 12) {
                musteriler.add(m);
              }
              final a = s.araci.trim();
              if (a.isNotEmpty && !aracilar.contains(a) && aracilar.length < 8) {
                aracilar.add(a);
              }
            }
            Widget grup(String baslik, IconData ikon, List<String> l) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(2, 6, 2, 8),
                      child: Text(baslik,
                          style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: Renk.soluk)),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final x in l)
                          ActionChip(
                            avatar: Icon(ikon, size: 18, color: Renk.anaKoyu),
                            label: Text(x),
                            onPressed: () => _yaz(x),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                );
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (musteriler.isNotEmpty)
                  grup('Son müşteriler', Icons.person_outline, musteriler),
                if (aracilar.isNotEmpty)
                  grup('Aracılar', Icons.handshake_outlined, aracilar),
                const BosDurum(
                    ikon: Icons.search,
                    yazi:
                        'Müşteri adı, ürün, aracı, sipariş numarası ya da nota göre arayın.\nı/i, ş/s gibi harf farkları önemli değil.'),
              ],
            );
          }

          final sonuc =
              d.siparisler.where((s) => aramadaEslesir(s, _ara.text)).toList();

          final toplam = sonuc.fold(0.0, (a, s) => a + s.toplam);
          final kalan = sonuc.fold(0.0, (a, s) => a + s.kalan);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              if (sonuc.isEmpty)
                const BosDurum(
                    ikon: Icons.search_off,
                    yazi: 'Eşleşen sipariş bulunamadı.')
              else ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
                  child: Text(
                    '${sonuc.length} sipariş · Toplam ${tl(toplam)}'
                    '${kalan > 0 ? ' · Kalan ${tl(kalan)}' : ''}',
                    style: const TextStyle(fontSize: 13.5, color: Renk.soluk),
                  ),
                ),
                for (final s in sonuc) SiparisKarti(durum: d, s: s),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Bir siparişin aramada eşleşip eşleşmediği (#12 ya da 12: sipariş no).
bool aramadaEslesir(Siparis s, String sorgu) {
  final q = araMetni(sorgu);
  if (q.isEmpty) return true;
  final no = q.replaceAll('#', '');
  if (no.isNotEmpty && int.tryParse(no) == s.no) return true;
  return araMetni('${s.musteri} ${s.urun} ${s.araci} ${s.not} ${s.birim}')
      .contains(q);
}
