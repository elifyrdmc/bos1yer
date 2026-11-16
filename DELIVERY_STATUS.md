# BOŞ1YER teslim durumu

Son güncelleme: 14 Kasım 2026

Bu belge uygulamanın mevcut kapsamını, teslim öncesi doğrulama durumunu ve sonraki geliştiricinin bilmesi gereken sınırları özetler. Kod haritası ve yerel kurulum için [geliştirici devir rehberine](DEVELOPER_HANDOFF.md), adım adım cihaz kontrolü için [manuel test planına](MANUAL_TEST_PLAN.md), kesinleşmiş ürün kuralları ve açık kararlar için [ürün kararları kaydına](PRODUCT_DECISIONS.md) bakın. GitHub erişimi olmadan kaynak teslimi [kaynak kod teslim notunda](SOURCE_CODE_DELIVERY.md), Supabase yedek/devir yaklaşımı [Supabase teslim notunda](SUPABASE_EXPORT_AND_TRANSFER.md), iOS beta gereksinimleri [TestFlight notunda](IOS_TESTFLIGHT_HANDOFF.md) tutulur.

## Depo ve veritabanı

- Yeniden kontrolde dal `main`, yerel HEAD `2e928f2`; GitHub `main` ise `601c953` (`docs: add BOŞ1YER delivery handoff`) olarak görüldü. İki commit'in ebeveyni `ae54c31` ve ağaç özeti `f0aa780` aynı; kaynak ağacı içerikleri eşleşiyor. Yerel `origin/main` izleme referansı henüz `ae54c31`'de olduğundan yerelde bir commit önde gösteriyor. Çalışma ağacında `README.md`, `docs/DELIVERY_STATUS.md` ve `docs/DEVELOPER_HANDOFF.md` değişiklikleri ile `docs/IOS_TESTFLIGHT_HANDOFF.md`, `docs/SOURCE_CODE_DELIVERY.md` ve `docs/SUPABASE_EXPORT_AND_TRANSFER.md` izlenmeyen belgeler var. Tam `git status` ilk denemede gecikti, tekrar denemede tamamlandı; bu belge düzenlemeleri commit edilmiş sayılmamalıdır.
- TestFlight, kaynak arşivi ve Supabase devir planları belgelendi. 14 Kasım 2026'da kaynak ZIP'i ve veritabanının roller/şema/veri SQL dökümleri oluşturuldu. Mevcut veri dökümü test/demo kayıtlarını içerdiğinden işverene verilmeyecek; teslim kapsamı roller ve şema dosyalarıyla sınırlı. Ayrıntılar `SUPABASE_EXPORT_AND_TRANSFER.md` içinde.
- Supabase projesi şimdilik kullanılmaya devam edecek; şirket için yeni proje oluşturulmadı. Test Auth hesapları, Storage fotoğrafları ve proje ayarları aktarılmayacak; yeni projede migration, özel bucket/politikalar, iki Edge Function kaynağı ve Auth ayarları yeniden kurulacak. Adımlar `SUPABASE_EXPORT_AND_TRANSFER.md` içinde.
- TestFlight'a başlamadan önce `com.example.parkist` yerine kalıcı bundle identifier seçilmeli ve şirketin Apple Developer/App Store Connect ekibi belirlenmelidir. Bu oturumda build yüklenmedi veya beta incelemesi yapılmadı.
- 14 Kasım'da kullanıcı tarafından paylaşılan `supabase migration list --remote` çıktısında yerel ve uzak migration sütunları aynı 37 sürümü gösterdi; bekleyen migration görünmüyordu.
- Migration geçmişini eşitlemek için `migration repair --status applied` kullanıldı. SQL migration'ları bu komutla tekrar çalıştırılmadı.
- Bu sonuç migration kayıtlarının eşleştiğini gösterir. Canlı şemanın tümüyle doğrulandığı veya uçtan uca akışların başarıyla test edildiği anlamına gelmez.
- Hesap silme Edge Function'ının 14 Kasım'da `Bos1yer-dev` projesinde etkin sürüm 6 olduğu ve veri dışa aktarma işlevinin etkin olduğu önceki dağıtım kaydında belirtilmiştir. Teslim günü Dashboard'dan son sürümü yeniden teyit edin.

## Uygulama kapsamı

- E-posta/parola ile hesap oluşturma ve giriş; e-posta doğrulama, parola sıfırlama ve oturum açıkken parola değiştirme.
- Haritada bildirim görüntüleme; giriş yapan kullanıcı için fotoğraflı park bildirimi oluşturma ve kendi bildirimini iptal etme.
- Profil, katkı geçmişi ve katkı fotoğrafları; kullanıcıya ait favori ilçeler.
- Sunucu taraflı puan hareketleri ve demo ödül/kupon kataloğu; hesap verisini dışa aktarma ve hesap silme.

Detaylı mimari, verinin nerede tutulduğu ve güvenlik sınırları [geliştirici devir rehberinde](DEVELOPER_HANDOFF.md) açıklanmıştır.

