part of '../profile_settings_page.dart';

class _NotificationSettings extends StatelessWidget {
  const _NotificationSettings({required this.preview});
  final _ProfilePreview preview;

  String _time(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  Future<void> _chooseTime(BuildContext context, bool start) async {
    final time = await showTimePicker(
      context: context,
      initialEntryMode: TimePickerEntryMode.input,
      helpText: 'Sessiz saat seç',
      cancelText: 'Vazgeç',
      confirmText: 'Seç',
      hourLabelText: 'Saat',
      minuteLabelText: 'Dakika',
      errorInvalidText: 'Geçerli bir saat yaz.',
      initialTime: start ? preview.quietStart : preview.quietEnd,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (time != null) {
      preview.change(() {
        if (start) {
          preview.quietStart = time;
        } else {
          preview.quietEnd = time;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Bildirim tercihleri')),
    body: AnimatedBuilder(
      animation: preview,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _PreviewNotice(preview: preview),
          const SizedBox(height: 12),
          const Text(
            'Bu tercihler cihazında saklanır. İlçe ve çevre bildirimleri henüz gönderilmez; konumun bu ekrandan alınmaz.',
          ),
          SwitchListTile(
            key: const ValueKey('notifications-enabled'),
            title: const Text('Bildirimler'),
            value: preview.notifications,
            onChanged: (value) =>
                preview.change(() => preview.notifications = value),
          ),
          SwitchListTile(
            key: const ValueKey('district-alerts'),
            title: const Text('İlçe bildirimi'),
            value: preview.districtAlerts,
            onChanged: !preview.notifications
                ? null
                : (value) =>
                      preview.change(() => preview.districtAlerts = value),
          ),
          DropdownButtonFormField<String>(
            initialValue: preview.district,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Bildirim ilçesi',
              border: OutlineInputBorder(),
            ),
            hint: const Text('İlçe seç'),
            items: [
              for (final district in istanbulDistricts)
                DropdownMenuItem(
                  value: district.name,
                  child: Text(district.name),
                ),
            ],
            onChanged: !preview.notifications || !preview.districtAlerts
                ? null
                : (value) => preview.change(() => preview.district = value),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            key: const ValueKey('nearby-alerts'),
            title: const Text('Yakın çevre bildirimi'),
            subtitle: const Text(
              '300 m çevre tercihi · bildirim gönderimi henüz etkin değil',
            ),
            value: preview.nearbyAlerts,
            onChanged: !preview.notifications
                ? null
                : (value) => preview.change(() => preview.nearbyAlerts = value),
          ),
          SwitchListTile(
            key: const ValueKey('quiet-hours'),
            title: const Text('Sessiz saatler'),
            value: preview.quietHours,
            onChanged: !preview.notifications
                ? null
                : (value) => preview.change(() => preview.quietHours = value),
          ),
          if (preview.quietHours) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: !preview.notifications
                      ? null
                      : () => _chooseTime(context, true),
                  child: Text('Başlangıç: ${_time(preview.quietStart)}'),
                ),
                OutlinedButton(
                  onPressed: !preview.notifications
                      ? null
                      : () => _chooseTime(context, false),
                  child: Text('Bitiş: ${_time(preview.quietEnd)}'),
                ),
              ],
            ),
            if (preview.quietStart == preview.quietEnd)
              const Text('Başlangıç ve bitiş farklı olmalı.')
            else
              const Text('Sessiz saat aralığı gece yarısını geçebilir.'),
          ],
        ],
      ),
    ),
  );
}
