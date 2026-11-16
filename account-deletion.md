# Hesap silme ve veri dışa aktarma

Flutter istemcisi service-role/secret key almaz. Hesap silme `delete-account` Edge Function'ı üzerinden, veri dışa aktarma ise `export-account-data` Function'ı üzerinden yapılır.

## Hesap silme akışı

1. Ayarlarda kullanıcı mevcut parolasını doğrular ve hesabın kalıcı silinmesini onaylar.
2. İstemci, oturum JWT'si ile `delete-account` Function'ını çağırır. Function JWT doğrulamasını zorunlu tutar (`verify_jwt: true`) ve ayrıca token'ın imzalı AMR bilgisinde son 10 dakika içinde parola doğrulaması arar.
3. Function, kullanıcıya ait rapor fotoğraflarını ve profilde bir Storage fotoğraf yolu kayıtlıysa onu siler.
4. `prepare_my_account_deletion()` RPC'si özel hesap verilerini temizler ve raporları kişisel olmayan biçimde anonimleştirir; sonra Auth kullanıcısı silinir.
5. Başarılı yanıtta uygulama yerel oturumu kapatır ve oturum açılmamış akışa döner.

Storage temizliği başarısız olursa Function ilgili aşamayı belirten hata döndürür ve Auth hesabını silmez. Rapor fotoğrafları daha önce kaldırılmış olabilir; yeniden deneme güvenli olmalıdır. Fotoğraf kaldırma işlemleri Supabase Storage API üzerinden yapılır.

## Supabase dağıtım durumu

14 Kasım 2026 tarihinde `delete-account` Function'ı `Bos1yer-dev` projesine sürüm 6 olarak dağıtıldı. Etkin sürüm hem parola yeniden doğrulamasını hem rapor/profil fotoğrafı temizliğini içerir. Bu değişiklik için yeni veritabanı migration'ı gerekmedi. `export-account-data` Function'ı da projede etkin durumdadır.

Function ortamında uygulamaya özel `PARKISTANBUL_SECRET_KEY` secret'ı bulunmalıdır. Değer olarak Supabase Secret key (`sb_secret_...`) veya legacy service-role key kullanılabilir. Bu anahtar Flutter'a, GitHub'a veya kullanıcıya açık loglara konmamalıdır. Function kaynağı `SUPABASE_URL` ve `SUPABASE_ANON_KEY`/publishable key platform değişkenlerini kullanır.

## Henüz tamamlanmamış doğrulama

Hesap silme ve dışa aktarma, gerçek bir test hesabıyla uçtan uca doğrulanmadı. Teslim öncesi test hesabında şunları kontrol et:

- Yanlış parola ile silme reddedilir ve doğru parola ile yakın zamanda yeniden doğrulama sonrası işlem ilerler.
- Hesap silinince Auth hesabı ve özel profil bilgileri kaldırılır; park raporları anonim kalır.
- Rapor fotoğrafları silinir; profil fotoğrafı Storage yolu varsa o nesne de silinir.
- Başarı sonrası uygulama Welcome/oturum açma akışına döner.
- Dışa aktarma JSON'u yalnızca oturum sahibinin verilerini içerir ve uygulamanın dosyalarına kaydedilir.

## Kupon notu

Ödül kataloğu ve kuponlar demo içeriğidir. Gerçek işletme anlaşmaları, gerçek kullanım teyidi, iptal/iade ve işletme kaynaklı koşullar netleşmeden demo kuponları gerçek ödül gibi sunulmamalıdır.
