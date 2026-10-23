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
import android.content.Context;
import android.content.Intent;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.StateListDrawable;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.KeyEvent;
import android.view.View;
import android.widget.GridLayout;
import android.widget.LinearLayout;
import android.widget.TextView;

/**
 * Full-screen 4-digit passcode screen. Works with the remote's number keys or the on-screen keypad.
 *
 * Modes:
 *  - unlock: shown on boot and wake, can't be dismissed without the passcode
 *  - set:    choose a new passcode (asks for the current one first if there is one)
 *  - remove: asks for the current passcode, then removes it
 *  - lock_now: locks right away (or asks to choose a passcode first if there is none)
 */
public class PinLockActivity extends Activity {
    static final String EXTRA_MODE = "mode";
    static final String MODE_UNLOCK = "unlock";
    static final String MODE_SET = "set";
    static final String MODE_REMOVE = "remove";
    static final String MODE_LOCK_NOW = "lock_now";

    private static final int PIN_LENGTH = 4;

    private enum Step { VERIFY_CURRENT, ENTER_NEW, CONFIRM_NEW }

    private String mode;
    private Step step;
    private String newPin;
    private final StringBuilder entered = new StringBuilder();

    private TextView titleView;
    private TextView messageView;
    private final TextView[] dots = new TextView[PIN_LENGTH];
    private final Handler handler = new Handler(Looper.getMainLooper());

