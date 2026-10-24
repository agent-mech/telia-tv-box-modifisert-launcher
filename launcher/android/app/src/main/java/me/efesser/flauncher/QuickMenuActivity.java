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
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.StateListDrawable;
import android.os.Bundle;
import android.provider.Settings;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.KeyEvent;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

import java.util.ArrayList;
import java.util.List;

/**
 * Pop-up menu opened by the remote's assistant/search button.
 * Its items are chosen in the launcher settings and stored by Flutter's shared_preferences
 * as a comma-separated list of "app:<package>" and "action:<id>" entries.
 */
public class QuickMenuActivity extends Activity {
    static final String PREFERENCES_NAME = "FlutterSharedPreferences";
    static final String ITEMS_KEY = "flutter.quick_menu_items";
    static final String DEFAULT_ITEMS = "action:home,action:settings,action:wifi,action:bluetooth";

    private static final class Item {
        private final String label;
        private final Drawable icon;
        private final Intent intent;

        Item(String label, Drawable icon, Intent intent) {
            this.label = label;
            this.icon = icon;
            this.intent = intent;
        }

        String label() { return label; }
        Drawable icon() { return icon; }
        Intent intent() { return intent; }
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        if (PinStore.isLocked(this)) {
            PinLockActivity.start(this, PinLockActivity.MODE_UNLOCK);
            finish();
            return;
        }

        List<Item> items = loadItems();

        LinearLayout list = new LinearLayout(this);
        list.setOrientation(LinearLayout.VERTICAL);
        list.setPadding(dp(16), dp(16), dp(16), dp(16));

        TextView title = new TextView(this);
        title.setText("Quick menu");
        title.setTextColor(Color.WHITE);
        title.setTextSize(TypedValue.COMPLEX_UNIT_SP, 22);
        title.setTypeface(Typeface.DEFAULT_BOLD);
        title.setPadding(dp(12), dp(4), dp(12), dp(12));
        list.addView(title);

        if (items.isEmpty()) {
            TextView empty = new TextView(this);
            empty.setText("No items yet. Choose them in Volt Launcher settings → Quick menu.");
            empty.setTextColor(0xB3FFFFFF);
            empty.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16);
            empty.setPadding(dp(12), dp(8), dp(12), dp(8));
            list.addView(empty);
        }

        View first = null;
        for (Item item : items) {
            View row = buildRow(item);
            list.addView(row);
            if (first == null) {
                first = row;
            }
        }

        ScrollView scrollView = new ScrollView(this);
        scrollView.addView(list);

        GradientDrawable background = new GradientDrawable();
        background.setColor(0xF0141833);
        background.setCornerRadius(dp(20));
        scrollView.setBackground(background);

        LinearLayout root = new LinearLayout(this);
        root.setGravity(Gravity.END | Gravity.CENTER_VERTICAL);
        root.setPadding(dp(32), dp(32), dp(32), dp(32));
        root.setOnClickListener(v -> finish());
        root.addView(scrollView, new LinearLayout.LayoutParams(dp(380), ViewGroup.LayoutParams.WRAP_CONTENT));
        setContentView(root);

