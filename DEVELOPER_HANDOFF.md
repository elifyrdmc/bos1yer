# BOŞ1YER geliştirici devir rehberi

Bu belge, repoyu devralan geliştiricinin çalışan kodu, veri sınırlarını ve doğrulanmamış noktaları ayırt etmesi içindir. Ürün kapsamı için [README](../README.md), arayüz kuralları için [DESIGN](../DESIGN.md) esas alınır. `SUPABASE_FOUNDATION.md` eski planlama kararlarını da içerir; güncel şema veya uygulama davranışı olarak okunmamalıdır.

## Kod haritası

| Alan | Başlangıç noktası | Sorumluluk |
| --- | --- | --- |
| Uygulama açılışı | `lib/main.dart`, `lib/src/app_shell.dart` | Supabase başlatma, oturum kapısı, ana sekmeler |
| Giriş ve kayıt | `lib/auth_page.dart`, `lib/backend/auth_repository.dart` | E-posta/parola akışı, şifre sıfırlama, özel ad metadata'sı |
| Harita | `lib/src/map_controller.dart`, `map_widgets.dart`, `map_report_cards.dart`, `map_canvas.dart`, `map_layers.dart`, `map_pin_models.dart`, `map_search.dart`, `map_filters.dart` | Harita yaşam döngüsü, görünüm, işaretler, arama ve filtre penceresi |
| Park bildirimi | `lib/src/report_flow.dart`, `report_photo_step.dart`, `report_location_picker.dart`, `report_review.dart`; `lib/backend/parking_report_repository.dart` | Form adımları, fotoğraf, konum ve sunucu RPC'leri |
| Ödül ve kupon | `lib/src/rewards_models.dart`, `rewards_page.dart`, `rewards_wallet.dart`, `rewards_coupons.dart`, `rewards_catalog_components.dart`; `lib/backend/` ödül repository'leri | Demo katalog, puan ve kupon gösterimi |
| Profil | `lib/profile_settings_page.dart`, `lib/src/profile_*.dart` | Profil ekranı, katkı geçmişi, cihaz verisi, düzenleme, hesap silme ve ayarlar |
| Görsel sistem | `lib/design_system.dart`, `lib/app_appearance.dart`, `DESIGN.md` | Tema, ortak bileşenler ve tokenlar |
| Sunucu | `supabase/migrations/`, `supabase/functions/` | Şema, RLS/RPC ve hesap işlemleri |

Harita, bildirim ve ödül ekranları `main.dart` içindeki `part` dosyalarıdır. Profil de aynı dosya ayırma tekniğini kullanır; `profile_settings_page.dart` profil kütüphanesinin girişidir. Bu ayırma davranışı değiştirmez ve özel sınıfların dosyalar arasında erişimini korur. `map_controller.dart` hâlâ haritanın büyük bir durum sınıfını içerir; yeni iş eklerken veri erişimini `lib/backend/` içinde tutun ve bu sınıfı daha fazla büyütmeyin. Büyük ekranları daha fazla ayırırken önce davranışı koruyan taşıma yapın, sonra özellik değişikliğini ayrı commit'te uygulayın.

## Veri sahipliği ve sınırlar

| Veri | Kaynak | Dikkat edilmesi gereken |
| --- | --- | --- |
| Oturum ve özel ad/soyad | Supabase Auth | Ad ve soyad Auth metadata'sında; genel `profiles.nickname` alanıyla karıştırılmamalı. |
| Profil fotoğrafı ve bildirim tercihleri | Bu cihaz | `parkist.profile.<auth-user-id>.*` anahtarları ile hesap bazında ayrılır. Oturumsuz demo için `guest` alanı kullanılır. Bildirim tercihleri push servisi değildir. |
| Favori ilçeler | Girişte Supabase, demo modunda cihaz | Eski hesap bazlı yerel favoriler, sunucuya başarıyla aktarılınca cihazdan kaldırılır. |
| Park raporları ve katkı geçmişi | Supabase | İstemci doğrudan güven/puan/durum yazmamalı; denetlenmiş RPC kullanılmalı. |
| Puan, ödül kataloğu ve kupon | Supabase demo kayıtları | Satın alma puanı sunucuda düşer. İşletme tarafından gerçek kullanım doğrulaması yoktur. |

Eski sürümlerdeki ortak `parkist.profile.*` anahtarları yeni hesaplara otomatik taşınmaz: hangi hesaba ait oldukları güvenle belirlenemez. Bu yüzden mevcut cihaz fotoğrafının yeniden seçilmesi gerekebilir. Yeni hesap bazlı anahtarları veya dosyaları bir hesaptan diğerine kopyalamayın.

## Ortamı kurma

1. Flutter SDK, Xcode (iOS) veya Android SDK (Android) kurulu olmalı. `flutter doctor` ile yerel gereksinimleri görün.
2. Repo kökünde `flutter pub get` çalıştırın.
3. `supabase.example.json` dosyasını örnek alarak Git'e eklenmeyen `supabase.local.json` oluşturun. Yalnızca `SUPABASE_URL` ve `SUPABASE_PUBLISHABLE_KEY` kullanın. Secret veya service-role anahtarı mobil uygulamaya konmaz.
4. `flutter devices` ile cihaz kimliğini bulun; `flutter run -d <cihaz-kimliği> --dart-define-from-file=supabase.local.json` ile açın. iOS'ta ilk Swift Package çözümü uzun sürebilir; uygulama derlemesi, paket indirme ve debug bağlantısı ayrı aşamalardır.

