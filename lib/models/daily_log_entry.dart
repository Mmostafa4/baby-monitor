class DailyLogEntry {
  final DateTime date;
  final int? cryingHours;
  final int? feedingCount;
  final int? wetDiapers;
  final int? sleepHours;
  final double? temperatureCelsius;
  final String notes;

  const DailyLogEntry({
    required this.date,
    this.cryingHours,
    this.feedingCount,
    this.wetDiapers,
    this.sleepHours,
    this.temperatureCelsius,
    this.notes = '',
  });

  String get dateKey => keyFor(date);

  static String keyFor(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Map<String, Object?> toJson() => {
        'date': keyFor(date),
        'cryingHours': cryingHours,
        'feedingCount': feedingCount,
        'wetDiapers': wetDiapers,
        'sleepHours': sleepHours,
        'temperatureCelsius': temperatureCelsius,
        'notes': notes,
      };

  factory DailyLogEntry.fromJson(Object? value) {
    if (value is! Map) {
      throw const FormatException('Invalid daily log entry.');
    }

    final rawDate = value['date'];
    if (rawDate is! String) {
      throw const FormatException('Invalid daily log date.');
    }
    final parsedDate = DateTime.tryParse(rawDate);
    if (parsedDate == null) {
      throw const FormatException('Invalid daily log date.');
    }

    int? readInt(Object? raw) {
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      return null;
    }

    final rawTemperature = value['temperatureCelsius'];
    final rawNotes = value['notes'];
    return DailyLogEntry(
      date: DateTime(parsedDate.year, parsedDate.month, parsedDate.day),
      cryingHours: readInt(value['cryingHours']),
      feedingCount: readInt(value['feedingCount']),
      wetDiapers: readInt(value['wetDiapers']),
      sleepHours: readInt(value['sleepHours']),
      temperatureCelsius:
          rawTemperature is num ? rawTemperature.toDouble() : null,
      notes: rawNotes is String ? rawNotes : '',
    );
  }
}
