import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../bicim.dart';
import '../modeller.dart';
import '../servis/veri.dart';
import '../tema.dart';

/// Ürünü WhatsApp mesajında ya da Durum'da paylaşmak için: hazır görsel kart,
/// çekilen ya da galeriden seçilen video/fotoğraf ve açıklama metni.
class PaylasEkrani extends StatefulWidget {
  const PaylasEkrani({super.key, required this.durum});
  final Durum durum;

  @override
  State<PaylasEkrani> createState() => _PaylasEkraniState();
}

class _PaylasEkraniState extends State<PaylasEkrani> {
  final _kart = GlobalKey();
  final _fiyat = TextEditingController();
  final _aciklama =
      TextEditingController(text: 'Taze ve kaliteli. Siparişlerinizi bekliyoruz.');
  final _telefon = TextEditingController();
  Urun? _urun;
  bool _mesgul = false;

  @override
  void initState() {
    super.initState();
    final l = widget.durum.firma?.urunler ?? const <Urun>[];
    if (l.isNotEmpty) _urunSec(l.first);
    SharedPreferences.getInstance().then((p) {
      final t = p.getString('paylas_telefon') ?? '';
      if (mounted && t.isNotEmpty) setState(() => _telefon.text = t);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _fiyat.dispose();
    _aciklama.dispose();
    _telefon.dispose();
    super.dispose();
  }

  void _urunSec(Urun u) {
    _urun = u;
    _fiyat.text = u.fiyat == null ? '' : sayi(u.fiyat!);
  }

  String get _firmaAdi {
    final a = widget.durum.firma?.ad.trim() ?? '';
    return a.isEmpty ? 'Keleş Tarım' : a;
  }

  String get _birim => _urun?.birim ?? 'kg';

  String get _metin {
    final u = _urun;
    final b = StringBuffer('🌾 *$_firmaAdi*\n');
    if (u != null) {
      b.write('${u.em} *${u.ad}*');
      if (_fiyat.text.trim().isNotEmpty) b.write(' — ${_fiyat.text.trim()} ₺ / $_birim');
      b.write('\n');
    }
    if (_aciklama.text.trim().isNotEmpty) b.write('${_aciklama.text.trim()}\n');
    if (_telefon.text.trim().isNotEmpty) {
      b.write('📞 Sipariş için: ${_telefon.text.trim()}');
    }
    return b.toString().trim();
  }

  Future<void> _telefonuSakla() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('paylas_telefon', _telefon.text.trim());
    } catch (_) {}
  }

  Future<void> _paylas(List<XFile> dosyalar) async {
    await _telefonuSakla();
    await Clipboard.setData(ClipboardData(text: _metin));
    await SharePlus.instance.share(ShareParams(files: dosyalar, text: _metin));
    if (mounted) {
      bildir(context,
          'Açıklama panoya da kopyalandı; Durum\'da yazı alanına yapıştırabilirsiniz.');
    }
  }

