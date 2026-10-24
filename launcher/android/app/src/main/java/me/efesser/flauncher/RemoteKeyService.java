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

import android.accessibilityservice.AccessibilityService;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Handler;
import android.os.Looper;
import android.view.KeyEvent;
import android.view.accessibility.AccessibilityEvent;
import android.widget.Toast;

import java.util.HashMap;
import java.util.Map;
import java.util.function.IntConsumer;

/**
 * Remaps remote buttons to launcher actions. Mappings are set in the launcher settings and stored
 * by Flutter's shared_preferences as "keyCode|keyName|action" entries joined by ";", where action is
 * "app:<package>", "action:<id>" (see QuickMenuActivity.actionIntent), "action:back" or "action:none".
 *
 * Only key presses are looked at; nothing is stored or sent anywhere.
 */
public class RemoteKeyService extends AccessibilityService implements SharedPreferences.OnSharedPreferenceChangeListener {
    static final String MAPPINGS_KEY = "flutter.remote_mappings";

    private static RemoteKeyService instance;
    private static IntConsumer captureCallback;

    private final Map<Integer, String> mappings = new HashMap<>();
    private boolean spotlightComboUsed;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private SharedPreferences preferences;

    static boolean isRunning() {
        return instance != null;
    }

    /** Hands the next remote button press to the callback (on the main thread) instead of acting on it. */
    static void captureNextKey(IntConsumer callback) {
        captureCallback = callback;
    }

    static void cancelCapture() {
        captureCallback = null;
    }

    /** Buttons that can't be remapped, so the remote can always navigate. */
    static boolean isProtected(int keyCode) {
        return switch (keyCode) {
            case KeyEvent.KEYCODE_DPAD_UP, KeyEvent.KEYCODE_DPAD_DOWN, KeyEvent.KEYCODE_DPAD_LEFT,
                 KeyEvent.KEYCODE_DPAD_RIGHT, KeyEvent.KEYCODE_DPAD_CENTER, KeyEvent.KEYCODE_ENTER,
                 KeyEvent.KEYCODE_BACK, KeyEvent.KEYCODE_POWER -> true;
            default -> false;
        };
    }

    @Override
    protected void onServiceConnected() {
        instance = this;

        preferences = getSharedPreferences(QuickMenuActivity.PREFERENCES_NAME, MODE_PRIVATE);
        preferences.registerOnSharedPreferenceChangeListener(this);
        loadMappings();
    }

    @Override
    public boolean onUnbind(Intent intent) {
        instance = null;
        captureCallback = null;
        if (preferences != null) {
            preferences.unregisterOnSharedPreferenceChangeListener(this);
        }
        return super.onUnbind(intent);
    }

    @Override
    public void onSharedPreferenceChanged(SharedPreferences sharedPreferences, String key) {
        if (MAPPINGS_KEY.equals(key)) {
            loadMappings();
        }
    }

    private void loadMappings() {
        mappings.clear();
        String stored = preferences.getString(MAPPINGS_KEY, "");
        for (String entry : stored.split(";")) {
            String[] parts = entry.split("\\|", 3);
            if (parts.length == 3) {
                try {
                    mappings.put(Integer.parseInt(parts[0]), parts[2]);
                } catch (NumberFormatException ignored) {
                }
            }
        }
    }

    @Override
    protected boolean onKeyEvent(KeyEvent event) {
        int keyCode = event.getKeyCode();

        // Cmd/Windows + Space opens Spotlight search from anywhere. The Cmd release after it is
        // swallowed too, so the desktop doesn't also treat it as a Cmd tap (start menu).
        if (keyCode == KeyEvent.KEYCODE_SPACE && event.isMetaPressed()) {
            if (event.getAction() == KeyEvent.ACTION_DOWN && event.getRepeatCount() == 0 && !PinStore.isLocked(this)) {
                spotlightComboUsed = true;
                handler.post(() -> {
                    try {
                        startActivity(new Intent(this, SpotlightActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
                    } catch (ActivityNotFoundException ignored) {
                    }
                });
            }
            return true;
        }
        if ((keyCode == KeyEvent.KEYCODE_META_LEFT || keyCode == KeyEvent.KEYCODE_META_RIGHT)
                && event.getAction() == KeyEvent.ACTION_UP && spotlightComboUsed) {
            spotlightComboUsed = false;
            return true;
        }

        IntConsumer capture = captureCallback;
        if (capture != null && !isProtected(keyCode)) {
            if (event.getAction() == KeyEvent.ACTION_UP) {
                captureCallback = null;
                handler.post(() -> capture.accept(keyCode));
            }
            return true;
        }

        // The Telia remote's MITT INNHOLD button sends DVR; unless remapped it switches TV / desktop layout
        String action = mappings.getOrDefault(keyCode,
                keyCode == KeyEvent.KEYCODE_DVR ? "action:toggle_layout" : null);

        // Keyboard Esc acts as the Back button, unless the user mapped it to something else
        if (action == null && keyCode == KeyEvent.KEYCODE_ESCAPE) {
            if (event.getAction() == KeyEvent.ACTION_UP) {
                handler.post(() -> performGlobalAction(GLOBAL_ACTION_BACK));
            }
            return true;
        }

        // Mappings are paused while the TV is locked so they can't be used to get past the passcode
        if (action == null || isProtected(keyCode) || PinStore.isLocked(this)) {
            return false;
        }

        if (event.getAction() == KeyEvent.ACTION_UP && event.getRepeatCount() == 0) {
            handler.post(() -> perform(action));
        }
        return true;
    }

    private void perform(String action) {
        if (action.equals("action:none")) {
            return;
        }
        if (action.equals("action:back")) {
            performGlobalAction(GLOBAL_ACTION_BACK);
            return;
        }
        if (action.equals("action:home")) {
            performGlobalAction(GLOBAL_ACTION_HOME);
            return;
        }

        Intent intent = action.startsWith("app:")
                ? QuickMenuActivity.appIntent(this, action.substring(4))
                : QuickMenuActivity.actionIntent(this, action.substring(action.indexOf(':') + 1));
        if (intent == null) {
            Toast.makeText(this, "Button action is no longer available", Toast.LENGTH_SHORT).show();
            return;
        }

        try {
            startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
        } catch (ActivityNotFoundException | SecurityException e) {
            Toast.makeText(this, "Can't open that", Toast.LENGTH_SHORT).show();
        }
    }

    @Override
    public void onAccessibilityEvent(AccessibilityEvent event) {
    }

    @Override
    public void onInterrupt() {
    }
}
