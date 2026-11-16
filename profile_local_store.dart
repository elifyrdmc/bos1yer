part of '../profile_settings_page.dart';

class _ProfilePreview extends ChangeNotifier {
  late final _ProfileLocalStore _store = _ProfileLocalStore(
    userId: SupabaseConfig.isConfigured
        ? Supabase.instance.client.auth.currentUser?.id
        : null,
  );
  Future<void> _saveQueue = Future<void>.value();
  bool _disposed = false;
  bool isLoading = true;
  bool storageAvailable = true;

  String nickname = 'Sürücü';
  String firstName = '';
  String lastName = '';
  String? photoPath;

  String get displayName {
    final name = [
      firstName.trim(),
      lastName.trim(),
    ].where((part) => part.isNotEmpty).join(' ');
    return name.isEmpty ? nickname : name;
  }

  String get _accountNickname {
    final user = Supabase.instance.client.auth.currentUser;
    final metadataName = user?.userMetadata?['nickname'];
    if (metadataName is String && metadataName.trim().isNotEmpty) {
      return metadataName.trim();
    }
    final emailName = user?.email?.split('@').first.trim();
    return emailName == null || emailName.isEmpty ? 'Sürücü' : emailName;
  }

  bool notifications = false;
  bool districtAlerts = false;
  bool nearbyAlerts = false;
  String? district;
  bool quietHours = false;
  TimeOfDay quietStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay quietEnd = const TimeOfDay(hour: 8, minute: 0);

  Future<void> load() async {
    try {
      final saved = await _store.load();
      firstName = saved.firstName;
      lastName = saved.lastName;
      final savedNickname = saved.nickname.trim();
      nickname = savedNickname.isEmpty || savedNickname == 'Deniz'
          ? _accountNickname
          : savedNickname;
      photoPath = saved.photoPath;
      notifications = saved.notifications;
      districtAlerts = saved.districtAlerts;
      nearbyAlerts = saved.nearbyAlerts;
      district = saved.district;
      quietHours = saved.quietHours;
      quietStart = TimeOfDay(
        hour: saved.quietStartMinutes ~/ 60,
        minute: saved.quietStartMinutes % 60,
      );
      quietEnd = TimeOfDay(
        hour: saved.quietEndMinutes ~/ 60,
        minute: saved.quietEndMinutes % 60,
      );

      if (SupabaseConfig.isConfigured &&
          Supabase.instance.client.auth.currentUser != null) {
        try {
          final accountName = AuthRepository(Supabase.instance.client)
              .ownProfileName;
          firstName = accountName.firstName;
          lastName = accountName.lastName;
          final accountNickname = await AuthRepository(Supabase.instance.client)
              .fetchNickname();
          if (accountNickname != null && firstName.trim().isEmpty) {
            nickname = accountNickname;
          }
        } catch (_) {
          // Keep the local value available if the profile request is offline.
        }
      }
    } catch (_) {
      storageAvailable = false;
    } finally {
      isLoading = false;
      _notifyIfMounted();
    }
  }

  void change(VoidCallback update) {
    update();
    _notifyIfMounted();
    if (isLoading) return;
    _saveQueue = _saveQueue.then((_) async {
      try {
        await _store.save(
          _ProfileLocalSnapshot(
            nickname: nickname,
            firstName: firstName,
            lastName: lastName,
            photoPath: photoPath,
            notifications: notifications,
            districtAlerts: districtAlerts,
            nearbyAlerts: nearbyAlerts,
            district: district,
            quietHours: quietHours,
            quietStartMinutes: quietStart.hour * 60 + quietStart.minute,
            quietEndMinutes: quietEnd.hour * 60 + quietEnd.minute,
          ),
        );
        storageAvailable = true;
      } catch (_) {
        storageAvailable = false;
      }
      _notifyIfMounted();
    });
  }

  Future<void> flush() async {
    await _saveQueue;
    if (!storageAvailable) {
      throw const FileSystemException('Profile preferences could not be saved');
    }
  }

  Future<void> clearLocalData() async {
    await _saveQueue;
    await _store.clear();
    nickname = _accountNickname;
    firstName = '';
    lastName = '';
    photoPath = null;
    notifications = false;
    districtAlerts = false;
    nearbyAlerts = false;
    district = null;
    quietHours = false;
    quietStart = const TimeOfDay(hour: 22, minute: 0);
    quietEnd = const TimeOfDay(hour: 8, minute: 0);
    storageAvailable = true;
    _notifyIfMounted();
  }

  Future<String?> storePhoto(String? sourcePath) async {
    try {
      return await _store.storePhoto(sourcePath);
    } catch (_) {
      storageAvailable = false;
      _notifyIfMounted();
      rethrow;
    }
  }

  void _notifyIfMounted() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Device-only profile details are scoped to the signed-in Auth user.
///
/// Legacy unscoped `parkist.profile.*` values are intentionally not imported:
/// their owner cannot be identified safely after an account switch. The user
/// may need to select a local profile photo again after this change.
class _ProfileLocalStore {
  _ProfileLocalStore({this.userId});

