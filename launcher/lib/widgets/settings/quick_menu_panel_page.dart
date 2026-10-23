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

import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/rounded_switch_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class QuickMenuPanelPage extends StatelessWidget {
  static const String routeName = "quick_menu_panel";

  // Ids must match QuickMenuActivity.actionItem on the Android side
  static const List<(String, String, IconData)> _actions = [
    ("action:home", "Home", Icons.home_outlined),
    ("action:settings", "Settings", Icons.settings_outlined),
    ("action:wifi", "Wi-Fi", Icons.wifi),
    ("action:bluetooth", "Bluetooth", Icons.bluetooth),
    ("action:display", "Display & sound", Icons.tv),
    ("action:apps", "Manage apps", Icons.apps),
    ("action:screensaver", "Screensaver", Icons.nightlight_outlined),
    ("action:lock", "Lock TV", Icons.lock_outline),
  ];

  @override
  Widget build(BuildContext context) {
    SettingsService settingsService = Provider.of(context);
    AppsService appsService = Provider.of(context);
    List<String> enabled = settingsService.quickMenuItems;

    return Column(
      children: [
        Text("Quick menu", style: Theme.of(context).textTheme.titleLarge),
        const Divider(),
        Text("Opens with the assistant button on the remote", style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                ..._actions.indexed.map((entry) {
                  final (index, (id, label, icon)) = entry;
                  return RoundedSwitchListTile(
                    autofocus: index == 0,
                    value: enabled.contains(id),
                    onChanged: (value) => settingsService.setQuickMenuItemEnabled(id, value),
                    title: Text(label, style: Theme.of(context).textTheme.bodyMedium),
                    secondary: Icon(icon),
                  );
                }),
                const Divider(),
                ...appsService.applications.map((app) {
                  final id = "app:${app.packageName}";
                  return RoundedSwitchListTile(
                    value: enabled.contains(id),
                    onChanged: (value) => settingsService.setQuickMenuItemEnabled(id, value),
                    title: Text(app.name, style: Theme.of(context).textTheme.bodyMedium),
                    secondary: const Icon(Icons.play_circle_outline),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
