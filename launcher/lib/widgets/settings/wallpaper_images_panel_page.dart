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

import 'dart:io';
import 'dart:typed_data';

import 'package:flauncher/part_of_day.dart';
import 'package:flauncher/flauncher_channel.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// Built-in wallpapers plus pictures found in the TV's Pictures and Download folders.
class WallpaperImagesPanelPage extends StatefulWidget {
  static const String routeName = "wallpaper_images_panel";

  @override
  State<WallpaperImagesPanelPage> createState() => _WallpaperImagesPanelPageState();
}

class _WallpaperImagesPanelPageState extends State<WallpaperImagesPanelPage> with WidgetsBindingObserver {
  static const List<(String, String)> _builtIn = [
    ("fjord_morning", "Fjord morning"), ("fjord_day", "Fjord day"), ("fjord_evening", "Fjord evening"),
    ("fjord_night", "Fjord night"), ("aurora", "Aurora"), ("mountains", "Mountains"), ("ocean", "Ocean"),
    ("nebula", "Nebula"), ("dunes", "Dunes"), ("bokeh", "Bokeh"), ("forest", "Forest"), ("volt", "Volt"),
    ("city_night", "City at night"), ("milky_way", "Milky Way"), ("low_poly", "Low poly"),
    ("pastel_waves", "Pastel waves"), ("rainy_window", "Rainy window"), ("planet", "Planet"),
    ("glacier", "Glacier"), ("circles", "Circles"), ("lavender", "Lavender"),
  ];
  static const List<String> _folders = ["/storage/emulated/0/Pictures", "/storage/emulated/0/Download"];
  static const Set<String> _extensions = {".jpg", ".jpeg", ".png", ".webp"};

  final FLauncherChannel _channel = FLauncherChannel();
  bool _hasPermission = true;
  List<File> _localImages = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLocalImages();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Coming back from the permission prompt
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadLocalImages();
    }
  }

  Future<void> _loadLocalImages() async {
    final hasPermission = await _channel.hasStoragePermission();
    final images = <File>[];

    if (hasPermission) {
      for (final folder in _folders) {
        try {
          await for (final entity in Directory(folder).list(recursive: true, followLinks: false)) {
            final name = entity.path.toLowerCase();
            if (entity is File && _extensions.any(name.endsWith)) {
              images.add(entity);
            }
          }
        } on FileSystemException {
          // Folder missing or unreadable: skip it
        }
      }
      images.sort((a, b) => a.path.compareTo(b.path));
    }

    if (mounted) {
      setState(() {
        _hasPermission = hasPermission;
        _localImages = images;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text("Images", style: Theme.of(context).textTheme.titleLarge),
      const Divider(),
      Expanded(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _grid([
                _ImageTile(
                  autofocus: true,
                  label: "Time of day (automatic)",
                  image: AssetImage(PartOfDay.of(DateTime.now()).wallpaperAsset),
                  onSelected: () => context.read<WallpaperService>().setTimeOfDay(),
                ),
                ..._builtIn.map((entry) {
                  final (name, label) = entry;
                  return _tile(
                    label: label,
                    image: ResizeImage(AssetImage("assets/wallpapers/$name.jpg"), width: 320),
                    load: () async => (await rootBundle.load("assets/wallpapers/$name.jpg")).buffer.asUint8List(),
                  );
                }),
              ]),
              const SizedBox(height: 4),
              Text("Time of day uses the fjord pictures: morning, day, evening and night, switching with the greeting.",
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              Text("Your pictures", style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              if (!_hasPermission)
                TextButton(
                  child: Row(
                    children: [
                      const Icon(Icons.folder_open),
                      Container(width: 8),
                      Text("Allow access to pictures", style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                  onPressed: () => _channel.requestStoragePermission(),
                )
              else if (_localImages.isEmpty)
                Text("Put pictures in the TV's Pictures or Download folder (USB stick, phone app or adb push) and they show up here.",
                    style: Theme.of(context).textTheme.bodySmall)
              else
                _grid(_localImages.map((file) => _tile(
                  label: file.uri.pathSegments.last,
                  image: ResizeImage(FileImage(file), width: 320),
                  load: file.readAsBytes,
                )).toList()),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _grid(List<Widget> tiles) => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 8,
    crossAxisSpacing: 8,
    childAspectRatio: 16 / 11,
    children: tiles,
  );

  Widget _tile({
    required String label,
    required ImageProvider image,
    required Future<Uint8List> Function() load,
    bool autofocus = false,
  }) => _ImageTile(
    autofocus: autofocus,
    label: label,
    image: image,
    onSelected: () async {
      final bytes = await load();
      if (mounted) {
        await context.read<WallpaperService>().setWallpaperBytes(bytes);
      }
    },
  );
}

class _ImageTile extends StatefulWidget {
  final bool autofocus;
  final String label;
  final ImageProvider image;
  final VoidCallback onSelected;

  const _ImageTile({required this.autofocus, required this.label, required this.image, required this.onSelected});

  @override
  State<_ImageTile> createState() => _ImageTileState();
}

class _ImageTileState extends State<_ImageTile> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) => InkWell(
    autofocus: widget.autofocus,
    onFocusChange: (focused) => setState(() => _focused = focused),
    onTap: widget.onSelected,
    borderRadius: BorderRadius.circular(10),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _focused ? Colors.white : Colors.transparent, width: 3),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: Image(image: widget.image, fit: BoxFit.cover)),
            Container(
              color: Colors.black54,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
        ),
      ),
    ),
  );
}
