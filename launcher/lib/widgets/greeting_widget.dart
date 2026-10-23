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

import 'package:flauncher/providers/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class GreetingWidget extends StatefulWidget {
  const GreetingWidget({super.key});

  @override
  State<GreetingWidget> createState() => _GreetingWidgetState();
}

class _GreetingWidgetState extends State<GreetingWidget> {
  static const List<Shadow> _shadows = [
    Shadow(color: Colors.black45, blurRadius: 12, offset: Offset(0, 2))
  ];

  late DateTime _now;
  late Timer    _timer;

  @override
  void initState() {
    super.initState();

    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _greeting(int hour) {
    if (hour >= 5 && hour < 12) {
      return "Good morning";
    }
    if (hour >= 12 && hour < 17) {
      return "Good afternoon";
    }
    if (hour >= 17 && hour < 22) {
      return "Good evening";
    }
    return "Good night";
  }

  @override
  Widget build(BuildContext context) => Selector<SettingsService, ({ String name, String timeFormat })>(
    selector: (_, service) => (name: service.greetingName.trim(), timeFormat: service.timeFormat),
    builder: (context, settings, _) {
      final greeting = settings.name.isEmpty
          ? _greeting(_now.hour)
          : "${_greeting(_now.hour)}, ${settings.name}";

      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat(settings.timeFormat).format(_now),
              style: const TextStyle(fontSize: 72, fontWeight: FontWeight.w200, height: 1, color: Colors.white, shadows: _shadows)
            ),
            const SizedBox(height: 8),
            Text(greeting,
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w500, color: Colors.white, shadows: _shadows)
            ),
            const SizedBox(height: 4),
            Text(DateFormat("EEEE d MMMM").format(_now),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w400, color: Colors.white70, shadows: _shadows)
            )
          ]
        )
      );
    }
  );
}
