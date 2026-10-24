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

import 'package:flauncher/widgets/settings/gradient_panel_page.dart';
import 'package:flauncher/widgets/settings/wallpaper_images_panel_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class WallpaperPanelPage extends StatelessWidget {
  static const String routeName = "wallpaper_panel";

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return Column(
        children: [
          Text(localizations.wallpaper, style: Theme.of(context).textTheme.titleLarge),
          Divider(),
          TextButton(
            autofocus: true,
            child: Row(
              children: [
                Icon(Icons.gradient),
                Container(width: 8),
                Text(localizations.gradient, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
            onPressed: () => Navigator.of(context).pushNamed(GradientPanelPage.routeName),
          ),
          TextButton(
            child: Row(
              children: [
                Icon(Icons.image_outlined),
                Container(width: 8),
                Text("Images", style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
            onPressed: () => Navigator.of(context).pushNamed(WallpaperImagesPanelPage.routeName),
          ),
        ],
      );
  }
}
