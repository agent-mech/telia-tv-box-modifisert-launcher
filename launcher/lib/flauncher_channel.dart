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

import 'dart:async';

import 'package:flutter/services.dart';

class FLauncherChannel {
  static const _methodChannel = MethodChannel('me.efesser.flauncher/method');
  static const _appsEventChannel = EventChannel('me.efesser.flauncher/event_apps');
  static const _networkEventChannel = EventChannel('me.efesser.flauncher/event_network');
  static const _inputDevicesEventChannel = EventChannel('me.efesser.flauncher/event_input_devices');

  Future<List<Map<dynamic, dynamic>>> getApplications() async {
    List<Map<dynamic, dynamic>>? applications = await _methodChannel.invokeListMethod("getApplications");
    return applications!;
  }

  Future<Uint8List> getApplicationBanner(String packageName) async {
    Uint8List bytes = await _methodChannel.invokeMethod("getApplicationBanner", packageName);
    return bytes;
  }

  Future<Uint8List> getApplicationIcon(String packageName) async {
    Uint8List bytes = await _methodChannel.invokeMethod("getApplicationIcon", packageName);
    return bytes;
  }

  Future<bool> applicationExists(String packageName) async =>
      await _methodChannel.invokeMethod('applicationExists', packageName);

  Future<void> launchActivityFromAction(String action) async => await _methodChannel.invokeMethod('launchActivityFromAction', action);

  Future<void> launchApp(String packageName) async => await _methodChannel.invokeMethod('launchApp', packageName);

  Future<void> launchAppWindowed(String packageName) async => await _methodChannel.invokeMethod('launchAppWindowed', packageName);

  Future<void> openSettings() async => await _methodChannel.invokeMethod('openSettings');

  Future<void> openAppInfo(String packageName) async => await _methodChannel.invokeMethod('openAppInfo', packageName);

  Future<void> uninstallApp(String packageName) async => await _methodChannel.invokeMethod('uninstallApp', packageName);

  Future<bool> isDefaultLauncher() async => await _methodChannel.invokeMethod('isDefaultLauncher');

  Future<bool> isPasscodeSet() async => await _methodChannel.invokeMethod('isPasscodeSet');

  Future<void> setPasscode() async => await _methodChannel.invokeMethod('setPasscode');

  Future<void> removePasscode() async => await _methodChannel.invokeMethod('removePasscode');

  Future<void> lockNow() async => await _methodChannel.invokeMethod('lockNow');

  /// Stops background apps; the result is shown as a toast.
  Future<void> freeRam() async => await _methodChannel.invokeMethod('freeRam');

  /// Desktop mode never shows an on-screen keyboard; false if the permission for it is missing.
  Future<bool> setDesktopKeyboardPolicy(bool desktop) async =>
      await _methodChannel.invokeMethod('setDesktopKeyboardPolicy', desktop);

  Future<bool> isRemoteServiceRunning() async => await _methodChannel.invokeMethod('isRemoteServiceRunning');

  Future<void> openAccessibilitySettings() async => await _methodChannel.invokeMethod('openAccessibilitySettings');

  /// Waits for the next remote button press; null if the remote buttons service is off.
  Future<({int code, String name})?> captureRemoteKey() async {
    Map<dynamic, dynamic>? key = await _methodChannel.invokeMapMethod('captureRemoteKey');
    return key == null ? null : (code: key['code'] as int, name: key['name'] as String);
  }

  Future<void> cancelRemoteKeyCapture() async => await _methodChannel.invokeMethod('cancelRemoteKeyCapture');

  /// Emits whether a mouse and a real typing keyboard are connected, now and whenever that changes.
  Stream<({bool mouse, bool keyboard})> inputDevices() => _inputDevicesEventChannel
      .receiveBroadcastStream()
      .map((event) => (mouse: event['mouse'] as bool, keyboard: event['keyboard'] as bool));

  /// Called when the "Switch TV / desktop" or "Settings" action is triggered from a remote button or the quick menu.
  void setLauncherActionHandlers({required void Function() toggleLayout, required void Function(String? route) openSettings}) =>
      _methodChannel.setMethodCallHandler((call) async {
        switch (call.method) {
          case "toggleLayout":
            toggleLayout();
          case "openSettings":
            openSettings(call.arguments as String?);
        }
      });

  /// Current Android TV settings values (volume, screensaver, sleep, animations, text size...).
  Future<Map<String, dynamic>> getSystemSettings() async =>
      (await _methodChannel.invokeMapMethod<String, dynamic>('getSystemSettings'))!;

  /// False if the value couldn't be written (permission missing).
  Future<bool> setSystemSetting(String key, Object value) async =>
      await _methodChannel.invokeMethod('setSystemSetting', {"key": key, "value": value});

  Future<bool> openSystemSettingsPage(String page) async =>
      await _methodChannel.invokeMethod('openSystemSettingsPage', page);

  Future<bool> hasStoragePermission() async => await _methodChannel.invokeMethod('hasStoragePermission');

  Future<void> requestStoragePermission() async => await _methodChannel.invokeMethod('requestStoragePermission');

  Future<bool> checkForGetContentAvailability() async =>
      await _methodChannel.invokeMethod("checkForGetContentAvailability");

  Future<Map<String, dynamic>> getActiveNetworkInformation() async {
    Map<dynamic, dynamic> map = await _methodChannel.invokeMethod("getActiveNetworkInformation");
    return map.cast<String, dynamic>();
  }

  Future<void> startAmbientMode() async => await _methodChannel.invokeMethod("startAmbientMode");

  void addAppsChangedListener(void Function(Map<String, dynamic>) listener) =>
      _appsEventChannel.receiveBroadcastStream().listen((event) {
        Map<dynamic, dynamic> eventMap = event;
        listener(eventMap.cast<String, dynamic>());
      });

  void addNetworkChangedListener(void Function(Map<String, dynamic>) listener) =>
      _networkEventChannel.receiveBroadcastStream().listen((event) {
        Map<dynamic, dynamic> eventMap = event;
        listener(eventMap.cast<String, dynamic>());
      });
}
