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

import 'package:flauncher/flauncher_channel.dart';
import 'package:flutter/foundation.dart';

class InputDevicesService extends ChangeNotifier {
  late final StreamSubscription _subscription;

  bool _hasMouse = false;
  bool _hasKeyboard = false;

  bool get hasMouse => _hasMouse;

  bool get hasKeyboard => _hasKeyboard;

  InputDevicesService(FLauncherChannel channel) {
    _subscription = channel.inputDevices().listen((state) {
      if (state.mouse != _hasMouse || state.keyboard != _hasKeyboard) {
        _hasMouse = state.mouse;
        _hasKeyboard = state.keyboard;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
