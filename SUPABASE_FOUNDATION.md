# Supabase backend hazırlığı (tarihsel taslak)

> **Durum notu — 14 Kasım 2026:** Bu belge ilk backend planlaması sırasında yazıldı ve aşağıdaki bazı ifadeler mevcut uygulamayı anlatmıyor. Auth, rapor yazma/iptal, profil katkı geçmişi, favori ilçeler, demo ödül/kupon akışları ve hesap verisi işlemleri artık uygulanmıştır. Güncel özellik ve teslim engelleri için [README](../README.md); hesap silme/dışa aktarma dağıtım ayrıntıları için [account-deletion.md](account-deletion.md) esas alınmalıdır. Aşağıdaki model ve güvenlik bölümleri planlama kaydıdır; canlı şema veya aktif RLS durumunun kanıtı değildir.

Bu dosyanın ilk sürümü 2 Kasım 2026 civarındaki kurulum durumunu kaydediyordu. O tarihte canlı bağlantı bu ortamdan DNS nedeniyle doğrulanamamış, Auth ve yazma akışları da henüz eklenmemişti. Bu ifadeler güncel durum değildir. Bugünkü uygulama özellikleri ve sınırlamaları için README'ye bakın.

## Mevcut prototipteki veriler

- Harita park işaretleri `lib/main.dart` içindeki `_demoMapPins` sabit listesinde; keşfet örnekleri de aynı dosyada tanımlıdır. Bunlar çalışma belleğindeki örneklerdir ve sunucuya gönderilmez.
- Bu feature dalı `main` üzerinden açıldı. Promosyon örnekleri bu dalın başlangıç kodunda yer almıyor; haritadaki park ve keşfet örnekleri `lib/main.dart` içindedir.
- Profil takma adı ve tercihleri `lib/profile_settings_page.dart` içindeki `_ProfileLocalStore` aracılığıyla `SharedPreferences` içine yazılır.
- Profil fotoğrafı uygulamanın destek dizinine dosya olarak kopyalanır; tercihlerde fotoğrafın cihaz içi dosya adı saklanır.
- Fotoğraf, profil ve park örneklerinin mevcut cihaz/sabit liste davranışı bu görevde değiştirilmemiştir.

## Flutter yapılandırması

`supabase.example.json` yalnızca örnektir. Yerel geliştirmede `supabase.local.json` dosyası proje URL'si ile oluşturulmuştur; içindeki örnek publishable key'i Supabase Dashboard → Connect ekranındaki **publishable key** ile değiştirin. `.gitignore`, bu yerel dosyanın Git'e eklenmesini engeller. Bu dosyayı sohbet, ekran görüntüsü veya PR'a koymayın.

Yerel dosyada proje URL'si ve publishable key bulunabilir; her geliştirici kendi bilgisayarında Dashboard → Connect ekranındaki publishable key'i kullanmalıdır. `service_role` veya `sb_secret_` anahtarını kullanma. `supabase/migrations/20261102000100_initial_core.sql` ilk şema migration'ıdır. Ürün sahibi bunun canlı projede çalıştırıldığını bildirdi; bu ortamda RPC erişimi DNS nedeniyle doğrulanamadı. Şema değişiklikleri için yeni migration hazırlamadan önce SQL'i ve aşağıdaki bekleyen kararları gözden geçir.

Supabase Flutter paketi `pubspec.yaml` dosyasına eklendi ve sürümü `pubspec.lock` içinde sabitlendi. Depoyu yeni bir makinede aldıktan sonra bağımlılıkları kurun:

```powershell
flutter pub get
```

Ardından yerel ayar dosyasını kullanarak Flutter'ı başlatın:

```powershell
flutter run --dart-define-from-file=supabase.local.json
```

Release derlemelerinde de aynı dosya parametresi `flutter build appbundle` veya `flutter build ipa` komutuna eklenir. CI/mağaza derlemelerinde değerleri gizli CI değişkenlerinden derleme zamanı tanımları olarak verin. Mobil uygulamaya gömülen URL ve publishable key istemci yapılandırmasıdır; güvenlik sınırı değildir. `lib/backend/supabase_config.dart` bu iki değeri okur ve ayarlar mevcutsa istemciyi başlatır. Başlangıçta ayar verilmezse Supabase başlatılmaz. Bu bölüm kurulum notudur; güncel işlev listesi README'dedir.

