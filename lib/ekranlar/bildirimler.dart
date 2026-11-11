import 'package:flutter/material.dart';

import '../bicim.dart';
import '../servis/bildirim.dart';
import '../servis/okundu.dart';
import '../servis/veri.dart';
import '../tema.dart';
import 'formlar.dart';

/// Zil simgesi: okunmamış bildirim sayısıyla. Dokununca Bildirimler açılır.
class BildirimZili extends StatelessWidget {
  const BildirimZili({super.key, required this.durum});
  final Durum durum;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([durum, Okundu.deger]),
        builder: (context, _) {
          final n = Okundu.sayi(durum);
          return IconButton(
            tooltip: 'Bildirimler',
            icon: Badge(
              isLabelVisible: n > 0,
              label: Text(n > 99 ? '99+' : '$n'),
              backgroundColor: Renk.kirmizi,
              child: Icon(n > 0
                  ? Icons.notifications_active
                  : Icons.notifications_outlined),
            ),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => BildirimlerEkrani(durum: durum))),
          );
        },
      );
}

/// Başkalarının yaptığı son işlemler. Açılınca hepsi okundu sayılır.
class BildirimlerEkrani extends StatefulWidget {
  const BildirimlerEkrani({super.key, required this.durum});
  final Durum durum;

  @override
  State<BildirimlerEkrani> createState() => _BildirimlerEkraniState();
}

class _BildirimlerEkraniState extends State<BildirimlerEkrani> {
  /// Ekran açılmadan önceki "son bakış": bundan yenileri "Yeni" görünür.
  late final int _onceki = Okundu.deger.value;

  @override
  void initState() {
    super.initState();
    Okundu.isaretle(widget.durum.fid, widget.durum.uid);
  }

  static const _ikonlar = {
    'siparis': ('🧾', Renk.mavi, Renk.maviAcik),
    'fiyat': ('🏷️', Renk.amber, Renk.amberAcik),
    'teslim': ('🚚', Renk.anaKoyu, Renk.anaAcik),
    'tahsilat': ('💵', Renk.yesil, Renk.yesilAcik),
  };

  @override
  Widget build(BuildContext context) {
    final d = widget.durum;
    return Scaffold(
      appBar: AppBar(title: const Text('Bildirimler')),
      body: ListenableBuilder(
        listenable: d,
        builder: (context, _) {
          final l = Okundu.hareketler(d).take(150).toList();
          final yeni = l.where((s) => s.sonIslemTarih > _onceki).length;
          if (l.isEmpty) {
            return const BosDurum(
                ikon: Icons.notifications_none,
                yazi: 'Henüz bildirim yok.\nEkipten biri sipariş, fiyat, teslim ya da tahsilat girince burada görünür.');
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 30),
            itemCount: l.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                  child: Text(
                      yeni > 0 ? '$yeni yeni bildirim' : 'Yeni bildirim yok',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Renk.soluk)),
                );
              }
              final s = l[i - 1];
              final yeniMi = s.sonIslemTarih > _onceki;
              final (baslik, metin) =
                  Hareketler.metinOlustur(s, d.isim(s.sonIslemBy));
              final ik = _ikonlar[s.sonIslemTur] ??
                  ('✏️', Renk.soluk, const Color(0xFFEFF3F5));
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: yeniMi ? const Color(0xFFFFFBEB) : Renk.kart,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: yeniMi ? const Color(0xFFFCD34D) : Renk.cizgi,
                      width: yeniMi ? 1.5 : 1),
                ),
                child: ListTile(
                  onTap: () => detayGoster(context, d, s),
                  leading: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: ik.$3, borderRadius: BorderRadius.circular(10)),
                    child: Text(ik.$1, style: const TextStyle(fontSize: 20)),
                  ),
                  title: Text(baslik,
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: yeniMi ? FontWeight.w700 : FontWeight.w600,
                          color: Renk.yazi)),
                  subtitle: Text(metin,
                      style: const TextStyle(fontSize: 13, color: Renk.soluk)),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(once(s.sonIslemTarih),
                          style: const TextStyle(
                              fontSize: 12, color: Renk.soluk)),
                      if (yeniMi)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                              color: Renk.kirmizi,
                              borderRadius: BorderRadius.circular(6)),
                          child: const Text('Yeni',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
