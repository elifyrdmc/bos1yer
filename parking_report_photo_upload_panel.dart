import 'dart:io';

import 'backend/photo_privacy_service.dart';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'backend/parking_report_repository.dart';

class ParkingReportPhotoUploadPanel extends StatefulWidget {
  const ParkingReportPhotoUploadPanel({
    super.key,
    required this.reportId,
    required this.reportPoint,
    required this.onUploaded,
  });

  final String reportId;
  final LatLng reportPoint;
  final ValueChanged<ParkingReportRecord> onUploaded;

  @override
  State<ParkingReportPhotoUploadPanel> createState() =>
      _ParkingReportPhotoUploadPanelState();
}

class _ParkingReportPhotoUploadPanelState
    extends State<ParkingReportPhotoUploadPanel> {
  bool _isUploading = false;
  String? _error;

  Future<LatLng> _currentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Konum servisi kapalı.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError('Fotoğraf eklemek için konum izni gerekli.');
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    ).timeout(const Duration(seconds: 15));
    if (position.accuracy > 30) {
      throw StateError('Konum doğruluğu 30 metre içinde değil.');
    }
    return LatLng(position.latitude, position.longitude);
  }

  Future<void> _captureAndUpload() async {
    if (_isUploading) return;
    setState(() {
      _isUploading = true;
      _error = null;
    });
    try {
      final before = await _currentLocation();
      final photo = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 88,
      );
      if (photo == null) return;
      final after = await _currentLocation();
      const distance = Distance();
      final movedDuringCapture = distance.as(LengthUnit.Meter, before, after);
      final distanceFromReport = distance.as(
        LengthUnit.Meter,
        widget.reportPoint,
        after,
      );
      if (movedDuringCapture > 30 || distanceFromReport > 30) {
        throw StateError(
          'Fotoğrafı bildirimdeki yerin 30 metresi içinden çek.',
        );
      }
      final privacyResult = await PhotoPrivacyService.sanitize(
        File(photo.path),
      );
      final record = await ParkingReportRepository(Supabase.instance.client)
          .addLeavingPhoto(
            reportId: widget.reportId,
            photo: privacyResult.file,
            location: after,
          );
      if (!mounted) return;
      if (privacyResult.needsPreviewWarning) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Fotoğraf yüklendi. Yüz/plaka bulanıklaştırılmamış olabilir; detayda fotoğrafı kontrol et.',
            ),
          ),
        );
      }
      widget.onUploaded(record);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is StateError
            ? error.message
            : 'Fotoğraf yüklenemedi. Bildirim süresi dolmamışsa tekrar dene.';
      });
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Araç fotoğrafı bekleniyor',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text('Bildirim oluşturulduktan sonra 10 dakika içinde ekle.'),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isUploading ? null : _captureAndUpload,
              icon: _isUploading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.camera_alt_outlined),
              label: Text(
                _isUploading ? 'Yükleniyor…' : 'Fotoğraf çek ve ekle',
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: colors.error)),
          ],
        ],
      ),
    );
  }
}
