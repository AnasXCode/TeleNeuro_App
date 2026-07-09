/// Birth date formatting and bounds for sign-up pickers.
class BirthDateUtils {
  static const int maxAgeYears = 120;
  static const int minAgeYears = 18;

  static int get minYear => DateTime.now().year - maxAgeYears;

  static int get maxYear => latestSelectableBirthDate.year;

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static DateTime get _today => _dateOnly(DateTime.now());

  /// Latest birth date that satisfies minimum age and is strictly before today.
  static DateTime get latestSelectableBirthDate {
    var candidate = DateTime(
      _today.year - minAgeYears,
      _today.month,
      _today.day,
    );

    while (!_isStrictlyBeforeToday(candidate) ||
        calculateAge(candidate) < minAgeYears) {
      candidate = candidate.subtract(const Duration(days: 1));
    }

    return candidate;
  }

  static bool _isStrictlyBeforeToday(DateTime date) {
    return _dateOnly(date).isBefore(_today);
  }

  static int calculateAge(DateTime birthDate) {
    final today = _today;
    final birth = _dateOnly(birthDate);
    var age = today.year - birth.year;

    if (today.month < birth.month ||
        (today.month == birth.month && today.day < birth.day)) {
      age--;
    }

    return age;
  }

  static String formatDisplay(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day-$month-${date.year}';
  }

  static bool isValidBirthDate(DateTime date) {
    return validateForSignup(date) == null;
  }

  /// Returns an error message when invalid, or null when valid.
  static String? validateForSignup(DateTime? date) {
    if (date == null) {
      return 'Please select a valid Date of Birth.';
    }

    if (date.year < minYear) {
      return 'Please select a valid Date of Birth.';
    }

    if (!_isStrictlyBeforeToday(date)) {
      return 'Date of Birth must be in the past.';
    }

    if (calculateAge(date) < minAgeYears) {
      return 'You must be at least 18 years old to create an account.';
    }

    return null;
  }

  static int daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  static List<int> allowedMonths(int year) {
    final latest = latestSelectableBirthDate;
    if (year < latest.year) {
      return List.generate(12, (i) => i + 1);
    }
    if (year > latest.year) {
      return [];
    }
    return List.generate(latest.month, (i) => i + 1);
  }

  static List<int> allowedDays(int year, int month) {
    final maxDay = daysInMonth(year, month);
    final latest = latestSelectableBirthDate;
    if (year < latest.year || month < latest.month) {
      return List.generate(maxDay, (i) => i + 1);
    }
    if (year > latest.year || month > latest.month) {
      return [];
    }
    return List.generate(latest.day, (i) => i + 1);
  }
}