  final String? userId;
  String get _prefix => userId == null
      ? 'parkist.profile.guest.'
      : 'parkist.profile.$userId.';
  String get _nickname => '${_prefix}nickname';
  String get _firstName => '${_prefix}first_name';
  String get _lastName => '${_prefix}last_name';
  String get _photoName => '${_prefix}photo_name';
  String get _notifications => '${_prefix}notifications';
  String get _districtAlerts => '${_prefix}district_alerts';
  String get _nearbyAlerts => '${_prefix}nearby_alerts';
  String get _district => '${_prefix}district';
  String get _quietHours => '${_prefix}quiet_hours';
  String get _quietStart => '${_prefix}quiet_start';
  String get _quietEnd => '${_prefix}quiet_end';

  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  Future<_ProfileLocalSnapshot> load() async {
    // Remove vehicle preferences saved by older profile previews. We no longer
    // collect vehicle details because the app cannot verify parking fit.
    await _preferences.remove('${_prefix}vehicle');
    await _preferences.remove('${_prefix}vehicle_size');
    final photoName = await _preferences.getString(_photoName);
    String? photoPath;
    if (photoName != null) {
      try {
        final directory = await getApplicationSupportDirectory();
        final savedPhoto = File('${directory.path}/$photoName');
        if (await savedPhoto.exists()) photoPath = savedPhoto.path;
      } catch (_) {
        // Preferences remain usable in widget previews without a path plugin.
      }
    }

    return _ProfileLocalSnapshot(
      nickname: await _preferences.getString(_nickname) ?? '',
      firstName: await _preferences.getString(_firstName) ?? '',
      lastName: await _preferences.getString(_lastName) ?? '',
      photoPath: photoPath,
      notifications: await _preferences.getBool(_notifications) ?? false,
      districtAlerts: await _preferences.getBool(_districtAlerts) ?? false,
      nearbyAlerts: await _preferences.getBool(_nearbyAlerts) ?? false,
      district: await _preferences.getString(_district),
      quietHours: await _preferences.getBool(_quietHours) ?? false,
      quietStartMinutes: _validMinutes(
        await _preferences.getInt(_quietStart),
        fallback: 22 * 60,
      ),
      quietEndMinutes: _validMinutes(
        await _preferences.getInt(_quietEnd),
        fallback: 8 * 60,
      ),
    );
  }

  Future<void> save(_ProfileLocalSnapshot snapshot) async {
    await _preferences.setString(_nickname, snapshot.nickname);
    await _preferences.setString(_firstName, snapshot.firstName);
    await _preferences.setString(_lastName, snapshot.lastName);
    await _preferences.setBool(_notifications, snapshot.notifications);
    await _preferences.setBool(_districtAlerts, snapshot.districtAlerts);
    await _preferences.setBool(_nearbyAlerts, snapshot.nearbyAlerts);
    await _preferences.setBool(_quietHours, snapshot.quietHours);
    await _preferences.setInt(_quietStart, snapshot.quietStartMinutes);
    await _preferences.setInt(_quietEnd, snapshot.quietEndMinutes);
    await _writeOptionalString(_district, snapshot.district);
    final photoName = snapshot.photoPath?.split(Platform.pathSeparator).last;
    await _writeOptionalString(_photoName, photoName);
  }

  Future<void> clear() async {
    final photoName = await _preferences.getString(_photoName);
    if (photoName != null) {
      final directory = await getApplicationSupportDirectory();
      final photo = File('${directory.path}/$photoName');
      if (await photo.exists()) await photo.delete();
    }
    for (final key in [
      _nickname,
      _firstName,
      _lastName,
      _photoName,
      _notifications,
      _districtAlerts,
      _nearbyAlerts,
      _district,
      _quietHours,
      _quietStart,
      _quietEnd,
    ]) {
      await _preferences.remove(key);
    }
  }

  Future<String?> storePhoto(String? sourcePath) async {
    final previousName = await _preferences.getString(_photoName);
    if (sourcePath == null) {
      await _preferences.remove(_photoName);
      if (previousName == null) return null;
      final directory = await getApplicationSupportDirectory();
      final previous = File('${directory.path}/$previousName');
      if (await previous.exists()) await previous.delete();
      return null;
    }

    final directory = await getApplicationSupportDirectory();
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw const FileSystemException('Profile photo is missing');
    }
    final extension = _safeImageExtension(sourcePath);
    final fileName = 'profile-photo-${userId ?? 'guest'}$extension';
    final destination = File('${directory.path}/$fileName');
    if (source.absolute.path != destination.absolute.path) {
      await source.copy(destination.path);
      await FileImage(destination).evict();
    }
    await _preferences.setString(_photoName, fileName);
    if (previousName != null && previousName != fileName) {
      final previous = File('${directory.path}/$previousName');
      if (await previous.exists()) await previous.delete();
    }
    return destination.path;
  }

  Future<void> _writeOptionalString(String key, String? value) async {
    if (value == null || value.isEmpty) {
      await _preferences.remove(key);
    } else {
      await _preferences.setString(key, value);
    }
  }

  static int _validMinutes(int? value, {required int fallback}) =>
      value != null && value >= 0 && value < 24 * 60 ? value : fallback;

  static String _safeImageExtension(String sourcePath) {
    final extension = sourcePath.split('.').last.toLowerCase();
    return const {'jpg', 'jpeg', 'png', 'heic', 'webp'}.contains(extension)
        ? '.$extension'
        : '.jpg';
  }
}

class _ProfileLocalSnapshot {
  const _ProfileLocalSnapshot({
    required this.nickname,
    required this.firstName,
    required this.lastName,
    required this.photoPath,
    required this.notifications,
    required this.districtAlerts,
    required this.nearbyAlerts,
    required this.district,
    required this.quietHours,
    required this.quietStartMinutes,
    required this.quietEndMinutes,
  });

  final String nickname;
  final String firstName;
  final String lastName;
  final String? photoPath;
  final bool notifications;
  final bool districtAlerts;
  final bool nearbyAlerts;
  final String? district;
  final bool quietHours;
  final int quietStartMinutes;
  final int quietEndMinutes;
}
