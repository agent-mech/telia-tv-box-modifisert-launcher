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

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.graphics.Color;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.text.Editable;
import android.text.TextWatcher;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.KeyEvent;
import android.view.View;
import android.view.ViewGroup;
import android.view.inputmethod.EditorInfo;
import android.widget.EditText;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;

/**
 * Spotlight-style search over apps, launcher settings, Android TV settings and actions.
 * Opened from anywhere with Cmd/Windows + Space (see RemoteKeyService); the same keys close it.
 */
public class SpotlightActivity extends Activity {
    private static final int MAX_RESULTS = 8;

    private record Entry(String label, String kind, String keywords, Drawable icon, Intent intent) {
    }

    private final List<Entry> entries = new ArrayList<>();
    private final List<Entry> results = new ArrayList<>();
    private LinearLayout resultsView;
    private int selected;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        if (PinStore.isLocked(this)) {
            PinLockActivity.start(this, PinLockActivity.MODE_UNLOCK);
            finish();
            return;
        }

        loadEntries();

        EditText search = new EditText(this);
        search.setHint("Search apps and settings");
        search.setHintTextColor(0x80FFFFFF);
        search.setTextColor(Color.WHITE);
        search.setTextSize(TypedValue.COMPLEX_UNIT_SP, 24);
        search.setSingleLine(true);
        search.setBackground(null);
        search.setImeOptions(EditorInfo.IME_ACTION_GO | EditorInfo.IME_FLAG_NO_EXTRACT_UI);
        search.setPadding(dp(8), dp(4), dp(8), dp(8));
        search.addTextChangedListener(new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {
            }

            @Override
            public void onTextChanged(CharSequence s, int start, int before, int count) {
            }

            @Override
            public void afterTextChanged(Editable text) {
                filter(text.toString());
            }
        });
        search.setOnEditorActionListener((view, actionId, event) -> {
            openSelected();
            return true;
        });
        search.setOnKeyListener((view, keyCode, event) -> {
            if (event.getAction() != KeyEvent.ACTION_DOWN) {
                return false;
            }
            switch (keyCode) {
                case KeyEvent.KEYCODE_DPAD_DOWN -> select(selected + 1);
                case KeyEvent.KEYCODE_DPAD_UP -> select(selected - 1);
                case KeyEvent.KEYCODE_ENTER, KeyEvent.KEYCODE_NUMPAD_ENTER, KeyEvent.KEYCODE_DPAD_CENTER -> openSelected();
                case KeyEvent.KEYCODE_ESCAPE -> finish();
                default -> {
                    return false;
                }
            }
            return true;
        });

        resultsView = new LinearLayout(this);
        resultsView.setOrientation(LinearLayout.VERTICAL);

        LinearLayout panel = new LinearLayout(this);
        panel.setOrientation(LinearLayout.VERTICAL);
        panel.setPadding(dp(16), dp(12), dp(16), dp(12));
        GradientDrawable background = new GradientDrawable();
        background.setColor(0xF0141833);
        background.setCornerRadius(dp(20));
        panel.setBackground(background);
        panel.addView(search, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        panel.addView(resultsView, new LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT));
        panel.setClickable(true);

        // Upper third of the screen, like macOS Spotlight; clicking outside closes it
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setGravity(Gravity.CENTER_HORIZONTAL);
        root.setPadding(dp(48), dp(90), dp(48), dp(48));
        root.setOnClickListener(v -> finish());
        root.addView(panel, new LinearLayout.LayoutParams(dp(640), ViewGroup.LayoutParams.WRAP_CONTENT));
        setContentView(root);

        search.requestFocus();
    }

    // Cmd + Space again closes it
    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        finish();
    }

    @Override
    protected void onPause() {
        super.onPause();
        finish();
    }

    private void loadEntries() {
        Drawable settingsIcon = icon(R.drawable.quick_menu_settings);

        // The launcher's own settings pages
        String[][] launcherPages = {
                {"Volt settings", "settings_panel", "launcher preferences desktop mode size screen margins greeting name clock back button"},
                {"TV settings", "tv_settings_panel", "volume screensaver sleep turn off animations text size font date time"},
                {"Wallpaper", "wallpaper_panel", "background gradient"},
                {"Wallpaper images", "wallpaper_images_panel", "background picture photo time of day"},
                {"Applications", "applications_panel", "hide apps show"},
                {"Launcher sections", "launcher_sections_panel", "categories rows home screen layout"},
                {"Status bar", "status_bar_panel", "clock date network"},
                {"Quick menu", "quick_menu_panel", "assistant google button"},
                {"Passcode", "passcode_panel", "pin lock code security"},
                {"Remote buttons", "remote_buttons_panel", "remap remote control keys mitt innhold"},
        };
        for (String[] page : launcherPages) {
            Intent intent = new Intent(this, MainActivity.class)
                    .putExtra(MainActivity.EXTRA_OPEN_SETTINGS, true)
                    .putExtra(MainActivity.EXTRA_SETTINGS_ROUTE, page[1]);
            entries.add(new Entry(page[0], "Volt settings", page[2], settingsIcon, intent));
        }

        // Android TV's own settings pages
        String[][] systemPages = {
                {"Network & Internet", "network", "wifi wi-fi wlan ethernet internet"},
                {"Remotes & accessories", "accessories", "bluetooth pair remote controller gamepad headphones"},
                {"Display & sound", "display_sound", "resolution hdmi audio picture screen sound"},
                {"Manage apps", "apps", "uninstall permissions storage cache"},
                {"Install unknown apps", "unknown_sources", "apk sideload"},
                {"Storage", "storage", "space disk usb"},
                {"Date & time", "date_time", "clock timezone"},
                {"Language", "language", "locale norsk english"},
                {"Keyboard", "keyboard", "input method gboard"},
                {"Accessibility", "accessibility", "captions talkback"},
                {"Accounts & sign-in", "accounts", "google account"},
                {"Device name", "device_name", "rename"},
                {"Developer options", "developer", "adb debugging"},
                {"About, updates & reset", "about", "system update factory reset version"},
                {"All Android settings", "all", "system"},
        };
        for (String[] page : systemPages) {
            Intent intent = SystemSettings.pageIntent(page[1]);
            if (intent != null) {
                entries.add(new Entry(page[0], "TV settings", page[2], settingsIcon, intent));
            }
        }

        // Actions
        String[][] actions = {
                {"Lock TV", "lock", "passcode pin", null},
                {"Switch TV / desktop", "toggle_layout", "layout mode desktop tv", null},
                {"Screensaver", "screensaver", "ambient", null},
                {"Home", "home", "launcher", null},
        };
        for (String[] action : actions) {
            Intent intent = QuickMenuActivity.actionIntent(this, action[1]);
            if (intent != null) {
                entries.add(new Entry(action[0], "Action", action[2], actionIcon(action[1]), intent));
            }
        }

        // Installed apps, TV and phone launcher entries, without duplicates
        PackageManager packageManager = getPackageManager();
        Set<String> seen = new HashSet<>(Set.of(getPackageName(), "com.android.tv.settings", "com.android.settings"));
        for (String category : new String[]{Intent.CATEGORY_LEANBACK_LAUNCHER, Intent.CATEGORY_LAUNCHER}) {
            Intent query = new Intent(Intent.ACTION_MAIN).addCategory(category);
            for (ResolveInfo info : packageManager.queryIntentActivities(query, 0)) {
                String packageName = info.activityInfo.packageName;
                if (seen.add(packageName)) {
                    Intent intent = QuickMenuActivity.appIntent(this, packageName);
                    if (intent != null) {
                        entries.add(new Entry(info.loadLabel(packageManager).toString(), "App", "",
                                info.loadIcon(packageManager), intent));
                    }
                }
            }
        }
    }

    private void filter(String text) {
        String query = text.trim().toLowerCase(Locale.ROOT);
        results.clear();

        if (!query.isEmpty()) {
            // Names starting with the text first, then names containing it, then keyword matches
            List<Entry> contains = new ArrayList<>();
            List<Entry> keywords = new ArrayList<>();
            for (Entry entry : entries) {
                String label = entry.label().toLowerCase(Locale.ROOT);
                if (label.startsWith(query)) {
                    results.add(entry);
                } else if (label.contains(query)) {
                    contains.add(entry);
                } else if (entry.keywords().contains(query)) {
                    keywords.add(entry);
                }
            }
            results.addAll(contains);
            results.addAll(keywords);
        }

        resultsView.removeAllViews();
        for (int i = 0; i < Math.min(results.size(), MAX_RESULTS); i++) {
            resultsView.addView(buildRow(results.get(i), i));
        }
        if (!query.isEmpty() && results.isEmpty()) {
            TextView empty = new TextView(this);
            empty.setText("No results");
            empty.setTextColor(0x80FFFFFF);
            empty.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16);
            empty.setPadding(dp(12), dp(8), dp(12), dp(4));
            resultsView.addView(empty);
        }
        select(0);
    }

    private View buildRow(Entry entry, int index) {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setPadding(dp(12), dp(8), dp(12), dp(8));
        row.setOnClickListener(v -> open(entry));
        row.setOnHoverListener((v, event) -> {
            select(index);
            return false;
        });

        ImageView icon = new ImageView(this);
        icon.setImageDrawable(entry.icon());
        row.addView(icon, new LinearLayout.LayoutParams(dp(32), dp(32)));

        TextView label = new TextView(this);
        label.setText(entry.label());
        label.setTextColor(Color.WHITE);
        label.setTextSize(TypedValue.COMPLEX_UNIT_SP, 18);
        label.setPadding(dp(14), 0, 0, 0);
        row.addView(label, new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1));

        TextView kind = new TextView(this);
        kind.setText(entry.kind());
        kind.setTextColor(0x80FFFFFF);
        kind.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14);
        row.addView(kind);
        return row;
    }

    private void select(int index) {
        int count = resultsView.getChildCount();
        if (results.isEmpty() || count == 0) {
            selected = 0;
            return;
        }
        selected = Math.max(0, Math.min(index, Math.min(results.size(), MAX_RESULTS) - 1));

        for (int i = 0; i < count; i++) {
            View row = resultsView.getChildAt(i);
            if (i == selected) {
                GradientDrawable highlight = new GradientDrawable();
                highlight.setColor(0x33FFFFFF);
                highlight.setCornerRadius(dp(12));
                row.setBackground(highlight);
            } else {
                row.setBackground(null);
            }
        }
    }

    private void openSelected() {
        if (selected < results.size()) {
            open(results.get(selected));
        }
    }

    private void open(Entry entry) {
        try {
            startActivity(new Intent(entry.intent()).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
        } catch (ActivityNotFoundException | SecurityException e) {
            Toast.makeText(this, "Can't open " + entry.label(), Toast.LENGTH_SHORT).show();
        }
        finish();
    }

    private Drawable actionIcon(String action) {
        return icon(switch (action) {
            case "lock" -> R.drawable.quick_menu_lock;
            case "screensaver" -> R.drawable.quick_menu_screensaver;
            case "home" -> R.drawable.quick_menu_home;
            default -> R.drawable.quick_menu_display;
        });
    }

    private Drawable icon(int resId) {
        Drawable drawable = getDrawable(resId).mutate();
        drawable.setTint(Color.WHITE);
        return drawable;
    }

    private int dp(int value) {
        return Math.round(TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, value, getResources().getDisplayMetrics()));
    }
}
