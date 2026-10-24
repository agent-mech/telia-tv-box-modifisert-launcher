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

import android.content.ContentResolver;
import android.content.Context;
import android.content.Intent;
import android.media.AudioManager;
import android.provider.Settings;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * The Android TV settings shown inside the launcher's own settings, so there is one settings
 * screen. Simple values are read and written here directly (WRITE_SECURE_SETTINGS and the
 * WRITE_SETTINGS app op are granted over adb); everything else opens the matching Android page.
 */
final class SystemSettings {
    private static final List<String> ANIMATION_SCALES = List.of(
            Settings.Global.WINDOW_ANIMATION_SCALE,
            Settings.Global.TRANSITION_ANIMATION_SCALE,
            Settings.Global.ANIMATOR_DURATION_SCALE);

    private SystemSettings() {
    }

    static Map<String, Object> get(Context context) {
        ContentResolver resolver = context.getContentResolver();
        AudioManager audio = (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);

        Map<String, Object> values = new HashMap<>();
        values.put("volume", audio.getStreamVolume(AudioManager.STREAM_MUSIC));
        values.put("maxVolume", audio.getStreamMaxVolume(AudioManager.STREAM_MUSIC));
        values.put("volumeFixed", audio.isVolumeFixed());
        values.put("screensaverEnabled", Settings.Secure.getInt(resolver, "screensaver_enabled", 1) == 1);
        values.put("screensaverTimeout", Settings.System.getInt(resolver, Settings.System.SCREEN_OFF_TIMEOUT, 300000));
        values.put("sleepTimeout", Settings.Secure.getInt(resolver, "sleep_timeout", -1));
        values.put("animationScale", (double) Settings.Global.getFloat(resolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f));
        values.put("fontScale", (double) Settings.System.getFloat(resolver, Settings.System.FONT_SCALE, 1f));
        values.put("autoTime", Settings.Global.getInt(resolver, Settings.Global.AUTO_TIME, 1) == 1);
        values.put("deviceName", Settings.Global.getString(resolver, Settings.Global.DEVICE_NAME));
        values.put("canWriteSystem", Settings.System.canWrite(context));
        return values;
    }

    /** False when the value couldn't be written (permission not granted). */
    static boolean set(Context context, String key, Object value) {
        ContentResolver resolver = context.getContentResolver();
        try {
            switch (key) {
                case "volume" -> ((AudioManager) context.getSystemService(Context.AUDIO_SERVICE))
                        .setStreamVolume(AudioManager.STREAM_MUSIC, (int) value, AudioManager.FLAG_SHOW_UI);
                case "screensaverEnabled" -> Settings.Secure.putInt(resolver, "screensaver_enabled", (boolean) value ? 1 : 0);
                case "screensaverTimeout" -> Settings.System.putInt(resolver, Settings.System.SCREEN_OFF_TIMEOUT, (int) value);
                case "sleepTimeout" -> {
                    // Android TV 11 uses both: sleep_timeout (TV settings) and attentive_timeout (framework)
                    Settings.Secure.putInt(resolver, "sleep_timeout", (int) value);
                    Settings.Secure.putInt(resolver, "attentive_timeout", (int) value);
                }
                case "animationScale" -> {
                    for (String scale : ANIMATION_SCALES) {
                        Settings.Global.putFloat(resolver, scale, ((Number) value).floatValue());
                    }
                }
                case "fontScale" -> Settings.System.putFloat(resolver, Settings.System.FONT_SCALE, ((Number) value).floatValue());
                case "autoTime" -> Settings.Global.putInt(resolver, Settings.Global.AUTO_TIME, (boolean) value ? 1 : 0);
                default -> {
                    return false;
                }
            }
            return true;
        } catch (SecurityException e) {
            return false;
        }
    }

    /** Intent for one Android settings page; null for an unknown page. */
    static Intent pageIntent(String page) {
        String action = switch (page) {
            case "network" -> Settings.ACTION_WIFI_SETTINGS;
            case "accessories" -> "com.google.android.intent.action.CONNECT_INPUT";
            case "display_sound" -> Settings.ACTION_SOUND_SETTINGS;
            case "apps" -> Settings.ACTION_MANAGE_APPLICATIONS_SETTINGS;
            case "unknown_sources" -> Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES;
            case "storage" -> Settings.ACTION_INTERNAL_STORAGE_SETTINGS;
            case "date_time" -> Settings.ACTION_DATE_SETTINGS;
            case "language" -> Settings.ACTION_LOCALE_SETTINGS;
            case "keyboard" -> Settings.ACTION_INPUT_METHOD_SETTINGS;
            case "accessibility" -> "android.settings.ACCESSIBILITY_TV_OEM_LINK";
            case "accounts" -> Settings.ACTION_SYNC_SETTINGS;
            case "device_name" -> "android.settings.DEVICE_NAME";
            case "developer" -> Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS;
            case "about" -> Settings.ACTION_DEVICE_INFO_SETTINGS;
            case "all" -> Settings.ACTION_SETTINGS;
            default -> null;
        };
        return action == null ? null : new Intent(action).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
    }
}
