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

import android.content.Context;
import android.hardware.input.InputManager;
import android.os.Handler;
import android.os.Looper;
import android.view.InputDevice;

import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

import io.flutter.plugin.common.EventChannel;

/**
 * Tells Flutter whether a mouse and a real typing keyboard are connected, so the launcher can
 * switch to its desktop layout. TV remotes report a non-alphabetic keyboard and don't count; nor
 * does the fake keyboard interface many gaming mice expose (same vendor/product as the mouse).
 */
public class InputDevicesStreamHandler implements EventChannel.StreamHandler, InputManager.InputDeviceListener {
    private final InputManager inputManager;
    private final Handler handler = new Handler(Looper.getMainLooper());
    private EventChannel.EventSink eventSink;

    public InputDevicesStreamHandler(Context context) {
        inputManager = (InputManager) context.getSystemService(Context.INPUT_SERVICE);
    }

    @Override
    public void onListen(Object arguments, EventChannel.EventSink events) {
        eventSink = events;
        inputManager.registerInputDeviceListener(this, handler);
        sendState();
    }

    @Override
    public void onCancel(Object arguments) {
        inputManager.unregisterInputDeviceListener(this);
        eventSink = null;
    }

    @Override
    public void onInputDeviceAdded(int deviceId) {
        sendState();
    }

    @Override
    public void onInputDeviceRemoved(int deviceId) {
        sendState();
    }

    @Override
    public void onInputDeviceChanged(int deviceId) {
        sendState();
    }

    private void sendState() {
        if (eventSink == null) {
            return;
        }

        Set<Long> mouseHardware = new HashSet<>();
        boolean mouse = false;
        for (int id : inputManager.getInputDeviceIds()) {
            InputDevice device = inputManager.getInputDevice(id);
            if (device != null && !device.isVirtual() && device.supportsSource(InputDevice.SOURCE_MOUSE)) {
                mouse = true;
                mouseHardware.add(hardwareId(device));
            }
        }

        boolean keyboard = false;
        for (int id : inputManager.getInputDeviceIds()) {
            InputDevice device = inputManager.getInputDevice(id);
            if (device != null && !device.isVirtual()
                    && device.getKeyboardType() == InputDevice.KEYBOARD_TYPE_ALPHABETIC
                    && !mouseHardware.contains(hardwareId(device))) {
                keyboard = true;
            }
        }

        Map<String, Object> state = new HashMap<>();
        state.put("mouse", mouse);
        state.put("keyboard", keyboard);
        eventSink.success(state);
    }

    private static long hardwareId(InputDevice device) {
        return ((long) device.getVendorId() << 32) | device.getProductId();
    }
}
