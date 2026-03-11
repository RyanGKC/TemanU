class WeightReading {
  final DateTime time;
  final double weight;
  WeightReading(this.time, this.weight);
}

class MockWeightData {
  static List<WeightReading> allReadings = [
    // ==========================================
    // TODAY & YESTERDAY (High density)
    // ==========================================
    WeightReading(DateTime.now().copyWith(hour: 7), 81.0), // Morning
    WeightReading(DateTime.now().copyWith(hour: 20), 80.5), // Evening
    WeightReading(DateTime.now().subtract(const Duration(days: 1)).copyWith(hour: 7), 81.2),
    WeightReading(DateTime.now().subtract(const Duration(days: 1)).copyWith(hour: 19), 80.9),

    // ==========================================
    // PAST WEEK (Daily readings with natural fluctuations)
    // ==========================================
    WeightReading(DateTime.now().subtract(const Duration(days: 2)).copyWith(hour: 8), 81.5),
    WeightReading(DateTime.now().subtract(const Duration(days: 3)).copyWith(hour: 7), 81.1),
    WeightReading(DateTime.now().subtract(const Duration(days: 4)).copyWith(hour: 8), 81.8),
    WeightReading(DateTime.now().subtract(const Duration(days: 5)).copyWith(hour: 7), 81.4),
    WeightReading(DateTime.now().subtract(const Duration(days: 6)).copyWith(hour: 8), 82.0),

    // ==========================================
    // PAST MONTH (Readings every few days)
    // ==========================================
    WeightReading(DateTime.now().subtract(const Duration(days: 8)), 81.9),
    WeightReading(DateTime.now().subtract(const Duration(days: 10)), 82.3),
    WeightReading(DateTime.now().subtract(const Duration(days: 12)), 82.1), // Slight drop
    WeightReading(DateTime.now().subtract(const Duration(days: 15)), 82.5),
    WeightReading(DateTime.now().subtract(const Duration(days: 18)), 82.8),
    WeightReading(DateTime.now().subtract(const Duration(days: 20)), 82.6), // Slight drop
    WeightReading(DateTime.now().subtract(const Duration(days: 24)), 83.1),
    WeightReading(DateTime.now().subtract(const Duration(days: 26)), 83.0),
    WeightReading(DateTime.now().subtract(const Duration(days: 28)), 83.5),

    // ==========================================
    // PAST 3 MONTHS (Weekly checkpoints)
    // ==========================================
    WeightReading(DateTime.now().subtract(const Duration(days: 35)), 83.2),
    WeightReading(DateTime.now().subtract(const Duration(days: 40)), 83.8),
    WeightReading(DateTime.now().subtract(const Duration(days: 47)), 84.0),
    WeightReading(DateTime.now().subtract(const Duration(days: 55)), 84.6),
    WeightReading(DateTime.now().subtract(const Duration(days: 62)), 84.2), // Good week!
    WeightReading(DateTime.now().subtract(const Duration(days: 70)), 85.0),
    WeightReading(DateTime.now().subtract(const Duration(days: 77)), 85.2),
    WeightReading(DateTime.now().subtract(const Duration(days: 85)), 85.8),

    // ==========================================
    // PAST 6 MONTHS (Bi-weekly checkpoints)
    // ==========================================
    WeightReading(DateTime.now().subtract(const Duration(days: 95)), 85.6),
    WeightReading(DateTime.now().subtract(const Duration(days: 110)), 86.5),
    WeightReading(DateTime.now().subtract(const Duration(days: 125)), 86.3),
    WeightReading(DateTime.now().subtract(const Duration(days: 140)), 87.2),
    WeightReading(DateTime.now().subtract(const Duration(days: 155)), 87.0),
    WeightReading(DateTime.now().subtract(const Duration(days: 170)), 87.6),

    // ==========================================
    // PAST YEAR (Monthly checkpoints showing the start of the journey)
    // ==========================================
    WeightReading(DateTime.now().subtract(const Duration(days: 190)), 87.5),
    WeightReading(DateTime.now().subtract(const Duration(days: 220)), 88.0),
    WeightReading(DateTime.now().subtract(const Duration(days: 250)), 88.3),
    WeightReading(DateTime.now().subtract(const Duration(days: 280)), 88.4),
    WeightReading(DateTime.now().subtract(const Duration(days: 310)), 88.8),
    WeightReading(DateTime.now().subtract(const Duration(days: 340)), 88.7),
    WeightReading(DateTime.now().subtract(const Duration(days: 360)), 89.2), // Starting weight!
  ];
}