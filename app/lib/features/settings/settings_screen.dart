import 'package:flutter/material.dart';

import '../../core/telemetry/telemetry_controller.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../theme/dimens.dart';

/// "Ajustes" — the minimal settings surface the telemetry legal doc assumes
/// (`docs/legal/consent-copy-first-run.md` §3).
///
/// It exists ONLY while telemetry is active (the Home shows its entry point
/// only then): with the endpoint empty nothing is collected, so there is
/// nothing to switch off and the app keeps its zero-settings simplicity
/// (D7). One section, one switch — it grows only when a real second setting
/// earns its place.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.telemetry});

  final TelemetryController telemetry;

  /// Test key of the opt-out switch.
  static const Key telemetrySwitchKey = Key('settings_telemetry_switch');

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// Switch position; null while the stored value loads (first frame).
  bool? _enabled;

  @override
  void initState() {
    super.initState();
    widget.telemetry.isEnabled().then((bool value) {
      if (mounted) setState(() => _enabled = value);
    });
  }

  Future<void> _toggle(bool value) async {
    setState(() => _enabled = value); // optimistic: the write is local-only
    // OFF purges the queue and blocks any future send (legal doc §3:
    // "dejamos de enviar nada" — literally).
    await widget.telemetry.setEnabled(value);
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final AppLocalizations l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.screenMargin,
          vertical: Space.lg,
        ),
        children: <Widget>[
          // — Anonymous usage stats (the D33 opt-out) —
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      l10n.settingsTelemetryTitle,
                      style: AppType.heading.copyWith(color: c.textPrimary),
                    ),
                    const SizedBox(height: Space.xs),
                    Text(
                      l10n.settingsTelemetryBody,
                      style: AppType.caption.copyWith(color: c.textTertiary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Space.md),
              Switch(
                key: SettingsScreen.telemetrySwitchKey,
                value: _enabled ?? true,
                onChanged: _enabled == null ? null : _toggle,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
