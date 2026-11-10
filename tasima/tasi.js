// Keleş Satış: eski Firebase projesinden (egitim-takip-5a833) yenisine
// (keles-satis) kullanıcı hesaplarını ve satis_* verilerini taşır.
//
// Kullanım:  node tasi.js kontrol   -> hiçbir şey yazmaz, yalnızca sayar/kontrol eder
//            node tasi.js tasi      -> hesapları ve verileri kopyalar, kuralları yayınlar
//
// Ortam:     ESKI_ANAHTAR, YENI_ANAHTAR  (servis hesabı JSON dosya yolları)
//
// Hesaplar aynı kullanıcı kimliği (uid) ve aynı şifreyle taşınır; böylece
// firma üyelikleri ve siparişlerdeki "olusturan" bilgileri olduğu gibi kalır.
'use strict';

const fs = require('fs');
const path = require('path');
const { initializeApp, cert } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore } = require('firebase-admin/firestore');
const { getSecurityRules } = require('firebase-admin/security-rules');

const MOD = process.argv[2];
if (!['kontrol', 'tasi'].includes(MOD)) {
  console.error('Kullanım: node tasi.js kontrol|tasi');
  process.exit(2);
}

const ESKI_PROJE = 'egitim-takip-5a833';
const YENI_PROJE = 'keles-satis';
const KOK_KOLEKSIYONLAR = ['satis_kullanicilar', 'satis_kodlar', 'satis_firmalar', 'satis_hareketleri'];

function oku(p) { return JSON.parse(fs.readFileSync(p, 'utf8')); }
const eskiSA = oku(process.env.ESKI_ANAHTAR);
const yeniSA = oku(process.env.YENI_ANAHTAR);

const hatalar = [];
function hata(m) { hatalar.push(m); console.log('HATA: ' + m); }

if (eskiSA.project_id !== ESKI_PROJE) hata(`Eski anahtar ${eskiSA.project_id} projesine ait, ${ESKI_PROJE} olmalı.`);
if (yeniSA.project_id !== YENI_PROJE) hata(`Yeni anahtar ${yeniSA.project_id} projesine ait, ${YENI_PROJE} olmalı.`);
if (hatalar.length) process.exit(1);

const eski = initializeApp({ credential: cert(eskiSA), projectId: ESKI_PROJE }, 'eski');
const yeni = initializeApp({ credential: cert(yeniSA), projectId: YENI_PROJE }, 'yeni');
const eskiDb = getFirestore(eski);
const yeniDb = getFirestore(yeni);

async function token(app) {
  return (await app.options.credential.getAccessToken()).access_token;
}

async function kimlikAyari(app, proje, yama) {
  const url = `https://identitytoolkit.googleapis.com/admin/v2/projects/${proje}/config` +
    (yama ? '?updateMask=signIn.email.enabled,signIn.email.passwordRequired' : '');
  const r = await fetch(url, {
    method: yama ? 'PATCH' : 'GET',
    headers: { Authorization: 'Bearer ' + await token(app), 'Content-Type': 'application/json' },
    body: yama ? JSON.stringify(yama) : undefined,
  });
  const j = await r.json();
  if (!r.ok) throw new Error(`${proje} kimlik ayarı okunamadı: ${r.status} ${JSON.stringify(j).slice(0, 300)}`);
  return j;
}

// ---- Firestore: belgeleri alt koleksiyonlarıyla birlikte gez -------------
async function gez(koleksiyon, ziyaret) {
  const refler = await koleksiyon.listDocuments(); // alt koleksiyonu olan "boş" belgeler dahil
  for (let i = 0; i < refler.length; i += 300) {
    const parca = refler.slice(i, i + 300);
    const anlik = await eskiDb.getAll(...parca);
    for (const s of anlik) {
      if (s.exists) await ziyaret(s);
      for (const alt of await s.ref.listCollections()) await gez(alt, ziyaret);
    }
  }
}

