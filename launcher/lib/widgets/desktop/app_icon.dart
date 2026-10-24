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
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Square app icon for the desktop layout. Icons are cached, since the taskbar,
/// desktop and start menu all show the same apps.
class AppIcon extends StatelessWidget {
  static final Map<String, Future<ImageProvider>> _cache = {};

  final String packageName;
  final double size;

  const AppIcon({super.key, required this.packageName, required this.size});

  @override
  Widget build(BuildContext context) {
    final appsService = context.read<AppsService>();
    final future = _cache.putIfAbsent(packageName,
        () => appsService.getAppIcon(packageName).then<ImageProvider>((bytes) => MemoryImage(bytes)));

    return SizedBox(
      width: size,
      height: size,
      child: FutureBuilder<ImageProvider>(
        future: future,
        builder: (context, snapshot) => snapshot.hasData
            ? Image(image: snapshot.data!, width: size, height: size, filterQuality: FilterQuality.medium)
            : const SizedBox.shrink(),
      ),
    );
  }
}
