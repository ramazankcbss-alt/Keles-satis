import 'package:flutter/material.dart';

/// Kurumsal, açık renkli tema: turkuaz ana renk, beyaz kartlar, sade butonlar.
class Renk {
  static const ana = Color(0xFF0E9E9B); // turkuaz
  static const anaKoyu = Color(0xFF0A7C7A);
  static const anaAcik = Color(0xFFE2F4F3);

  static const zemin = Color(0xFFF3F6F7);
  static const kart = Colors.white;
  static const cizgi = Color(0xFFE2E8EC);
  static const yazi = Color(0xFF1E293B);
  static const soluk = Color(0xFF64748B);

  static const yesil = Color(0xFF15803D);
  static const yesilAcik = Color(0xFFDCFCE7);
  static const mavi = Color(0xFF1D4ED8);
  static const maviAcik = Color(0xFFDBEAFE);
  static const amber = Color(0xFFB45309);
  static const amberAcik = Color(0xFFFEF3C7);
  static const turuncu = Color(0xFFC2410C);
  static const turuncuAcik = Color(0xFFFFEDD5);
  static const kirmizi = Color(0xFFDC2626);
  static const kirmiziAcik = Color(0xFFFEE2E2);
}

ThemeData temaOlustur() {
  final cs = ColorScheme.fromSeed(
    seedColor: Renk.ana,
    brightness: Brightness.light,
  ).copyWith(
    primary: Renk.ana,
    onPrimary: Colors.white,
    primaryContainer: Renk.anaAcik,
    onPrimaryContainer: Renk.anaKoyu,
    secondaryContainer: Renk.anaAcik,
    onSecondaryContainer: Renk.anaKoyu,
    surface: Renk.kart,
    onSurface: Renk.yazi,
    onSurfaceVariant: Renk.soluk,
    outline: const Color(0xFFCBD5DC),
    outlineVariant: Renk.cizgi,
    error: Renk.kirmizi,
  );
  final kenar = OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: Color(0xFFCBD5DC)),
  );
  final yuvarlak =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));
  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: Renk.zemin,
    dividerColor: Renk.cizgi,
    dividerTheme: const DividerThemeData(color: Renk.cizgi, space: 1, thickness: 1),
    appBarTheme: const AppBarTheme(
      backgroundColor: Renk.ana,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
          fontSize: 19, fontWeight: FontWeight.w600, color: Colors.white),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(color: Renk.soluk),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
      border: kenar,
      enabledBorder: kenar,
      focusedBorder:
          kenar.copyWith(borderSide: const BorderSide(color: Renk.ana, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 46),
        shape: yuvarlak,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 46),
        shape: yuvarlak,
        foregroundColor: Renk.yazi,
        side: const BorderSide(color: Color(0xFFCBD5DC)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: Renk.anaKoyu),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Renk.ana,
      foregroundColor: Colors.white,
      elevation: 2,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: Renk.anaAcik,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 68,
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? Renk.anaKoyu : Renk.soluk)),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
          fontSize: 12,
          fontWeight:
              s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? Renk.anaKoyu : Renk.soluk)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: Renk.anaAcik,
      side: const BorderSide(color: Renk.cizgi),
      labelStyle: const TextStyle(color: Renk.yazi, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      showCheckmark: false,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: Renk.anaAcik,
        selectedForegroundColor: Renk.anaKoyu,
      ),
    ),
    dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
    popupMenuTheme: const PopupMenuThemeData(color: Colors.white),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Renk.yazi,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: Renk.ana),
  );
}

void bildir(BuildContext context, String mesaj) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(mesaj)));
}

/// Beyaz, ince kenarlıklı kart; isteğe bağlı başlık ve sağda bir bağlantı.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    this.baslik,
    required this.child,
    this.margin,
    this.padding,
    this.eylem,
  });

  final String? baslik;
  final Widget child;
  final EdgeInsets? margin;
  final EdgeInsets? padding;
  final Widget? eylem;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Renk.kart,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Renk.cizgi),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (baslik != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(baslik!,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Renk.yazi)),
                  ),
                  if (eylem != null) eylem!,
                ],
              ),
              const SizedBox(height: 12),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

