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
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class RemoteButtonsPanelPage extends StatefulWidget {
  static const String routeName = "remote_buttons_panel";

  @override
  State<RemoteButtonsPanelPage> createState() => _RemoteButtonsPanelPageState();
}

class _RemoteButtonsPanelPageState extends State<RemoteButtonsPanelPage> with WidgetsBindingObserver {
  // Ids must match RemoteKeyService.perform / QuickMenuActivity.actionIntent on the Android side
  static const List<(String, String)> _actions = [
    ("action:quickmenu", "Quick menu"),
    ("action:toggle_layout", "Switch TV / desktop layout"),
    ("action:home", "Home"),
    ("action:back", "Back"),
    ("action:lock", "Lock TV"),
    ("action:free_ram", "Free up RAM"),
    ("action:settings", "Settings"),
    ("action:wifi", "Wi-Fi"),
    ("action:bluetooth", "Remotes & accessories"),
    ("action:display", "Display & sound"),
    ("action:screensaver", "Screensaver"),
    ("action:none", "Do nothing (disable button)"),
  ];

  final FLauncherChannel _channel = FLauncherChannel();
  late Future<bool> _serviceRunning;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _serviceRunning = _channel.isRemoteServiceRunning();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // The service is turned on in Android's accessibility settings, so re-check when we come back
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() => _serviceRunning = _channel.isRemoteServiceRunning());
    }
  }

  @override
  Widget build(BuildContext context) {
    SettingsService settingsService = Provider.of(context);
    AppsService appsService = Provider.of(context);

    return Column(
      children: [
        Text("Remote buttons", style: Theme.of(context).textTheme.titleLarge),
        const Divider(),
        Expanded(
          child: FutureBuilder<bool>(
            future: _serviceRunning,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox.shrink();
              }
              if (!snapshot.data!) {
                return _serviceOff(context);
              }

              return SingleChildScrollView(
                child: Column(
                  children: [
                    TextButton(
                      autofocus: true,
                      child: Row(
                        children: [
                          const Icon(Icons.add),
                          Container(width: 8),
                          Text("Add button", style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                      onPressed: () => _addButton(context, settingsService, appsService),
                    ),
                    const Divider(),
                    if (settingsService.remoteMappings.isEmpty)
                      Text("No buttons remapped yet", style: Theme.of(context).textTheme.bodySmall),
                    ...settingsService.remoteMappings.map((mapping) => TextButton(
                      child: Row(
                        children: [
                          const Icon(Icons.settings_remote_outlined),
                          Container(width: 8),
                          Expanded(
                            child: Text(_keyLabel(mapping.name), style: Theme.of(context).textTheme.bodyMedium),
                          ),
                          Text(_actionLabel(mapping.action, appsService), style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      onPressed: () => _editButton(context, settingsService, appsService, mapping.code, mapping.name),
                    )),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _serviceOff(BuildContext context) => Column(
    children: [
      Text(
        "Remapping needs the \"Volt Launcher remote buttons\" service. "
        "Turn it on in Accessibility settings, then come back here.",
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 8),
      TextButton(
        autofocus: true,
        child: Row(
          children: [
            const Icon(Icons.accessibility_new),
            Container(width: 8),
            Text("Open Accessibility settings", style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
        onPressed: () => _channel.openAccessibilitySettings(),
      ),
    ],
  );

  Future<void> _addButton(BuildContext context, SettingsService settingsService, AppsService appsService) async {
    bool cancelled = false;
    final captured = _channel.captureRemoteKey();

    // Back isn't remappable, so it always reaches this dialog and cancels the capture
    showDialog(
      context: context,
      builder: (dialogContext) {
        captured.then((_) {
          if (!cancelled && Navigator.of(dialogContext).canPop()) {
            Navigator.of(dialogContext).pop();
          }
        });
        return const AlertDialog(
          title: Text("Press a button on the remote"),
          content: Text("Arrows, OK, Back and Power can't be remapped. Press Back to cancel."),
        );
      },
    ).then((_) {
      cancelled = true;
      _channel.cancelRemoteKeyCapture();
    });

    final key = await captured;
    if (key == null || !context.mounted) {
      return;
    }

    final action = await _pickAction(context, _keyLabel(key.name), appsService);
    if (action != null) {
      await settingsService.setRemoteMapping(key.code, key.name, action);
    }
  }

  Future<void> _editButton(BuildContext context, SettingsService settingsService, AppsService appsService,
      int code, String name) async {
    final action = await _pickAction(context, _keyLabel(name), appsService, allowRemove: true);
    if (action == "") {
      await settingsService.setRemoteMapping(code, name, null);
    } else if (action != null) {
      await settingsService.setRemoteMapping(code, name, action);
    }
  }

  /// Returns the chosen action id, "" for "Remove mapping", or null if dismissed.
  Future<String?> _pickAction(BuildContext context, String keyLabel, AppsService appsService,
      {bool allowRemove = false}) {
    final options = <(String, String)>[
      if (allowRemove) ("", "Remove mapping (back to normal)"),
      ..._actions,
      ...appsService.applications.map((app) => ("app:${app.packageName}", "Open ${app.name}")),
    ];

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("$keyLabel button does…"),
        content: SizedBox(
          width: 420,
          height: 420,
          // The first option takes focus so the remote can navigate the list straight away
          child: ListView(
            children: options.indexed.map((entry) {
              final (index, (id, label)) = entry;
              return TextButton(
                autofocus: index == 0,
                style: TextButton.styleFrom(alignment: Alignment.centerLeft),
                child: Text(label),
                onPressed: () => Navigator.pop(context, id),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // The Telia remote's MITT INNHOLD button sends DVR
  String _keyLabel(String keyName) => keyName == "KEYCODE_DVR" ? "Mitt innhold" : keyName
      .replaceFirst("KEYCODE_", "")
      .split("_")
      .map((word) => word.isEmpty ? word : word[0] + word.substring(1).toLowerCase())
      .join(" ");

  String _actionLabel(String action, AppsService appsService) {
    for (final (id, label) in _actions) {
      if (id == action) {
        return label;
      }
    }
    if (action.startsWith("app:")) {
      final packageName = action.substring(4);
      for (final app in appsService.applications) {
        if (app.packageName == packageName) {
          return app.name;
        }
      }
      return packageName;
    }
    return action;
  }
}
