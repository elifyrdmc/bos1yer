# BOŞ1YER arayüz sistemi

Bu belge, onaylanan `parkist-ui-proposal` yönünü Flutter ekranlarına taşımak için ortak kuralları tanımlar. Harita, bildirim, hesap ve ödül davranışları bu tasarım çalışmasında değişmez.

## Yön

- Açık görünümde nötr kırık beyaz sayfa, beyaz yüzey, koyu mürekkep ve temiz canlı yeşil ana eylem kullanılır.
- Koyu görünümde sayfalar siyah ve koyu gri kalır. Yeşil yalnızca seçim, bağlantı ve ana eylem vurgusudur; bütün sayfayı boyamaz.
- Açık lavanta ödül cüzdanına ve seyrek ödül ayrıntılarına ayrılır.
- Park durumu renkleri marka renginden ayrı tutulur: çıkış bekleniyor sarı, yeni aktif bildirim yeşil, eskimiş bildirim turuncu. Renk her zaman metin ya da ikonla desteklenir.
- Aynı bilgiyi bir kartın, liste satırının ve ayrıntının içinde tekrarlamayız. Yasal/ürün uyarısı ilgili karar noktasında kısa gösterilir; yardım açıklaması ayrı yerde yeterli ayrıntıyı verir.

## Tokenlar

Kod karşılıkları `lib/design_system.dart` içindeki `ParkDesign` sınıfındadır. Onaylanan görseldeki ana yeşil `#087C53`, parlak yeşil `#B4CE2E`, açık zemin `#F8F9F5`, açık yüzey `#FFFFFF`, metin `#202723`, lavanta `#EDE8F3` olarak belirlenmiştir. Koyu zemin `#101210`, genel koyu yüzey `#1C201D`, kart yüzeyi nötr gri `#222322`, yükseltilmiş yüzey `#292E29`, metin `#F0F2EC` ve koyu lavanta `#302B36` kullanılır. Profil ve ödül kartları koyu modda gri yüzey ve yeşil kenarlıkla; cüzdan özeti ise lavanta yüzeyle gösterilir.

Boşluk ölçeği 4/8/12/16/24/32; temel köşe 16'dır. Sayfa başlığı 29, alt başlık 22, bölüm başlığı 17, gövde 14–16, yardımcı metin 12 punto ailesindedir. Sayılar ve kısa durum etiketleri okunabilir ağırlıkta kalır. Tek bir adımda bir ana işlem belirgin olur.

## Bileşen ve durum ilkeleri

- Form alanları, ana/ikincil düğmeler, listeler, ayraçlar, çipler ve alt paneller ortak `ThemeData` ile çizilir. Yalnızca gruplanması gereken içerik yüzey içine alınır.
- Boş durum kullanıcıya neyin eksik olduğunu söyler; yüklenme ve hata durumları eylemi gizlemez. Devre dışı eylemin nedeni ilgili alanda kısa anlatılır.
- Uzun Türkçe metinler ve büyük yazı boyutları için satır kaydırma veya kaydırılabilir içerik kullanılır. Dokunma alanları yaklaşık 44–48 pikselden küçük bırakılmaz.
- Yardım kısa başlıklar ve adımlar halinde gösterilir; teknik depolama bilgisi ana kullanıcı akışında yer almaz.
- Yardım girişleri sayfa başlığının yanındaki soru işaretiyle sunulur; aynı amaç için metin bağlantısı ve ikon karıştırılmaz.
- Ödül cüzdanı lavanta yüzeyli tek bir özet alanıdır. Bakiye öne çıkar, hareketler ayırıcı altındaki satırdan açılır. Alınabilir ödül kalmadığında boş durum açıkça söylenir.
- Aktif bildirim listesinde başlık, durum ve zaman taranabilir satırlardır. Güven puanı yalnızca bildirim verisiyle güvenilir biçimde gelirse gösterilir; örnek değer üretilmez.
- Bildirim formunda süre ve konum kararı fotoğraftan önce alınır; konum tercihi açıklamalı seçenekler, süre seçimi kısa bölmeli kontrol olarak gösterilir. Fotoğraf ve doğrulanan konum yan yanadır; araç uygunluğu kısa seçimlerle verilir. Fotoğraf eylemi ikincil, alttaki önizleme/gönderme eylemi birincildir.
- Ekle seçim paneli yalnızca Harita sekmesindeki artı düğmesine bağlı, hızlı açılan kompakt bir açılır paneldir; tam sayfa veya alt gezinme öğesi değildir. Tema tercihi Ayarlar satırından açılan tek seçim panelinde yapılır.

## Gezinme sınırı

Ana sekmeler tüm kök ekranlarda Harita / Ödüller / Profil sırasındadır. Alt gezinme güvenli alt alanda sabit duran, kompakt ve yarı saydam buzlu cam dock olarak kalır; simgelerin yanında kısa etiketleri gösterir. Ödüller ve Profil ekranlarında dock çok açık, nötr mint tonuyla ayrışır; koyu görünümde koyu gri yüzey kullanır. Ödül ve profil sayfalarının zemini beyazdır; beyaz kartlar ince nötr kenarlıkla ayrılır. İçerik dock'un arkasından akabilir; liste sonuna yeterli alt kaydırma payı eklenerek son öğelerin dock'un üstüne alınması sağlanır. Dock'un altında opak, tam genişlikte bir şerit kullanılmaz. Ekle, gezinme öğesi değildir; yalnızca haritada ayrı bir yüzen eylem düğmesi olarak görünür ve bildirim çekmecesinin hemen üstüne, aradaki boşluğu en aza indirecek şekilde yerleşir. Ekle, tür seçimi için artı düğmesinin hemen üstünde açılan küçük panel kullanır. Profil içindeki çıkış eylemi Ayarlar sayfasında yer alır. Harita üst bilgisinde ortalanmış küçük marka kapsülü bulunur; arama çubuğu hemen altında durur. Harita görünümünde görünür yenileme düğmesi yoktur; harita verisi uygulama açılışı, belirli aralıklarla yenileme ve uygulamaya dönüşte otomatik güncellenir. Favori bölgeler arama/filtre kontrollerinden ve Profil içindeki daraltılabilir bölümden açılır. İlçe seçildiğinde sadeleştirilmiş ilçe sınırı düşük opaklıkta doldurma ve belirgin konturla vurgulanır; harita işaretleri üstte kalır.

## Veri sınırı

Ödül kataloğu, puan hareketleri ve demo kupon alımı Supabase üzerinden yürür. Kuponlar hesapla ilişkili sunucu kayıtlarıdır; cihazda yalnızca görüntülenir. Gerçek işletme kullanımı doğrulanmadığından arayüz demo kuponları doğrulanmış kullanım gibi sunmaz.
