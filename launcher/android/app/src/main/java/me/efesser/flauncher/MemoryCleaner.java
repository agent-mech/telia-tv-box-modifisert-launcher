package me.efesser.flauncher;

import android.app.ActivityManager;
import android.app.Activity;
import android.content.Context;
import android.content.pm.ApplicationInfo;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.widget.Toast;

import java.util.Collections;
import java.util.Set;

/**
 * "Free up RAM": stops the cached background processes of every app.
 * Android never lets this stop the app in front, music playing in the background or the keyboard.
 */
public final class MemoryCleaner {
    private static final long MB = 1024 * 1024;

    // Heavy apps that don't declare themselves as games
    private static final Set<String> HEAVY_APPS = Collections.singleton("com.roblox.client");

    private MemoryCleaner() { }

    /** Cleans on a background thread, then shows how much was freed. */
    public static void clean(Context context) {
        clean(context, null);
    }

    /** Games and other heavy apps get memory freed for them as they launch. */
    public static boolean isHeavy(Context context, String packageName) {
        if (HEAVY_APPS.contains(packageName)) {
            return true;
        }
        try {
            ApplicationInfo info = context.getPackageManager().getApplicationInfo(packageName, 0);
            return info.category == ApplicationInfo.CATEGORY_GAME || (info.flags & ApplicationInfo.FLAG_IS_GAME) != 0;
        } catch (Exception e) {
            return false;
        }
    }

    /** Like {@link #clean(Context)}, but leaves [keep] running, e.g. the app being launched. */
    public static void clean(Context context, String keep) {
        Context app = context.getApplicationContext();
        ActivityManager activityManager = (ActivityManager) app.getSystemService(Context.ACTIVITY_SERVICE);

        new Thread(() -> {
            long before = availableMemory(activityManager);
            for (ApplicationInfo info : app.getPackageManager().getInstalledApplications(0)) {
                if (!info.packageName.equals(app.getPackageName()) && !info.packageName.equals(keep)) {
                    activityManager.killBackgroundProcesses(info.packageName);
                }
            }

            // Memory is returned to the system shortly after the processes die
            try {
                Thread.sleep(1000);
            } catch (InterruptedException ignored) { }
            long after = availableMemory(activityManager);

            long freed = Math.max(0, after - before) / MB;
            new Handler(Looper.getMainLooper()).post(() -> Toast.makeText(app,
                    "Freed " + freed + " MB · " + after / MB + " MB free", Toast.LENGTH_SHORT).show());
        }, "MemoryCleaner").start();
    }

    private static long availableMemory(ActivityManager activityManager) {
        ActivityManager.MemoryInfo memoryInfo = new ActivityManager.MemoryInfo();
        activityManager.getMemoryInfo(memoryInfo);
        return memoryInfo.availMem;
    }

    /** Invisible activity behind the "action:free_ram" quick menu item and remote button action. */
    public static class Action extends Activity {
        @Override
        protected void onCreate(Bundle savedInstanceState) {
            super.onCreate(savedInstanceState);
            clean(this);
            finish();
        }
    }
}