enum ButonRenk { birincil, ikincil, tehlike }

/// Sade buton: birincil (turkuaz dolu), ikincil (çerçeveli), tehlike (kırmızı).
class Buton extends StatelessWidget {
  const Buton({
    super.key,
    required this.yazi,
    this.renk = ButonRenk.birincil,
    required this.onTap,
    this.mesgul = false,
    this.ikon,
    this.yukseklik = 46,
  });

  final String yazi;
  final ButonRenk renk;
  final VoidCallback? onTap;
  final bool mesgul;
  final IconData? ikon;
  final double yukseklik;

  @override
  Widget build(BuildContext context) {
    final boyut = Size(64, yukseklik);
    final icerik = mesgul
        ? const SizedBox(
            width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4))
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (ikon != null) ...[Icon(ikon, size: 19), const SizedBox(width: 8)],
              Flexible(child: Text(yazi, overflow: TextOverflow.ellipsis)),
            ],
          );
    final tik = mesgul ? null : onTap;
    switch (renk) {
      case ButonRenk.birincil:
        return FilledButton(
            onPressed: tik,
            style: FilledButton.styleFrom(minimumSize: boyut),
            child: mesgul
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: Colors.white))
                : icerik);
      case ButonRenk.ikincil:
        return OutlinedButton(
            onPressed: tik,
            style: OutlinedButton.styleFrom(minimumSize: boyut),
            child: icerik);
      case ButonRenk.tehlike:
        return OutlinedButton(
            onPressed: tik,
            style: OutlinedButton.styleFrom(
              minimumSize: boyut,
              foregroundColor: Renk.kirmizi,
              side: const BorderSide(color: Color(0xFFFCA5A5)),
            ),
            child: icerik);
    }
  }
}

/// Küçük etiket + değer (sipariş kartındaki fiyat / toplam / kalan).
class Cip extends StatelessWidget {
  const Cip({super.key, required this.ust, required this.deger, this.durum});

  final String ust;
  final String deger;

  /// null: normal, true: olumlu (yeşil), false: dikkat (kırmızı)
  final bool? durum;

  @override
  Widget build(BuildContext context) {
    final renk = durum == null
        ? Renk.yazi
        : durum!
            ? Renk.yesil
            : Renk.kirmizi;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(ust,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Renk.soluk)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(deger,
              maxLines: 1,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: renk)),
        ),
      ],
    );
  }
}

/// Renkli, sade durum etiketi.
class DurumEtiketi extends StatelessWidget {
  const DurumEtiketi(
      {super.key, required this.yazi, required this.renk, required this.zemin});
  final String yazi;
  final Color renk;
  final Color zemin;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration:
            BoxDecoration(color: zemin, borderRadius: BorderRadius.circular(6)),
        child: Text(yazi,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: renk)),
      );
}

/// Sayı rozeti (liste satırlarında).
class SayiRozeti extends StatelessWidget {
  const SayiRozeti({super.key, required this.sayi, this.vurgulu = false});
  final int sayi;
  final bool vurgulu;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 28),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: vurgulu && sayi > 0 ? Renk.ana : const Color(0xFFEFF3F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text('$sayi',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: vurgulu && sayi > 0 ? Colors.white : Renk.soluk)),
      );
}

class BosDurum extends StatelessWidget {
  const BosDurum({super.key, required this.ikon, required this.yazi});
  final IconData ikon;
  final String yazi;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 12),
        child: Column(
          children: [
            Icon(ikon, size: 44, color: const Color(0xFFB8C4CC)),
            const SizedBox(height: 10),
            Text(yazi,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Renk.soluk, fontSize: 15)),
          ],
        ),
      );
}

/// Alttan açılan form sayfası.
Future<T?> altSayfa<T>(BuildContext context,
    {required String baslik,
    String? aciklama,
    required WidgetBuilder builder}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, 20 + MediaQuery.of(ctx).viewPadding.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(baslik,
                style: const TextStyle(
                    fontSize: 19, fontWeight: FontWeight.w600, color: Renk.yazi)),
            if (aciklama != null) ...[
              const SizedBox(height: 4),
              Text(aciklama,
                  style: const TextStyle(color: Renk.soluk, fontSize: 14)),
            ],
            const SizedBox(height: 16),
            _BirKez(builder: builder),
          ],
        ),
      ),
    ),
  );
}

