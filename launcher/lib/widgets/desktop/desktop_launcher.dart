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

import 'dart:ui';

import 'package:flauncher/flauncher_channel.dart';
import 'package:flauncher/models/app.dart';
import 'package:flauncher/models/category.dart';
import 'package:flauncher/providers/apps_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/providers/wallpaper_service.dart';
import 'package:flauncher/widgets/date_time_widget.dart';
import 'package:flauncher/widgets/desktop/app_icon.dart';
import 'package:flauncher/widgets/greeting_widget.dart';
import 'package:flauncher/widgets/network_widget.dart';
import 'package:flauncher/widgets/settings/settings_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

const double _shelfHeight = 56;

// Android TV's overscan-safe area: TVs that crop the picture edges still show everything inside it
const double _safeX = 48;
const double _safeY = 27;

// ChromeOS dark surfaces
const Color _surface = Color(0xE6202124);
const Color _surfaceVariant = Color(0xFF303134);
const Color _accent = Color(0xFF8AB4F8);

enum _Bubble { none, launcher, quickSettings }

/// Desktop layout used when a mouse and keyboard are connected, styled after ChromeOS:
/// a clean desktop, a floating shelf, a bubble launcher with search and a quick settings bubble.
class DesktopLauncher extends StatefulWidget {
  const DesktopLauncher({super.key});

  @override
  State<DesktopLauncher> createState() => _DesktopLauncherState();
}

class _DesktopLauncherState extends State<DesktopLauncher> {
  _Bubble _bubble = _Bubble.none;
  String _launcherQuery = "";

  void _openLauncher([String query = ""]) => setState(() {
    _bubble = _Bubble.launcher;
    _launcherQuery = query;
  });

  void _toggle(_Bubble bubble) => bubble == _Bubble.launcher && _bubble != _Bubble.launcher
      ? _openLauncher()
      : setState(() => _bubble = _bubble == bubble ? _Bubble.none : bubble);

  bool _metaTapped = false;

  void _closeBubble() => setState(() => _bubble = _Bubble.none);

  // Typing anywhere on the desktop opens the launcher with that text; the Windows/Command key toggles it
  // A Cmd tap on its own; Cmd + Space (Spotlight) never shows up here, the Cmd release after it is swallowed
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final isMeta = event.logicalKey == LogicalKeyboardKey.metaLeft || event.logicalKey == LogicalKeyboardKey.metaRight;
    if (isMeta && event is KeyUpEvent) {
      if (_metaTapped) {
        _toggle(_Bubble.launcher);
      }
      _metaTapped = false;
      return KeyEventResult.handled;
    }
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    _metaTapped = isMeta;
    if (isMeta) {
      return KeyEventResult.handled;
    }
    final character = event.character;
    if (_bubble != _Bubble.launcher && character != null && RegExp(r'^[\p{L}\p{N}]$', unicode: true).hasMatch(character)) {
      _openLauncher(character);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final appsService = context.watch<AppsService>();
    final apps = _visibleApps(appsService);

    return PopScope(
      canPop: false,
      onPopInvoked: (_) {
        if (_bubble != _Bubble.none) {
          _closeBubble();
        }
      },
      child: Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      // Text needs a Material ancestor for its default style
      child: Material(
      type: MaterialType.transparency,
      child: Selector<SettingsService, double>(
      selector: (_, settings) => settings.desktopScale,
      builder: (context, scale, _) => _Scaled(
      scale: scale,
      child: Stack(
        children: [
          Positioned.fill(child: Consumer<WallpaperService>(builder: (_, service, __) => _wallpaper(service))),
          // Like ChromeOS, the desktop itself stays clean: apps live in the launcher and on the shelf
          Positioned(
            top: _safeY,
            right: _safeX,
            child: Selector<SettingsService, bool>(
              selector: (_, service) => service.showGreeting,
              builder: (_, showGreeting, __) => showGreeting ? const GreetingWidget(showTime: false) : const SizedBox.shrink(),
            ),
          ),
          if (_bubble != _Bubble.none)
            Positioned.fill(
              child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _closeBubble),
            ),
          Positioned(
            left: _safeX,
            right: _safeX,
            bottom: _safeY,
            height: _shelfHeight,
            child: _Shelf(
              pinned: apps.take(8).toList(),
              bubble: _bubble,
              onLauncherPressed: () => _toggle(_Bubble.launcher),
              onStatusPressed: () => _toggle(_Bubble.quickSettings),
            ),
          ),
          if (_bubble == _Bubble.launcher)
            Positioned(
              left: _safeX,
              bottom: _safeY + _shelfHeight + 12,
              child: _LauncherBubble(
                key: ValueKey(_launcherQuery),
                apps: apps,
                initialQuery: _launcherQuery,
                onClose: _closeBubble,
              ),
            ),
          if (_bubble == _Bubble.quickSettings)
            Positioned(
              right: _safeX,
              bottom: _safeY + _shelfHeight + 12,
              child: _QuickSettingsBubble(onClose: _closeBubble),
            ),
        ],
      ),
      ),
      ),
      ),
      ),
    );
  }

  /// Apps in the order they appear in the launcher sections (desktop apps first), without duplicates.
  List<App> _visibleApps(AppsService appsService) {
    final seen = <String>{};
    final apps = <App>[];
    final sections = appsService.launcherSections.toList()
      ..sort((a, b) => (b is Category && b.name == DESKTOP_CATEGORY_NAME ? 1 : 0)
          - (a is Category && a.name == DESKTOP_CATEGORY_NAME ? 1 : 0));
    for (final section in sections) {
      if (section is Category) {
        for (final app in section.applications) {
          if (seen.add(app.packageName)) {
            apps.add(app);
          }
        }
      }
    }
    final desktop = apps.where((app) => isDesktopApp(app.packageName, sections)).toList();
    return [...desktop, ...apps.where((app) => !desktop.contains(app))];
  }

  Widget _wallpaper(WallpaperService service) => service.wallpaper != null
      ? Image(image: service.wallpaper!, fit: BoxFit.cover)
      : DecoratedBox(decoration: BoxDecoration(gradient: service.gradient.gradient));
}

