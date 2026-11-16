import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_page.dart';
import 'auth_routing.dart';
import 'app_appearance.dart';
import 'design_system.dart';
import 'backend/auth_repository.dart';
import 'backend/parking_report_repository.dart';
import 'backend/points_wallet_repository.dart';
import 'backend/rewards_catalog_repository.dart';
import 'backend/rewards_redemption_repository.dart';
import 'backend/photo_privacy_service.dart';
import 'backend/supabase_config.dart';
import 'parking_report_feedback_panel.dart';
import 'parking_report_photo_upload_panel.dart';
import 'parking_directions.dart';
import 'profile_settings_page.dart';
import 'first_use_hints.dart';
import 'favorite_district_store.dart';
import 'map_filter_rules.dart';
import 'trust_score_format.dart';
import 'istanbul_districts.dart';
import 'district_boundary_store.dart';

part 'src/app_shell.dart';
part 'src/map_controller.dart';
part 'src/map_widgets.dart';
part 'src/map_report_cards.dart';
part 'src/map_canvas.dart';
part 'src/map_layers.dart';
part 'src/map_pin_models.dart';
part 'src/explore_page.dart';
part 'src/report_flow.dart';
part 'src/report_photo_step.dart';
part 'src/report_location_picker.dart';
part 'src/report_review.dart';
part 'src/rewards_models.dart';
part 'src/rewards_page.dart';
part 'src/rewards_wallet.dart';
part 'src/rewards_coupons.dart';
part 'src/rewards_catalog_components.dart';
part 'src/map_search.dart';
part 'src/map_filters.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppAppearance.load();
  Object? bootstrapError;
  try {
    await SupabaseConfig.initializeIfConfigured();
  } catch (error) {
    bootstrapError = error;
  }
  runApp(ParkIstApp(bootstrapError: bootstrapError));
}

/// Account is required before accessing the map or contribution features.
class _AuthGate extends StatefulWidget {
  const _AuthGate({this.bootstrapError});

  final Object? bootstrapError;

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool _recoveringPassword = false;
  String? _profileUserId;
  Future<void>? _profileFuture;
  Object? _bootstrapError;
  bool _retryingBootstrap = false;
  int _authStreamRevision = 0;

  @override
  void initState() {
    super.initState();
    _bootstrapError = widget.bootstrapError;
  }

  @override
  void didUpdateWidget(covariant _AuthGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bootstrapError != widget.bootstrapError) {
      _bootstrapError = widget.bootstrapError;
    }
  }

  Future<void> _ensureProfile(String userId) {
    if (_profileUserId != userId || _profileFuture == null) {
      _profileUserId = userId;
      _profileFuture = AuthRepository(Supabase.instance.client).ensureProfile();
    }
    return _profileFuture!;
  }

  Future<void> _retryBootstrap() async {
    setState(() => _retryingBootstrap = true);
    try {
      await SupabaseConfig.initializeIfConfigured();
      if (mounted) setState(() => _bootstrapError = null);
    } catch (_) {
      if (mounted) {
        setState(() => _bootstrapError = StateError('Supabase başlatılamadı.'));
      }
    } finally {
      if (mounted) setState(() => _retryingBootstrap = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_bootstrapError != null) {
      return _AuthGateMessage(
        title: 'Hesap bağlantısı kurulamadı',
        message: 'Bağlantını kontrol edip yeniden deneyebilirsin.',
        busy: _retryingBootstrap,
        onRetry: _retryBootstrap,
      );
    }
    if (!SupabaseConfig.isConfigured) return const AuthPage();
    final client = Supabase.instance.client;
    return StreamBuilder<AuthState>(
      key: ValueKey(_authStreamRevision),
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.data?.event == AuthChangeEvent.passwordRecovery) {
          _recoveringPassword = true;
        }
        if (_recoveringPassword) {
          return PasswordRecoveryPage(
            onComplete: () => setState(() => _recoveringPassword = false),
          );
        }
        // A signed-out event intentionally has a null session; don't fall
        // back to a stale currentSession while StreamBuilder is rebuilding.
        final session = snapshot.hasData
            ? snapshot.data!.session
            : client.auth.currentSession;
        final destination = resolveAuthEntry(
          configured: true,
          bootstrapFailed: false,
          streamFailed: snapshot.hasError,
          checkingSession:
              snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData,
          hasSession: session != null,
        );
        if (destination == AuthEntryDestination.retry) {
          return _AuthGateMessage(
            title: 'Oturum bilgisi alınamadı',
            message: 'Bağlantını kontrol edip yeniden deneyebilirsin.',
            onRetry: () => setState(() => _authStreamRevision++),
          );
        }
        if (destination == AuthEntryDestination.checkingSession) {
          return const _AuthGateLoading();
        }
        if (destination == AuthEntryDestination.welcome) {
          _profileUserId = null;
          _profileFuture = null;
          return const AuthPage();
        }
        return FutureBuilder<void>(
          future: _ensureProfile(session!.user.id),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.hasError) {
              return _AuthGateMessage(
                title: 'Profil hazırlanamadı',
                message: 'Bağlantını kontrol edip yeniden deneyebilirsin.',
                onRetry: () => setState(() => _profileFuture = null),
              );
            }
            if (profileSnapshot.connectionState != ConnectionState.done) {
              return const _AuthGateLoading(message: 'Hesabın hazırlanıyor…');
            }
            return const HomeScreen();
          },
        );
      },
    );
  }
}

class _AuthGateLoading extends StatelessWidget {
  const _AuthGateLoading({this.message = 'Oturum kontrol ediliyor…'});
  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(height: 16),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    ),
  );
}

class _AuthGateMessage extends StatelessWidget {
  const _AuthGateMessage({
    required this.title,
    required this.message,
    required this.onRetry,
    this.busy = false,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;
  final bool busy;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 38,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: busy ? null : onRetry,
                child: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Tekrar dene'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