  Future<void> _calistir(Future<void> Function() is_) async {
    if (_mesgul) return;
    setState(() => _mesgul = true);
    try {
      await is_();
    } catch (e) {
      if (mounted) bildir(context, 'Paylaşılamadı: $e');
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  Future<void> _kartiPaylas() => _calistir(() async {
        final r = _kart.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final img = await r.toImage(pixelRatio: 3);
        final veri = await img.toByteData(format: ui.ImageByteFormat.png);
        final klasor = await getTemporaryDirectory();
        final ad = (_urun?.ad ?? 'urun').replaceAll(RegExp(r'[^A-Za-z0-9ğüşıöçĞÜŞİÖÇ]+'), '-');
        final f = File('${klasor.path}/keles-$ad.png');
        await f.writeAsBytes(veri!.buffer.asUint8List());
        await _paylas([XFile(f.path, mimeType: 'image/png')]);
      });

  Future<void> _videoCek() => _calistir(() async {
        final v = await ImagePicker().pickVideo(
            source: ImageSource.camera, maxDuration: const Duration(seconds: 90));
        if (v != null) await _paylas([v]);
      });

  Future<void> _galeridenSec() => _calistir(() async {
        final m = await ImagePicker().pickMedia();
        if (m != null) await _paylas([m]);
      });

  @override
  Widget build(BuildContext context) {
    final urunler = widget.durum.firma?.urunler ?? const <Urun>[];
    return Scaffold(
      appBar: AppBar(title: const Text('WhatsApp\'ta paylaş')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 40),
        children: [
          Panel(
            baslik: 'Ürün ve açıklama',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (urunler.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final u in urunler)
                        ChoiceChip(
                          label: Text('${u.em} ${u.ad}'),
                          selected: _urun?.ad == u.ad,
                          onSelected: (_) => setState(() => _urunSec(u)),
                        ),
                    ],
                  )
                else
                  const Text('Ayarlar → Ürünler bölümünden ürün ekleyin.',
                      style: TextStyle(color: Renk.soluk)),
                const SizedBox(height: 10),
                TextField(
                  controller: _fiyat,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                      labelText: 'Fiyat (₺ / $_birim)', hintText: 'Boş bırakılabilir'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _aciklama,
                  maxLines: 3,
                  maxLength: 160,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Anlatım'),
                ),
                TextField(
                  controller: _telefon,
                  keyboardType: TextInputType.phone,
                  onChanged: (_) => setState(() {}),
                  decoration:
                      const InputDecoration(labelText: 'Sipariş telefonu'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text('Durum için hazır kart',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: Renk.yazi)),
          const SizedBox(height: 8),
          Center(
            child: SizedBox(
              width: 220,
              height: 391,
              child: FittedBox(
                child: RepaintBoundary(
                  key: _kart,
                  child: _DurumKarti(
                    firma: _firmaAdi,
                    urun: _urun,
                    fiyat: _fiyat.text.trim(),
                    birim: _birim,
                    aciklama: _aciklama.text.trim(),
                    telefon: _telefon.text.trim(),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Buton(
            yazi: 'Kartı paylaş',
            ikon: Icons.image_outlined,
            mesgul: _mesgul,
            onTap: _mesgul ? null : _kartiPaylas,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Buton(
                  yazi: 'Video çek',
                  ikon: Icons.videocam_outlined,
                  renk: ButonRenk.ikincil,
                  onTap: _mesgul ? null : _videoCek,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Buton(
                  yazi: 'Galeriden seç',
                  ikon: Icons.photo_library_outlined,
                  renk: ButonRenk.ikincil,
                  onTap: _mesgul ? null : _galeridenSec,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _metin));
              if (context.mounted) bildir(context, 'Açıklama kopyalandı');
            },
            icon: const Icon(Icons.copy),
            label: const Text('Sadece açıklamayı kopyala'),
          ),
          const SizedBox(height: 6),
          const Text(
            'Paylaş ekranında WhatsApp\'ı seçin. Durum için listenin en üstündeki "Durumum"u, mesaj için kişiyi ya da grubu seçin. Açıklama yazısı mesaja kendiliğinden eklenir; Durum\'da yazı alanına yapıştırabilirsiniz.',
            style: TextStyle(fontSize: 12.5, color: Renk.soluk),
          ),
        ],
      ),
    );
  }
}

/// 9:16 boyutunda (1080 × 1920) Durum görseli.
class _DurumKarti extends StatelessWidget {
  const _DurumKarti({
    required this.firma,
    required this.urun,
    required this.fiyat,
    required this.birim,
    required this.aciklama,
    required this.telefon,
  });
  final String firma;
  final Urun? urun;
  final String fiyat, birim, aciklama, telefon;

  @override
  Widget build(BuildContext context) => Container(
        width: 360,
        height: 640,
        color: const Color(0xFF1F6F4A),
        padding: const EdgeInsets.fromLTRB(26, 40, 26, 34),
        child: Column(
          children: [
            Image.asset('assets/logo.png', width: 92, height: 92),
            const SizedBox(height: 10),
            Text(firma.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5)),
            Container(
                width: 70,
                height: 3,
                margin: const EdgeInsets.only(top: 8),
                color: const Color(0xFFFFC928)),
            const Spacer(),
            if (urun != null) ...[
              Text(urun!.em, style: const TextStyle(fontSize: 64)),
              const SizedBox(height: 6),
              Text(urun!.ad,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      height: 1.1)),
            ],
            if (fiyat.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                decoration: BoxDecoration(
                    color: const Color(0xFFFFC928),
                    borderRadius: BorderRadius.circular(30)),
                child: Text('$fiyat ₺ / $birim',
                    style: const TextStyle(
                        color: Color(0xFF1F2937),
                        fontSize: 30,
                        fontWeight: FontWeight.w800)),
              ),
            ],
            if (aciklama.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(aciklama,
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  style: const TextStyle(
                      color: Color(0xFFDFF3F1), fontSize: 18, height: 1.35)),
            ],
            const Spacer(),
            if (telefon.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    const Text('Sipariş için',
                        style: TextStyle(color: Color(0xFF1F6F4A), fontSize: 14)),
                    Text('📞 $telefon',
                        style: const TextStyle(
                            color: Color(0xFF1F6F4A),
                            fontSize: 24,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
          ],
        ),
      );
}