/// Lays the desktop out on a larger virtual screen and shrinks it to fit, so it has
/// PC-like proportions on a TV whose pixel density is set for viewing from the sofa.
class _Scaled extends StatelessWidget {
  final double scale;
  final Widget child;

  const _Scaled({required this.scale, required this.child});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => FittedBox(
      fit: BoxFit.fill,
      child: SizedBox(
        width: constraints.maxWidth / scale,
        height: constraints.maxHeight / scale,
        child: child,
      ),
    ),
  );
}

/// Shared right-click / long-press menu for an app.
Future<void> _showAppMenu(BuildContext context, App app, Offset position) async {
  final appsService = context.read<AppsService>();
  final choice = await showMenu<String>(
    context: context,
    color: _surfaceVariant,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
    items: const [
      PopupMenuItem(value: "open", child: Text("Open")),
      PopupMenuItem(value: "info", child: Text("App info")),
      PopupMenuItem(value: "hide", child: Text("Hide from launcher")),
      PopupMenuItem(value: "uninstall", child: Text("Uninstall")),
    ],
  );

  switch (choice) {
    case "open":
      await appsService.launchApp(app, windowed: true);
    case "info":
      await appsService.openAppInfo(app);
    case "hide":
      await appsService.hideApplication(app);
    case "uninstall":
      await appsService.uninstallApp(app);
  }
}

/// Frosted, rounded ChromeOS surface used by the shelf and the bubbles.
class _Frosted extends StatelessWidget {
  final double radius;
  final Widget child;

  const _Frosted({required this.radius, required this.child});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 24, offset: Offset(0, 8))],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(color: _surface, child: child),
      ),
    ),
  );
}

class _Shelf extends StatelessWidget {
  final List<App> pinned;
  final _Bubble bubble;
  final VoidCallback onLauncherPressed;
  final VoidCallback onStatusPressed;

  const _Shelf({
    required this.pinned,
    required this.bubble,
    required this.onLauncherPressed,
    required this.onStatusPressed,
  });

