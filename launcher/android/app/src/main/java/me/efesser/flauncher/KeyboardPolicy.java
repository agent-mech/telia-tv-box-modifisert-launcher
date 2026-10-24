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

package me.efesser.flauncher;

import android.Manifest;
import android.content.ComponentName;
import android.content.Context;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.provider.Settings;

/**
 * Desktop mode policy: never show an on-screen keyboard. Switches the system keyboard to
 * NoKeyboardInputMethod in desktop mode and back to the previous keyboard in TV mode.
 * Needs WRITE_SECURE_SETTINGS, granted over adb: pm grant <package> android.permission.WRITE_SECURE_SETTINGS
 */
final class KeyboardPolicy {
    private static final String PREFERENCES_NAME = "volt_keyboard_policy";
    private static final String PREVIOUS_IME_KEY = "previous_ime";

    private KeyboardPolicy() {}

    static boolean canApply(Context context) {
        return context.checkSelfPermission(Manifest.permission.WRITE_SECURE_SETTINGS) == PackageManager.PERMISSION_GRANTED;
    }

    /** Returns false if the permission is missing. */
    static boolean apply(Context context, boolean desktop) {
        if (!canApply(context)) {
            return false;
        }

        String ours = new ComponentName(context, NoKeyboardInputMethod.class).flattenToShortString();
        String current = Settings.Secure.getString(context.getContentResolver(), Settings.Secure.DEFAULT_INPUT_METHOD);
        SharedPreferences preferences = context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE);

        if (desktop) {
            if (ours.equals(current)) {
                return true;
            }
            preferences.edit().putString(PREVIOUS_IME_KEY, current).apply();
            setEnabled(context, ours, true);
            Settings.Secure.putString(context.getContentResolver(), Settings.Secure.DEFAULT_INPUT_METHOD, ours);
        } else if (ours.equals(current)) {
            String previous = preferences.getString(PREVIOUS_IME_KEY, null);
            if (previous != null) {
                Settings.Secure.putString(context.getContentResolver(), Settings.Secure.DEFAULT_INPUT_METHOD, previous);
            }
            setEnabled(context, ours, false);
        }
        return true;
    }

    private static void setEnabled(Context context, String ime, boolean enabled) {
        String list = Settings.Secure.getString(context.getContentResolver(), Settings.Secure.ENABLED_INPUT_METHODS);
        StringBuilder result = new StringBuilder();
        if (list != null) {
            for (String entry : list.split(":")) {
                // Entries can carry subtypes after ';'
                if (!entry.isEmpty() && !entry.split(";")[0].equals(ime)) {
                    result.append(result.length() > 0 ? ":" : "").append(entry);
                }
            }
        }
        if (enabled) {
            result.append(result.length() > 0 ? ":" : "").append(ime);
        }
        Settings.Secure.putString(context.getContentResolver(), Settings.Secure.ENABLED_INPUT_METHODS, result.toString());
    }
}
