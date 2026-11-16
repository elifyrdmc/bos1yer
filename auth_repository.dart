import 'package:supabase_flutter/supabase_flutter.dart';

/// Email/password account operations and the private profile row bootstrap.
/// No service-role key is used; profile access is restricted by RLS.
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) {
    return _client.auth.signUp(
      email: email.trim(),
      password: password,
      // Names live in the signed-in user's private Auth metadata. They are
      // deliberately not copied into the public-facing profiles.nickname.
      data: {
        'first_name': _cleanPersonName(firstName),
        'last_name': _cleanPersonName(lastName),
      },
    );
  }

  Future<void> sendPasswordReset(String email) {
    return _client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: 'bos1yer://reset-password',
    );
  }

  Future<void> setNewPassword(String password) async {
    await _client.auth.updateUser(UserAttributes(password: password));
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _client.auth.updateUser(
      UserAttributes(password: newPassword, currentPassword: currentPassword),
    );
  }

  Future<void> resendEmailConfirmation(String email) {
    return _client.auth.resend(type: OtpType.signup, email: email.trim());
  }

  Future<void> ensureProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final profile = await _client
        .from('profiles')
        .select('id')
        .eq('id', user.id)
        .maybeSingle();
    if (profile != null) return;

    final metadata = user.userMetadata;
    final nickname = metadata?['nickname'];
    await _client.from('profiles').insert({
      'id': user.id,
      'nickname': _cleanNickname(nickname is String ? nickname : ''),
    });
  }

  Future<String?> fetchNickname() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final profile = await _client
        .from('profiles')
        .select('nickname')
        .eq('id', user.id)
        .maybeSingle();
    final value = profile?['nickname'];
    if (value is! String || value.trim().isEmpty) return null;
    return _cleanNickname(value);
  }

  Future<void> updateNickname(String value) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('A signed-in user is required.');

    final updated = await _client
        .from('profiles')
        .update({'nickname': _cleanNickname(value)})
        .eq('id', user.id)
        .select('id')
        .maybeSingle();
    if (updated == null) {
      throw StateError('The signed-in user profile was not updated.');
    }
  }

  /// Returns the current account's private name without reading or exposing
  /// another user's profile row. Legacy nickname values are left untouched.
  ProfileName get ownProfileName {
    final metadata = _client.auth.currentUser?.userMetadata;
    return ProfileName(
      firstName: _cleanPersonName(
        metadata?['first_name'] is String
            ? metadata!['first_name'] as String
            : '',
      ),
      lastName: _cleanPersonName(
        metadata?['last_name'] is String
            ? metadata!['last_name'] as String
            : '',
      ),
    );
  }

  Future<void> updateOwnProfileName({
    required String firstName,
    required String lastName,
  }) async {
    if (_client.auth.currentUser == null) {
      throw StateError('A signed-in user is required.');
    }
    await _client.auth.updateUser(
      UserAttributes(
        data: {
          'first_name': _cleanPersonName(firstName),
          'last_name': _cleanPersonName(lastName),
        },
      ),
    );
  }

  /// Deletes the signed-in account through the server-side Edge Function.
  /// The service-role key never reaches this Flutter client.
  Future<void> deleteAccount() async {
    try {
      await _client.functions.invoke('delete-account', body: const {});
    } on FunctionException catch (error) {
      final detail = error.details?.toString().trim();
      final message = detail == null || detail.isEmpty
          ? error.reasonPhrase ?? 'Sunucu hesabı silemedi.'
          : detail;
      throw StateError('Hesap silinemedi: $message');
    }
    await _client.auth.signOut(scope: SignOutScope.local);
  }

  Future<void> signOutEverywhere() {
    return _client.auth.signOut(scope: SignOutScope.global);
  }

  /// Fetches a JSON-safe export from the server for the signed-in account.
  Future<Map<String, dynamic>> exportAccountData() async {
    final response = await _client.functions.invoke(
      'export-account-data',
      body: const {},
    );
    final data = response.data;
    if (data is! Map) throw const FormatException('Invalid account export.');
    return Map<String, dynamic>.from(data);
  }

  static String _cleanNickname(String value) {
    final nickname = value.trim();
    if (nickname.length < 2) return 'Sürücü';
    return nickname.length > 24 ? nickname.substring(0, 24) : nickname;
  }

  static String _cleanPersonName(Object? value) {
    if (value is! String) return '';
    final cleaned = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    return cleaned.length > 60 ? cleaned.substring(0, 60).trimRight() : cleaned;
  }
}

class ProfileName {
  const ProfileName({required this.firstName, required this.lastName});

  final String firstName;
  final String lastName;

  String get displayName =>
      [firstName, lastName].where((part) => part.trim().isNotEmpty).join(' ');
}