  @override
  Widget build(BuildContext context) => _Frosted(
    radius: _shelfHeight / 2,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _ShelfButton(
              tooltip: "Launcher",
              selected: bubble == _Bubble.launcher,
              onPressed: onLauncherPressed,
              child: const Icon(Icons.radio_button_unchecked, size: 22, color: Colors.white),
            ),
          ),
          // Pinned apps sit in the middle of the shelf, as on ChromeOS
          Row(
            mainAxisSize: MainAxisSize.min,
            children: pinned.map((app) => _ShelfButton(
              tooltip: app.name,
              onPressed: () => context.read<AppsService>().launchApp(app, windowed: true),
              onSecondaryTap: (position) => _showAppMenu(context, app, position),
              child: AppIcon(packageName: app.packageName, size: 32),
            )).toList(),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: _StatusArea(selected: bubble == _Bubble.quickSettings, onPressed: onStatusPressed),
          ),
        ],
      ),
    ),
  );
}

class _ShelfButton extends StatelessWidget {
  final String tooltip;
  final Widget child;
  final VoidCallback onPressed;
  final void Function(Offset position)? onSecondaryTap;
  final bool selected;

  const _ShelfButton({
    required this.tooltip,
    required this.child,
    required this.onPressed,
    this.onSecondaryTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    waitDuration: const Duration(milliseconds: 400),
    child: GestureDetector(
      onSecondaryTapDown: onSecondaryTap == null ? null : (details) => onSecondaryTap!(details.globalPosition),
      child: InkWell(
        customBorder: const CircleBorder(),
        hoverColor: Colors.white12,
        focusColor: Colors.white24,
        onTap: onPressed,
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: selected ? const BoxDecoration(color: Colors.white24, shape: BoxShape.circle) : null,
          child: child,
        ),
      ),
    ),
  );
}

/// The shelf's status area: network and time in a pill that opens quick settings.
class _StatusArea extends StatelessWidget {
  final bool selected;
  final VoidCallback onPressed;

  const _StatusArea({required this.selected, required this.onPressed});

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(20),
    hoverColor: Colors.white12,
    focusColor: Colors.white24,
    onTap: onPressed,
    child: Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: selected ? Colors.white24 : Colors.white10,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const IconTheme(data: IconThemeData(size: 18), child: NetworkWidget()),
          const SizedBox(width: 10),
          Selector<SettingsService, String>(
            selector: (_, service) => service.timeFormat,
            builder: (_, timeFormat, __) => DateTimeWidget(timeFormat,
                key: ValueKey(timeFormat), textStyle: const TextStyle(fontSize: 15, color: Colors.white)),
          ),
        ],
      ),
    ),
  );
}

class _LauncherBubble extends StatefulWidget {
  final List<App> apps;
  final String initialQuery;
  final VoidCallback onClose;

  const _LauncherBubble({super.key, required this.apps, required this.initialQuery, required this.onClose});

  @override
  State<_LauncherBubble> createState() => _LauncherBubbleState();
}

class _LauncherBubbleState extends State<_LauncherBubble> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialQuery)
    ..selection = TextSelection.collapsed(offset: widget.initialQuery.length);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _query => _controller.text.trim().toLowerCase();

  List<App> get _matches {
    final query = _query;
    final matches = widget.apps.where((app) => app.name.toLowerCase().contains(query)).toList();
    // Names that start with the query first
    matches.sort((a, b) {
      final aStarts = a.name.toLowerCase().startsWith(query) ? 0 : 1;
      final bStarts = b.name.toLowerCase().startsWith(query) ? 0 : 1;
      return aStarts != bStarts ? aStarts - bStarts : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return matches;
  }

  void _launch(App app) {
    widget.onClose();
    context.read<AppsService>().launchApp(app, windowed: true);
  }

  @override
  Widget build(BuildContext context) {
    final searching = _query.isNotEmpty;
    final results = searching ? _matches : widget.apps;

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): widget.onClose},
      child: _Frosted(
        radius: 24,
        child: SizedBox(
          width: 640,
          height: 560,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _controller,
                  autofocus: true,
                  style: const TextStyle(fontSize: 16),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, color: Colors.white70),
                    hintText: "Search your apps…",
                    filled: true,
                    fillColor: _surfaceVariant,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: _accent, width: 2)),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) {
                    if (results.isNotEmpty) {
                      _launch(results.first);
                    }
                  },
                ),
                const SizedBox(height: 16),
                if (searching && results.isEmpty)
                  const Expanded(child: Center(child: Text("No matching apps", style: TextStyle(color: Colors.white70)))),
                if (searching && results.isNotEmpty)
                  Expanded(
                    child: ListView(
                      children: results.map((app) => GestureDetector(
                        onSecondaryTapDown: (details) => _showAppMenu(context, app, details.globalPosition),
                        child: ListTile(
                          dense: true,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          leading: AppIcon(packageName: app.packageName, size: 32),
                          title: Text(app.name, style: const TextStyle(fontSize: 15)),
                          hoverColor: Colors.white12,
                          onTap: () => _launch(app),
                        ),
                      )).toList(),
                    ),
                  ),
                if (!searching)
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 5,
                      childAspectRatio: 1.1,
                      children: results.map((app) => _LauncherTile(app: app, onLaunch: () => _launch(app))).toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LauncherTile extends StatelessWidget {
  final App app;
  final VoidCallback onLaunch;

  const _LauncherTile({required this.app, required this.onLaunch});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onSecondaryTapDown: (details) => _showAppMenu(context, app, details.globalPosition),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      hoverColor: Colors.white12,
      focusColor: Colors.white24,
      onTap: onLaunch,
      onLongPress: () {
        final box = context.findRenderObject() as RenderBox;
        _showAppMenu(context, app, box.localToGlobal(box.size.center(Offset.zero)));
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppIcon(packageName: app.packageName, size: 48),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(app.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: Colors.white),
            ),
          ),
        ],
      ),
    ),
  );
}

