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

import 'package:flauncher/flauncher.dart';
import 'package:flauncher/flauncher_channel.dart';
import 'package:flauncher/providers/input_devices_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/desktop/desktop_launcher.dart';
import 'package:flauncher/widgets/settings/settings_panel.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Picks the TV layout or the desktop layout (mouse and keyboard connected, or forced in settings).
class LauncherHome extends StatefulWidget {
  const LauncherHome({super.key});

  @override
  State<LauncherHome> createState() => _LauncherHomeState();
}

class _LauncherHomeState extends State<LauncherHome> {
  bool? _keyboardPolicyDesktop;

  // Set by the "Switch TV / desktop" button until a keyboard or mouse is plugged in or out
  bool? _layoutOverride;
  (bool, bool)? _inputDevicesSeen;

  @override
  void initState() {
    super.initState();

    FLauncherChannel().setLauncherActionHandlers(
      // "Switch TV / desktop" flips to the other layout, without changing the desktop mode setting
      toggleLayout: () => setState(() =>
          _layoutOverride = !_isDesktop(context.read<SettingsService>(), context.read<InputDevicesService>())),
      openSettings: _openSettings,
    );
  }

  bool _settingsOpen = false;

  /// Opens the settings panel, on a given page when [route] is set (Spotlight results).
  Future<void> _openSettings(String? route) async {
    if (!mounted) {
      return;
    }
    if (_settingsOpen) {
      if (route == null) {
        return;
      }
      // Replace the open panel with the requested page
      Navigator.of(context).pop();
    }

    _settingsOpen = true;
    await showDialog(context: context, builder: (_) => SettingsPanel(initialRoute: route));
    _settingsOpen = false;
  }

  bool _isDesktop(SettingsService settings, InputDevicesService inputDevices) => _layoutOverride ?? switch (settings.desktopMode) {
    DESKTOP_MODE_ALWAYS => true,
    DESKTOP_MODE_NEVER => false,
    _ => inputDevices.hasMouse || inputDevices.hasKeyboard,
  };

  @override
  Widget build(BuildContext context) => Consumer2<SettingsService, InputDevicesService>(
    builder: (context, settings, inputDevices, __) {
      // Plugging a keyboard or mouse in or out goes back to the automatic layout
      final inputDevicesNow = (inputDevices.hasMouse, inputDevices.hasKeyboard);
      if (_inputDevicesSeen != null && _inputDevicesSeen != inputDevicesNow) {
        _layoutOverride = null;
      }
      _inputDevicesSeen = inputDevicesNow;

      final desktop = _isDesktop(settings, inputDevices);

      // Policy: no on-screen keyboard while in desktop mode
      if (_keyboardPolicyDesktop != desktop) {
        _keyboardPolicyDesktop = desktop;
        FLauncherChannel().setDesktopKeyboardPolicy(desktop);
      }

      return desktop ? const DesktopLauncher() : const FLauncher();
    },
  );
}
