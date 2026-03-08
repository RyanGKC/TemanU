import 'bloodpressure.dart';

class MockBpData {
  // A single master list of raw, real-world readings. 
  // The app will dynamically group these into hours, days, or months automatically!
  static List<BpReading> allReadings = [
    // ==========================================
    // TODAY
    // ==========================================
    BpReading(DateTime.now().copyWith(hour: 7, minute: 0), 118, 76),
    // Test: Two readings in the same hour block (3:15 PM and 3:45 PM). 
    BpReading(DateTime.now().copyWith(hour: 15, minute: 15), 120, 70),
    BpReading(DateTime.now().copyWith(hour: 15, minute: 45), 130, 80),
    BpReading(DateTime.now().copyWith(hour: 22, minute: 15), 119, 77),

    // ==========================================
    // PAST WEEK (Days 1 - 6)
    // ==========================================
    BpReading(DateTime.now().subtract(const Duration(days: 1)).copyWith(hour: 6), 119, 77),
    BpReading(DateTime.now().subtract(const Duration(days: 1)).copyWith(hour: 20), 125, 82), // 2nd reading yesterday
    BpReading(DateTime.now().subtract(const Duration(days: 2)).copyWith(hour: 8), 117, 76),
    BpReading(DateTime.now().subtract(const Duration(days: 3)).copyWith(hour: 8), 118, 77),
    BpReading(DateTime.now().subtract(const Duration(days: 5)).copyWith(hour: 9), 121, 79),
    BpReading(DateTime.now().subtract(const Duration(days: 6)).copyWith(hour: 7), 120, 78),

    // ==========================================
    // PAST MONTH (Days 7 - 30)
    // ==========================================
    BpReading(DateTime.now().subtract(const Duration(days: 10)), 122, 80),
    BpReading(DateTime.now().subtract(const Duration(days: 12)), 124, 81),
    BpReading(DateTime.now().subtract(const Duration(days: 15)), 122, 80),
    // Multiple readings on Day 18 to show a daily candlestick on the Month view
    BpReading(DateTime.now().subtract(const Duration(days: 18)).copyWith(hour: 8), 119, 78),
    BpReading(DateTime.now().subtract(const Duration(days: 18)).copyWith(hour: 19), 128, 83),
    BpReading(DateTime.now().subtract(const Duration(days: 22)), 120, 77),
    BpReading(DateTime.now().subtract(const Duration(days: 25)), 123, 80),
    BpReading(DateTime.now().subtract(const Duration(days: 28)), 125, 82),

    // ==========================================
    // PAST 3 MONTHS (Days 31 - 90)
    // ==========================================
    BpReading(DateTime.now().subtract(const Duration(days: 35)), 126, 82),
    BpReading(DateTime.now().subtract(const Duration(days: 40)), 126, 83),
    BpReading(DateTime.now().subtract(const Duration(days: 45)), 130, 85),
    BpReading(DateTime.now().subtract(const Duration(days: 52)), 128, 84),
    // High variance month
    BpReading(DateTime.now().subtract(const Duration(days: 60)).copyWith(hour: 9), 135, 88),
    BpReading(DateTime.now().subtract(const Duration(days: 60)).copyWith(hour: 20), 122, 80),
    BpReading(DateTime.now().subtract(const Duration(days: 75)), 129, 83),
    BpReading(DateTime.now().subtract(const Duration(days: 85)), 131, 85),

    // ==========================================
    // PAST 6 MONTHS (Days 91 - 180)
    // ==========================================
    BpReading(DateTime.now().subtract(const Duration(days: 100)), 135, 88),
    BpReading(DateTime.now().subtract(const Duration(days: 110)), 132, 85),
    BpReading(DateTime.now().subtract(const Duration(days: 125)), 136, 89),
    BpReading(DateTime.now().subtract(const Duration(days: 140)), 138, 90),
    BpReading(DateTime.now().subtract(const Duration(days: 155)), 134, 87),
    // Wide variance in this month
    BpReading(DateTime.now().subtract(const Duration(days: 170)).copyWith(hour: 8), 142, 93),
    BpReading(DateTime.now().subtract(const Duration(days: 172)).copyWith(hour: 18), 128, 84),

    // ==========================================
    // PAST YEAR (Days 181 - 365)
    // ==========================================
    BpReading(DateTime.now().subtract(const Duration(days: 200)), 140, 92),
    BpReading(DateTime.now().subtract(const Duration(days: 215)), 139, 91),
    BpReading(DateTime.now().subtract(const Duration(days: 235)), 145, 95), // Highest peak
    BpReading(DateTime.now().subtract(const Duration(days: 260)), 141, 93),
    BpReading(DateTime.now().subtract(const Duration(days: 290)), 138, 90),
    BpReading(DateTime.now().subtract(const Duration(days: 315)), 135, 88),
    BpReading(DateTime.now().subtract(const Duration(days: 340)), 132, 86),
    BpReading(DateTime.now().subtract(const Duration(days: 360)), 130, 85), // Start of the journey!
  ];
}