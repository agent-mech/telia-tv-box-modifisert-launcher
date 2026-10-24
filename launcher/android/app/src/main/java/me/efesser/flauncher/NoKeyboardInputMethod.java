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

import android.inputmethodservice.InputMethodService;
import android.view.View;

/**
 * Keyboard that never appears on screen. Used in desktop mode so only the physical keyboard is
 * used: key presses aren't consumed here, so they reach apps exactly as typed.
 */
public class NoKeyboardInputMethod extends InputMethodService {
    @Override
    public boolean onEvaluateInputViewShown() {
        return false;
    }

    @Override
    public boolean onEvaluateFullscreenMode() {
        return false;
    }

    @Override
    public boolean onShowInputRequested(int flags, boolean configChange) {
        return false;
    }

    @Override
    public View onCreateInputView() {
        return new View(this);
    }
}
