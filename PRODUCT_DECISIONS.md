# BOŞ1YER ürün kararları ve açık noktalar

Son güncelleme: 14 Kasım 2026

Bu kayıt, ürün sahibiyle netleşen kuralları geliştirici varsayımlarından ayırır. İşletme veya hukuk anlaşması gerektiren konularda bu belge tek başına sözleşme yerine geçmez.

## Kuponlar

### Kararlaştırılmış kurallar

- Şu an katalogdaki teklifler demo örneğidir. Gerçek işletme anlaşması ve kullanım doğrulaması yoktur.
- Teklifin süresi işletme tarafından belirlenir. Ay cinsinden süre veya süresiz seçenek kullanılabilir; kısa süreli kampanyalar gün cinsinden de tanımlanabilir.
- Kupon süresi, puanın düşülüp kuponun verildiği anda başlar. Ay cinsinden süre takvim ayı olarak hesaplanır; sunucu saat dilimi `Europe/Istanbul`'dur. Ay sonu taşması hedef aydaki son güne kısalır (ör. 31 Ocak + 1 ay → 28/29 Şubat).
- Çok kullanımlı teklifin puanı ilk satın almada bir kez düşer. Gerçek kullanım adedini işletme takip eder; uygulama henüz doğrulamaz.
- Teklif yeniden satın almaya izin verebilir. Aynı teklif için aktif kupon varken yeni alım yapılmaz; mevcut ürün kuralında süresi dolan kupondan sonra yeniden alım açılabilir.
- Kullanıcı kuponu iptal edemez. Kullanılmayan kupon için puan iadesi tanımlı değildir.
- Anlaşma yürürlükteyken işletme kuponu kabul etmemiş gibi bir uygulama durumu gösterilmez. Anlaşmaya göre katalog satışı sürer; anlaşma bitişi varsa yeni alımlar durur, daha önce verilmiş kupon kendi süresini korur.
- Şube kapsamı ve kullanım talimatını işletme sağlar; katalog kaydında tüm şubeler veya seçili şubeler açıkça belirtilir.

### Mevcut uygulamanın gerçek durumu

- Sunucu kuponu satın alma sırasında oluşturur, puanı aynı işlemde bir kez düşer ve satın alma anındaki teklif koşullarını kupona kopyalar.
- Supabase listelemesi şu an kuponu aktif veya süresi geçmişse süresi dolmuş döndürür. Kuponu `used` durumuna geçiren bir işletme/QR doğrulama entegrasyonu yoktur.
- Uygulamada “Kullanıldı” sekmesi görünür, ancak kullanıcı kuponu oraya taşıyamaz; sekme gerçek kullanım kaydı veya doğrulama kanıtı değildir.
- Yeniden satın alma denetimi sunucuda mevcut kuponun bitiş zamanına göre yapılır. Gelecekte işletme doğrulaması eklendiğinde, doğrulanmış kullanımdan sonra kupon süresi dolmadan tekrar alımın açılıp açılmayacağı bu sunucu kuralına ayrıca eklenmelidir.
- Demo QR/kod/link gerçek işletmede kullanılamaz. Kullanıcıya bunları gerçek fayda veya anlaşma gibi sunmayın.

### Sonraki teknik ve işletme kararları

- Kullanımı kim doğrulayacak ve doğrulama kanıtı ne olacak?
- Kullanım doğrulanınca hangi bilgi saklanacak; tekrar satın alma aynı anda mı açılacak?
- İşletme/teklif yönetim aracı, QR veya online kod entegrasyonu ve çevrimdışı durumda izlenecek yol ne olacak?
- İptal/iade istisnası, anlaşma sonu ve önceden verilmiş kuponların işletme yükümlülükleri sözleşmede nasıl tanımlanacak?

Bu başlıklar çözülene kadar istemci tarafından kuponu “kullanıldı” diye güncelleyen işlem eklenmemelidir.

## Hesap, rapor ve veri

- Hesap silme için parola yeniden doğrulaması gerekir. Silme başarılı olduğunda oturum kapatılıp oturumsuz akışa dönülür.
- Hesap silinince özel profil verileri ve kullanıcı fotoğrafları temizlenir; park raporları kişisel bilgilerden arındırılarak korunur.
- Veri dışa aktarma ve hesap silme için istemciye service-role/secret anahtar verilmez; sunucu Edge Function kullanılır.
- Kullanım koşulları ve gizlilik metinleri hukukça onaylanmış metin değildir. Taslak ibaresi kaldırılmadan gerçek yasal kabul olarak sunulamaz.

## Bakım notu

Kararlar ürün sahibiyle yapılan çalışma görüşmelerinden kaydedilmiştir. Kod, migration veya işletme anlaşması değişirse bu belgeyi de güncelleyin. Yeni davranışı yalnızca bu metne dayanarak canlı veritabanına uygulamayın; önce mevcut kodu ve Supabase şemasını inceleyin.