        if (first != null) {
            first.requestFocus();
        }
    }

    @Override
    public boolean onKeyDown(int keyCode, KeyEvent event) {
        // Pressing the same button again closes the menu
        if (keyCode == KeyEvent.KEYCODE_SEARCH || keyCode == KeyEvent.KEYCODE_ASSIST || keyCode == KeyEvent.KEYCODE_VOICE_ASSIST) {
            finish();
            return true;
        }
        return super.onKeyDown(keyCode, event);
    }

    private View buildRow(Item item) {
        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setPadding(dp(12), dp(10), dp(12), dp(10));
        row.setFocusable(true);
        row.setClickable(true);

        GradientDrawable focused = new GradientDrawable();
        focused.setColor(0x33FFFFFF);
        focused.setCornerRadius(dp(12));
        StateListDrawable states = new StateListDrawable();
        states.addState(new int[]{android.R.attr.state_focused}, focused);
        states.addState(new int[]{android.R.attr.state_pressed}, focused);
        row.setBackground(states);

        ImageView icon = new ImageView(this);
        icon.setImageDrawable(item.icon());
        row.addView(icon, new LinearLayout.LayoutParams(dp(36), dp(36)));

        TextView label = new TextView(this);
        label.setText(item.label());
        label.setTextColor(Color.WHITE);
        label.setTextSize(TypedValue.COMPLEX_UNIT_SP, 18);
        label.setPadding(dp(16), 0, 0, 0);
        row.addView(label);

        row.setOnClickListener(v -> {
            try {
                startActivity(item.intent().addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
            } catch (ActivityNotFoundException | SecurityException e) {
                Toast.makeText(this, "Can't open " + item.label(), Toast.LENGTH_SHORT).show();
            }
            finish();
        });
        return row;
    }

    private List<Item> loadItems() {
        SharedPreferences preferences = getSharedPreferences(PREFERENCES_NAME, MODE_PRIVATE);
        String stored = preferences.getString(ITEMS_KEY, DEFAULT_ITEMS);
        List<Item> items = new ArrayList<>();

        for (String entry : stored.split(",")) {
            Item item = null;
            if (entry.startsWith("app:")) {
                item = appItem(entry.substring(4));
            } else if (entry.startsWith("action:")) {
                item = actionItem(entry.substring(7));
            }
            if (item != null) {
                items.add(item);
            }
        }
        return items;
    }

    private Item appItem(String packageName) {
        PackageManager packageManager = getPackageManager();
        Intent intent = appIntent(this, packageName);
        if (intent == null) {
            return null;
        }

        try {
            ApplicationInfo info = packageManager.getApplicationInfo(packageName, 0);
            return new Item(packageManager.getApplicationLabel(info).toString(), packageManager.getApplicationIcon(info), intent);
        } catch (PackageManager.NameNotFoundException e) {
            return null;
        }
    }

    private Item actionItem(String id) {
        Intent intent = actionIntent(this, id);
        if (intent == null) {
            return null;
        }

        return switch (id) {
            case "home" -> new Item("Home", icon(R.drawable.quick_menu_home), intent);
            case "settings" -> new Item("Settings", icon(R.drawable.quick_menu_settings), intent);
            case "wifi" -> new Item("Wi-Fi", icon(R.drawable.quick_menu_wifi), intent);
            case "bluetooth" -> new Item("Remotes & accessories", icon(R.drawable.quick_menu_bluetooth), intent);
            case "display" -> new Item("Display & sound", icon(R.drawable.quick_menu_display), intent);
            case "apps" -> new Item("Manage apps", icon(R.drawable.quick_menu_apps), intent);
            case "screensaver" -> new Item("Screensaver", icon(R.drawable.quick_menu_screensaver), intent);
            case "lock" -> new Item("Lock TV", icon(R.drawable.quick_menu_lock), intent);
            case "toggle_layout" -> new Item("Switch TV / desktop", icon(R.drawable.quick_menu_display), intent);
            case "free_ram" -> new Item("Free up RAM", icon(R.drawable.quick_menu_memory), intent);
            default -> null;
        };
    }

    /** Intent for an "action:<id>" entry; shared with the remote button remapping. */
    static Intent actionIntent(Context context, String id) {
        return switch (id) {
            case "home" -> new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME);
            case "settings" -> new Intent(context, MainActivity.class)
                    .putExtra(MainActivity.EXTRA_OPEN_SETTINGS, true)
                    .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP);
            case "wifi" -> SystemSettings.pageIntent("network");
            case "bluetooth" -> SystemSettings.pageIntent("accessories");
            case "display" -> SystemSettings.pageIntent("display_sound");
            case "apps" -> SystemSettings.pageIntent("apps");
            case "screensaver" -> new Intent(Intent.ACTION_MAIN).setClassName("com.android.systemui", "com.android.systemui.Somnambulator");
            case "lock" -> new Intent(context, PinLockActivity.class).putExtra(PinLockActivity.EXTRA_MODE, PinLockActivity.MODE_LOCK_NOW);
            case "quickmenu" -> new Intent(context, QuickMenuActivity.class);
            case "free_ram" -> new Intent(context, MemoryCleaner.Action.class);
            case "toggle_layout" -> new Intent(context, MainActivity.class)
                    .putExtra(MainActivity.EXTRA_TOGGLE_LAYOUT, true)
                    .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP);
            default -> null;
        };
    }

    /** Launch intent for an "app:<package>" entry, preferring the TV launcher entry. */
    static Intent appIntent(Context context, String packageName) {
        PackageManager packageManager = context.getPackageManager();
        Intent intent = packageManager.getLeanbackLaunchIntentForPackage(packageName);
        return intent != null ? intent : packageManager.getLaunchIntentForPackage(packageName);
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
