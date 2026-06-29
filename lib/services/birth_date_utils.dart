/// Birth date formatting and bounds for sign-up pickers.
class BirthDateUtils {
  static const int maxAgeYears = 120;

  static int get minYear => DateTime.now().year - maxAgeYears;

  static int get maxYear => DateTime.now().year;

  static DateTime get latestAllowedDate {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  static String formatDisplay(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day-$month-${date.year}';
  }

  static bool isValidBirthDate(DateTime date) {
    if (date.year < minYear || date.year > maxYear) return false;
    final latest = latestAllowedDate;
    return !date.isAfter(latest);
  }

  static int daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  static List<int> allowedMonths(int year) {
    final latest = latestAllowedDate;
    if (year < latest.year) {
      return List.generate(12, (i) => i + 1);
    }
    return List.generate(latest.month, (i) => i + 1);
  }

  static List<int> allowedDays(int year, int month) {
    final maxDay = daysInMonth(year, month);
    final latest = latestAllowedDate;
    if (year < latest.year || month < latest.month) {
      return List.generate(maxDay, (i) => i + 1);
    }
    return List.generate(latest.day, (i) => i + 1);
  }
}
