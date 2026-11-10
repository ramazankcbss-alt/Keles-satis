# Keleş Satış (Android)

Keleş Tarım'ın satış ve ticaret takibi. Çok kullanıcılı: her çalışan kendi
telefonundan kendi hesabıyla girer, herkes aynı veriyi canlı görür.

## Akış

| Adım | Ne olur |
|---|---|
| **1. Sipariş** | Ortadaki ＋ ile müşteri, ürün, miktar, birim girilir. Hazır ürünler kare kutucuk olarak çıkar. |
| **2. Fiyat** | *Fiyat* sekmesinde kesin miktar ve birim fiyat yazılır; toplam anında hesaplanır. |
| **3. Teslim** | *Teslim* sekmesinde "Teslim Edildi" işaretlenir (isteğe bağlı not ve teslimde alınan para). |
| **4. Tahsilat** | *Tahsilat* sekmesinde alınan tutar (kısmi olabilir) ve yöntem (nakit, havale, çek…) girilir. Borç kapanınca sipariş *Tamamlanan*a geçer. |

Ana sayfada ciro, sipariş sayısı, alacak ve tahsil edilen tutar; müşteri
bakiyeleri ve ürün bazında satış özeti; her siparişte kimin ne zaman ne
yaptığı görünür.

## Ekip

- İlk giren kişi **"Yeni firma kur"** der ve yönetici olur.
- Yönetici **Ayarlar → Ekip** bölümündeki **davet kodunu** çalışanlara gönderir.
- Çalışan uygulamayı kurar, hesap açar, **"Kodla katıl"** deyip kodu yazar.
- Yönetici; firma adını, hazır ürünleri, birimleri değiştirir, başka birini
  yönetici yapar ya da ekipten çıkarır. Ekipten çıkarılan kişi verileri göremez.

## Teknik

- Flutter + Firebase (Auth + Firestore). Kendi Firebase projesi:
  **`keles-satis`** (10 Kasım 2026'da `egitim-takip-5a833` projesinden
  taşındı; ayrıntı: `yeni-proje/BENIOKU.md`).
- `firestore.rules` yalnızca Keleş Satış kurallarıdır. Değiştirince Firebase
  Console'da **keles-satis** projesini seçip Firestore → Kurallar'a dosyanın
  tamamını yapıştırın ve Yayınla deyin.
- Veriler her gece Google Drive'daki "Uygulama Yedekleri" klasörüne
  yedeklenir (betik: `yedek/betik/`, Google Apps Script).
- `main` dalına her gönderimde GitHub Actions APK derler ve **Releases**
  bölümüne koyar. Kurulu uygulama yeni sürümü kendisi bulup günceller.
- İmza: uygulamanın kendi anahtarı (`ci/keles-satis.p12`). Şifresi depo
  ayarlarında `KELES_KEYSTORE_PASSWORD` gizli değişkenindedir. Bu şifre
  kaybolursa telefondaki uygulama güncellenemez, bir yere not edin.