/// İçeriği yalnızca bir kez kurar; klavye açılıp kapanınca formdaki
/// denetleyiciler (yazılan metin) kaybolmaz.
class _BirKez extends StatefulWidget {
  const _BirKez({required this.builder});
  final WidgetBuilder builder;

  @override
  State<_BirKez> createState() => _BirKezState();
}

class _BirKezState extends State<_BirKez> {
  Widget? _icerik;

  @override
  Widget build(BuildContext context) => _icerik ??= widget.builder(context);
}

/// Yazarken öneri gösteren metin kutusu.
class OneriliAlan extends StatelessWidget {
  const OneriliAlan({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.secenekler,
    required this.etiket,
    this.ipucu,
    this.onSecildi,
    this.onDegisti,
    this.buyukHarf = TextCapitalization.sentences,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Iterable<String> secenekler;
  final String etiket;
  final String? ipucu;
  final ValueChanged<String>? onSecildi;
  final ValueChanged<String>? onDegisti;
  final TextCapitalization buyukHarf;

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode: focusNode,
      optionsBuilder: (v) {
        final q = v.text.trim().toLowerCase();
        if (q.isEmpty) return const Iterable<String>.empty();
        return secenekler
            .where((m) => m.toLowerCase().contains(q) && m.toLowerCase() != q)
            .take(8);
      },
      onSelected: (v) => onSecildi?.call(v),
      fieldViewBuilder: (c, ctrl, fn, gonder) => TextField(
        controller: ctrl,
        focusNode: fn,
        textCapitalization: buyukHarf,
        onChanged: onDegisti,
        decoration: InputDecoration(labelText: etiket, hintText: ipucu),
      ),
      optionsViewBuilder: (c, sec, liste) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          color: Colors.white,
          elevation: 6,
          borderRadius: BorderRadius.circular(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220, maxWidth: 360),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [
                for (final o in liste)
                  ListTile(dense: true, title: Text(o), onTap: () => sec(o)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ToplamKutusu extends StatelessWidget {
  const ToplamKutusu({super.key, required this.etiket, required this.deger});
  final String etiket;
  final String deger;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Renk.anaAcik,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
                child: Text(etiket,
                    style: const TextStyle(color: Renk.anaKoyu, fontSize: 14))),
            Text(deger,
                style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: Renk.anaKoyu)),
          ],
        ),
      );
}

/// Renkli özet hapı (açık zemin, renkli çerçeve, emoji): ana sayfanın
/// üstündeki toplamlar için.
class Hap extends StatelessWidget {
  const Hap({
    super.key,
    required this.emoji,
    required this.deger,
    required this.etiket,
    required this.renk,
    required this.zemin,
    this.onTap,
  });

  final String emoji;
  final String deger;
  final String etiket;
  final Color renk;
  final Color zemin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: zemin,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: renk.withValues(alpha: .55), width: 2),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(deger,
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Renk.yazi)),
                      ),
                      Text(
                          etiket
                              .replaceAll('i', 'İ')
                              .replaceAll('ı', 'I')
                              .toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .4,
                              color: renk)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

/// Renkli kutucuk: üstte küçük bilgi, ortada emoji, altta başlık.
class RenkliKutu extends StatelessWidget {
  const RenkliKutu({
    super.key,
    required this.emoji,
    required this.baslik,
    required this.renk,
    required this.zemin,
    required this.onTap,
    this.ust,
  });

  final String emoji;
  final String baslik;
  final String? ust;
  final Color renk;
  final Color zemin;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: zemin,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: renk.withValues(alpha: .45), width: 2),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (ust != null) ...[
                  Text(ust!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Renk.yazi)),
                  Container(
                    height: 1.5,
                    margin: const EdgeInsets.fromLTRB(10, 5, 10, 4),
                    color: renk.withValues(alpha: .25),
                  ),
                ],
                Text(emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(height: 3),
                Text(baslik,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        height: 1.15,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Renk.yazi)),
              ],
            ),
          ),
        ),
      );
}