    static void start(Context context, String mode) {
        context.startActivity(new Intent(context, PinLockActivity.class)
                .putExtra(EXTRA_MODE, mode)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP));
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        buildLayout();
        startMode(getIntent());
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        startMode(intent);
    }

    private void startMode(Intent intent) {
        String requested = intent.getStringExtra(EXTRA_MODE);
        mode = requested != null ? requested : MODE_UNLOCK;

        String message = null;
        if (mode.equals(MODE_LOCK_NOW)) {
            if (PinStore.isSet(this)) {
                PinStore.lock();
                mode = MODE_UNLOCK;
            } else {
                mode = MODE_SET;
                message = "Choose a passcode first, then the TV can be locked";
            }
        }

        if (mode.equals(MODE_UNLOCK) && !PinStore.isLocked(this)) {
            finish();
            return;
        }
        if (mode.equals(MODE_REMOVE) && !PinStore.isSet(this)) {
            finish();
            return;
        }

        step = (mode.equals(MODE_SET) && !PinStore.isSet(this)) ? Step.ENTER_NEW : Step.VERIFY_CURRENT;
        newPin = null;
        showStep(message);
    }

    private void showStep(String message) {
        entered.setLength(0);
        updateDots();

        switch (step) {
            case VERIFY_CURRENT -> titleView.setText(mode.equals(MODE_UNLOCK) ? "Enter passcode" : "Enter current passcode");
            case ENTER_NEW -> titleView.setText("Choose a 4-digit passcode");
            case CONFIRM_NEW -> titleView.setText("Enter it again to confirm");
        }
        messageView.setText(message != null ? message : "");
    }

    private void onDigit(int digit) {
        if (entered.length() >= PIN_LENGTH) {
            return;
        }
        entered.append(digit);
        updateDots();

        if (entered.length() == PIN_LENGTH) {
            // Short pause so the last dot is visible before moving on
            handler.postDelayed(this::onComplete, 150);
        }
    }

    private void onDelete() {
        if (entered.length() > 0) {
            entered.setLength(entered.length() - 1);
            updateDots();
        }
    }

    private void onComplete() {
        String pin = entered.toString();

        switch (step) {
            case VERIFY_CURRENT -> {
                if (!PinStore.check(this, pin)) {
                    showStep("Wrong passcode, try again");
                    return;
                }
                switch (mode) {
                    case MODE_UNLOCK -> {
                        PinStore.unlock();
                        finish();
                    }
                    case MODE_REMOVE -> {
                        PinStore.clear(this);
                        finish();
                    }
                    default -> {
                        step = Step.ENTER_NEW;
                        showStep(null);
                    }
                }
            }
            case ENTER_NEW -> {
                newPin = pin;
                step = Step.CONFIRM_NEW;
                showStep(null);
            }
            case CONFIRM_NEW -> {
                if (pin.equals(newPin)) {
                    PinStore.set(this, pin);
                    finish();
                } else {
                    step = Step.ENTER_NEW;
                    showStep("The passcodes didn't match, start again");
                }
            }
        }
    }

    @Override
    public boolean onKeyDown(int keyCode, KeyEvent event) {
        if (keyCode >= KeyEvent.KEYCODE_0 && keyCode <= KeyEvent.KEYCODE_9) {
            onDigit(keyCode - KeyEvent.KEYCODE_0);
            return true;
        }
        if (keyCode >= KeyEvent.KEYCODE_NUMPAD_0 && keyCode <= KeyEvent.KEYCODE_NUMPAD_9) {
            onDigit(keyCode - KeyEvent.KEYCODE_NUMPAD_0);
            return true;
        }
        if (keyCode == KeyEvent.KEYCODE_DEL) {
            onDelete();
            return true;
        }
        if (keyCode == KeyEvent.KEYCODE_BACK && mode.equals(MODE_UNLOCK)) {
            // Back mustn't get past the lock; it deletes a digit instead
            onDelete();
            return true;
        }
        return super.onKeyDown(keyCode, event);
    }

    private void updateDots() {
        for (int i = 0; i < PIN_LENGTH; i++) {
            dots[i].setText(i < entered.length() ? "●" : "○");
        }
    }

    private void buildLayout() {
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setGravity(Gravity.CENTER);
        GradientDrawable background = new GradientDrawable(GradientDrawable.Orientation.TL_BR,
                new int[]{0xFF0B1026, 0xFF1B2450, 0xFF3A1F5C});
        root.setBackground(background);

        titleView = new TextView(this);
        titleView.setTextColor(Color.WHITE);
        titleView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 30);
        titleView.setTypeface(Typeface.DEFAULT_BOLD);
        titleView.setGravity(Gravity.CENTER);
        root.addView(titleView);

        LinearLayout dotRow = new LinearLayout(this);
        dotRow.setGravity(Gravity.CENTER);
        dotRow.setPadding(0, dp(20), 0, dp(8));
        for (int i = 0; i < PIN_LENGTH; i++) {
            TextView dot = new TextView(this);
            dot.setTextColor(Color.WHITE);
            dot.setTextSize(TypedValue.COMPLEX_UNIT_SP, 34);
            dot.setPadding(dp(12), 0, dp(12), 0);
            dots[i] = dot;
            dotRow.addView(dot);
        }
        root.addView(dotRow);

        messageView = new TextView(this);
        messageView.setTextColor(0xFFFF8A80);
        messageView.setTextSize(TypedValue.COMPLEX_UNIT_SP, 18);
        messageView.setGravity(Gravity.CENTER);
        messageView.setPadding(0, 0, 0, dp(16));
        root.addView(messageView);

        GridLayout keypad = new GridLayout(this);
        keypad.setColumnCount(3);
        String[] labels = {"1", "2", "3", "4", "5", "6", "7", "8", "9", "", "0", "⌫"};
        View five = null;
        for (String label : labels) {
            View key = label.isEmpty() ? new View(this) : buildKey(label);
            GridLayout.LayoutParams params = new GridLayout.LayoutParams();
            params.width = dp(84);
            params.height = dp(64);
            params.setMargins(dp(6), dp(6), dp(6), dp(6));
            keypad.addView(key, params);
            if (label.equals("5")) {
                five = key;
            }
        }
        // Wrap the keypad's width so it sits in the middle instead of stretching across the screen
        LinearLayout.LayoutParams keypadParams = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        keypadParams.gravity = Gravity.CENTER_HORIZONTAL;
        root.addView(keypad, keypadParams);

        TextView hint = new TextView(this);
        hint.setText("Use the number keys on the remote, or the keypad");
        hint.setTextColor(0x99FFFFFF);
        hint.setTextSize(TypedValue.COMPLEX_UNIT_SP, 15);
        hint.setGravity(Gravity.CENTER);
        hint.setPadding(0, dp(16), 0, 0);
        root.addView(hint);

        setContentView(root);
        if (five != null) {
            five.requestFocus();
        }
    }

    private View buildKey(String label) {
        TextView key = new TextView(this);
        key.setText(label);
        key.setTextColor(Color.WHITE);
        key.setTextSize(TypedValue.COMPLEX_UNIT_SP, 26);
        key.setGravity(Gravity.CENTER);
        key.setFocusable(true);
        key.setClickable(true);

        GradientDrawable normal = new GradientDrawable();
        normal.setColor(0x22FFFFFF);
        normal.setCornerRadius(dp(14));
        GradientDrawable focused = new GradientDrawable();
        focused.setColor(0x66FFFFFF);
        focused.setCornerRadius(dp(14));
        StateListDrawable states = new StateListDrawable();
        states.addState(new int[]{android.R.attr.state_focused}, focused);
        states.addState(new int[]{android.R.attr.state_pressed}, focused);
        states.addState(new int[]{}, normal);
        key.setBackground(states);

        key.setOnClickListener(v -> {
            if (label.equals("⌫")) {
                onDelete();
            } else {
                onDigit(Integer.parseInt(label));
            }
        });
        return key;
    }

    private int dp(int value) {
        return Math.round(TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, value, getResources().getDisplayMetrics()));
    }
}