/// ChromeOS-style quick settings: the date and rounded feature buttons.
class _QuickSettingsBubble extends StatelessWidget {
  final VoidCallback onClose;

  const _QuickSettingsBubble({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final channel = FLauncherChannel();
    final appsService = context.read<AppsService>();

    void run(void Function() action) {
      onClose();
      action();
    }

    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): onClose},
      child: _Frosted(
        radius: 24,
        child: SizedBox(
          width: 380,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                  child: Row(
                    children: [
                      const DateTimeWidget("EEEE d MMMM",
                          updateInterval: Duration(minutes: 1), textStyle: TextStyle(fontSize: 15, color: Colors.white)),
                      const Spacer(),
                      _RoundIconButton(
                        tooltip: "Lock TV",
                        icon: Icons.lock_outline,
                        onPressed: () => run(channel.lockNow),
                      ),
                      const SizedBox(width: 8),
                      _RoundIconButton(
                        tooltip: "TV settings",
                        icon: Icons.settings_outlined,
                        onPressed: () => run(appsService.openSettings),
                      ),
                    ],
                  ),
                ),
                GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 2,
                  childAspectRatio: 3.2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: [
                    _FeaturePill(icon: Icons.wifi, label: "Wi-Fi",
                        onPressed: () => run(() => channel.openSystemSettingsPage("network"))),
                    _FeaturePill(icon: Icons.bluetooth, label: "Bluetooth",
                        onPressed: () => run(() => channel.openSystemSettingsPage("accessories"))),
                    _FeaturePill(icon: Icons.memory, label: "Free up RAM", onPressed: () => run(channel.freeRam)),
                    _FeaturePill(icon: Icons.tv, label: "Display & sound",
                        onPressed: () => run(() => channel.openSystemSettingsPage("display_sound"))),
                    _FeaturePill(icon: Icons.tune, label: "Launcher",
                        onPressed: () => run(() => showDialog(context: context, builder: (_) => const SettingsPanel()))),
                    _FeaturePill(icon: Icons.apps, label: "Manage apps",
                        onPressed: () => run(() => channel.openSystemSettingsPage("apps"))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _FeaturePill({required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) => Material(
    color: _surfaceVariant,
    borderRadius: BorderRadius.circular(28),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      hoverColor: Colors.white12,
      focusColor: Colors.white24,
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(icon, size: 20, color: _accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, color: Colors.white)),
            ),
          ],
        ),
      ),
    ),
  );
}

class _RoundIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const _RoundIconButton({required this.tooltip, required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: _surfaceVariant,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        hoverColor: Colors.white12,
        focusColor: Colors.white24,
        onTap: onPressed,
        child: SizedBox(width: 40, height: 40, child: Icon(icon, size: 20, color: Colors.white)),
      ),
    ),
  );
}
