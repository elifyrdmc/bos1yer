# BOŞ1YER manuel teslim kontrolü

Bu liste son test oturumunda kullanılmak içindir. Her akışta test hesabı ve hedef ortamı not edin; gerçek kullanıcı verisiyle deneme yapmayın. Bir adım çalıştırılmadıysa “geçti” olarak işaretlemeyin.

## Test kaydı

- Tarih ve saat:
- Commit:
- Ortam: (Bos1yer-dev / başka)
- Cihaz ve işletim sistemi:
- Uygulama yapılandırması: (yerel demo / Supabase bağlı)
- Test hesabı: (test hesabı e-postası; parola yazmayın)
- Sonuç / hata notları:

## iOS ve Android için temel akışlar

- [ ] Uygulama açılır; oturum yoksa Welcome, geçerli oturum varsa ana ekran açılır.
- [ ] E-posta ile hesap oluşturma tamamlanır; ad, soyad ve profil alanları kaydedilir.
- [ ] Aynı e-posta ile ikinci kayıt anlaşılır hata verir; mevcut hesap bozulmaz.
- [ ] E-posta doğrulama ve doğrulama bağlantısından uygulamaya dönüş kontrol edilir.
- [ ] Doğru bilgilerle giriş ve çıkış çalışır.
- [ ] Yanlış parola hatası formu bozmadan gösterilir; yüklenme durumu işlem bitince kapanır.
- [ ] Parola sıfırlama e-postası gönderilir ve bağlantı doğru uygulama/akışa döner.
- [ ] Giriş yapılmışken mevcut parola doğrulanarak parola değiştirilir; yeni parola ile giriş yapılır.
- [ ] Google ve Apple seçenekleri “Yakında” olarak görünür ve giriş başlatmaz.

## Harita ve katkılar

- [ ] Konum izni verilmeden harita/adres araması kullanılabilir.
- [ ] Konum izni verildiğinde kullanıcının konumu ve harita kontrolleri çalışır.
- [ ] Park bildirimi fotoğraf ve konumla oluşturulur; doğrulama hataları kullanıcıya anlaşılır gösterilir.
- [ ] Kendi bildirimi iptal edilir; başka kullanıcı bildirimi iptal edilemez.
- [ ] Bildirim süresi dolunca aktif harita listesinden çıkar.
- [ ] Katkı geçmişinde bildirim tarihi, fotoğraf ve topluluk yanıtları doğru hesaba aittir.
- [ ] Rapor fotoğrafı yetkisiz oturumdan görüntülenemez; rapor silme/anonymize akışı beklenen sonucu verir.

## Profil, ödül ve hesap verisi

- [ ] Profil adı/soyadı ve fotoğraf güncellenir; hata halinde girilen değerler korunur.
- [ ] Favori ilçe ekleme/kaldırma oturumla eşitlenir.
- [ ] Puan hareketi ve kupon listesi doğru hesapta görünür; demo kuponlar gerçek anlaşma gibi sunulmaz.
- [ ] Kupon satın alımı puanı sunucu tarafında yalnızca bir kez düşürür; yinelenen istek tekrar düşüm yapmaz.
- [ ] Kullanım durumu yalnızca ürün akışındaki mevcut kurala göre görünür; işletme doğrulaması varmış gibi davranılmaz.
- [ ] Hesap dışa aktarma JSON'u yalnızca test hesabının verilerini içerir.
- [ ] Yanlış parola ile hesap silme başarısız olur; hesap ve oturum korunur.
- [ ] Doğru parola ile hesap silme tamamlanır; kullanıcı Welcome/oturumsuz akışa döner.
- [ ] Silme sonrası profile ait özel veriler/fotoğraf temizlenir; raporlar kararlaştırılmış anonimleştirme davranışını korur.

## Görsel ve erişilebilirlik kontrolü

- [ ] Küçük ve büyük telefon boyutları kontrol edilir.
- [ ] Kayıt, giriş ve parola ekranları klavye kapalı/açıkken kullanılabilir; ana eylem klavye arkasında kalmaz.
- [ ] Açık ve koyu tema kontrol edilir; metin, hata, pasif durum ve buton kontrastı okunur.
- [ ] Uzun Türkçe metinlerde taşma, kesilme veya tıklama alanı çakışması yoktur.
- [ ] Sistem yazı boyutu büyütülünce kritik içerik ve eylemler erişilebilir kalır.

## Sonuç özeti

| Platform | Cihaz / OS | Commit | Geçen / başarısız / atlanan | Kanıt veya hata özeti |
| --- | --- | --- | --- | --- |
| iOS |  |  |  |  |
| Android |  |  |  |  |

Başarısız adımlar için ekran görüntüsü veya log eklerken parola, erişim anahtarı, e-posta doğrulama bağlantısı ve kişisel konum bilgisini maskeleyin. Bu manuel kontrol GitHub CI, mağaza imzalama veya güvenlik incelemesinin yerine geçmez.
