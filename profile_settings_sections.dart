part of '../profile_settings_page.dart';

class _SettingsPage extends StatelessWidget {
  const _SettingsPage({required this.preview});
  final _ProfilePreview preview;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ayarlar')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _Section(
          title: 'Hesap ve profil bilgileri',
          children: [
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profil bilgilerini düzenle'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _editProfile(context, preview),
            ),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Hesap bağlantısı'),
              subtitle: Text(
                !SupabaseConfig.isConfigured ||
                        Supabase.instance.client.auth.currentUser == null
                    ? 'Hesap bağlantısı yapılandırılmadı'
                    : Supabase
                              .instance
                              .client
                              .auth
                              .currentUser!
                              .emailConfirmedAt !=
                          null
                    ? 'E-posta doğrulandı'
                    : 'E-posta doğrulanmadı · yeniden gönder',
              ),
              trailing:
                  SupabaseConfig.isConfigured &&
                      Supabase.instance.client.auth.currentUser != null
                  ? Icon(
                      Supabase
                                  .instance
                                  .client
                                  .auth
                                  .currentUser!
                                  .emailConfirmedAt !=
                              null
                          ? Icons.verified_outlined
                          : Icons.warning_amber_outlined,
                      color:
                          Supabase
                                  .instance
                                  .client
                                  .auth
                                  .currentUser!
                                  .emailConfirmedAt !=
                              null
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.error,
                    )
                  : null,
              onTap:
                  SupabaseConfig.isConfigured &&
                      Supabase
                              .instance
                              .client
                              .auth
                              .currentUser
                              ?.emailConfirmedAt ==
                          null
                  ? () => _resendAccountEmailConfirmation(
                      context,
                      Supabase.instance.client.auth.currentUser?.email,
                    )
                  : null,
            ),
          ],
        ),
        _Section(
          title: 'Tercihler',
          children: [
            const AppearanceSetting(),
            ListTile(
              leading: const Icon(Icons.notifications_none),
              title: const Text('İlçe, çevre ve sessiz saatler'),
              subtitle: const Text('Bildirim gönderimi henüz etkin değil'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => _NotificationSettings(preview: preview),
                ),
              ),
            ),
          ],
        ),
        _Section(
          title: 'Gizlilik ve güvenlik',
          children: [
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Konum ve görünürlük'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  _showInfo(context, preview, 'Konum ve görünürlük', const [
                    Text('Konum yalnızca kullanım sırasında'),
                    SizedBox(height: 8),
                    Text(
                      'Arka planda konum takibi yapılmaz. Haritadaki konum düğmesine bastığında konum izni istenir; bu ayar ekranı konum izni istemez.',
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Adın yalnızca kendi hesabında saklanır; diğer kullanıcılara gösterilmez.',
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Uygulama fotoğraflardaki yüzleri ve plakaları otomatik gizlemez. Paylaşmadan önce kişisel bilgileri kontrol et.',
                    ),
                  ]),
            ),
            if (SupabaseConfig.isConfigured &&
                Supabase.instance.client.auth.currentUser != null)
              ListTile(
                leading: const Icon(Icons.password_outlined),
                title: const Text('Şifre değiştir'),
                subtitle: const Text(
                  'Mevcut şifreni doğrula ve yenisini belirle',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => const _ChangePasswordPage(),
                  ),
                ),
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Bu cihazdaki fotoğraf ve tercihleri sil'),
              subtitle: const Text(
                'Hesabındaki takma ad, puan ve katkılar korunur',
              ),
              onTap: () => _confirmClearLocalProfile(context, preview),
            ),
            if (SupabaseConfig.isConfigured &&
                Supabase.instance.client.auth.currentUser != null) ...[
              ListTile(
                leading: Icon(
                  Icons.delete_forever_outlined,
                  color: ParkDesign.destructiveAction(
                    Theme.of(context).brightness,
                  ),
                ),
                title: const Text('Hesabımı sil'),
                subtitle: const Text(
                  'Raporların anonimleştirilir; profilin ve özel verilerin silinir',
                ),
                onTap: () => _confirmDeleteAccount(context),
              ),
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Verilerimi indir'),
                subtitle: const Text(
                  'Profil, rapor geçmişi ve puan hareketlerini JSON olarak kaydet',
                ),
                onTap: () => _exportAccountData(context),
              ),
            ],
          ],
        ),
        _Section(
          title: 'Yardım ve uygulama bilgisi',
          children: [
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: const Text('Nasıl kullanılır?'),
              subtitle: const Text('Bildirim, puan ve kupon akışını öğren'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  _showInfo(context, preview, 'Nasıl kullanılır?', const [
                    ParkHelpStep(
                      icon: Icons.map_outlined,
                      title: 'Harita',
                      description: 'Sarı çıkış tahmini, yeşil aktif, turuncu eskiyen bildirimi gösterir. Park kurallarını yerinde kontrol et.',
                    ),
                    ParkHelpStep(
                      icon: Icons.add_a_photo_outlined,
                      title: 'Bildirim oluştur',
                      description: 'Ekle ile Boş yer veya Çıkıyorum seç. Boş yerde fotoğraf zorunlu; Yakındayım fotoğrafını seçtiğin sürede ekle.',
                    ),
                    ParkHelpStep(
                      icon: Icons.location_searching_outlined,
                      title: 'Sonuç bildir',
                      description: 'Noktaya 30 metre yaklaşınca Park ettim, Yer doluydu veya Bulamadım yanıtı verebilirsin.',
                    ),
                    ParkHelpStep(
                      icon: Icons.stars_outlined,
                      title: 'Puan ve güven',
                      description: 'Fotoğraflı bildirim +10, başka sürücü senin bildiriminle park ederse +20, park eden sürücüye +10 puan verilir. Güven puanı ayrı hesaplanır.',
                    ),
                    ParkHelpStep(
                      icon: Icons.card_giftcard_outlined,
                      title: 'Ödüller',
                      description: 'Puanlarını ve hareketlerini Ödüller’de görürsün. Örnek kuponlar gerçek işletmelerde geçerli değildir.',
                    ),
                  ]),
            ),
            ListTile(
              leading: const Icon(Icons.help_outline),
              title: const Text('Destek'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showInfo(context, preview, 'Destek', const [
                Text(
                  'Destek kanalı henüz tanımlanmadı. Yayından önce ürün sahibi gerçek iletişim bilgisini eklemeli.',
                ),
              ]),
            ),
            ListTile(
              leading: const Icon(Icons.policy_outlined),
              title: const Text('Gizlilik / KVKK'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  _showInfo(context, preview, 'Gizlilik / KVKK', const [
                    Text('Gizlilik metni henüz yayınlanmadı.'),
                    SizedBox(height: 12),
                    Text(
                      'Bu ekran bir gizlilik sözleşmesi veya KVKK onay formu değildir. Gerçek hesap, veri işleme amaçları ve iletişim bilgileri netleşince metin hazırlanmalı.',
                    ),
                  ]),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Uygulama ve park bilgisi'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showInfo(
                context,
                preview,
                'Uygulama ve park bilgisi',
                const [
                  Text('BOŞ1YER · Park paylaşım uygulaması'),
                  SizedBox(height: 12),
                  Text(
                    'İstanbul’da yol kenarı park bilgilerini topluluk katkılarıyla bulmana yardımcı olur.',
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Topluluk bilgisi boş yer veya yasal park garantisi değildir. Yerindeki tabelaları ve güncel kuralları kontrol et. Ücretli otopark, ücretsiz alan ve park kısıtlaması ayrı bilgilerdir.',
                  ),
                ],
              ),
            ),
          ],
        ),
        if (SupabaseConfig.isConfigured &&
            Supabase.instance.client.auth.currentUser != null)
          _Section(
            title: 'Oturum',
            children: [
              const AccountStatusCard(),
              ListTile(
                leading: const Icon(Icons.devices_outlined),
                title: const Text('Tüm cihazlardan çıkış yap'),
                subtitle: const Text('Diğer cihazlardaki oturumları kapat'),
                onTap: () => _confirmSignOutEverywhere(context),
              ),
            ],
          ),
      ],
    ),
  );
}

