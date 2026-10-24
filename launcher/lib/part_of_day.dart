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

/// Part of the day, shared by the greeting and the time-of-day wallpaper so they switch together.
enum PartOfDay {
  morning("Good morning", "assets/wallpapers/fjord_morning.jpg"),
  afternoon("Good afternoon", "assets/wallpapers/fjord_day.jpg"),
  evening("Good evening", "assets/wallpapers/fjord_evening.jpg"),
  night("Good night", "assets/wallpapers/fjord_night.jpg");

  final String greeting;
  final String wallpaperAsset;

  const PartOfDay(this.greeting, this.wallpaperAsset);

  static PartOfDay of(DateTime time) {
    final hour = time.hour;
    if (hour >= 5 && hour < 12) {
      return morning;
    }
    if (hour >= 12 && hour < 17) {
      return afternoon;
    }
    if (hour >= 17 && hour < 22) {
      return evening;
    }
    return night;
  }
}
