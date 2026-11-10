/**
 * Uygulama Yedekleri — her gün tüm Firebase verisini Google Drive'a yedekler.
 *
 * İLK KURULUM (bir kere):
 *   1. Üstteki fonksiyon listesinden "kurulum"u seçip ▶ Çalıştır'a bas.
 *   2. İzin ekranında hesabını seç → "Gelişmiş" → "... (güvenli değil) sayfasına git" → İzin ver.
 *      (Bu betik senin kendi betiğin olduğu için Google bu uyarıyı gösterir.)
 *   3. Bitti. Her gece 03:00 civarında otomatik çalışır, ilk yedeği de hemen alır.
 *
 * Yedekler Drive'da "Uygulama Yedekleri/<proje>/" klasörüne gider.
 * Son 30 günün yedeği tutulur, daha eskiler çöp kutusuna taşınır.
 * Bir gün yedek alınamazsa Google sana e-posta ile bildirir.
 */

// Yedeklenecek Firebase projeleri. Yeni proje açınca buraya ekle.
const PROJELER = ['egitim-takip-5a833', 'keles-satis'];
const ANA_KLASOR = 'Uygulama Yedekleri';
const SAKLAMA_GUNU = 30;

function kurulum() {
  ScriptApp.getProjectTriggers()
    .filter(t => t.getHandlerFunction() === 'gunlukYedek')
    .forEach(t => ScriptApp.deleteTrigger(t));
  ScriptApp.newTrigger('gunlukYedek').timeBased().everyDays(1).atHour(3).create();
  gunlukYedek();
}

function gunlukYedek() {
  const hatalar = [];
  for (const proje of PROJELER) {
    try {
      projeyiYedekle_(proje);
    } catch (e) {
      hatalar.push(proje + ': ' + e.message);
    }
  }
  if (hatalar.length) throw new Error('Yedek alınamayan projeler:\n' + hatalar.join('\n'));
}

function projeyiYedekle_(proje) {
  const kok = `projects/${proje}/databases/(default)/documents`;
  const belgeler = [];
  // Kökteki koleksiyonlar, sonra her belgenin alt koleksiyonları (tüm derinlik).
  let kuyruk = listCollectionIds_([kok])[0].map(c => `${kok}/${c}`);
  while (kuyruk.length) {
    const yeniBelgeler = [];
    for (const kol of kuyruk) {
      for (const b of listeleTumBelgeler_(kol)) {
        belgeler.push(b);
        yeniBelgeler.push(b.name);
      }
    }
    kuyruk = [];
    for (let i = 0; i < yeniBelgeler.length; i += 50) {
      const parca = yeniBelgeler.slice(i, i + 50);
      listCollectionIds_(parca).forEach((koller, j) =>
        koller.forEach(c => kuyruk.push(`${parca[j]}/${c}`)));
    }
  }

  const veri = {
    proje,
    tarih: new Date().toISOString(),
    belgeSayisi: belgeler.length,
    kullanicilar: kullanicilar_(proje),
    // Firestore REST biçimi (türler korunur, geri yüklemeye uygundur).
    belgeler: belgeler.map(b => ({ yol: b.name.slice(kok.length + 1), alanlar: b.fields || {},
                                   olusturma: b.createTime, guncelleme: b.updateTime })),
  };

  const klasor = klasor_([ANA_KLASOR, proje]);
  const ad = `${proje}-yedek-${Utilities.formatDate(new Date(), 'Europe/Istanbul', 'yyyy-MM-dd')}.json`;
  const eski = klasor.getFilesByName(ad);
  while (eski.hasNext()) eski.next().setTrashed(true);
  klasor.createFile(ad, JSON.stringify(veri), 'application/json');
  eskileriTemizle_(klasor);
}

function istek_(url, secenek) {
  const yanit = UrlFetchApp.fetch(url, Object.assign({
    headers: { Authorization: 'Bearer ' + ScriptApp.getOAuthToken() },
    muteHttpExceptions: true, contentType: 'application/json',
  }, secenek || {}));
  const kod = yanit.getResponseCode();
  if (kod >= 300) throw new Error(`HTTP ${kod}: ${yanit.getContentText().slice(0, 300)}`);
  return JSON.parse(yanit.getContentText() || '{}');
}

function listeleTumBelgeler_(koleksiyonYolu) {
  const sonuc = [];
  let token = '';
  do {
    const url = `https://firestore.googleapis.com/v1/${koleksiyonYolu}?pageSize=300&showMissing=true`
      + (token ? '&pageToken=' + encodeURIComponent(token) : '');
    const y = istek_(url);
    (y.documents || []).forEach(d => sonuc.push(d));
    token = y.nextPageToken || '';
  } while (token);
  return sonuc;
}

function listCollectionIds_(ustYollar) {
  const istekler = ustYollar.map(y => ({
    url: `https://firestore.googleapis.com/v1/${y}:listCollectionIds`,
    method: 'post', contentType: 'application/json', muteHttpExceptions: true,
    headers: { Authorization: 'Bearer ' + ScriptApp.getOAuthToken() },
    payload: JSON.stringify({ pageSize: 300 }),
  }));
  return UrlFetchApp.fetchAll(istekler).map((r, i) => {
    if (r.getResponseCode() >= 300)
      throw new Error(`HTTP ${r.getResponseCode()} (${ustYollar[i]}): ${r.getContentText().slice(0, 300)}`);
    return JSON.parse(r.getContentText() || '{}').collectionIds || [];
  });
}

// Giriş hesapları (e-posta, kimlik, şifre özeti). Yeni projeye taşımada gerekir.
function kullanicilar_(proje) {
  try {
    const liste = [];
    let token = '';
    do {
      const url = `https://identitytoolkit.googleapis.com/v1/projects/${proje}/accounts:batchGet?maxResults=1000`
        + (token ? '&nextPageToken=' + encodeURIComponent(token) : '');
      const y = istek_(url, { headers: { Authorization: 'Bearer ' + ScriptApp.getOAuthToken(),
                                         'X-Goog-User-Project': proje } });
      (y.users || []).forEach(u => liste.push(u));
      token = y.nextPageToken || '';
    } while (token);
    return liste;
  } catch (e) {
    return { hata: e.message };
  }
}

function klasor_(yol) {
  let k = DriveApp.getRootFolder();
  for (const ad of yol) {
    const it = k.getFoldersByName(ad);
    k = it.hasNext() ? it.next() : k.createFolder(ad);
  }
  return k;
}

function eskileriTemizle_(klasor) {
  const sinir = Date.now() - SAKLAMA_GUNU * 24 * 3600 * 1000;
  const it = klasor.getFiles();
  while (it.hasNext()) {
    const f = it.next();
    if (f.getDateCreated().getTime() < sinir) f.setTrashed(true);
  }
}