Future<void> _confirmClearLocalProfile(
  BuildContext context,
  _ProfilePreview preview,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Bu cihazdaki fotoğraf ve tercihler silinsin mi?'),
      content: const Text(
        'Bu işlem profil fotoğrafını ve bu cihazdaki bildirim tercihlerini siler. Hesabındaki takma ad, puan ve katkılar korunur.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Verileri sil'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  try {
    await preview.clearLocalData();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fotoğraf ve cihaz tercihleri silindi.')),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cihaz fotoğrafı ve tercihleri silinemedi. Tekrar dene.'),
      ),
    );
  }
}

Future<void> _confirmDeleteAccount(BuildContext context) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  final email = user?.email;
  if (user == null || email == null || email.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Hesap bilgisi alınamadı. Tekrar giriş yap.'),
      ),
    );
    return;
  }

  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) => const _DeleteAccountConfirmationSheet(),
  );
  if (confirmed != true || !context.mounted) return;

  final reauthenticated = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DeleteAccountPasswordDialog(
      email: email,
      userId: user.id,
      auth: AuthRepository(client),
    ),
  );
  if (reauthenticated != true || !context.mounted) return;

  final navigator = Navigator.of(context, rootNavigator: true);
  final messenger = ScaffoldMessenger.of(context);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _AccountDeletionProgressDialog(),
  );

  try {
    await AuthRepository(client).deleteAccount();
    if (navigator.mounted && navigator.canPop()) navigator.pop();
    // The deletion progress dialog is above the pushed Profile route. Close
    // both so the AuthGate's signed-out state can show Welcome immediately.
    closeProfileAfterSignOut(navigator);
    messenger.showSnackBar(const SnackBar(content: Text('Hesabın silindi.')));
  } catch (_) {
    if (navigator.mounted && navigator.canPop()) navigator.pop();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Hesap silinemedi. Bağlantıyı kontrol edip tekrar dene.'),
      ),
    );
  }
}
