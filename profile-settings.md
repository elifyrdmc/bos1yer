# Profil ve ayarlar — tarihsel uygulama notları

> **Durum notu — 14 Kasım 2026:** Bu belge 30 Ekim 2026'daki yerel profil prototipini ve o tarihteki test/cihaz sonuçlarını kaydeder; tüm bölümler güncel uygulama durumu değildir. Hesap, rapor, katkı geçmişi ve ayarların bugünkü davranışı için [README](../README.md) ve [hesap silme/dışa aktarma notları](account-deletion.md) esas alınmalıdır. Aşağıdaki eski test sonuçları yeni sürümün doğrulandığı anlamına gelmez.

İlk çalışma dalı: `feature/profile-settings`. Yerel kayıt devamı:
`feature/profile-local-persistence` (30 Ekim 2026).

## Kapsam

- Yeni `lib/profile_settings_page.dart`: profil, takma ad/fotoğraf önizlemesi,
  ayrı ödül puanı ve güven alanları, kullanıcı etkinliği özeti.
- Ayarlar: hesap/profil, demo ilçe/çevre bildirimleri ve sessiz saatler,
  gizlilik/güvenlik, destek, gizlilik/KVKK ve park bilgisi.
- Mevcut ThemeData, kartlar ve düğmeler kullanılır. Harita, arama, filtre,
  renk paleti ve ana gezinme değiştirilmez. Yerel profil saklama için
  `shared_preferences` ve fotoğrafı uygulama alanında tutmak için
  `path_provider` kullanılır.
- `ios/Runner/Info.plist`: mevcut image_picker paketinin profil fotoğrafı seçimi
  için ihtiyaç duyduğu `NSPhotoLibraryUsageDescription` eklenir. Konum izinleri
  ve park bildiriminin kamera akışı değiştirilmez.

## main.dart bağlantısı

1. `import 'profile_settings_page.dart';`
2. Profil açma callback'i: `_openPage('Profil', const ProfileSettingsPage())`.
3. Yerine geçen eski özel `_ProfilePage` sınıfı kaldırıldı; başka ekran taşınmadı.

## Gerçek işlem / önizleme ayrımı

- Takma ad, fotoğraf ve bildirim tercihleri cihazda yerel olarak saklanır;
  uygulama kapatılıp açıldığında korunur. Fotoğraf uygulamanın özel destek
  klasörüne kopyalanır. Bu bilgiler hesaba veya sunucuya yüklenmez. Fotoğraf
  isteğinde tam metadata talep edilmez.
- Ayarlarda bu cihazdaki önizleme verilerini silme seçeneği bulunur; onay
  alındıktan sonra yerel tercihler ve profil fotoğrafı kaldırılır. Bu, gerçek
  hesap silme işlemi değildir.
- Düzenleme ekranındaki buton "Önizlemeye uygula"dır. İptal/geri, taslağı uygulamaz.
- Puan ve etkinlik sayıları uydurulmaz; `—` ve "henüz bağlı değil" gösterilir.
  Güven durumu puandan ayrıdır; doğrulanmış katkı verisi olmadığı belirtilir.
- Bildirim düğmeleri yalnızca bu cihazda saklanan demo tercihleridir. İşletim sistemi bildirimi,
  arka plan konumu, bildirim izni, push aboneliği veya zamanlayıcı oluşturulmaz.
- 30 Ekim 2026 tarihli prototip notu: Veri indirme, hesap silme ve tüm cihazlardan çıkış o sürümde kapalıydı. Güncel durum için README ve hesap silme belgesine bakın.
- Destek adresi ve gizlilik/KVKK metni henüz hazır değildir; uydurma iletişim
  adresi veya kullanılabilir hukuki metin gösterilmez.

## Kontroller

```sh
flutter test test/profile_settings_test.dart test/profile_map_integration_test.dart
flutter analyze
flutter test
```

Ortamda önbellekteki paketlerle çalışmak için `flutter pub get --offline`, ardından
`flutter test --no-pub ...` / `flutter analyze --no-pub` kullanıldı.

Önceki `feature/profile-settings` dalında odaklı koşu: **8 test geçti**.
Yerel saklama ve hata düzeltme dalında odaklı profil, yerel kayıt ve harita entegrasyon koşusu: **9 test geçti**. `flutter analyze --no-pub`: **sorun yok**.

Profil testleri: takma ad doğrulama ve uygulama, fotoğraf seçimi/iptali/hatası/kaldırma,
ilçe ve sessiz saatlerin ekranlar arasında korunması, kapalı hesap
aksiyonları, küçük ekranda büyük yazı. Haritadaki mevcut profil düğmesinden giriş
ve haritaya geri dönüş ayrıca kontrol edilir.

### Ortak main üzerinde de bulunan hatalar

Tam test paketi yeşil değil. Başlangıç commit'inin orijinal kodu ayrı geçici
kopyada test edildi: **2 test geçti, aynı 10 test başarısız oldu**. Geçici kopyalar
silindi. Profil değişiklikleriyle ilk tam koşuda 7 profil testi de geçti;
10 eski hata aynı kaldı. Harita kapsamı değiştirilmedi.

