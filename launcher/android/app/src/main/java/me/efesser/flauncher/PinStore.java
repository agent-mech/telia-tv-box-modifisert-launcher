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
import android.content.SharedPreferences;
import android.util.Base64;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;

/**
 * Stores the passcode as a salted SHA-256 hash, never the digits themselves.
 * Also holds whether the TV is currently locked (in memory, so a process restart locks it again).
 */
final class PinStore {
    private static final String PREFERENCES_NAME = "volt_passcode";
    private static final String HASH_KEY = "hash";
    private static final String SALT_KEY = "salt";

    private static boolean unlocked = false;

    private PinStore() {}

    static boolean isSet(Context context) {
        return preferences(context).contains(HASH_KEY);
    }

    static boolean isLocked(Context context) {
        return isSet(context) && !unlocked;
    }

    static void lock() {
        unlocked = false;
    }

    static void unlock() {
        unlocked = true;
    }

    static boolean check(Context context, String pin) {
        SharedPreferences preferences = preferences(context);
        String salt = preferences.getString(SALT_KEY, null);
        String hash = preferences.getString(HASH_KEY, null);
        return salt != null && hash != null && MessageDigest.isEqual(hash.getBytes(), hash(salt, pin).getBytes());
    }

    static void set(Context context, String pin) {
        byte[] saltBytes = new byte[16];
        new SecureRandom().nextBytes(saltBytes);
        String salt = Base64.encodeToString(saltBytes, Base64.NO_WRAP);

        preferences(context).edit()
                .putString(SALT_KEY, salt)
                .putString(HASH_KEY, hash(salt, pin))
                .apply();
        unlocked = true;
    }

    static void clear(Context context) {
        preferences(context).edit().clear().apply();
        unlocked = false;
    }

    private static SharedPreferences preferences(Context context) {
        return context.getApplicationContext().getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE);
    }

    private static String hash(String salt, String pin) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] bytes = digest.digest((salt + ":" + pin).getBytes(StandardCharsets.UTF_8));
            return Base64.encodeToString(bytes, Base64.NO_WRAP);
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }
}
