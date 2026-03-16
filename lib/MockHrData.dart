import 'package:temanu/heartrate.dart';

class MockHrData {
  static List<HrReading> allReadings = [
    // ==========================================
    // TODAY
    // ==========================================
    HrReading(DateTime.now().copyWith(hour: 6,  minute: 30), 62),
    HrReading(DateTime.now().copyWith(hour: 8,  minute: 0),  78),
    HrReading(DateTime.now().copyWith(hour: 9,  minute: 15), 85),
    HrReading(DateTime.now().copyWith(hour: 11, minute: 0),  72),
    HrReading(DateTime.now().copyWith(hour: 13, minute: 30), 88),
    HrReading(DateTime.now().copyWith(hour: 15, minute: 0),  76),
    HrReading(DateTime.now().copyWith(hour: 17, minute: 45), 95),
    HrReading(DateTime.now().copyWith(hour: 19, minute: 0),  80),
    HrReading(DateTime.now().copyWith(hour: 21, minute: 30), 68),
    HrReading(DateTime.now().copyWith(hour: 23, minute: 0),  64),

    // ==========================================
    // PAST WEEK (Days 1 – 6)
    // ==========================================
    HrReading(DateTime.now().subtract(const Duration(days: 1)).copyWith(hour: 7),  65),
    HrReading(DateTime.now().subtract(const Duration(days: 1)).copyWith(hour: 12), 82),
    HrReading(DateTime.now().subtract(const Duration(days: 1)).copyWith(hour: 18), 90),
    HrReading(DateTime.now().subtract(const Duration(days: 1)).copyWith(hour: 22), 66),

    HrReading(DateTime.now().subtract(const Duration(days: 2)).copyWith(hour: 8),  70),
    HrReading(DateTime.now().subtract(const Duration(days: 2)).copyWith(hour: 14), 88),
    HrReading(DateTime.now().subtract(const Duration(days: 2)).copyWith(hour: 20), 74),

    HrReading(DateTime.now().subtract(const Duration(days: 3)).copyWith(hour: 7),  63),
    HrReading(DateTime.now().subtract(const Duration(days: 3)).copyWith(hour: 10), 79),
    HrReading(DateTime.now().subtract(const Duration(days: 3)).copyWith(hour: 16), 92),
    HrReading(DateTime.now().subtract(const Duration(days: 3)).copyWith(hour: 21), 67),

    HrReading(DateTime.now().subtract(const Duration(days: 4)).copyWith(hour: 9),  75),
    HrReading(DateTime.now().subtract(const Duration(days: 4)).copyWith(hour: 15), 83),

    HrReading(DateTime.now().subtract(const Duration(days: 5)).copyWith(hour: 8),  68),
    HrReading(DateTime.now().subtract(const Duration(days: 5)).copyWith(hour: 17), 96),
    HrReading(DateTime.now().subtract(const Duration(days: 5)).copyWith(hour: 22), 65),

    HrReading(DateTime.now().subtract(const Duration(days: 6)).copyWith(hour: 7),  71),
    HrReading(DateTime.now().subtract(const Duration(days: 6)).copyWith(hour: 13), 85),
    HrReading(DateTime.now().subtract(const Duration(days: 6)).copyWith(hour: 19), 78),

    // ==========================================
    // PAST MONTH (Days 7 – 30)
    // ==========================================
    HrReading(DateTime.now().subtract(const Duration(days: 8)),  74),
    HrReading(DateTime.now().subtract(const Duration(days: 10)), 80),
    HrReading(DateTime.now().subtract(const Duration(days: 12)), 77),
    HrReading(DateTime.now().subtract(const Duration(days: 14)), 72),
    // Wide variance day
    HrReading(DateTime.now().subtract(const Duration(days: 16)).copyWith(hour: 7),  60),
    HrReading(DateTime.now().subtract(const Duration(days: 16)).copyWith(hour: 18), 102),
    HrReading(DateTime.now().subtract(const Duration(days: 18)), 79),
    HrReading(DateTime.now().subtract(const Duration(days: 20)), 83),
    HrReading(DateTime.now().subtract(const Duration(days: 22)), 76),
    HrReading(DateTime.now().subtract(const Duration(days: 25)), 81),
    HrReading(DateTime.now().subtract(const Duration(days: 28)), 78),

    // ==========================================
    // PAST 3 MONTHS (Days 31 – 90)
    // ==========================================
    HrReading(DateTime.now().subtract(const Duration(days: 35)), 82),
    HrReading(DateTime.now().subtract(const Duration(days: 40)), 85),
    HrReading(DateTime.now().subtract(const Duration(days: 45)), 80),
    HrReading(DateTime.now().subtract(const Duration(days: 50)), 88),
    // High variance week
    HrReading(DateTime.now().subtract(const Duration(days: 55)).copyWith(hour: 8),  65),
    HrReading(DateTime.now().subtract(const Duration(days: 55)).copyWith(hour: 20), 108),
    HrReading(DateTime.now().subtract(const Duration(days: 60)), 84),
    HrReading(DateTime.now().subtract(const Duration(days: 70)), 87),
    HrReading(DateTime.now().subtract(const Duration(days: 80)), 83),
    HrReading(DateTime.now().subtract(const Duration(days: 88)), 86),

    // ==========================================
    // PAST 6 MONTHS (Days 91 – 180)
    // ==========================================
    HrReading(DateTime.now().subtract(const Duration(days: 100)), 90),
    HrReading(DateTime.now().subtract(const Duration(days: 110)), 88),
    HrReading(DateTime.now().subtract(const Duration(days: 120)), 92),
    HrReading(DateTime.now().subtract(const Duration(days: 135)), 95),
    HrReading(DateTime.now().subtract(const Duration(days: 150)), 89),
    // Wide variance month
    HrReading(DateTime.now().subtract(const Duration(days: 165)).copyWith(hour: 8),  72),
    HrReading(DateTime.now().subtract(const Duration(days: 165)).copyWith(hour: 20), 112),
    HrReading(DateTime.now().subtract(const Duration(days: 175)), 91),

    // ==========================================
    // PAST YEAR (Days 181 – 365)
    // ==========================================
    HrReading(DateTime.now().subtract(const Duration(days: 200)), 95),
    HrReading(DateTime.now().subtract(const Duration(days: 220)), 98),
    HrReading(DateTime.now().subtract(const Duration(days: 240)), 102), // Peak
    HrReading(DateTime.now().subtract(const Duration(days: 265)), 99),
    HrReading(DateTime.now().subtract(const Duration(days: 290)), 96),
    HrReading(DateTime.now().subtract(const Duration(days: 315)), 93),
    HrReading(DateTime.now().subtract(const Duration(days: 340)), 89),
    HrReading(DateTime.now().subtract(const Duration(days: 360)), 86), // Start of the journey
  ];
}