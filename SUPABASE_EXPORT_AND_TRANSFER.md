# Supabase veritabanı şema teslimi

Son güncelleme: 14 Kasım 2026

## Teslim edilen dosya

`work/bos1yer-schema-only-delivery/` klasöründe yalnızca iki dosya bulunur:

- `schema-only.sql`: 14 Kasım 2026'da alınan `schema.sql` çıktısının veri satırı içermeyen kopyası.
- `README.md`: kapsamı, Supabase bağımlılıklarını ve kurulum sınırlarını açıklar.

Bu klasöre `data.sql`, `roles.sql`, kullanıcı fotoğrafları, anahtar veya bağlantı parolası eklenmez. `schema-only.sql` yalnızca şema tanımlarını, fonksiyonları, erişim politikalarını ve izinleri içerir; kullanıcı/rapor/kupon satırlarını içermez.

## Güvenlik notu

Mevcut `work/bos1yer-database-export/data.sql` dosyasını teslim etmeyin. İncelemede bu dosyanın Supabase `auth` tablolarından kullanıcı, oturum, yenileme ve geçici kimlik doğrulama kayıtları içerdiği görüldü. Bu dosya kullanıcı verisi ve geçici kimlik bilgileri barındırabilir. Kaynak ZIP'ine, GitHub'a veya alıcıya eklenmemelidir. Yerel dosyayı saklama gereği kalmadığında güvenli biçimde silin.

`roles.sql` ayrı teslim dosyasına alınmadı. Hedef Supabase projesi kendi yönetilen rollerini sağlar; bu dosyadaki rol ayarları yeni projeye otomatik aktarılmamalıdır.

## Nerede çalışır?

Bu SQL, Supabase Postgres için oluşturulmuştur. `auth.users`, `auth.uid()`, `storage.objects`, Supabase rolleri ve uzantılarına dayanır. **Genel bir PostgreSQL sunucusunda veya başka bir SQL hizmetinde doğrudan çalışacağı garanti edilmez.** Başka bir sağlayıcıya geçiş; Auth, Storage, erişim politikaları ve uygulama API'leri için uyarlama gerektirir.

Bu dosya tek başına yeni ve çalışır bir BOŞ1YER backend'i kurmaz. Supabase tarafından yönetilen Auth/Storage nesnelerini ve Storage bucket ayarlarını içermez. Tam uygulama kurulumu için kaynak depodaki `supabase/migrations/` dizisi kanonik kurulum kaynağıdır. Migration'larda kişisel kullanıcı verisi yoktur; ancak ödül kataloğunu göstermek için sabit, açıkça demo olarak işaretlenmiş örnek kupon kayıtları ekleyen seed migration'ları vardır. Şirket hiç örnek kayıt istemezse bu seed'ler hedefte uygulanmadan önce gözden geçirilmelidir; mevcut migration dosyalarını sonradan düzenlemek yerine yeni ve temiz bir kurulum planı hazırlanmalıdır.

## Kurulum ve doğrulama

1. Hedef Supabase projesi şirketin sahipliğinde oluşturulur; Auth, Storage, e-posta ve redirect ayarları şirketçe yapılandırılır.
2. Boş Supabase projesinde tam uygulama şeması gerekiyorsa migration'lar sıralı biçimde uygulanır. `schema-only.sql` ile migration'ları aynı hedefe birlikte uygulamayın; aynı nesneleri iki kez oluşturabilir.
3. Sadece SQL şema snapshot'ı incelemek/aktarmak gerekiyorsa `schema-only.sql`, yeni ve boş bir Supabase projesinde yetkili veritabanı bağlantısıyla değerlendirilir. Mevcut projeye veya üretim veritabanına doğrudan yüklemeyin.
4. Kurulumdan sonra Auth, Storage bucket/politikaları, RLS, fonksiyonlar ve uygulama akışları ayrı ayrı doğrulanır.

Mevcut ortamda yerel PostgreSQL/Docker çalıştırılmadı ve ücretli Supabase test dalı açılmadı. Bu nedenle `schema-only.sql` hedef veritabanına geri yüklenerek doğrulanmış değildir. Şu anki dosya, kullanıcı verisi içermeyen şema teslimidir; çalışır kurulum garantisi değildir.

## Hedef ortama ayrıca yapılandırılacaklar

- Supabase Auth e-posta sağlayıcısı, e-posta doğrulama, SMTP, Site URL ve mobil deep-link yönlendirmeleri.
- Storage bucket'ları ve `storage.objects` erişim politikaları; dosya içerikleri taşınmaz.
- `delete-account` ve `export-account-data` Edge Function dağıtımları ve hedefe özel secret'lar.
- Uygulama için yeni proje URL'si ve publishable key. Service-role/secret anahtarları uygulama paketine veya teslim belgelerine konmaz.
- Google ve Apple sağlayıcı girişi şu an etkin değildir; uygulamada “Yakında” olarak kalır.

Hedef organizasyon ve proje belirlenince proje devri veya boş şirkete ait Supabase projesi seçilir. Üretim projesine bu teslim sırasında değişiklik yapılmadı.
