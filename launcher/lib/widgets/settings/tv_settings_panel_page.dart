/*
 * FLauncher
 * Copyright (C) 2021  Étienne Fesser
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'package:flauncher/flauncher_channel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../rounded_switch_list_tile.dart';

/// Android TV's own settings, inside the launcher settings: common values are changed right
/// here, the rest open the matching Android page.
class TvSettingsPanelPage extends StatefulWidget {
  static const String routeName = "tv_settings_panel";

  @override
  State<TvSettingsPanelPage> createState() => _TvSettingsPanelPageState();
}

class _TvSettingsPanelPageState extends State<TvSettingsPanelPage> with WidgetsBindingObserver {
  static const _never = -1;
  static const List<(int, String)> _screensaverTimeouts = [
    (60000, "1 minute"), (300000, "5 minutes"), (900000, "15 minutes"), (1800000, "30 minutes"),
    (3600000, "1 hour"), (7200000, "2 hours"),
  ];
  static const List<(int, String)> _sleepTimeouts = [
    (1800000, "30 minutes"), (3600000, "1 hour"), (14400000, "4 hours"), (28800000, "8 hours"),
    (43200000, "12 hours"), (86400000, "24 hours"), (_never, "Never"),
  ];
  static const List<(double, String)> _animationScales = [(0.0, "Off"), (0.5, "Fast"), (1.0, "Normal")];
  static const List<(double, String)> _fontScales = [(0.85, "Small"), (1.0, "Default"), (1.15, "Large"), (1.3, "Largest")];

  static const List<(String, IconData, String)> _pages = [
    ("network", Icons.wifi, "Network & Internet"),
    ("accessories", Icons.settings_remote_outlined, "Remotes & accessories"),
    ("display_sound", Icons.tv, "Display & sound"),
    ("apps", Icons.apps_outlined, "Manage apps"),
    ("unknown_sources", Icons.install_mobile_outlined, "Install unknown apps"),
    ("storage", Icons.sd_storage_outlined, "Storage"),
    ("date_time", Icons.schedule, "Date & time"),
    ("language", Icons.language, "Language"),
    ("keyboard", Icons.keyboard_outlined, "Keyboard"),
    ("accessibility", Icons.accessibility_new, "Accessibility"),
    ("accounts", Icons.account_circle_outlined, "Accounts & sign-in"),
    ("device_name", Icons.drive_file_rename_outline, "Device name"),
    ("developer", Icons.developer_mode, "Developer options"),
    ("about", Icons.info_outline, "About, updates & reset"),
  ];

  final FLauncherChannel _channel = FLauncherChannel();
  Map<String, dynamic>? _values;
  double? _volume;
  bool _adjustingVolume = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Coming back from an Android settings page
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load();
    }
  }

  Future<void> _load() async {
    final values = await _channel.getSystemSettings();
    if (mounted) {
      setState(() {
        _values = values;
        _volume = (values["volume"] as int).toDouble();
      });
    }
  }

  Future<void> _set(String key, Object value) async {
    final written = await _channel.setSystemSetting(key, value);
    if (!written && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Not allowed: run the launcher install script again to grant settings access")));
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final values = _values;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Text("TV settings", style: textTheme.titleLarge),
        const Divider(),
        Expanded(
          child: values == null
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!(values["volumeFixed"] as bool)) _volumeSlider(values, textTheme),
                      RoundedSwitchListTile(
                        autofocus: values["volumeFixed"] as bool,
                        value: values["screensaverEnabled"] as bool,
                        onChanged: (value) => _set("screensaverEnabled", value),
                        title: Text("Screensaver", style: textTheme.bodyMedium),
                        secondary: const Icon(Icons.nights_stay_outlined),
                      ),
                      _choice<int>(
                        icon: Icons.timer_outlined,
                        label: "Start screensaver after",
                        options: _screensaverTimeouts,
                        current: values["screensaverTimeout"] as int,
                        onSelected: (value) => _set("screensaverTimeout", value),
                      ),
                      _choice<int>(
                        icon: Icons.power_settings_new,
                        label: "Turn off after",
                        options: _sleepTimeouts,
                        current: (values["sleepTimeout"] as int) <= 0 ? _never : values["sleepTimeout"] as int,
                        onSelected: (value) => _set("sleepTimeout", value),
                      ),
                      _choice<double>(
                        icon: Icons.animation,
                        label: "Animations",
                        options: _animationScales,
                        current: values["animationScale"] as double,
                        onSelected: (value) => _set("animationScale", value),
                      ),
                      _choice<double>(
                        icon: Icons.format_size,
                        label: "Text size",
                        options: _fontScales,
                        current: values["fontScale"] as double,
                        onSelected: (value) => _set("fontScale", value),
                      ),
                      RoundedSwitchListTile(
                        value: values["autoTime"] as bool,
                        onChanged: (value) => _set("autoTime", value),
                        title: Text("Automatic date & time", style: textTheme.bodyMedium),
                        secondary: const Icon(Icons.update),
                      ),
                      const Divider(),
                      for (final (page, icon, label) in _pages)
                        TextButton(
                          child: Row(
                            children: [
                              Icon(icon),
                              Container(width: 8),
                              Expanded(child: Text(label, style: textTheme.bodyMedium)),
                              if (page == "device_name" && values["deviceName"] != null)
                                Text(values["deviceName"] as String, style: textTheme.bodySmall),
                              const Icon(Icons.chevron_right, size: 18),
                            ],
                          ),
                          onPressed: () => _channel.openSystemSettingsPage(page),
                        ),
                      const Divider(),
                      TextButton(
                        child: Row(
                          children: [
                            const Icon(Icons.settings_applications_outlined),
                            Container(width: 8),
                            Text("All Android settings", style: textTheme.bodyMedium),
                          ],
                        ),
                        onPressed: () => _channel.openSystemSettingsPage("all"),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  // Left/right only change the volume after OK is pressed on it, so the remote can still move past it.
  // Android's own volume overlay shows the level, so there is only one volume bar on screen.
  Widget _volumeSlider(Map<String, dynamic> values, TextTheme textTheme) {
    final maxVolume = values["maxVolume"] as int;

    void step(int delta) {
      final volume = (_volume!.round() + delta).clamp(0, maxVolume);
      setState(() => _volume = volume.toDouble());
      _channel.setSystemSetting("volume", volume);
    }

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        if (!_adjustingVolume || event is KeyUpEvent) {
          return KeyEventResult.ignored;
        }

        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.arrowLeft) {
          step(-1);
        } else if (key == LogicalKeyboardKey.arrowRight) {
          step(1);
        } else if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.arrowDown) {
          setState(() => _adjustingVolume = false);
          return KeyEventResult.ignored;
        } else if (key == LogicalKeyboardKey.select || key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.gameButtonA || key == LogicalKeyboardKey.escape ||
            key == LogicalKeyboardKey.goBack) {
          setState(() => _adjustingVolume = false);
        }
        return KeyEventResult.handled;
      },
      child: TextButton(
        autofocus: true,
        onFocusChange: (focused) {
          if (!focused) {
            setState(() => _adjustingVolume = false);
          }
        },
        onPressed: () => setState(() => _adjustingVolume = true),
        style: _adjustingVolume
            ? TextButton.styleFrom(backgroundColor: Colors.white24)
            : null,
        child: Row(
          children: [
            const Icon(Icons.volume_up_outlined),
            Container(width: 8),
            Text("Volume", style: textTheme.bodyMedium),
            const Spacer(),
            Text("${_volume!.round()}", style: textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _choice<T>({
    required IconData icon,
    required String label,
    required List<(T, String)> options,
    required T current,
    required void Function(T) onSelected,
  }) {
    final currentLabel = options.where((option) => option.$1 == current).map((option) => option.$2).firstOrNull ?? "Custom";

    return TextButton(
      child: Row(
        children: [
          Icon(icon),
          Container(width: 8),
          Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          Text(currentLabel, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      onPressed: () async {
        final value = await showDialog<T>(
          context: context,
          builder: (context) => SimpleDialog(
            title: Text(label),
            children: [
              for (final (value, optionLabel) in options)
                SimpleDialogOption(
                  child: Text(value == current ? "$optionLabel  ✓" : optionLabel),
                  onPressed: () => Navigator.pop(context, value),
                ),
            ],
          ),
        );
        if (value != null) {
          onSelected(value);
        }
      },
    );
  }
}
