import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'backend/auth_repository.dart';
import 'backend/supabase_config.dart';
import 'design_system.dart';

enum _AuthView { welcome, signIn, signUp, resetPassword }

/// Signed-out entry point. Email authentication is available; social providers
/// stay out of the form until their real Supabase flows are configured.
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirmation = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  late final AuthRepository? _auth;
  _AuthView _view = _AuthView.welcome;
  bool _busy = false;
  bool _obscurePassword = true;
  bool _obscurePasswordConfirmation = true;
  bool _showResendConfirmation = false;
  bool _termsRead = false;
  bool _privacyRead = false;
  String? _notice;
  String? _error;

  bool get _isRegistering => _view == _AuthView.signUp;
  bool get _isSigningIn => _view == _AuthView.signIn;

  @override
  void initState() {
    super.initState();
    _auth = SupabaseConfig.isConfigured
        ? AuthRepository(Supabase.instance.client)
        : null;
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordConfirmation.dispose();
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  void _openForm(_AuthView view) {
    setState(() {
      _view = view;
      _error = null;
      _notice = null;
      _showResendConfirmation = false;
    });
  }

  Future<void> _submit() async {
    if (_isRegistering && (!_termsRead || !_privacyRead)) {
      setState(() {
        _error = 'Devam etmek için iki taslak bilgilendirmeyi de açıp okuduğunu işaretle.';
        _notice = null;
      });
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final auth = _auth;
    if (auth == null) {
      setState(() {
        _error = 'Hesap servisi henüz yapılandırılmadı. Şu an e-posta ile giriş kullanılamıyor.';
        _notice = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      if (_isRegistering) {
        final result = await auth.signUp(
          email: _email.text,
          password: _password.text,
          firstName: _firstName.text,
          lastName: _lastName.text,
        );
        if (result.session == null && mounted) {
          setState(() {
            _view = _AuthView.signIn;
            _notice = 'E-postanı kontrol et. Yeni kayıt uygunsa doğrulama bağlantısı gönderilir; hesabın varsa giriş yap veya şifreni yenile.';
            _showResendConfirmation = true;
          });
        }
      } else {
        await auth.signIn(email: _email.text, password: _password.text);
      }
    } on SocketException {
      if (mounted) {
        setState(
          () => _error = 'İnternet bağlantısı kesildi. Bağlantını kontrol edip tekrar dene.',
        );
      }
    } on TimeoutException {
      if (mounted) {
        setState(() => _error = 'Bağlantı zaman aşımına uğradı. Tekrar dene.');
      }
    } on AuthException catch (error) {
      if (mounted) {
        final message = error.message.toLowerCase();
        setState(() {
          _showResendConfirmation =
              message.contains('email_not_confirmed') ||
              message.contains('email not confirmed');
          _error = _friendlyAuthError(error);
        });
      }
    } on PostgrestException catch (error) {
      if (mounted) {
        setState(
          () => _error = error.code == '23505'
              ? 'Profil zaten oluşturulmuş. Giriş yapmayı dene.'
              : 'Hesap profili hazırlanamadı. Biraz sonra tekrar dene.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'İşlem tamamlanamadı. Bilgilerini kontrol edip tekrar dene.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendlyAuthError(AuthException error) {
    final message = error.message.toLowerCase();
    if (message.contains('email_not_confirmed') ||
        message.contains('email not confirmed')) {
      return 'E-posta adresini doğrulamadan giriş yapamazsın. Gelen kutunu kontrol et veya onay e-postasını yeniden gönder.';
    }
    if (message.contains('invalid login') ||
        message.contains('invalid credentials')) {
      return 'E-posta veya şifre doğru değil.';
    }
    if (message.contains('already registered') ||
        message.contains('already exists')) {
      return 'Bu e-posta ile bir hesap var. Giriş yapmayı dene.';
    }
    if (message.contains('password')) {
      return 'Şifre en az 8 karakter, bir harf ve bir rakam içermeli.';
    }
    return 'Hesap işlemi tamamlanamadı. Bilgilerini kontrol edip tekrar dene.';
  }

  Future<void> _resendConfirmation() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Önce kayıt olurken kullandığın e-postayı yaz.');
      return;
    }
    final auth = _auth;
    if (auth == null) {
      setState(
        () => _error = 'E-posta doğrulama servisi şu an kullanılamıyor.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await auth.resendEmailConfirmation(email);
      if (mounted) {
        setState(
          () => _notice = 'Onay e-postası yeniden gönderildi. Gelen kutusu ve spam klasörünü kontrol et.',
        );
      }
    } on AuthException catch (error) {
      if (mounted) {
        setState(
          () => _error = error.message.toLowerCase().contains('rate')
              ? 'Çok fazla e-posta istendi. Bir süre bekleyip tekrar dene.'
              : 'E-posta gönderilemedi. Biraz sonra tekrar dene.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'E-posta gönderilemedi. Bağlantını kontrol edip tekrar dene.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Şifre sıfırlama bağlantısı için e-postanı yaz.');
      return;
    }
    final auth = _auth;
    if (auth == null) {
      setState(() => _error = 'Şifre yenileme servisi şu an kullanılamıyor.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await auth.sendPasswordReset(email);
      if (mounted) {
        setState(
          () => _notice = 'Şifre sıfırlama bağlantısı gönderildi. Gelen kutusu ve spam klasörünü kontrol et.',
        );
      }
    } on AuthException catch (error) {
      if (mounted) {
        setState(
          () => _error = error.message.toLowerCase().contains('rate')
              ? 'Çok fazla istek gönderildi. Bir süre bekleyip tekrar dene.'
              : 'Şifre sıfırlama e-postası gönderilemedi. Bilgilerini kontrol et.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'Şifre sıfırlama e-postası gönderilemedi. Tekrar dene.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openDraftDocument({required bool privacy}) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _DraftLegalPage(privacy: privacy),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pageColor = isDark ? ParkDesign.darkPage : ParkDesign.paper;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: pageColor,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact =
                constraints.maxHeight < 720 || constraints.maxWidth < 360;
            final horizontalPadding = compact ? 20.0 : 24.0;
            final contentBottomPadding = compact ? 12.0 : 20.0;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, contentConstraints) =>
                        SingleChildScrollView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: EdgeInsets.fromLTRB(
                            horizontalPadding,
                            0,
                            horizontalPadding,
                            contentBottomPadding,
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: (contentConstraints.maxHeight -
                                      contentBottomPadding)
                                  .clamp(0.0, double.infinity)
                                  .toDouble(),
                            ),
                            child: _view == _AuthView.welcome
                                ? Align(
                                    alignment: Alignment.topCenter,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: 440,
                                        minHeight: (contentConstraints.maxHeight -
                                                contentBottomPadding)
                                            .clamp(0.0, double.infinity)
                                            .toDouble(),
                                      ),
                                      child: IntrinsicHeight(
                                        child: _buildWelcome(context, compact),
                                      ),
                                    ),
                                  )
                                : Align(
                                    alignment: Alignment.topCenter,
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 440,
                                      ),
                                      child: _view == _AuthView.resetPassword
                                          ? _buildResetRequest(context)
                                          : _buildForm(context, compact),
                                    ),
                                  ),
                          ),
                        ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildWelcome(BuildContext context, bool compact) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Center(child: _BrandHeader(height: 84)),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Boş park yerini bul, paylaş.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: compact ? 28 : 32,
                      letterSpacing: -.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'İstanbul’daki güncel park bildirimlerini gör, bulduklarını toplulukla paylaş.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(color: colors.onSurfaceVariant, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: compact ? 12 : 20),
        SizedBox(height: compact ? 8 : 12),
        const _ProviderOptions(),
        const SizedBox(height: 10),
        _EmailContinueButton(onPressed: () => _openForm(_AuthView.signIn)),
        SizedBox(height: compact ? 12 : 20),
      ],
    );
  }

  Widget _buildResetRequest(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Center(child: _BrandHeader(height: 84)),
        ),
        Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: 'Giriş ekranına dön',
                onPressed: _busy ? null : () => _openForm(_AuthView.signIn),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 52),
              child: Text(
                _notice == null ? 'Şifreni yenile' : 'E-postanı kontrol et',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          _notice == null
              ? 'Hesabına bağlı e-posta adresini yaz. Şifreni yenilemen için bir bağlantı göndereceğiz.'
              : 'Şifre yenileme bağlantısını e-postana gönderdik. Gelen kutunu ve spam klasörünü kontrol et.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge
              ?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 28),
        if (_notice == null) ...[
          TextFormField(
            controller: _email,
            enabled: !_busy,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            onFieldSubmitted: (_) => _forgotPassword(),
            decoration: const InputDecoration(
              labelText: 'E-posta',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
          ),
          const SizedBox(height: 12),
          if (_error != null) ...[
            _MessageBox(text: _error!, isError: true),
            const SizedBox(height: 12),
          ],
          FilledButton(
            onPressed: _busy ? null : _forgotPassword,
            style: FilledButton.styleFrom(
              disabledBackgroundColor: colors.primary,
              disabledForegroundColor: colors.onPrimary,
            ),
            child: Text(_busy ? 'Bağlantı gönderiliyor…' : 'Bağlantı gönder'),
          ),
        ] else
          FilledButton(
            onPressed: () => _openForm(_AuthView.signIn),
            child: const Text('Giriş ekranına dön'),
          ),
      ],
    );
  }

  Widget _buildForm(BuildContext context, bool compact) {
    final colors = Theme.of(context).colorScheme;
    return AutofillGroup(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Center(child: _BrandHeader(height: 84)),
            ),
            Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    tooltip: 'Karşılama ekranına dön',
                    onPressed: _busy
                        ? null
                        : () => _openForm(_AuthView.welcome),
                    icon: const Icon(Icons.arrow_back_rounded),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 52),
                  child: Text(
                    _isRegistering ? 'Aramıza katıl' : 'Tekrar hoş geldin',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.5,
                    ),
                  ),
                ),
              ],
            ),
            if (!_isRegistering) ...[
              const SizedBox(height: 6),
              Text(
                'E-posta ve şifrenle devam et.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
            SizedBox(
              height: _isRegistering ? (compact ? 8 : 10) : (compact ? 16 : 20),
            ),
            if (_isRegistering) ...[
              LayoutBuilder(
                builder: (context, nameConstraints) {
                  final nameWidth = nameConstraints.maxWidth < 340
                      ? nameConstraints.maxWidth
                      : (nameConstraints.maxWidth - 10) / 2;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: nameWidth,
                        child: TextFormField(
                          controller: _firstName,
                          enabled: !_busy,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.givenName],
                          decoration: const InputDecoration(
                            labelText: 'Ad',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                          validator: (value) =>
                              (value?.trim().isNotEmpty ?? false)
                              ? null
                              : 'Adını yaz.',
                        ),
                      ),
                      SizedBox(
                        width: nameWidth,
                        child: TextFormField(
                          controller: _lastName,
                          enabled: !_busy,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.familyName],
                          decoration: const InputDecoration(labelText: 'Soyad'),
                          validator: (value) =>
                              (value?.trim().isNotEmpty ?? false)
                              ? null
                              : 'Soyadını yaz.',
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 6),
            ],
            TextFormField(
              controller: _email,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'E-posta',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
              validator: (value) =>
                  RegExp(r'^[^@\s]+@[^@\s]+\.[A-Za-z]{2,}$')
                      .hasMatch(value?.trim() ?? '')
                  ? null
                  : 'Geçerli bir e-posta adresi gir.',
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _password,
              enabled: !_busy,
              obscureText: _obscurePassword,
              textInputAction: _isRegistering
                  ? TextInputAction.next
                  : TextInputAction.done,
              autofillHints: _isRegistering
                  ? const [AutofillHints.newPassword]
                  : const [AutofillHints.password],
              onFieldSubmitted: _isRegistering ? null : (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Şifre',
                helperText: _isRegistering
                    ? 'En az 8 karakter; bir harf ve bir rakam.'
                    : null,
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: _obscurePassword
                      ? 'Şifreyi göster'
                      : 'Şifreyi gizle',
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (value) {
                final password = value ?? '';
                if (_isRegistering) {
                  if (password.length < 8) {
                    return 'Şifre en az 8 karakter olmalı.';
                  }
                  if (!RegExp(r'[A-Za-z]').hasMatch(password)) {
                    return 'Şifrede en az bir harf olmalı.';
                  }
                  if (!RegExp(r'\d').hasMatch(password)) {
                    return 'Şifrede en az bir rakam olmalı.';
                  }
                } else if (password.length < 6) {
                  return 'Şifre en az 6 karakter olmalı.';
                }
                return null;
              },
            ),
            if (_isRegistering) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordConfirmation,
                enabled: !_busy,
                obscureText: _obscurePasswordConfirmation,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Şifre tekrar',
                  prefixIcon: const Icon(Icons.lock_reset_rounded),
                  suffixIcon: IconButton(
                    tooltip: _obscurePasswordConfirmation
                        ? 'Şifreyi göster'
                        : 'Şifreyi gizle',
                    onPressed: () => setState(
                      () => _obscurePasswordConfirmation =
                          !_obscurePasswordConfirmation,
                    ),
                    icon: Icon(
                      _obscurePasswordConfirmation
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (value) =>
                    value == _password.text ? null : 'Şifreler aynı olmalı.',
              ),
              SizedBox(height: compact ? 8 : 10),
              _LegalAcknowledgementRow(
                label: 'Kullanım koşulları',
                value: _termsRead,
                onChanged: (value) => setState(() => _termsRead = value),
                onOpen: () => _openDraftDocument(privacy: false),
              ),
              const SizedBox(height: 0),
              _LegalAcknowledgementRow(
                label: 'Gizlilik bilgilendirmesi',
                value: _privacyRead,
                onChanged: (value) => setState(() => _privacyRead = value),
                onOpen: () => _openDraftDocument(privacy: true),
              ),
              const SizedBox(height: 4),
            ] else ...[
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _busy
                      ? null
                      : () => _openForm(_AuthView.resetPassword),
                  child: const Text('Şifremi unuttum'),
                ),
              ),
            ],
            if (_error != null || _notice != null) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: _MessageBox(
                    text: _error ?? _notice!,
                    isError: _error != null,
                  ),
                ),
              ),
            ],
            if (_showResendConfirmation && _isSigningIn)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _busy ? null : _resendConfirmation,
                  child: const Text('Onay e-postasını yeniden gönder'),
                ),
              ),
            SizedBox(height: compact ? 6 : 8),
            FilledButton(
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(
                disabledBackgroundColor: colors.primary,
                disabledForegroundColor: colors.onPrimary,
              ),
              child: _busy
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.onPrimary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _isRegistering
                              ? 'Hesap oluşturuluyor…'
                              : 'Giriş yapılıyor…',
                        ),
                      ],
                    )
                  : Text(_isRegistering ? 'Hesap oluştur' : 'Giriş yap'),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: Divider(color: colors.outline)),
                Flexible(
                  flex: 4,
                  child: Text(
                    'Diğer giriş seçenekleri',
                    textAlign: TextAlign.center,
                    softWrap: true,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                Expanded(child: Divider(color: colors.outline)),
              ],
            ),
            const SizedBox(height: 12),
            const _ProviderOptions(),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  _isRegistering
                      ? 'Zaten hesabın var mı?'
                      : 'İlk kez mi geliyorsun?',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _openForm(
                          _isRegistering ? _AuthView.signIn : _AuthView.signUp,
                        ),
                  child: Text(_isRegistering ? 'Giriş yap' : 'Hesap oluştur'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) => BrandLockup(
    iconSize: height,
    wordmarkHeight: height * .36,
    gap: height * .12,
  );
}

