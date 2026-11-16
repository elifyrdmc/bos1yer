# Kaynak kod teslimi

Son güncelleme: 14 Kasım 2026

Özel GitHub deposuna erişim vermeden kaynak kod teslim edilebilir. 14 Kasım 2026'da `work/bos1yer-source.zip` arşivi oluşturuldu. Bu arşiv mevcut proje dosyalarının teslim kopyasıdır; teslimden önce hedef commit ile eşleştiği ve son belge güncellemelerini içerdiği doğrulanmalıdır. Güncel dosya boyutu ve SHA-256 özeti depo dışındaki teslim manifestinde tutulur. Gelecek arşivlerde temiz ve doğrulanmış commit'ten üretmek için:

```sh
git status --short --branch
git log -1 --oneline
git archive --format=zip --prefix=bos1yer-source/ --output=../bos1yer-source.zip main
```

`git archive` yalnızca commit'teki izlenen dosyaları alır; bu yüzden önce gerekli değişiklikler commit edilmiş olmalı ve çalışma ağacı kontrol edilmelidir. Arşivde `.git` geçmişi bulunmaz. Teslimden önce ZIP içeriğini açıp kontrol edin ve SHA-256 özetini teslim tutanağına yazın.

## Kaynak arşivinde bulunması gerekenler

- Flutter uygulama kodu, iOS/Android proje dosyaları ve gerçek marka varlıkları
- `pubspec.yaml` ve `pubspec.lock` gibi bağımlılık tanımları
- `supabase/migrations/` ve `supabase/functions/` kaynakları
- README, tasarım sistemi ve devir/teslim belgeleri
- CI ve doğrulama betikleri

## Arşive eklenmemesi gerekenler

- `.git/`, `supabase.local.json`, `.env` dosyaları veya gerçek bağlantı URI'leri
- Supabase secret/service-role anahtarları, Apple sertifikaları, provisioning profile'ları ve imzalama parolaları
- Kullanıcı verisi içeren canlı SQL yedeği (ayrı, şifreli ve erişimi sınırlı teslim edilir; [Supabase dışa aktarma notu](SUPABASE_EXPORT_AND_TRANSFER.md))
- `build/`, DerivedData, `.dart_tool/` ve diğer üretilebilir derleme çıktıları

Teslimden önce `git status` ve arşiv içeriği gözden geçirilir. Arşiv ayrıca GitHub'a yüklenmez; şirkete güvenli, erişimi sınırlandırılmış bir kanaldan verilir. Sonraki geliştirme için şirket bu kaynaklardan kendi Git deposunu başlatabilir.