async function main() {
  console.log(`== Mod: ${MOD}`);

  // 1) Keleş Satış kullanıcıları (satis_kullanicilar ve firma üyelikleri)
  const uidler = new Set();
  (await eskiDb.collection('satis_kullanicilar').listDocuments()).forEach((r) => uidler.add(r.id));
  for (const f of (await eskiDb.collection('satis_firmalar').get()).docs) {
    const d = f.data();
    for (const k of ['uyeler', 'yoneticiler', 'saha']) (d[k] || []).forEach((u) => uidler.add(u));
    if (d.sahip) uidler.add(d.sahip);
  }
  console.log(`Keleş Satış kullanıcı kimliği: ${uidler.size}`);

  const kullanicilar = [];
  let sayfa;
  do {
    const r = await getAuth(eski).listUsers(1000, sayfa);
    r.users.forEach((u) => { if (uidler.has(u.uid)) kullanicilar.push(u); });
    sayfa = r.pageToken;
  } while (sayfa);
  const sifresiz = kullanicilar.filter((u) => !u.passwordHash);
  console.log(`Taşınacak hesap: ${kullanicilar.length} (şifre bilgisi olmayan: ${sifresiz.length})`);
  sifresiz.forEach((u) => console.log(`  şifresiz: ${u.email || u.uid}`));
  const bulunamayan = [...uidler].filter((u) => !kullanicilar.some((k) => k.uid === u));
  if (bulunamayan.length) console.log(`Verilerde olup hesabı olmayan kimlik: ${bulunamayan.length}`);

  // 2) Şifre karma ayarı (eski proje) ve yeni projenin giriş ayarı
  const eskiAyar = await kimlikAyari(eski, ESKI_PROJE);
  const hc = eskiAyar.signIn && eskiAyar.signIn.hashConfig;
  if (!hc || hc.algorithm !== 'SCRYPT') hata('Eski projenin şifre karma ayarı alınamadı.');
  else console.log(`Şifre karma ayarı alındı (SCRYPT, rounds=${hc.rounds}, memoryCost=${hc.memoryCost}).`);

  const yeniAyar = await kimlikAyari(yeni, YENI_PROJE);
  const epostaAcik = !!(yeniAyar.signIn && yeniAyar.signIn.email && yeniAyar.signIn.email.enabled);
  console.log(`Yeni projede e-posta/şifre girişi: ${epostaAcik ? 'açık' : 'KAPALI (taşımada açılacak)'}`);
  const yeniHesap = await getAuth(yeni).listUsers(1);
  console.log(`Yeni projede şu an hesap var mı: ${yeniHesap.users.length ? 'evet' : 'hayır'}`);

  // 3) Firestore: eski projedeki belge sayıları, yeni projenin durumu
  const sayac = {};
  for (const k of KOK_KOLEKSIYONLAR) {
    await gez(eskiDb.collection(k), async (s) => {
      const tur = s.ref.parent.id;
      sayac[tur] = (sayac[tur] || 0) + 1;
    });
  }
  console.log('Eski projedeki belgeler: ' + JSON.stringify(sayac));

  try {
    const mevcut = await yeniDb.listCollections();
    console.log(`Yeni projenin veritabanı erişilebilir. Kök koleksiyonlar: ${mevcut.map((c) => c.id).join(', ') || '(boş)'}`);
  } catch (e) {
    hata(`Yeni projenin Firestore veritabanına erişilemedi (oluşturulmamış olabilir): ${e.message}`);
  }

  if (MOD === 'kontrol') {
    console.log(hatalar.length ? `\n${hatalar.length} sorun var.` : '\nKONTROL TAMAM: taşımaya hazır.');
    process.exit(hatalar.length ? 1 : 0);
  }
  if (hatalar.length) process.exit(1);

  // ---- TAŞIMA ------------------------------------------------------------
  // a) E-posta/şifre girişini yeni projede aç
  if (!epostaAcik) {
    await kimlikAyari(yeni, YENI_PROJE, { signIn: { email: { enabled: true, passwordRequired: true } } });
    console.log('Yeni projede e-posta/şifre girişi açıldı.');
  }

  // b) Hesaplar (aynı uid ve şifre)
  const kayitlar = kullanicilar.map((u) => {
    const k = {
      uid: u.uid,
      email: u.email,
      emailVerified: u.emailVerified,
      displayName: u.displayName,
      disabled: u.disabled,
    };
    const md = {};
    if (u.metadata.creationTime) md.creationTime = u.metadata.creationTime;
    if (u.metadata.lastSignInTime) md.lastSignInTime = u.metadata.lastSignInTime;
    if (Object.keys(md).length) k.metadata = md;
    if (u.passwordHash) {
      k.passwordHash = Buffer.from(u.passwordHash, 'base64');
      k.passwordSalt = Buffer.from(u.passwordSalt || '', 'base64');
    }
    Object.keys(k).forEach((a) => k[a] === undefined && delete k[a]);
    return k;
  });
  for (let i = 0; i < kayitlar.length; i += 1000) {
    const r = await getAuth(yeni).importUsers(kayitlar.slice(i, i + 1000), {
      hash: {
        algorithm: 'SCRYPT',
        key: Buffer.from(hc.signerKey, 'base64'),
        saltSeparator: Buffer.from(hc.saltSeparator || '', 'base64'),
        rounds: hc.rounds,
        memoryCost: hc.memoryCost,
      },
    });
    console.log(`Hesap aktarımı: ${r.successCount} başarılı, ${r.failureCount} hatalı`);
    r.errors.forEach((e) => hata(`Hesap ${kayitlar[i + e.index].email || kayitlar[i + e.index].uid}: ${e.error.message}`));
  }

  // c) Veriler (aynı belge kimlikleri, aynı alanlar ve türler)
  const yazici = yeniDb.bulkWriter();
  yazici.onWriteError((e) => { hata(`Yazılamadı ${e.documentRef.path}: ${e.message}`); return false; });
  let yazilan = 0;
  for (const k of KOK_KOLEKSIYONLAR) {
    await gez(eskiDb.collection(k), async (s) => {
      yazici.set(yeniDb.doc(s.ref.path), s.data());
      yazilan++;
    });
  }
  await yazici.close();
  console.log(`Kopyalanan belge: ${yazilan}`);

  // d) Doğrulama: yeni projedeki sayılar eskisiyle aynı mı
  const yeniSayac = {};
  async function yeniGez(kol) {
    for (const r of await kol.listDocuments()) {
      const s = await r.get();
      if (s.exists) yeniSayac[kol.id] = (yeniSayac[kol.id] || 0) + 1;
      for (const alt of await r.listCollections()) await yeniGez(alt);
    }
  }
  for (const k of KOK_KOLEKSIYONLAR) await yeniGez(yeniDb.collection(k));
  console.log('Yeni projedeki belgeler: ' + JSON.stringify(yeniSayac));
  for (const t of Object.keys(sayac)) {
    if ((yeniSayac[t] || 0) < sayac[t]) hata(`${t}: eski ${sayac[t]}, yeni ${yeniSayac[t] || 0}`);
  }

  // e) Güvenlik kuralları
  try {
    const kaynak = fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8');
    await getSecurityRules(yeni).releaseFirestoreRulesetFromSource(kaynak);
    console.log('Yeni projeye güvenlik kuralları yayınlandı.');
  } catch (e) {
    hata(`Kurallar yayınlanamadı (Console'dan elle yapıştırın): ${e.message}`);
  }

  console.log(hatalar.length ? `\nTAŞIMA BİTTİ, ${hatalar.length} sorun var.` : '\nTAŞIMA TAMAM.');
  process.exit(hatalar.length ? 1 : 0);
}

main().catch((e) => { console.error('HATA: ' + (e.stack || e)); process.exit(1); });
