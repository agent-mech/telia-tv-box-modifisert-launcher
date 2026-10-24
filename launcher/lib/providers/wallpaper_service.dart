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
import 'dart:io';

import 'package:flauncher/part_of_day.dart';
import 'package:flauncher/flauncher_channel.dart';
import 'package:flauncher/gradients.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class WallpaperService extends ChangeNotifier {
  final FLauncherChannel _fLauncherChannel;
  final SettingsService _settingsService;

  late File _wallpaperFile;

  ImageProvider? _wallpaper;

  Timer? _periodTimer;
  PartOfDay _period = PartOfDay.of(DateTime.now());

  bool get timeOfDay => _settingsService.timeOfDayWallpaper;

  ImageProvider?  get wallpaper     => timeOfDay ? AssetImage(_period.wallpaperAsset) : _wallpaper;

  FLauncherGradient get gradient => FLauncherGradients.all.firstWhere(
        (gradient) => gradient.uuid == _settingsService.gradientUuid,
        orElse: () => FLauncherGradients.voltNight,
      );

  WallpaperService(this._fLauncherChannel, this._settingsService) :
    _wallpaper = null
  {
    _init();
  }

  Future<void> _init() async {
    // Switch the time-of-day wallpaper when the part of the day changes
    _periodTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final period = PartOfDay.of(DateTime.now());
      if (period != _period) {
        _period = period;
        if (timeOfDay) {
          notifyListeners();
        }
      }
    });

    final directory = await getApplicationDocumentsDirectory();
    _wallpaperFile = File("${directory.path}/wallpaper");
    if (await _wallpaperFile.exists()) {
      _wallpaper = FileImage(_wallpaperFile);
      notifyListeners();
    }
  }

  Future<void> pickWallpaper() async {
    if (!await _fLauncherChannel.checkForGetContentAvailability()) {
      throw NoFileExplorerException();
    }

    final imagePicker = ImagePicker();
    final pickedFile = await imagePicker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      Uint8List bytes = await pickedFile.readAsBytes();
      await _wallpaperFile.writeAsBytes(bytes);

      _wallpaper = MemoryImage(bytes);
      notifyListeners();
    }
  }

  /// Wallpaper follows the time of day (morning, afternoon, evening, night).
  @override
  void dispose() {
    _periodTimer?.cancel();
    super.dispose();
  }

  Future<void> setTimeOfDay() async {
    _period = PartOfDay.of(DateTime.now());
    await _settingsService.setTimeOfDayWallpaper(true);
    notifyListeners();
  }

  /// Sets a picture from the built-in wallpapers or the TV's own folders.
  Future<void> setWallpaperBytes(Uint8List bytes) async {
    await _settingsService.setTimeOfDayWallpaper(false);
    await _wallpaperFile.writeAsBytes(bytes);
    _wallpaper = MemoryImage(bytes);
    notifyListeners();
  }

  Future<void> setGradient(FLauncherGradient fLauncherGradient) async {
    await _settingsService.setTimeOfDayWallpaper(false);
    if (await _wallpaperFile.exists()) {
      await _wallpaperFile.delete();
    }

    _settingsService.setGradientUuid(fLauncherGradient.uuid);
    notifyListeners();
  }
}

class NoFileExplorerException implements Exception {}