## Ürün sınırları ve harici kararlar

- Ödül/kupon kayıtları örnektir. İşletme anlaşmaları, gerçek QR/kod kullanımı ve işletme doğrulaması entegre değildir.
- “Kullanıldı” sekmesi arayüzde bulunur; kuponu bu duruma geçirip doğrulayan bir işletme/QR akışı yoktur. Tekrar satın alma mevcut sunucu kuralında aktif kuponun bitiş zamanına göre denetlenir.
- Google ve Apple ile giriş arayüzde “Yakında” durumundadır; sağlayıcı bağlantıları etkin değildir.
- Bildirim tercihleri cihazda saklanır; push bildirimi göndermez.
- Kullanım koşulları ve gizlilik metinleri hukuk incelemesi bekleyen taslaklardır.
- Harita sağlayıcısı, sokak park kuralı verisi ve üretim harita döşemesi seçimi netleşmemiştir. Halka açık OpenStreetMap döşeme hizmeti sınırsız üretim altyapısı olarak kabul edilmemelidir.

Bu kararlar yazılım ekibinin varsayarak kapatacağı işler değildir. Anlaşma veya ürün kararı gelene kadar mevcut demo/taslak etiketleri korunmalıdır.

## Teslim öncesi doğrulama

Gerçek cihazda son manuel akışlar kullanıcı tarafından yarın çalıştırılacak. Sonuçlar henüz bu belgeye işlenmiş değildir. Takip için [manuel test planındaki](MANUAL_TEST_PLAN.md) kutuları ve kayıt alanlarını doldurun.

Şu an doğrulanmış olanlar:

- Kullanıcının terminalinden paylaşılan migration listesinde 37 yerel/uzak sürüm eşleşiyor.
- 14 Kasım 2026'da `bos1yer-database-export/roles.sql`, `schema.sql` ve `data.sql` üretildi. Test/demo kayıtlarını içeren `data.sql` yerel test çıktısı olarak kalacak ve devir paketine alınmayacak. Paylaşım için düşünülen `roles.sql` ve `schema.sql` henüz geçici bir hedef veritabanına geri yüklenerek doğrulanmadı.
- `bos1yer-source.zip` 14 Kasım 2026'da `work/` klasöründe üretildi. Güncel teslim kopyasının boyutu ve SHA-256 özeti depo dışındaki teslim manifestinde tutulur.
- `.github/workflows/flutter-checks.yml`, Flutter 3.47.8 ile `bash tool/verify.sh` çalıştırır. Bu incelemede Flutter 3.47.8 / Dart 3.13.7 ile `dart analyze lib test` hatasız tamamlandı; `flutter test --no-pub --reporter expanded` 51 testi başarıyla tamamladı. `tool/verify.sh` ayrıca bağımlılık çözümlemesi çalıştırdığı için bu turda kullanılmadı. GitHub Actions'taki `Flutter checks` çalıştırması `601c953` commit'inde 14 Kasım 2026'da `success` oldu; `analyze-and-test` işi ve tüm adımları başarılı. Bu CI sonucu iOS/Android yerel derlemesi veya gerçek cihaz kontrolü değildir.

Şu an kanıtlanmamış olanlar:

- iOS ve Android yerel derlemeleri; bu turda çalıştırılmadı. Yarın gerçek cihazda yapılacak testler bu derlemelerin veya mağaza imzalama kontrollerinin yerine geçmez.
- Kaynak ZIP'inin teslim edilecek commit ile birebir aynı olduğu ve teslim edilecek ZIP'in son belge güncellemelerini içerdiği.
- Paylaşılacak roller/şema SQL dosyalarının şifreli biçimde paketlenmesi ve alıcı/erişim kanalının belirlenmesi.
- Yeni şirket Supabase projesinin oluşturulması, Auth/redirect/SMTP ayarlarının kurulması, Edge Function dağıtımı ve secret'ların hedefte yeniden üretilmesi. Hedef organizasyon ve yetkili erişim henüz yok.
- iOS ve Android release derlemeleri, imzalama ve mağaza paketleri.
- Canlı Supabase üzerinde kayıt, rapor, kupon, dışa aktarma ve hesap silme uçtan uca akışlarının son tekrar kontrolü.
- Küçük/büyük cihazlarda ve iki temada görsel regresyon kontrolü.

## Sonraki geliştirici için devir kuralları

1. Önce `git status`, dal ve son commit'i kaydedin; kullanıcı değişikliklerini koruyun.
2. Kurulumda yalnızca publishable key kullanın; secret/service-role anahtarını istemciye veya repoya koymayın.
3. Üretim migration'larını yeniden çalıştırmadan önce uzak geçmişi ve SQL etkisini inceleyin.
4. Test ve cihaz sonuçlarını tarih, platform, cihaz/OS, commit ve ortamla kaydedin. Bir platformdaki sonuç diğerini doğrulamaz.
5. İşletme ve hukuk kararlarını koddan çıkarsamayın; açık taslakları görünür tutun.