Harita bildirimleri uygulama açılırken, harita sekmesine dönülürken ve uygulama arka plandan açılırken yeniden okunur. Realtime aboneliği yoktur; bu nedenle yeni katkılar anında görünmeyebilir. Boş yer bildirimi ilk beş dakika yeşil, beş ile on dakika arasında turuncu görünür; tüm bildirimler onuncu dakikada haritadan kaldırılır. Çıkış bildirimi boş yer garantisi vermediğinden sarı anlamını korur. Demo modunda da aynı geçerlilik süresi uygulanır.

Paket bilgisi: `supabase_flutter` 2.18.3 kararlı sürüm olarak incelendi; proje Dart SDK sınırı `^3.13.5` olduğundan SDK gereksinimini karşılar. Paket pub.dev'de MIT lisanslıdır; SDK kullanımı için paket ücreti yoktur. Supabase'in barındırılan hizmet maliyeti ve ücretsiz plan kotaları proje açılacağı zaman ayrıca kontrol edilmelidir. Kaynaklar: [Supabase Flutter kurulum belgesi](https://supabase.com/docs/reference/dart/installing), [pub.dev paket sürümleri, SDK ve lisans bilgisi](https://pub.dev/packages/supabase_flutter/versions).

## Taslak veri modeli

Bu bölüm tablo ve alan önerisidir, uygulanmış şema değildir. PostgreSQL kimlikleri UUID, zaman damgaları UTC `timestamptz` olarak düşünülebilir. Coğrafi nokta/çizgiler için PostGIS `geography`/`geometry` ve SRID 4326 değerlendirilebilir.

| Önerilen tablo | Taslak alanlar ve amaç |
| --- | --- |
| `profiles` | `id` (Auth kullanıcısına bağlı UUID), `nickname`, `avatar_object_path`, `created_at`, `updated_at`. E-posta gibi özel hesap verileri profilin herkese açık alanlarına konmamalı. |
| `parking_reports` | Noktasal, zamana duyarlı katkı: `id`, `author_id`, `kind` (ör. boş yer / çıkıyorum), `location geography(Point,4326)`, isteğe bağlı not ve özel fotoğraf nesne yolu, `created_at`, `expires_at`, durum/inceleme alanları. Süresi geçmiş boş yer aktif boş olarak sunulmamalı. |
| `street_parking_rules` | Sokak veya yol kesimi için genel park kuralı; `id`, yol geometrisi, kural bilgisi, veri kaynağı ve kaynağa ait güncelleme/geçerlilik zamanı. Bu kayıtlar kullanıcıların anlık nokta bildirimlerinden ayrı tutulmalı. |
| `points_ledger` | Puan hareketi kaydı: `id`, `user_id`, imzalı miktar veya hareket türü, kaynak kayıt, neden kodu, sunucu zamanı ve tekrar işlemeyi engellemek için idempotency anahtarı. Kullanıcı istemcisi doğrudan bakiye/puan hareketi yazmamalı. |
| `coupons` | İleride onaylanmış işletme anlaşmalarının kampanya/kupon tanımı; işletme referansı, açıklama, geçerlilik, stok/kullanım sınırları ve yayın durumu gibi alanlar. İşletme ve anlaşma modeli henüz kararlaştırılmadı. |
| `coupon_redemptions` | Kullanıcıya tahsis veya kullanım denemesi: kullanıcı, kupon, durum, oluşturma/kullanma zamanları ve sunucu tarafından doğrulanan tek kullanımlık kod/QR referansı. Gerçek işletme anlaşması olmadan aktif kupon üretilmemeli. |

Durum isimleri, saklama süresi, moderasyon akışı, hangi harita verisinin herkese açık olacağı ve puan kuralları açık ürün kararı bekliyor. Fotoğraflar tabloya byte olarak konmamalı; özel Storage bucket'ta nesne olarak saklanıp veritabanında yalnızca nesne yolu tutulmalı.

## Güvenlik taslağı

1. İstemciye yalnızca proje URL'si ve publishable key verilir. `service_role`/secret key hiçbir Flutter koduna, build değişkenine, uygulama paketine veya GitHub'a eklenmez.
2. Kullanıcıya ait tablolar için RLS etkinleştirilir. Her tablo için `anon` ve `authenticated` erişimi açıkça sınırlandırılır; varsayılan yaklaşım erişimi kapalı tutup gerekli politikaları kararlar sonrası eklemektir.
3. `profiles`: kullanıcı kendi özel alanlarını okuyup değiştirebilir. Herkese açık takma adın ve avatarın kimlerce görüleceği ayrıca seçilmelidir.
4. Park bildirimleri: harita oturumsuz okunabilir; paylaşım ve doğrulama göndermek için giriş gerekir. Yazarın düzenleme/silme hakkı ve doğrulamaların rapor durumuna etkisi ayrıca kararlaştırılacaktır. Erişim sınırları aşağıdaki onaylı karara göre uygulanmalıdır.
5. Fotoğraf bucket'ı özel olmalı; yükleme/okuma izinleri kullanıcı ve nesne yolu ile sınırlandırılmalı. Paylaşım gerekiyorsa süreli signed URL değerlendirilmeli; herkese açık kalıcı URL varsayılmamalıdır. Yüz/plaka mahremiyeti ve saklama/silme süresi ayrıca belirlenmelidir.
6. Puan verme, raporu onaylama/kapama, kupon çıkarma ve QR kullanımını onaylama gibi güven etkili işlemler istemciden tablo güncellemesi olarak kabul edilmemeli; yetkili sunucu fonksiyonu/Edge Function içinde kimlik, izin, tekrar gönderim ve iş kuralı kontrollerinden geçmelidir. Gizli anahtar gerekiyorsa yalnızca sunucu ortamında tutulur.

## İlk SQL migration

`supabase/migrations/20261102000100_initial_core.sql` PostGIS'i `extensions` şemasında açar; özel `profiles` tablosu ve geçici `parking_reports` tablosunu oluşturur. RLS açıktır. Kullanıcı yalnızca kendi profil satırını görebilir/değiştirebilir. Harita ziyaretçileri yalnızca bildirim kimliği, türü, koordinatı ve oluşturulma zamanını okuyabilir; `author_id`, not ve fotoğraf yolu seçme izni verilmez. `get_active_parking_reports()` RPC'si PostGIS noktasını enlem/boylam alanlarına çevirir ve yaşı veritabanı saatinden hesaplar. Okuma politikası 10 dakikadan eski satırları harita sorgusunda dışlar. İstemciye bildirim ekleme, değiştirme veya silme yetkisi verilmez; önce sunucu doğrulaması tasarlanmalıdır.

`lib/backend/parking_report_repository.dart` salt okunur RPC yanıtını doğrulanmış Dart kayıtlarına dönüştürür. Ana harita, Supabase yapılandırılmışsa bu repository ile açılışta raporları okur; sekmeye geri dönünce ve uygulama ön planda tekrar açılınca yeniler. Yapılandırma yoksa demo pinleri korunur. Canlı modda bağlantı hatası olduğunda örnek veriler gösterilmez. Harita pinleri ve açık detay kartı 10 dakika dolan raporu kaldırır. Otomatik arka plan polling/realtime henüz eklenmedi.

## Rapor yazma yetkisi incelemesi

`20261102000200_authenticated_report_writes_and_photos.sql`, `create_parking_report()` RPC'sini giriş, koordinat, fotoğraf yolu, not uzunluğu ve ayrılma süresi için doğrulamalarla oluşturur. Ancak RPC `SECURITY INVOKER` iken aynı migration `authenticated` rolüne rapor tablosunda sütun bazlı doğrudan `INSERT` izni de verir. Bu, istemcinin RPC doğrulamalarını atlayarak tabloya doğrudan kayıt ekleyebilmesi anlamına gelir.

`20261103000100_lock_parking_report_writes_to_rpc.sql` bu açığı kapatmak için hazırlanmış takip migration'ıdır: istemcinin doğrudan ekleme yetkisini ve ekleme politikasını kaldırır. `public.create_parking_report()` `SECURITY INVOKER` olarak kalır ve `app_private` şemasındaki doğrulanan `SECURITY DEFINER` yardımcı fonksiyonunu çağırır. Yardımcı fonksiyon sabit boş `search_path` kullanır; oturum, koordinat ve rapor alanlarını doğrular, ayrıca Storage'da aynı özel kovada ve kullanıcıya ait fotoğraf nesnesinin gerçekten bulunduğunu kontrol eder. **`app_private` Supabase API ayarlarında exposed schema olarak eklenmemelidir. Canlı migration çalıştırılmadı.** Uygulamadan önce migration geçmişinde 002'nin uygulanmış olduğu teyit edilmeli; 001 veya 002 tekrar çalıştırılmamalı. Bu değişiklik canlıya alındığında, function owner'ın `parking_reports` tablosuna insert yapabildiği doğrulanmalı.

Uygulama sonrası SQL Editor'da şu salt okunur kontrolleri kullanın. Doğrudan ekleme sorgusu `false` dönmeli; `public` RPC için `prosecdef` `false`, `app_private` yardımcı fonksiyonu için `true` olmalı. İki fonksiyonun `proconfig` değeri boş `search_path` ayarını göstermelidir.

```sql
select has_any_column_privilege(
  'authenticated', 'public.parking_reports', 'INSERT'
) as authenticated_can_insert;

select n.nspname as schema_name, p.prosecdef, p.proconfig
from pg_proc as p
join pg_namespace as n on n.oid = p.pronamespace
where p.proname = 'create_parking_report'
  and n.nspname in ('public', 'app_private');
```

Bu migration puan, kupon, sokak kuralları, fotoğraf bucket'ı veya rapor moderasyonu oluşturmaz. Hesap silindiğinde rapor geçmişinin ne olacağı, yazma/inceleme kuralları ve fotoğraf saklama süresi karara bağlanınca ek migration hazırlanmalı. İlk migration'ın canlı projede çalıştırıldığı ürün sahibi tarafından bildirildi; uygulamanın RPC yanıtı bu ortamdan doğrulanamadı.

## Onaylanan erişim kararı — 1 Kasım 2026

Ürün sahibi haritanın giriş yapmadan görülebilmesini; park yeri paylaşma ve bildirim doğrulama işlemleri için giriş gerekmesini onayladı. Bu karar henüz canlı RLS politikası veya uygulamada çalışan giriş ekranı değildir.

| İşlem | Giriş yapmamış ziyaretçi | Giriş yapmış kullanıcı |
| --- | --- | --- |
| Yayımlanabilir park bildirimlerini haritada okuma | İzin verilecek | İzin verilecek |
| Park yeri paylaşma isteği gönderme | Reddedilecek | Sunucu doğrulamasına gönderilebilecek |
| Mevcut bildirim için doğrulama gönderme | Reddedilecek | Sunucu doğrulamasına gönderilebilecek |
| Raporun nihai durumunu veya puanı doğrudan değiştirme | İzin verilmeyecek | İzin verilmeyecek; sunucu işlemi gerekecek |

### Uygulama ve sunucuya aktarım planı

- Harita açılışı giriş ekranına bağlanmayacak. Konum izni verilmeden adres aramasıyla kullanım korunacak.
- Canlı paylaşım/doğrulama akışı bağlandığında, oturumu olmayan kullanıcı bu işlemlerde girişe yönlendirilecek. Bu görevde mevcut demo ekranlarına giriş engeli eklenmedi.
- Sunucu, her katkıda geçerli oturumu kontrol edecek ve katkı sahibini doğrulanmış oturumdan belirleyecek. İstek gövdesindeki kullanıcı kimliğine güvenilmeyecek. Uygulamadaki düğme kontrolü tek başına yetkilendirme sayılmayacak.
- Harita okuması için `anon` ve `authenticated` rollerine yalnızca yayımlanabilir kayıtların gerekli alanları açılacak. Süresi dolan boş yer, sunucu zamanı esas alınarak 10 dakika sonunda aktif harita sonuçlarından çıkarılacak.
- RLS satır erişimini sınırlandıracak; özel alanların gizlenmesi için ayrıca sütun yetkileri veya denetlenmiş bir sunucu okuma uç noktası kullanılacak. Tüm ham tabloya genel okuma izni verilmeyecek.
- Herkese açık harita yanıtı için önerilen alanlar: bildirim kimliği, park noktasının koordinatı, bildirim türü, gösterilebilir durum ve güncellik zamanı. Nihai alan listesi şema incelemesinde kesinleşecek. Kullanıcı e-postası, hesap kimliği, özel fotoğraf nesne yolu, bildirim tercihleri ve puan kayıtları bu yanıta eklenmeyecek. Profil görünürlüğü ayrıca karar bekliyor.
- Giriş yapmış kullanıcının doğrulaması bir katkı olarak işlenecek. Bunun tek başına bildirimi onaylaması, kapatması veya puan üretmesi kararlaştırılmış değildir. Tekrarlı istekler ve eşzamanlı değişiklikler sunucu tarafında kontrol edilecek.

### Gerçek backend hazır olduğunda doğrulanacak senaryolar

1. Oturumsuz harita okuması başarılı olur; paylaşım ve doğrulama istekleri reddedilir.
2. Geçerli oturumla katkı gönderilebilir; başka kullanıcı kimliği gönderilerek onun adına katkı oluşturulamaz.
3. Oturumu sona ermiş kullanıcının yazma isteği reddedilir; harita okuması açık kalır.
4. İstemciden doğrudan durum/puan değişikliği yapılamaz; özel profil ve fotoğraf bilgileri harita yanıtından alınamaz.
5. Süresi dolan boş yer, arka plan temizliği gecikse bile aktif sonuçlarda görünmez.

Bu senaryolar plan niteliğindedir; canlı veritabanına erişim DNS nedeniyle doğrulanamadığı için bu ortamda çalıştırılmadı.

## Onaylanan bildirim süresi — 1 Kasım 2026

| Sunucudaki oluşturulma anından geçen süre | Harita davranışı |
| --- | --- |
| 0 dakika dahil, 5 dakikadan az | Yeşil |
| 5 dakika dahil, 10 dakikadan az | Turuncu |
| 10 dakika ve sonrası | Haritadan ve aktif bildirim listesinden kaldırılır |

Renkler bildirimin yaşını anlatır; boş yer veya yasal park garantisi değildir. Genel sokak park kuralları ve işletme kampanyaları bu geçici bildirim süresine dahil değildir.

`lib/backend/parking_report_lifecycle.dart` bu hesabın bağımsız Dart karşılığını içerir. Harita RPC'si rapor yaşını veritabanı saatinden alır; istemci rapor yaşını cihaz saatinden hesaplamaz. Aktif RPC sorgusu süre dolmuş kayıtları arka plan temizliği beklemeden dışlar; istemcideki zamanlayıcı da pin ve açık rapor kartını 10 dakika dolduğunda kaldırır. İstemcinin gönderdiği yaş/süre/durum değerleri yetki kaynağı kabul edilmemelidir.

Sürenin dolması veritabanından kalıcı silmeyle aynı işlem değildir: geçmiş, puan denetimi ve fotoğraf saklama/silme süreleri ayrıca karar bekliyor. Bir doğrulamanın süreyi yenileyip yenilemeyeceği henüz kararlaştırılmadı; bu modül süre yenilemez.

Sınır kontrolü komutu: `flutter test test/parking_report_lifecycle_test.dart`. Bu kontrol gerçek Supabase bağlantısı veya harita entegrasyonu testi değildir.

Yerel çalıştırma notu: 1 Kasım 2026 denemesinde Flutter testleri başlamadan `objective_c` native asset hook'u Windows kullanıcı yolundaki boşluk nedeniyle başarısız oldu (`C:\Users\Elifnaz is not recognized`). Bu nedenle testlerin geçtiği doğrulanmış değildir.

## Ürün sahibinden bekleyen kararlar

- Doğrulamalar hangi koşullarda rapor durumunu değiştirir veya süreyi yeniler? Yanlış bildirme, kapatma ve düzenleme yetkileri nasıl olacak? Süresi dolan bildirim veritabanında ne kadar süre saklanır?
- Sokak park kuralı kaynağı, doğrulama süreci ve güncellik sorumlusu kim olacak?
- Takma ad/avatar görünürlüğü, kullanıcı adı benzersizliği ve kullanıcı tarafından değişiklik sıklığı nasıl olacak?
- Fotoğraf boyut/format sınırı, moderasyon, saklama süresi ve silme talebi akışı ne olacak?
- Puan hangi olayda ve hangi miktarda verilecek; günlük sınır, iptal/itiraz ve sahte katkı incelemesi nasıl işleyecek?
- Gerçek kupon/işletme anlaşması, tek kullanımlık QR doğrulaması ve iptal/iade kuralları ne zaman/hangi aktörle belirlenecek?
- Auth sağlayıcısı ve hesap silme/veri dışa aktarma akışı nedir?
