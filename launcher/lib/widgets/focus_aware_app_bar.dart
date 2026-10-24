import 'package:flauncher/flauncher_channel.dart';
import 'package:flauncher/widgets/settings/settings_panel.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_service.dart';
import 'date_time_widget.dart';
import 'network_widget.dart';

class FocusAwareAppBar extends StatefulWidget implements PreferredSizeWidget
{
  @override
  State<StatefulWidget> createState() {
    return _FocusAwareAppBarState();
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}

class _FocusAwareAppBarState extends State<FocusAwareAppBar>
{
  bool focused = false;

  @override
  Widget build(BuildContext context) {
    return Selector<SettingsService, bool>(
      selector: (_, settings) => settings.autoHideAppBarEnabled,
      builder: (context, autoHide, widget) {
        if (autoHide) {
          return Focus(
            canRequestFocus: false,
            child: AnimatedContainer(
              curve: Curves.decelerate,
              duration: Duration(milliseconds: 250),
              height: focused ? kToolbarHeight : 0,
              child: widget!
            ),
            onFocusChange: (hasFocus) {
              this.setState(() {
                focused = hasFocus;
              });
            }
          );
        }

        return widget!;
      },
      child: AppBar(
        actions: [
          _barButton(context, Icons.memory, "Free up RAM", () => FLauncherChannel().freeRam()),
          const SizedBox(width: 6),
          _barButton(context, Icons.lock_outline, "Lock TV", () => FLauncherChannel().lockNow()),
          const SizedBox(width: 6),
          _barButton(context, Icons.settings_outlined, "Settings",
              () => showDialog(context: context, builder: (_) => const SettingsPanel())),
          const Padding(
            padding: EdgeInsets.only(left: 16),
            child: IconTheme(data: IconThemeData(size: 18), child: NetworkWidget()),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 32),
            child: Selector<SettingsService,
                ({
                  bool showDateInStatusBar,
                  bool showTimeInStatusBar,
                  String dateFormat,
                  String timeFormat })>(
              selector: (context, service) => (
              showDateInStatusBar: service.showDateInStatusBar,
              showTimeInStatusBar: service.showTimeInStatusBar,
              dateFormat: service.dateFormat,
              timeFormat: service.timeFormat),
              builder: (context, dateTimeSettings, _) {
                // TODO: Disabling the "show date" option while both are enabled causes the *time* to disappear,
                // then re-enabling that same option causes the time to appear twice.
                // A restart (or just changing to the full screen clock) fixes the issue, but why does this happen?
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (dateTimeSettings.showDateInStatusBar)
                      Flexible(
                          child: DateTimeWidget(dateTimeSettings.dateFormat,
                            updateInterval: const Duration(minutes: 1),
                            textStyle: Theme.of(context).textTheme.titleLarge!.copyWith(
                              shadows: [
                                const Shadow(color: Colors.black54, offset: Offset(0, 2), blurRadius: 8)
                              ],
                            ),
                          )
                      ),
                    if (dateTimeSettings.showDateInStatusBar && dateTimeSettings.showTimeInStatusBar)
                      const SizedBox(width: 16),
                    if (dateTimeSettings.showTimeInStatusBar)
                      Flexible(
                        child: DateTimeWidget(dateTimeSettings.timeFormat,
                          textStyle: Theme.of(context).textTheme.titleLarge!.copyWith(
                            shadows: [
                              const Shadow(color: Colors.black54, offset: Offset(0, 2), blurRadius: 8)
                            ],
                          )
                        )
                      )
                  ]
                );
              },
            ),
          ),
        ],
      )
    );
  }

  Widget _barButton(BuildContext context, IconData icon, String tooltip, VoidCallback onPressed) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    icon: Icon(icon, size: 15),
    style: ButtonStyle(
      fixedSize: const WidgetStatePropertyAll(Size(28, 28)),
      // IconButton otherwise keeps a 40 minimum size and 8 padding
      minimumSize: const WidgetStatePropertyAll(Size(28, 28)),
      padding: const WidgetStatePropertyAll(EdgeInsets.zero),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: const WidgetStatePropertyAll(CircleBorder()),
      backgroundColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.focused) ? Colors.white : Colors.black.withOpacity(0.25)),
      foregroundColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.focused) ? Colors.black : Colors.white),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
  );
}
