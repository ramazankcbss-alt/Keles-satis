import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../servis/guncelleme.dart';
import '../servis/veri.dart';
import '../tema.dart';
import 'ana.dart';
import 'giris.dart';
import 'saha.dart';

/// Oturum → profil → firma sırasıyla doğru ekranı gösterir.
class Kapi extends StatelessWidget {
  const Kapi({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, s) {
        if (s.connectionState == ConnectionState.waiting) {
          return const _Yukleniyor();
        }
        final u = s.data;
        if (u == null) return const GirisEkrani();
        return _ProfilKapi(key: ValueKey(u.uid), uid: u.uid);
      },
    );
  }
}

class _Yukleniyor extends StatelessWidget {
  const _Yukleniyor();
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
}

class _ProfilKapi extends StatefulWidget {
  const _ProfilKapi({super.key, required this.uid});
  final String uid;

  @override
  State<_ProfilKapi> createState() => _ProfilKapiState();
}

class _ProfilKapiState extends State<_ProfilKapi> {
  late final _akis = Veri.kullanicilar.doc(widget.uid).snapshots();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _akis,
      builder: (context, s) {
        if (s.hasError) {
          return _HataEkrani(yazi: hataYazisi(s.error!));
        }
        if (!s.hasData) return const _Yukleniyor();
        final d = s.data!.data() ?? {};
        final ad = (d['ad'] as String?) ?? '';
        final fid = (d['firmaId'] as String?) ?? '';
        if (fid.isEmpty) return KurulumEkrani(uid: widget.uid, ad: ad);
        return _FirmaKapi(key: ValueKey(fid), uid: widget.uid, fid: fid);
      },
    );
  }
}

class _FirmaKapi extends StatefulWidget {
  const _FirmaKapi({super.key, required this.uid, required this.fid});
  final String uid;
  final String fid;

  @override
  State<_FirmaKapi> createState() => _FirmaKapiState();
}

class _FirmaKapiState extends State<_FirmaKapi> {
  late Durum _durum = Durum(fid: widget.fid, uid: widget.uid);

  void _yenidenDene() {
    final eski = _durum;
    setState(() => _durum = Durum(fid: widget.fid, uid: widget.uid));
    eski.dispose();
  }

  @override
  void dispose() {
    _durum.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _durum,
      builder: (context, _) {
        final d = _durum;
        if (d.firmaHata != null || d.firmaYok || (d.firma != null && !d.uye && !d.saha)) {
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Panel(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.lock_outline, size: 48, color: Renk.soluk),
                        const SizedBox(height: 8),
                        const Text(
                          'Bu firmaya erişiminiz yok. Yönetici sizi çıkarmış ya da firma silinmiş olabilir.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 15, color: Renk.yazi),
                        ),
                        const SizedBox(height: 18),
                        Buton(
                          yazi: 'Tekrar dene',
                          ikon: Icons.refresh,
                          onTap: _yenidenDene,
                        ),
                        const SizedBox(height: 10),
                        Buton(
                          yazi: 'Başka firmaya katıl / yeni kur',
                          renk: ButonRenk.ikincil,
                          onTap: () => Veri.firmadanAyril(widget.uid),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                            onPressed: () => FirebaseAuth.instance.signOut(),
                            child: const Text('Çıkış yap')),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        if (d.firma == null) return const _Yukleniyor();
        return d.saha ? SahaKabuk(durum: d) : AnaKabuk(durum: d);
      },
    );
  }
}

class _HataEkrani extends StatelessWidget {
  const _HataEkrani({required this.yazi});
  final String yazi;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Renk.kirmizi),
                  const SizedBox(height: 10),
                  Text(yazi, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  TextButton(
                      onPressed: () => FirebaseAuth.instance.signOut(),
                      child: const Text('Çıkış yap')),
                ],
              ),
            ),
          ),
        ),
      );
}

/// İlk açılış: adınız + yeni firma kur ya da davet koduyla katıl.
class KurulumEkrani extends StatefulWidget {
  const KurulumEkrani({super.key, required this.uid, required this.ad});
  final String uid;
  final String ad;

  @override
  State<KurulumEkrani> createState() => _KurulumEkraniState();
}

class _KurulumEkraniState extends State<KurulumEkrani> {
  late final _ad = TextEditingController(text: widget.ad);
  final _kod = TextEditingController();
  final _firma = TextEditingController(text: 'Keleş Tarım');
  bool _kur = false;
  bool _mesgul = false;

  @override
  void initState() {
    super.initState();
    // Ekipten çıkarılmış ya da yeni katılan biri ana ekrana giremeden
    // burada kalır; eski sürümdeyse güncellemeyi burada da görsün.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Guncelleme.kontrolEt(context);
    });
  }

  @override
  void dispose() {
    _ad.dispose();
    _kod.dispose();
    _firma.dispose();
    super.dispose();
  }

  Future<void> _devam() async {
    final ad = _ad.text.trim();
    if (ad.length < 2) {
      bildir(context, 'Adınızı ve soyadınızı yazın.');
      return;
    }
    if (_kur && _firma.text.trim().length < 2) {
      bildir(context, 'Firma adını yazın.');
      return;
    }
    if (!_kur && _kod.text.trim().length < 6) {
      bildir(context, 'Yöneticiden aldığınız davet kodunu yazın.');
      return;
    }
    setState(() => _mesgul = true);
    try {
      if (_kur) {
        await Veri.firmaKur(widget.uid, ad, _firma.text);
      } else {
        await Veri.kodlaKatil(widget.uid, ad, _kod.text);
      }
    } catch (e) {
      if (mounted) bildir(context, hataYazisi(e));
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hoş geldiniz'),
        actions: [
          TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: () => FirebaseAuth.instance.signOut(),
              child: const Text('Çıkış')),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Panel(
              baslik: 'Adınız',
              child: TextField(
                controller: _ad,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    hintText: 'Örn. Ramazan Kocabaş',
                    prefixIcon: Icon(Icons.person_outline)),
              ),
            ),
            Panel(
              baslik: 'Firma',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Kodla katıl'), icon: Icon(Icons.group_add)),
                      ButtonSegment(value: true, label: Text('Yeni firma kur'), icon: Icon(Icons.store)),
                    ],
                    selected: {_kur},
                    onSelectionChanged: (s) => setState(() => _kur = s.first),
                  ),
                  const SizedBox(height: 14),
                  if (_kur) ...[
                    TextField(
                      controller: _firma,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Firma adı'),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Firmayı kuran kişi yönetici olur. Çalışanlarınızı Ayarlar → Ekip bölümündeki davet koduyla eklersiniz.',
                      style: TextStyle(color: Renk.soluk, fontSize: 13.5),
                    ),
                  ] else ...[
                    TextField(
                      controller: _kod,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                          labelText: 'Davet kodu', hintText: 'Örn. K7PX3MQA'),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Kodu firma yöneticisi Ayarlar → Ekip bölümünden size gönderir.',
                      style: TextStyle(color: Renk.soluk, fontSize: 13.5),
                    ),
                  ],
                ],
              ),
            ),
            Buton(
              yazi: _kur ? 'Firmayı Kur' : 'Firmaya Katıl',
              yukseklik: 54,
              mesgul: _mesgul,
              onTap: _devam,
            ),
            const SizedBox(height: 16),
            Text(
              Guncelleme.buSurum > 0
                  ? 'Uygulama sürümü: ${Guncelleme.buSurum}'
                  : 'Uygulama sürümü: geliştirme',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Renk.soluk, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}