class _ProviderOptions extends StatelessWidget {
  const _ProviderOptions();

  @override
  Widget build(BuildContext context) => const Column(
    children: [
      _ProviderOption(name: 'Google', provider: _Provider.google),
      SizedBox(height: 8),
      _ProviderOption(name: 'Apple', provider: _Provider.apple),
    ],
  );
}

class _EmailContinueButton extends StatelessWidget {
  const _EmailContinueButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onPressed,
    icon: const Icon(Icons.mail_outline_rounded),
    label: const Text('E-posta ile devam et'),
    style: FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(56),
      textStyle: Theme.of(context).textTheme.labelLarge,
    ),
  );
}

enum _Provider { google, apple }

class _ProviderOption extends StatelessWidget {
  const _ProviderOption({required this.name, required this.provider});
  final String name;
  final _Provider provider;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isApple = provider == _Provider.apple;
    final isGoogle = provider == _Provider.google;
    final background = isApple ? const Color(0xFF000000) : colors.surface;
    final foreground = isApple ? Colors.white : colors.onSurface;
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: isApple ? null : Border.all(color: colors.outline),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: _ProviderLogo(provider: provider),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Google ile devam et'.replaceFirst('Google', name),
              style: TextStyle(
                color: foreground,
                fontFamily: isGoogle ? 'GoogleSans' : null,
                fontSize: 16,
                fontWeight: isGoogle ? FontWeight.w500 : FontWeight.w600,
              ),
            ),
          ),
          Text(
            'Yakında',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: isApple ? Colors.white70 : colors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProviderLogo extends StatelessWidget {
  const _ProviderLogo({required this.provider});
  final _Provider provider;

  @override
  Widget build(BuildContext context) {
    if (provider == _Provider.google) {
      return Semantics(
        image: true,
        label: 'Google logosu',
        child: Image.asset(
          'assets/brand/google_g_icon.png',
          width: 24,
          height: 24,
          fit: BoxFit.contain,
          excludeFromSemantics: true,
        ),
      );
    }
    return FaIcon(
      FontAwesomeIcons.apple,
      size: 26,
      color: Colors.white,
      semanticLabel: 'Apple logosu',
    );
  }
}

class _LegalAcknowledgementRow extends StatelessWidget {
  const _LegalAcknowledgementRow({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.onOpen,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: Checkbox(
            value: value,
            onChanged: (next) => onChanged(next ?? false),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Wrap(
            spacing: 4,
            runSpacing: 0,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Semantics(
                link: true,
                label: '$label taslak metnini aç',
                onTap: onOpen,
                child: InkWell(
                  onTap: onOpen,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                        decorationThickness: 1.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              ),
              Text(
                label == 'Kullanım koşulları' ? 'nı okudum' : 'ni okudum',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DraftLegalPage extends StatelessWidget {
  const _DraftLegalPage({required this.privacy});
  final bool privacy;

  @override
  Widget build(BuildContext context) {
    final title = privacy ? 'Gizlilik bilgilendirmesi' : 'Kullanım koşulları';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              'Taslak metin — yayın öncesi hukuk incelemesi gerekir.',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Bu sayfa hukuki belge değildir',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            privacy
                ? 'BOŞ1YER’in yayın öncesinde; hesap bilgileri, konum kullanımı, bildirim ve fotoğraf verileri, saklama süreleri, hizmet sağlayıcılar ve kullanıcı hakları hakkında onaylı bir gizlilik metni yayımlaması gerekir.'
                : 'BOŞ1YER’in yayın öncesinde; hizmetin kapsamı, topluluk bildirimlerinin niteliği, kullanıcı sorumlulukları, hesap koşulları ve destek süreci için onaylı kullanım koşulları yayımlaması gerekir.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 14),
          Text(
            'Bu taslak gerçek bir onay veya hukuki kabul kaydı oluşturmaz. Metin şirket ve hukuk danışmanı tarafından tamamlanıp onaylanmalıdır.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({required this.text, required this.isError});
  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: isError
          ? Theme.of(context).colorScheme.surface
          : Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isError
            ? Theme.of(context).colorScheme.error.withValues(alpha: .58)
            : Theme.of(context).colorScheme.primary.withValues(alpha: .25),
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          isError
              ? Icons.error_outline_rounded
              : Icons.check_circle_outline_rounded,
          size: 20,
          color: isError
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isError
                  ? Theme.of(context).colorScheme.onSurface
                  : Theme.of(context).colorScheme.onSurface,
              height: 1.3,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Shown only after Supabase reports a valid password-recovery link.
class PasswordRecoveryPage extends StatefulWidget {
  const PasswordRecoveryPage({required this.onComplete, super.key});
  final VoidCallback onComplete;

  @override
  State<PasswordRecoveryPage> createState() => _PasswordRecoveryPageState();
}

class _PasswordRecoveryPageState extends State<PasswordRecoveryPage> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  bool _saved = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AuthRepository(Supabase.instance.client)
          .setNewPassword(_password.text);
      if (mounted) setState(() => _saved = true);
    } on AuthException {
      if (mounted) {
        setState(
          () => _error = 'Bağlantının süresi dolmuş olabilir. Giriş ekranından yeni bağlantı iste.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Şifre yenilenemedi. Bağlantını kontrol edip tekrar dene.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 48,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        child: Center(child: _BrandHeader(height: 84)),
                      ),
                      Text(
                        'Yeni şifreni belirle',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'En az 8 karakter, bir harf ve bir rakam kullan.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      if (!_saved)
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _password,
                                obscureText: _obscure,
                                enabled: !_busy,
                                decoration: InputDecoration(
                                  labelText: 'Yeni şifre',
                                  suffixIcon: IconButton(
                                    tooltip: _obscure
                                        ? 'Şifreyi göster'
                                        : 'Şifreyi gizle',
                                    onPressed: () =>
                                        setState(() => _obscure = !_obscure),
                                    icon: Icon(
                                      _obscure
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  final password = value ?? '';
                                  if (password.length < 8 ||
                                      !RegExp(r'[A-Za-z]').hasMatch(password) ||
                                      !RegExp(r'\d').hasMatch(password)) {
                                    return '8 karakter, bir harf ve bir rakam gerekli.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _confirmation,
                                obscureText: true,
                                enabled: !_busy,
                                decoration: const InputDecoration(
                                  labelText: 'Yeni şifre tekrar',
                                ),
                                validator: (value) => value == _password.text
                                    ? null
                                    : 'Şifreler aynı olmalı.',
                              ),
                            ],
                          ),
                        ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        _MessageBox(text: _error!, isError: true),
                      ],
                      if (_saved) ...[
                        _MessageBox(text: 'Şifren yenilendi.', isError: false),
                        const SizedBox(height: 16),
                      ] else
                        const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _busy
                            ? null
                            : (_saved ? widget.onComplete : _save),
                        style: FilledButton.styleFrom(
                          disabledBackgroundColor: colors.primary,
                          disabledForegroundColor: colors.onPrimary,
                        ),
                        child: Text(
                          _busy
                              ? 'Şifre yenileniyor…'
                              : (_saved ? 'Devam et' : 'Şifreyi yenile'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Signed-in account details and sign-out action for the profile page.
class AccountStatusCard extends StatelessWidget {
  const AccountStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    if (!SupabaseConfig.isConfigured) return const SizedBox.shrink();
    final client = Supabase.instance.client;
    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final user = snapshot.data?.session?.user ?? client.auth.currentUser;
        if (user == null) return const SizedBox.shrink();
        final colors = Theme.of(context).colorScheme;
        return ListTile(
          leading: Icon(Icons.logout_rounded, color: colors.error),
          title: Text(
            'Bu hesaptan çıkış yap',
            style: TextStyle(color: colors.error),
          ),
          subtitle: user.email == null ? null : Text(user.email!),
          onTap: () async {
            final navigator = Navigator.of(context, rootNavigator: true);
            final messenger = ScaffoldMessenger.of(context);
            try {
              final signOutRequest = client.auth.signOut();
              // Close the profile route immediately while AuthGate receives
              // the signed-out event.
              closeProfileAfterSignOut(navigator);
              await signOutRequest;
            } catch (_) {
              if (messenger.mounted) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Çıkış yapılamadı. Tekrar dene.'),
                  ),
                );
              }
            }
          },
        );
      },
    );
  }
}

/// Closes the profile route as soon as sign-out starts.
void closeProfileAfterSignOut(NavigatorState navigator) {
  if (navigator.mounted && navigator.canPop()) {
    navigator.pop();
  }
}
