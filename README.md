# Telia TV box – modifisert launcher

A step-by-step guide to turning the Telia TV box (Sagemcom DCIW393 / "Telia box 2", Android TV 11) into a clean, fast smart-TV box: no operator software, no telemetry, no Google recommendation clutter. You also get a custom home screen with a few extras.

**What you get**

- **Volt Launcher:** a modified [FLauncher](https://github.com/osrosal/flauncher) with:
  - a large clock, weekday and date
  - a time-of-day greeting ("Good morning / afternoon / evening / night", optionally with your name)
  - a dark background
  - all apps in a grid; newly installed apps appear automatically
- **Quick Menu on the remote's Google Assistant button:** opens over any app, and you choose its contents (apps, Wi-Fi, Bluetooth, Settings, Lock TV, …)
- **Remote button remapping:** make any button (Guide, number keys, colour keys, …) open an app, the Quick Menu, Home, Lock TV and more, or disable it
- **A 4-digit passcode lock** that you can set, change or remove in the launcher's settings, plus a lock button
- **A debloat script** that removes the Telia/GET apps, Sagemcom analytics and operator update services, and unneeded Google extras
- **A restore script** that puts everything back

No root is needed and nothing permanent is changed: a factory reset returns the box to stock.

> **Disclaimer:** this project is not affiliated with Telia, GET or Sagemcom. If the box is rented, do a factory reset before you return it. Removing the operator update service means the box stops receiving Telia firmware updates. You do this at your own risk.

---

## What you need

- The Telia TV box, connected to your home network
- A computer (macOS, Linux or Windows) on the same network
- `adb` (Android platform-tools)
  - macOS: `brew install --cask android-platform-tools`
  - Linux: `sudo apt install adb` (or your distro's equivalent)
  - Windows: download [platform-tools](https://developer.android.com/tools/releases/platform-tools) and unzip it
- A Google account signed in on the box (for the Play Store)

## Step 1 – Turn on network debugging

1. On the box: **Settings → Device Preferences → About**, then select **Build** 7 times until it says you're a developer.
2. Go back to **Device Preferences → Developer options** and turn on **USB debugging**.
3. Find the box's IP address under **Settings → Network & Internet → (your network)**.

Check that the box is listening for ADB:

```sh
adb connect <box-ip>:5555
```

A prompt **"Allow USB debugging?"** appears on the TV. Tick **Always allow from this computer** and choose **Allow**. Then:

```sh
adb devices -l
```

The box should be listed as `device` (not `unauthorized`), with `model:Telia_box_2`.

> If `adb connect` is refused, connect the box to the computer with a USB-A to USB-A cable, run `adb tcpip 5555`, then unplug and run `adb connect <box-ip>:5555` again.

## Step 2 – Install Volt Launcher

Download `volt-launcher-armeabi-v7a.apk` from the [Releases](../../releases) page (or build it yourself, see below), then:

```sh
./scripts/install-launcher.sh <box-ip> volt-launcher-armeabi-v7a.apk
```

This:

- installs the launcher
- makes it the home screen
- makes it the box's "assistant", so the Google Assistant button on the remote opens the Quick Menu
- lets the passcode screen appear when the box wakes from standby (the `SYSTEM_ALERT_WINDOW` app-op)
- lets desktop mode hide the on-screen keyboard (`WRITE_SECURE_SETTINGS`) and the TV settings page change text size and screensaver delay (the `WRITE_SETTINGS` app-op)
- turns on the **remote buttons** service. It is an accessibility service, which is the only way Android lets an app remap remote buttons without root. It only looks at button presses; nothing is stored or sent anywhere. You can also turn it on yourself under **Settings → Device Preferences → Accessibility → Volt Launcher remote buttons**.

## Step 3 – Remove the bloat

Look through [`scripts/packages.txt`](scripts/packages.txt) first and delete any line you want to keep. For example, delete the Chromecast line if you cast from your phone. Then:

```sh
./scripts/debloat.sh <box-ip>
```

The script won't run until Volt Launcher is installed, so you never end up without a home screen.

**Kept on purpose:** Google Play Services, Play Store, WebView, the keyboard, the remote-control service and all hardware drivers. Streaming apps (Netflix, Disney+, HBO Max, YouTube, …) need Play Services for sign-in and DRM.

Reboot to make sure everything comes back cleanly:

```sh
adb reboot
```

## Step 4 – Install your apps

Install what you want from the Play Store on the box, for example Netflix, YouTube, Disney+, HBO Max, Prime Video, Apple TV, Viaplay, SkyShowtime, NRK TV, TV 2 Play, Spotify or Plex. New apps appear on the home screen automatically.

## Step 5 – Set up the launcher

Open settings with the **gear icon** in the top-right corner of the home screen.

| Setting | What it does |
|---|---|
| **Greeting name** | Name shown in "Good evening, …". Leave empty for no name. |
| **Show greeting and clock** | Turns the clock/greeting header on or off |
| **Quick menu** | Choose what the remote's assistant button opens |
| **Passcode** | Set, change or remove the 4-digit passcode |
| **Remote buttons** | **Add button** → press a button on the remote → choose what it does. Select a mapping to change or remove it. |
| **Sections** | Reorder, rename or add rows; switch between row and grid layout |
| **Applications** | Add apps to sections or hide them |
| **Wallpaper** | Gradient, a built-in wallpaper or your own picture |
| **TV settings** | The Android TV settings (volume, screensaver, sleep, text size, …) inside the launcher's settings |
| **Desktop mode** | Automatic (when a keyboard or mouse is connected), always or never |
| **Desktop size** | How large the desktop is drawn |

**Remote buttons:** the arrow keys, OK, Back and Power can't be remapped, so the remote can always navigate. Mappings are paused while the TV is locked, so they can't be used to get past the passcode. The assistant button is handled by the system before apps see it; it opens the Quick Menu instead.

**Free up RAM:** the chip icon next to the lock stops apps that sit idle in the background and shows how much memory it freed. It never stops the app in front, music playing in the background or the keyboard. It is also available in the Quick Menu and as a remote button action. Games (Roblox, and apps that declare themselves as games) get the same clean-up automatically as they start.

**Desktop mode:** plug in a mouse or keyboard and the home screen turns into a ChromeOS-style desktop: a floating shelf with pinned apps, a launcher bubble with search (or just start typing, or tap Cmd/Windows), and a quick settings bubble behind the clock (Wi-Fi, Bluetooth, Free up RAM, display, launcher and app settings). Cmd/Windows + Space opens Spotlight search from anywhere. Apps open in windows if freeform windows are turned on: `adb shell settings put global enable_freeform_support 1`, then reboot. Games always open full screen, since in a window they run out of graphics memory on this box.

**Locking:** with a passcode set, the TV locks when it starts and every time it wakes from standby. To lock it right away, press the **lock icon** next to the gear, or add **Lock TV** to the Quick Menu. You enter the code with the remote's number keys or the on-screen keypad.

---

## Limitations

- **No root:** the bootloader is locked and verified boot is on, so the **Telia boot animation can't be changed** and system apps can only be removed for the user, not deleted.
- **The passcode is a launcher-level lock,** not Android's system lock screen (that is switched off on this build and has no TV PIN pad). It covers normal use with the remote; someone with ADB access, or who resets the box, can get past it.
- **Forgot the passcode?** Run `adb shell pm clear com.voltlauncher.tv`. This also resets the launcher's layout and settings.

## Undo everything

```sh
./scripts/restore.sh <box-ip>
adb uninstall com.voltlauncher.tv
```

Or do a factory reset: **Settings → Device Preferences → Reset**.

---

## Building the launcher from source

The launcher needs **Flutter 3.24.5** exactly; newer Flutter versions fail to build this project.

```sh
git clone --depth 1 --branch 3.24.5 https://github.com/flutter/flutter.git ~/flutter-3.24.5
export PATH="$HOME/flutter-3.24.5/bin:$PATH"
# JDK 17 and the Android SDK (platform 35, build-tools 35) are required
cd launcher
flutter pub get
flutter build apk --release --split-per-abi --target-platform android-arm
# -> build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
```

The release build is signed with the Android debug key so anyone can build it. If you build your own APK, uninstall the released one first, because Android only accepts updates signed with the same key.

### Changes compared to FLauncher

- `lib/widgets/greeting_widget.dart`: clock, greeting and date header
- `lib/widgets/settings/quick_menu_panel_page.dart` and `android/…/QuickMenuActivity.java`: Quick Menu
- `lib/widgets/settings/passcode_panel_page.dart`, `android/…/PinLockActivity.java`, `PinStore.java`, `VoltApplication.java`: passcode lock (the code is stored as a salted SHA-256 hash)
- `lib/widgets/settings/remote_buttons_panel_page.dart` and `android/…/RemoteKeyService.java`: remote button remapping
- `lib/widgets/focus_aware_app_bar.dart`: lock button next to the settings gear
- `lib/gradients.dart`: "Volt Night" default background
- `lib/providers/apps_service.dart`: new apps are added to the home screen automatically, and the launcher hides its own tile
- `lib/widgets/app_card.dart`, `apps_grid.dart`, `category_row.dart`: Apple TV style tiles (rounded corners, lift with a deep shadow and a glossy sheen, the app name under the focused tile)
- `lib/widgets/desktop/` and `lib/launcher_home.dart`: ChromeOS-style desktop mode
- `android/…/InputDevicesStreamHandler.java`, `KeyboardPolicy.java`, `NoKeyboardInputMethod.java`: mouse/keyboard detection and no on-screen keyboard in desktop mode
- `android/…/SpotlightActivity.java`: Spotlight search
- `android/…/SystemSettings.java` and `lib/widgets/settings/tv_settings_panel_page.dart`: TV settings inside the launcher
- `android/…/MemoryCleaner.java`: Free up RAM and the automatic clean-up for games
- `assets/wallpapers/` (made with `tool/generate_wallpapers.py`): built-in wallpapers

## Credits and license

Volt Launcher is based on [FLauncher](https://gitlab.com/flauncher/flauncher) by Étienne Fesser and the [osrosal fork](https://github.com/osrosal/flauncher), and is released under the **GNU General Public License v3.0**, like the original. See [`launcher/LICENSE`](launcher/LICENSE).

The scripts and this guide are released under the same license.
