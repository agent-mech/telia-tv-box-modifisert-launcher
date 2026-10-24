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

import 'package:flauncher/part_of_day.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class GreetingWidget extends StatefulWidget {
  /// The desktop shows the time on the shelf instead
  final bool showTime;

  const GreetingWidget({super.key, this.showTime = true});

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

  @override
  Widget build(BuildContext context) => Selector<SettingsService, ({ String name, String timeFormat })>(
    selector: (_, service) => (name: service.greetingName.trim(), timeFormat: service.timeFormat),
    builder: (context, settings, _) {
      final greeting = settings.name.isEmpty
          ? PartOfDay.of(_now).greeting
          : "${PartOfDay.of(_now).greeting}, ${settings.name}";

      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showTime) ...[
              Text(DateFormat(settings.timeFormat).format(_now),
                style: const TextStyle(fontSize: 72, fontWeight: FontWeight.w200, height: 1, color: Colors.white, shadows: _shadows)
              ),
              const SizedBox(height: 8),
            ],
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
