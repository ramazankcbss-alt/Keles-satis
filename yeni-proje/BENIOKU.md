# Yeni Firebase projesi (keles-satis) ayarları

Uygulama şu an hâlâ eski `egitim-takip-5a833` projesini kullanıyor
(`lib/firebase_options.dart`). Kullanıcı hesapları ve veriler yeni projeye
taşındıktan sonra bu klasördeki dosyalar yerine konur:

- `firebase_options.dart`   → `lib/firebase_options.dart`
- `google-services.json`    → (gerekirse) `android/app/google-services.json`

Kökteki `firestore.rules` yeni `keles-satis` projesi içindir. Taşıma bitene
kadar eski projedeki kurallar Eğitim Takip deposundaki birleşik dosyadan
yönetilir.
