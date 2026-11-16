part of '../profile_settings_page.dart';

class _ProfileEditor extends StatefulWidget {
  const _ProfileEditor({required this.preview});
  final _ProfilePreview preview;

  @override
  State<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<_ProfileEditor> {
  final _form = GlobalKey<FormState>();
  late final _firstName = TextEditingController(text: widget.preview.firstName);
  late final _lastName = TextEditingController(text: widget.preview.lastName);
  late String? _photoPath = widget.preview.photoPath;
  bool _pickingPhoto = false;
  bool _saving = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  Future<void> _choosePhoto() async {
    setState(() => _pickingPhoto = true);
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
        maxWidth: 800,
        imageQuality: 80,
      );
      if (mounted && photo != null) setState(() => _photoPath = photo.path);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Fotoğraf seçilemedi. Fotoğrafsız devam edebilirsin.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Profili düzenle')),
    body: Form(
      key: _form,
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          _PreviewNotice(preview: widget.preview),
          const SizedBox(height: 28),
          Center(child: _ProfileAvatar(path: _photoPath)),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: _pickingPhoto || _saving ? null : _choosePhoto,
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(
              _pickingPhoto ? 'Fotoğraf seçiliyor...' : 'Profil fotoğrafı seç',
            ),
          ),
          if (_photoPath != null)
            TextButton(
              onPressed: _saving || _pickingPhoto
                  ? null
                  : () => setState(() => _photoPath = null),
              child: const Text('Profil fotoğrafını kaldır'),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Fotoğraf yalnızca bu cihazda saklanır; sunucuya yüklenmez.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 28),
          TextFormField(
            enabled: !_saving,
            controller: _firstName,
            maxLength: 60,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Ad',
              border: OutlineInputBorder(),
            ),
            validator: (value) => value?.trim().isNotEmpty == true
                ? null
                : 'Ad alanı boş bırakılamaz.',
          ),
          const SizedBox(height: 12),
          TextFormField(
            enabled: !_saving,
            controller: _lastName,
            maxLength: 60,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Soyad',
              border: OutlineInputBorder(),
            ),
            validator: (value) => value?.trim().isNotEmpty == true
                ? null
                : 'Soyad alanı boş bırakılamaz.',
          ),
          const SizedBox(height: 6),
          Text(
            SupabaseConfig.isConfigured &&
                    Supabase.instance.client.auth.currentUser != null
                ? widget.preview.firstName.isEmpty &&
                          widget.preview.lastName.isEmpty &&
                          widget.preview.nickname != 'Sürücü'
                      ? 'Önceden kaydedilmiş profil adı korunur; adını ve soyadını ekleyebilirsin. Ad bilgisi yalnızca kendi hesabında görünür.'
                      : 'Adın ve soyadın hesabında saklanır, diğer kullanıcılara gösterilmez. E-posta adresin değişmez.'
                : 'Adın bu cihazda saklanır; hesap e-postanı değiştirmez.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: FilledButton(
          onPressed: _pickingPhoto || _saving
              ? null
              : () async {
                  if (!_form.currentState!.validate()) return;
                  final firstName = _firstName.text.trim();
                  final lastName = _lastName.text.trim();
                  setState(() => _saving = true);
                  try {
                    if (SupabaseConfig.isConfigured &&
                        Supabase.instance.client.auth.currentUser != null) {
                      await AuthRepository(Supabase.instance.client)
                          .updateOwnProfileName(
                            firstName: firstName,
                            lastName: lastName,
                          );
                    }
                    final savedPhotoPath = await widget.preview.storePhoto(
                      _photoPath,
                    );
                    widget.preview.change(() {
                      widget.preview.firstName = firstName;
                      widget.preview.lastName = lastName;
                      widget.preview.photoPath = savedPhotoPath;
                    });
                    await widget.preview.flush();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Profil bilgilerin kaydedildi.'),
                      ),
                    );
                    Navigator.of(context).pop();
                  } catch (_) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Profil bilgileri kaydedilemedi.'),
                      ),
                    );
                  } finally {
                    if (mounted) setState(() => _saving = false);
                  }
                },
          child: _saving
              ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 10),
                    Text('Kaydediliyor…'),
                  ],
                )
              : const Text('Değişiklikleri kaydet'),
        ),
      ),
    ),
  );
}

class _ChangePasswordPage extends StatefulWidget {
  const _ChangePasswordPage();

  @override
  State<_ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<_ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmation = TextEditingController();
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirmation = false;
  bool _busy = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _success = null;
    });
    try {
      await AuthRepository(Supabase.instance.client).changePassword(
        currentPassword: _currentPassword.text,
        newPassword: _newPassword.text,
      );
      if (!mounted) return;
      _currentPassword.clear();
      _newPassword.clear();
      _confirmation.clear();
      setState(() => _success = 'Şifren güncellendi.');
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error = 'Şifre değiştirilemedi. Mevcut şifreni ve yeni şifre kurallarını kontrol edip tekrar dene.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Şifre değiştir')),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              Text(
                'Hesabını güvende tut',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Değişikliği onaylamak için mevcut şifreni doğrula.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _currentPassword,
                obscureText: !_showCurrent,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Mevcut şifre',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: _showCurrent ? 'Şifreyi gizle' : 'Şifreyi göster',
                    onPressed: () =>
                        setState(() => _showCurrent = !_showCurrent),
                    icon: Icon(
                      _showCurrent
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Mevcut şifreni yaz.'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newPassword,
                obscureText: !_showNew,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Yeni şifre',
                  prefixIcon: const Icon(Icons.lock_reset_outlined),
                  suffixIcon: IconButton(
                    tooltip: _showNew ? 'Şifreyi gizle' : 'Şifreyi göster',
                    onPressed: () => setState(() => _showNew = !_showNew),
                    icon: Icon(
                      _showNew
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                  helperText: 'En az 8 karakter; bir harf ve bir rakam.',
                ),
                validator: (value) {
                  final password = value ?? '';
                  if (password.length < 8 ||
                      !RegExp(r'[A-Za-z]').hasMatch(password) ||
                      !RegExp(r'\d').hasMatch(password)) {
                    return 'En az 8 karakter, bir harf ve bir rakam kullan.';
                  }
                  if (password == _currentPassword.text) {
                    return 'Yeni şifren mevcut şifrenle aynı olamaz.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmation,
                obscureText: !_showConfirmation,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Yeni şifreyi tekrar yaz',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: _showConfirmation
                        ? 'Şifreyi gizle'
                        : 'Şifreyi göster',
                    onPressed: () =>
                        setState(() => _showConfirmation = !_showConfirmation),
                    icon: Icon(
                      _showConfirmation
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
                validator: (value) => value == _newPassword.text
                    ? null
                    : 'Yeni şifreler aynı olmalı.',
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                _PasswordChangeFeedback(text: _error!, isError: true),
              ],
              if (_success != null) ...[
                const SizedBox(height: 16),
                _PasswordChangeFeedback(text: _success!, isError: false),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: SizedBox(
                  height: 28,
                  child: Center(
                    child: _busy
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Şifreyi güncelle'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordChangeFeedback extends StatelessWidget {
  const _PasswordChangeFeedback({required this.text, required this.isError});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isError ? colors.errorContainer : colors.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError
                ? colors.onErrorContainer
                : colors.onPrimaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: isError
                    ? colors.onErrorContainer
                    : colors.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
