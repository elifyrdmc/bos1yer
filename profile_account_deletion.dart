part of '../profile_settings_page.dart';

class _DeleteAccountConfirmationSheet extends StatelessWidget {
  const _DeleteAccountConfirmationSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hesabın silinsin mi?',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w800,
              height: 1.15,
              letterSpacing: -.45,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Profilin ve özel verilerin silinir. Park raporların konum ve zaman bilgisiyle anonim kalır; fotoğraf ve notların kaldırılır. Bu işlem geri alınamaz.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Devam et'),
          ),
          const SizedBox(height: 8),
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Vazgeç'),
          ),
        ],
      ),
    );
  }
}

class _DeleteAccountPasswordDialog extends StatefulWidget {
  const _DeleteAccountPasswordDialog({
    required this.email,
    required this.userId,
    required this.auth,
  });

  final String email;
  final String userId;
  final AuthRepository auth;

  @override
  State<_DeleteAccountPasswordDialog> createState() =>
      _DeleteAccountPasswordDialogState();
}

class _DeleteAccountPasswordDialogState
    extends State<_DeleteAccountPasswordDialog> {
  final _password = TextEditingController();
  final _focusNode = FocusNode();
  String? _error;
  String? _message;
  bool _busy = false;

  @override
  void dispose() {
    _focusNode.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _verifyPassword() async {
    if (_busy || _password.text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      final result = await widget.auth.signIn(
        email: widget.email,
        password: _password.text,
      );
      if (result.user?.id != widget.userId) {
        throw StateError('Kimlik doğrulanamadı.');
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Şifre doğrulanamadı. Kontrol edip tekrar dene.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _message = null;
    });
    try {
      await widget.auth.sendPasswordReset(widget.email);
      if (mounted) {
        setState(
          () => _message = 'Şifre yenileme bağlantısını e-postana gönderdik. Şifreni yenileyip bu ekrana dönerek işlemi yeniden başlat.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'E-posta gönderilemedi. Biraz sonra tekrar dene.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final availableHeight =
        MediaQuery.sizeOf(context).height -
        MediaQuery.viewInsetsOf(context).bottom -
        48;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: availableHeight.clamp(240.0, 900.0).toDouble(),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Şifreni doğrula',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                  letterSpacing: -.45,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Hesabını silmeden önce ${widget.email} adresinin parolasını doğrulamamız gerekiyor.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _password,
                focusNode: _focusNode,
                autofocus: true,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _verifyPassword(),
                onTapOutside: (_) => _focusNode.unfocus(),
                onChanged: (_) => setState(() {
                  _error = null;
                  _message = null;
                }),
                decoration: const InputDecoration(
                  labelText: 'Mevcut şifre',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: ParkDesign.destructiveAction(
                      Theme.of(context).brightness,
                    ),
                  ),
                ),
              ],
              if (_message != null) ...[
                const SizedBox(height: 12),
                Text(
                  _message!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              TextButton(
                onPressed: _busy ? null : _sendPasswordReset,
                child: const Text('Şifremi unuttum'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: const Text('Vazgeç'),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  backgroundColor: ParkDesign.destructiveButton(
                    Theme.of(context).brightness,
                  ),
                  foregroundColor: Colors.white,
                ),
                onPressed: _busy || _password.text.isEmpty
                    ? null
                    : _verifyPassword,
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.delete_forever_outlined),
                label: const Text('Hesabı kalıcı olarak sil'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountDeletionProgressDialog extends StatelessWidget {
  const _AccountDeletionProgressDialog();

  @override
  Widget build(BuildContext context) => Dialog(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          const SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Hesap verilerin siliniyor…',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> _exportAccountData(BuildContext context) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Expanded(child: Text('Verilerin hazırlanıyor...')),
        ],
      ),
    ),
  );

  try {
    final export = await AuthRepository(Supabase.instance.client)
        .exportAccountData();
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final file = File('${directory.path}/bos1yer-veriler-$timestamp.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(export),
      flush: true,
    );
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Veri dosyası hazır'),
        content: SelectableText(
          'JSON dosyası cihazına kaydedildi:\n\n${file.path}\n\nDosyada yalnızca kendi hesap verilerin bulunur; özel Storage fotoğraf yolları ve başka kullanıcılar dahil edilmez.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  } catch (_) {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Veriler indirilemedi. Bağlantıyı kontrol edip tekrar dene.',
        ),
      ),
    );
  }
}

Future<void> _confirmSignOutEverywhere(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Tüm cihazlardan çıkış yapılsın mı?'),
      content: const Text(
        'Bu hesapla açık olan diğer telefon ve tarayıcı oturumları da kapatılır. Bu cihazda tekrar giriş yapman gerekir.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Tümünden çık'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  try {
    final navigator = Navigator.of(context, rootNavigator: true);
    await AuthRepository(Supabase.instance.client).signOutEverywhere();
    closeProfileAfterSignOut(navigator);
  } on AuthException catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Oturumlar kapatılamadı. Tekrar dene.')),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Çıkış yapılamadı. Bağlantıyı kontrol et.')),
    );
  }
}

Future<void> _resendAccountEmailConfirmation(
  BuildContext context,
  String? email,
) async {
  if (email == null || email.trim().isEmpty) return;
  try {
    await AuthRepository(Supabase.instance.client)
        .resendEmailConfirmation(email);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Doğrulama e-postası yeniden gönderildi.')),
    );
  } on AuthException catch (error) {
    if (!context.mounted) return;
    final isRateLimited = error.message.toLowerCase().contains('rate');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isRateLimited
              ? 'Çok fazla e-posta istendi. Biraz bekleyip tekrar dene.'
              : 'Doğrulama e-postası gönderilemedi.',
        ),
      ),
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Doğrulama e-postası gönderilemedi.')),
    );
  }
}

Future<void> _showInfo(
  BuildContext context,
  _ProfilePreview preview,
  String title,
  List<Widget> children,
) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [...children],
      ),
    ),
  ),
);
