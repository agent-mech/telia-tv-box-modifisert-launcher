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

import 'package:flauncher/widgets/settings/back_button_actions.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _appHighlightAnimationEnabledKey = "app_highlight_animation_enabled";
const _appKeyClickEnabledKey = "app_key_click_enabled";
const _autoHideAppBar = "auto_hide_app_bar";
const _gradientUuidKey = "gradient_uuid";
const _backButtonAction = "back_button_action";
const _dateFormat = "date_format";
const _showCategoryTitles = "show_category_titles";
const _showDateInStatusBar = "show_date_in_status_bar";
const _showTimeInStatusBar = "show_time_in_status_bar";
const _timeFormat = "time_format";
const _greetingName = "greeting_name";
const _showGreeting = "show_greeting";
// Also read natively by QuickMenuActivity, keep the format in sync
const _quickMenuItems = "quick_menu_items";
// Read natively by RemoteKeyService: "keyCode|keyName|action" entries joined by ";"
const _remoteMappings = "remote_mappings";

class SettingsService extends ChangeNotifier {
  static final defaultDateFormat = "EEEE d";
  static final defaultTimeFormat = "H:mm";
  static final defaultGreetingName = "";
  static final defaultQuickMenuItems = "action:home,action:settings,action:wifi,action:bluetooth";
  final SharedPreferences _sharedPreferences;


  bool get appHighlightAnimationEnabled => _sharedPreferences.getBool(_appHighlightAnimationEnabledKey) ?? true;

  bool get appKeyClickEnabled => _sharedPreferences.getBool(_appKeyClickEnabledKey) ?? true;

  bool get autoHideAppBarEnabled => _sharedPreferences.getBool(_autoHideAppBar) ?? false;

  bool get showCategoryTitles => _sharedPreferences.getBool(_showCategoryTitles) ?? true;

  bool get showDateInStatusBar => _sharedPreferences.getBool(_showDateInStatusBar) ?? false;

  bool get showTimeInStatusBar => _sharedPreferences.getBool(_showTimeInStatusBar) ?? false;

  String? get gradientUuid => _sharedPreferences.getString(_gradientUuidKey);

  String get backButtonAction => _sharedPreferences.getString(_backButtonAction) ?? BACK_BUTTON_ACTION_NOTHING;

  String get dateFormat => _sharedPreferences.getString(_dateFormat) ?? defaultDateFormat;

  String get timeFormat => _sharedPreferences.getString(_timeFormat) ?? defaultTimeFormat;

  String get greetingName => _sharedPreferences.getString(_greetingName) ?? defaultGreetingName;

  bool get showGreeting => _sharedPreferences.getBool(_showGreeting) ?? true;

  List<({int code, String name, String action})> get remoteMappings =>
      (_sharedPreferences.getString(_remoteMappings) ?? "")
          .split(";")
          .map((entry) => entry.split("|"))
          .where((parts) => parts.length == 3 && int.tryParse(parts[0]) != null)
          .map((parts) => (code: int.parse(parts[0]), name: parts[1], action: parts[2]))
          .toList();

  List<String> get quickMenuItems => (_sharedPreferences.getString(_quickMenuItems) ?? defaultQuickMenuItems)
      .split(",")
      .where((item) => item.isNotEmpty)
      .toList();

  SettingsService(
    this._sharedPreferences
  );

  Future<void> set(String key, bool value) async {
    await _sharedPreferences.setBool(key, value);
    notifyListeners();
  }

  Future<void> setAppHighlightAnimationEnabled(bool value) async {
    return set(_appHighlightAnimationEnabledKey, value);
  }

  Future<void> setAppKeyClickEnabled(bool value) async {
    return set(_appKeyClickEnabledKey, value);
  }

  Future<void> setAutoHideAppBarEnabled(bool value) async {
    return set(_autoHideAppBar, value);
  }

  Future<void> setGradientUuid(String value) async {
    await _sharedPreferences.setString(_gradientUuidKey, value);
    notifyListeners();
  }

  Future<void> setBackButtonAction(String value) async {
    await _sharedPreferences.setString(_backButtonAction, value);
    notifyListeners();
  }

  Future<void> setDateTimeFormat(String dateFormatString, String timeFormatString) async {
    await Future.wait([
      _sharedPreferences.setString(_dateFormat, dateFormatString),
      _sharedPreferences.setString(_timeFormat, timeFormatString)
    ]);
    notifyListeners();
  }

  Future<void> setShowCategoryTitles(bool show) async {
    return set(_showCategoryTitles, show);
  }

  Future<void> setShowDateInStatusBar(bool show) async {
    return set(_showDateInStatusBar, show);
  }

  Future<void> setShowTimeInStatusBar(bool show) async {
    return set(_showTimeInStatusBar, show);
  }

  Future<void> setGreetingName(String value) async {
    await _sharedPreferences.setString(_greetingName, value);
    notifyListeners();
  }

  Future<void> setShowGreeting(bool show) async {
    return set(_showGreeting, show);
  }

  Future<void> setRemoteMapping(int code, String name, String? action) async {
    final mappings = remoteMappings.where((mapping) => mapping.code != code).toList();
    if (action != null) {
      mappings.add((code: code, name: name, action: action));
    }
    await _sharedPreferences.setString(_remoteMappings,
        mappings.map((mapping) => "${mapping.code}|${mapping.name}|${mapping.action}").join(";"));
    notifyListeners();
  }

  Future<void> setQuickMenuItemEnabled(String item, bool enabled) async {
    List<String> items = quickMenuItems..remove(item);
    if (enabled) {
      items.add(item);
    }
    await _sharedPreferences.setString(_quickMenuItems, items.join(","));
    notifyListeners();
  }
}
