# iOS TestFlight devir notu

Son güncelleme: 14 Kasım 2026

## Seçilen dağıtım yolu

İşverenin iPhone'una beta kurulum için TestFlight kullanılacak. Bu, her test cihazının UDID'sini tek tek kaydetme ihtiyacını kaldırır. TestFlight yüklemesi App Store Connect ve Apple Developer Program erişimi olan ekip hesabından yapılır.

## Apple incelemesi ve giriş sağlayıcıları

- Ekip içi TestFlight testçileri App Store Connect ekibine eklenir. İşveren ekip üyesi olmayacaksa dış testçi olarak davet edilir.
- İlk dış TestFlight grubuna eklenecek build Apple'ın TestFlight beta incelemesine gönderilir. İncelemeden geçiş garanti edilemez.
- Şu an Google ve Apple giriş sağlayıcıları uygulamada etkin değil, “Yakında” durumundadır; çalışan giriş yöntemi e-posta/paroladır. Apple'ın Sign in with Apple şartı, üçüncü taraf/sosyal oturum açmayı birincil hesap girişi olarak sunan uygulamalara ilişkindir. Bu nedenle yalnızca Apple ile giriş sağlayıcısının henüz olmaması otomatik bir engel değildir. İleride Google veya başka üçüncü tarafla gerçek oturum açma etkinleştirilirse App Review Guidelines 4.8 yeniden değerlendirilmelidir.
- İnceleme notlarında mevcut test giriş yöntemini, test hesabını ve “Yakında” düğmelerinin çalışmadığını açıklayın. Test hesabı parolasını kaynak kod veya bu belgeye koymayın; App Store Connect inceleme bilgileri alanında güvenli biçimde sağlayın.

## Yüklemeden önce çözülmesi gerekenler

1. `ios/Runner.xcodeproj/project.pbxproj` içinde şu an `com.example.parkist` bundle identifier'ı bulunuyor. Şirketin kontrol edeceği benzersiz ve kalıcı bundle identifier seçilmeden App Store Connect kaydı ve TestFlight arşivi hazırlamayın.
2. Apple Developer Program ekibinin App Store Connect erişimi, uygulama kaydı, imzalama ve dağıtım yetkisi olmalı. Şirket uygulamanın uzun dönem sahibi olacaksa kayıt ve imzalama şirket hesabı üzerinden yapılmalı.
3. Release derlemesine doğru Supabase proje URL'si ve publishable key konmalı. Secret/service-role anahtarı uygulama paketine eklenmemeli.
4. TestFlight inceleme bilgileri, gizlilik beyanları, destek irtibatı ve App Store Connect'teki gerekli uygulama bilgileri doldurulmalı.
5. iOS release arşivi cihazda çalıştırılmalı; giriş, kayıt, parola sıfırlama, harita, rapor, fotoğraf, profil, kupon ve hesap işlemleri beta testinde kontrol edilmeli.

## Durum

Bu belge yalnızca teslim planıdır. Bu oturumda iOS release arşivi oluşturulmadı, App Store Connect'e build yüklenmedi ve TestFlight incelemesi yapılmadı. Bundle identifier ve Apple ekip erişimi çözülmeden gerçek TestFlight daveti gönderilemez.

Kaynaklar: [Apple TestFlight](https://developer.apple.com/testflight/), [App Review Guidelines 4.8](https://developer.apple.com/app-store/review/guidelines/).