İlk Flutter exception:

```text
A RenderFlex overflowed by 120 pixels on the right.
Row: lib/main.dart:1865 (başlangıç commit'indeki satır)
```

Diğer eski test beklentileri arasında `Yakınlaşınca örnek işaretler görünür`
yazısının bulunamaması ve harita davranışı/filtre beklentileri var. Hata görülen testler:

- map_first_flow_test: selecting an unknown map point offers a report flow
- map_visibility_test: filters apply to vacancy and leaving markers
- map_visibility_test: map controls stay separated on a narrow phone
- map_visibility_test: map markers appear individually after zooming in
- map_visibility_test: sample reports expire instead of staying active on the map
- report_flow_test: leaving report also requires a camera photo
- search_map_test: Turkish search text is preserved and selecting a result zooms in
- widget_test: BOŞ1YER opens with a map-first home screen
- widget_test: quick report buttons fit on a narrow phone
- widget_test: quick report starts with camera-only photo step

### Önceki dalda cihaz kontrolü — 30 Ekim 2026

Android 17 / API 37 emülatöründe bu dalın Dart kodu mevcut debug uygulamasına
`flutter attach` ve hot restart ile bağlanarak kontrol edildi:

- Profil açılışı, takma ad düzenleme ve geri dönüş.
- Android fotoğraf seçicisinden TEST görselini seçip profil önizlemesine uygulama.
- Demo bildirim anahtarının alt seçenekleri etkinleştirmesi.
- Kadıköy ilçe seçimi ve sessiz saat başlangıcını 23:00 yapma.
- Bildirim ekranından çıkıp tekrar girince Kadıköy ve 23:00 tercihlerinin korunması.
- Konum/görünürlük, destek, gizlilik/KVKK ve uygulama bilgisi sayfalarının açılması.
- Bağlı olmayan hesap işlemlerinin kilitli görünmesi.

Profil/ayar akışında yeni bir çalışma zamanı hatası gözlenmedi. 18 adet doğrudan
Android ekran görüntüsü, kod deposunun dışında ayrı bir teslim klasöründe hazırlandı.
Demo bilgiler sunucuya gönderilmedi.

### Kayıt hataları ve fotoğraf önbelleği — 30 Ekim 2026

`fix/profile-save-feedback` dalında profil ayarları cihaz kaydına yazılamazsa
kayıt artık başarısız kabul edilir; düzenleme sayfası kapanmaz ve tekrar deneme
imkânı kalır. Kaydetme sürerken alan ve fotoğraf düğmeleri devre dışı bırakılır.
Aynı uygulama içi fotoğraf dosyasının içeriği değiştiğinde Flutter görsel
önbelleği temizlenir. Yerel saklamayı taklit eden test altyapısı ve kayıt hatası,
tekrar deneme, silme onayı için testler eklendi.
### Yerel saklama dalı — 30 Ekim 2026

`feature/profile-local-persistence` dalında takma ad, profil fotoğrafı ve demo
bildirim tercihleri yerel olarak saklanır. Kişinin kendi araç bilgisi profil
ve ayarlardan kaldırıldı. Park yeri bildirimindeki büyük araca uygunluk alanı
katkı sahibinin tahmini olarak kalır; doğrulanmış ölçü veya garanti olmadığı
açıkça belirtilir. Fotoğraf uygulamanın
özel destek klasörüne kopyalanır; hesap veya sunucu bağlantısı eklenmedi.
Ayarlara bu cihazdaki önizleme verilerini silme işlemi eklendi. `flutter analyze
--no-pub`: sorun yok. Odaklı testler 9/9 geçti. Uygulamayı yeniden başlatma
sonrası kalıcılık ve silme akışı iPhone'da ayrıca elle doğrulanmalı.

Profil ana ekranı yerel durumunu avatar alanında gösterir, ayarlara dişli/düzen
kontrolleriyle erişir ve puan, güven, katkı ölçülerini kısa kartlarda sunar.
Boş yer ve Çıkıyorum katkı kartları ilgili geçmiş ekranına açılır; gerçek hesap
Bu tarihsel kayıtta hesap backend'i henüz bağlı olmadığından bu ekranlar boş
durum açıklaması gösteriyordu. O sürümde metrikler boş değerle gösteriliyor, başarı veya puan
uydurulmaz. Bu güncel görünüm de iPhone 11'e derlenip yüklendi.

Güncel Flutter sürümü iPhone 11'e başarıyla derlenip yüklendi. iPhone'da galeri
izin reddi ve uygulamayı yeniden açtıktan sonra yerel kayıtların korunması henüz
elle denenmedi. Android için bu dalda yeni APK üretilmedi.

## Sonraki işler

Gerçek hesabın API sözleşmesi; profil kayıtları; bildirim altyapısı;
puan/güven kuralları ve veri hakları. Bu PR bunları sunucuya bağlamaz.
