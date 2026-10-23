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

class PasscodePanelPage extends StatefulWidget {
  static const String routeName = "passcode_panel";

  @override
  State<PasscodePanelPage> createState() => _PasscodePanelPageState();
}

class _PasscodePanelPageState extends State<PasscodePanelPage> with WidgetsBindingObserver {
  final FLauncherChannel _channel = FLauncherChannel();
  late Future<bool> _isSet;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isSet = _channel.isPasscodeSet();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // The passcode screen is a separate native activity, so refresh when we come back from it
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() => _isSet = _channel.isPasscodeSet());
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text("Passcode", style: Theme.of(context).textTheme.titleLarge),
      const Divider(),
      FutureBuilder<bool>(
        future: _isSet,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox.shrink();
          }

          final isSet = snapshot.data!;
          return Column(
            children: [
              Text(
                isSet
                    ? "On: the TV asks for the passcode when it starts or wakes up"
                    : "Off: anyone can use the TV",
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              TextButton(
                autofocus: true,
                child: Row(
                  children: [
                    const Icon(Icons.pin_outlined),
                    Container(width: 8),
                    Text(isSet ? "Change passcode" : "Set passcode", style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
                onPressed: () => _channel.setPasscode(),
              ),
              if (isSet)
                TextButton(
                  child: Row(
                    children: [
                      const Icon(Icons.lock_open_outlined),
                      Container(width: 8),
                      Text("Remove passcode", style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                  onPressed: () => _channel.removePasscode(),
                ),
            ],
          );
        },
      ),
    ],
  );
}