Yapılandırma verilmezse uygulama sınırlı demo yolunu açar. Demo işaretleri canlı park raporu değildir. Supabase kullanan akışları sınamak için yapılandırılmış bir proje ve test hesabı gerekir.

Şirket devrinde GitHub deposu erişimi zorunlu değildir. Kaynak arşivi kuralları için [kaynak kod teslim notuna](SOURCE_CODE_DELIVERY.md), Supabase projesi ve DB yedeği için [Supabase dışa aktarma ve devir notuna](SUPABASE_EXPORT_AND_TRANSFER.md), TestFlight hazırlığı için [iOS TestFlight notuna](IOS_TESTFLIGHT_HANDOFF.md) bakın.

## Supabase şema ve dağıtım notu

`Bos1yer-dev` projesinin migration geçmişi 14 Kasım 2026'da yerel dosyalarla eşitlendi. Geliştiricinin terminalinden alınan `supabase migration list --remote` çıktısında yerel ve uzak sütunlar aynı 37 sürümü gösterdi; bekleyen migration yoktu. Eşitleme `supabase migration repair --status applied` ile yapıldı; bu işlem SQL dosyalarını tekrar çalıştırmadı, yalnızca migration geçmişi kayıtlarını düzenledi. Bu doğrulama, şema eşitliğini veya her RPC/politikanın canlı davranışını tek başına kanıtlamaz.

Yeni geliştirici migration eklemeden önce `supabase migration list --remote` çalıştırıp mevcut geçmişi kontrol etmelidir. Üretim ortamında `db push`, `migration repair` veya eski SQL dosyalarını çalıştırmadan önce şema ve migration etkisini inceleyin. Yeni değişiklikler için benzersiz sürümlü migration hazırlayıp ayrı bir test projesinde doğrulayın. Tamamlanmamış son cihaz ve backend kontrolleri için [teslim durumu](DELIVERY_STATUS.md) ve [manuel test planı](MANUAL_TEST_PLAN.md) kullanılmalıdır.

Hesap silme ve dışa aktarma Edge Function'ları için [hesap işlemleri notu](account-deletion.md) geçerlidir. `delete-account` sunucu ortamında özel anahtar kullanır. Function sürümünü, JWT ayarını ve gerekli secret'ın varlığını hedef projede ayrıca kontrol edin; anahtarın değerini repo veya loglara yazmayın.

## Doğrulama sırası

- Her kod değişikliğinden sonra repo kökünde `bash tool/verify.sh` çalıştırın. Komut bağımlılıkları çözer, `lib` ve `test` için statik analiz yapar, tüm Flutter testlerini çalıştırır. GitHub Actions aynı komutu `main` push'larında ve pull request'lerde Flutter 3.47.8 ile çalıştırır; workflow sonucu cihaz veya canlı Supabase testi sayılmaz.
- Kod değişikliğinde ilgili Dart dosyaları için `dart analyze` ve etkilenen `test/` dosyaları için `flutter test` çalıştırın.
- Oturum, profil, rapor, puan veya kupon davranışını değiştirirken yalnızca widget testiyle yetinmeyin: test hesabı ve ayrı Supabase ortamında gerçek akışı kontrol edin.
- Arayüz değişikliğinde küçük ve büyük telefon, klavye açık/kapalı, açık/koyu tema ve uzun Türkçe metinlerle cihaz görüntüsünü inceleyin.
- iOS ve Android sonuçlarını ayrı kaydedin. Bir platformda çalıştırılmış testi diğer platform için kanıt saymayın.

Başlangıç için ilgili testler: `test/auth_routing_test.dart`, `test/auth_page_test.dart`, `test/profile_settings_test.dart`, `test/profile_persistence_test.dart`, `test/parking_report_lifecycle_test.dart`, `test/coupon_tabs_test.dart`. Testlerin geçmişte mevcut olması, yeni bir değişikliğin geçtiği anlamına gelmez.

## Bilinen açık noktalar

- Google ve Apple girişleri görünür ama “Yakında”; gerçek sağlayıcı entegrasyonu yoktur.
- Kuponlar demo içeriktir. “Kullanıldı” sekmesi görünür olsa da işletme/QR doğrulama ve kuponu kullanıldı durumuna geçirme akışı yoktur. Tekrar satın alma mevcut sunucu kuralında aktif kuponun bitiş zamanına göre açılır; gerçek kullanım doğrulaması sonrasında kuponun erken yeniden alınması henüz ele alınmamıştır. Kararlar ve entegrasyon açıkları için [ürün kararları kaydına](PRODUCT_DECISIONS.md) bakın.
- Kullanım koşulları ve gizlilik belgeleri taslaktır. Gerçek hukuk metni ve işletme koşulları ürün sahibinden gelmelidir.
- `docs/SUPABASE_FOUNDATION.md` tarihsel planlama kaydıdır. Özellikle eski “henüz uygulanmadı” cümleleri güncel kodu tarif etmez.
- Mevcut testler canlı Supabase politikalarını, gerçek cihaz klavyesini veya mağaza derlemesini kanıtlamaz. Sonraki geliştirici doğrulama sonucunu tarih, ortam, cihaz ve commit ile kaydetmelidir.
