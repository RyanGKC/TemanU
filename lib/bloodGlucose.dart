import 'dart:ui';
import 'package:flutter/material.dart';
import 'assistantpage.dart';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';

class BloodGlucose extends StatefulWidget {
  const BloodGlucose({super.key});

  @override
  State<BloodGlucose> createState() => _BloodGlucoseState();
}

class _BloodGlucoseState extends State<BloodGlucose> {
  // dummy values
  //////////////////////////////////////////////////

  double currentBGlevel = 110;
  double average = 190;
  double fluctuation = 120;

  double high = 180;
  double low = 70;
  double veryHigh = 250;
  double veryLow = 54;
  double highFluncuation = 80;
  double veryHighFlunctuation = 120;

  List<String> dailyLabels = ['12AM', '4AM', '8AM', '12PM', '4PM', '8PM', '12AM'];
  List<double> dailyValues = [50, 60, 140, 200, 270, 400, 180];

  List<String> weeklyLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thur', 'Fri', 'Sat'];
  List<double> weeklyHighs = [168, 142, 175, 169, 180, 183, 190];
  List<double> weeklyLows = [60, 70, 90, 60, 67, 57, 79];

  List<String> monthlyLabels = ['1/3', '2/3', '3/3', '4/3', '5/3', '6/3', '7/3', '8/3', '9/3', '10/3',
                                '11/3', '12/3', '13/3', '14/3', '15/3', '16/3', '17/3', '18/3', '19/3', '20/3',
                                '21/3', '22/3', '23/3', '24/3', '25/3', '26/3', '27/3', '28/3', '29/3', '30/3',
                                '31/3'];
  List<double> monthlyHighs = [145, 132, 156, 123, 178, 130, 182, 156, 136, 109,
                                194, 134, 120, 125, 148, 199, 128, 162, 139, 128,
                                150, 160, 132, 193, 149, 198, 195, 189, 122, 198,
                                189];
  List<double> monthlyLows = [58, 62, 76, 83, 48, 80, 42, 76, 46, 79,
                                94, 34, 60, 45, 78, 59, 98, 82, 93, 86,
                                80, 30, 75, 33, 79, 48, 95, 89, 92, 38,
                                69];

  List<String> sixMonthLabels = ['Oct', 'Nov', 'Dec', 'Jan', 'Feb', 'Mar'];
  List<double> sixMonthHighs = [190, 150, 123, 196, 389, 294];
  List<double> sixMonthLows = [60, 89, 33, 56, 89, 124];

  List<String> yearlyLabels = ['Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Jan', 'Feb', 'Mar'];
  List<double> yearlyHighs = [238, 193, 209, 193, 259, 158, 140, 150, 200, 196, 189, 193];
  List<double> yearlyLows = [123, 110, 102, 89, 134, 80, 99, 71, 89, 49, 89, 93];

  //////////////////////////////////////////////////

  int _selected = 0;

  List<String> getLabelsList(int selected) {
     switch (selected) {
      case 0:
        return dailyLabels;
      case 1:
        return weeklyLabels;
      case 2:
        return monthlyLabels;
      case 3:
        return sixMonthLabels;
      case 4:
        return yearlyLabels;
      default:
        return [];
    }
  }

  List<double> getHighList(int selected) {
     switch (selected) {
      case 0:
        return dailyValues;
      case 1:
        return weeklyHighs;
      case 2:
        return monthlyHighs;
      case 3:
        return sixMonthHighs;
      case 4:
        return yearlyHighs;
      default:
        return [];
    }
  }

    List<double> getLowList(int selected) {
     switch (selected) {
      case 1:
        return weeklyLows;
      case 2:
        return monthlyLows;
      case 3:
        return sixMonthLows;
      case 4:
        return yearlyLows;
      default:
        return [];
    }
  }
  

  List<double> getBGLThresholds() {
    return [veryHigh, high, low, veryLow];
  }

  List<double> getFluctuationThresholds() {
    return [highFluncuation, veryHighFlunctuation];
  }

  Color getBGLColor(double value) {
    if (value > low && value < high) {
      return Colors.green;
    } else if (value > veryHigh || value < veryLow) {
      return Colors.red;
    } else {
      return const Color.fromARGB(255, 200, 200, 0);
    }
  }

  Color getFluctuationColor(double value) {
    if (value < highFluncuation) {
      return Colors.green;
    } else if (value < veryHighFlunctuation) {
      return const Color.fromARGB(255, 200, 200, 0);
    } else {
      return Colors.red;
    }
  }

  // helper function to setColorRange()
  Future<List<double>?> showMultiNumberDialog({
    required BuildContext context,
    required String title,
    required List<String> fieldLabels,
    bool allowDecimal = false,
  }) async {
    List<TextEditingController> controllers = List.generate(
      fieldLabels.length,
      (_) => TextEditingController(),
    );

    final formatter = allowDecimal
        ? FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
        : FilteringTextInputFormatter.digitsOnly;

    return showDialog<List<double>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(fieldLabels.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fieldLabels[index]),
                      TextField(
                        controller: controllers[index],
                        keyboardType: TextInputType.numberWithOptions(
                          decimal: allowDecimal,
                        ),
                        inputFormatters: [formatter],
                        decoration: InputDecoration(
                          hintText: (fieldLabels.length == 2)
                              ? getFluctuationThresholds()[index].toString()
                              : getBGLThresholds()[index].toString(),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                try {
                  List<double> values = [];
                  for (int i = 0; i < controllers.length; i++) {
                    if (controllers[i].text.isEmpty) {
                      values.add(
                        (controllers.length == 2)
                            ? getFluctuationThresholds()[i]
                            : getBGLThresholds()[i],
                      );
                    } else {
                      values.add(double.parse(controllers[i].text));
                    }
                  }
                  Navigator.pop(context, values);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Please enter valid numbers.")),
                  );
                }
              },
              child: Text("Submit"),
            ),
          ],
        );
      },
    );
  }

  // pop out a window that ask the user to set color range
  void setColorRange(int mode) async {
    List<double>? results = await showMultiNumberDialog(
      context: context,
      title: "Edit color Range",
      // mode = 0: set for blood glucose level (average or current)
      // mode = 1: set for flunctuation
      fieldLabels: mode == 0
          ? [
              'Very High Threshold',
              'High Threshold',
              'Low Threshold',
              'Very Low Threshold',
            ]
          : ['High Threshold', 'Very High Threshold'],
    );
    if (results != null) {
      if (mode == 0) {
        setState(() {
          veryHigh = results[0];
          high = results[1];
          low = results[2];
          veryLow = results[3];
        });
      } else {
        setState(() {
          highFluncuation = results[0];
          veryHighFlunctuation = results[1];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff040F31),
      extendBodyBehindAppBar: false,
      extendBody: true,

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Blood Glucose Level',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w600,
            color: Color(0xff00E5FF),
          ),
        ),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(color: Colors.white.withValues(alpha: 0.25)),
          ),
        ),
      ),

      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    children: [
                      // average blood glucose level
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            setColorRange(0);
                          },
                          child: Container(
                            width: 120,
                            height: 120,
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: getBGLColor(average),
                              border: Border.all(color: Colors.white, width: 5),
                            ),
                            child: Center(
                              child: Text.rich(
                                textAlign: TextAlign.center,
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: average.toInt().toString(),
                                      style: TextStyle(
                                        fontSize: 55,
                                        color: Colors.white,
                                        height: 1,
                                      ),
                                    ),
                                    TextSpan(
                                      text: '\nmg/dL',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 5),

                      Text(
                        'Daily\nAverage',
                        style: TextStyle(fontSize: 15, color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),

                  SizedBox(width: 30),

                  Column(
                    children: [
                      // current blood glucose level
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            setColorRange(0);
                          },
                          child: Container(
                            width: 150,
                            height: 150,
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: getBGLColor(currentBGlevel),
                              border: Border.all(color: Colors.white, width: 5),
                            ),
                            child: Center(
                              child: Text.rich(
                                textAlign: TextAlign.center,
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: currentBGlevel.toInt().toString(),
                                      style: TextStyle(
                                        fontSize: 80,
                                        color: Colors.white,
                                        height: 1,
                                      ),
                                    ),
                                    TextSpan(
                                      text: '\nmg/dL',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 5),

                      Text(
                        'Current',
                        style: TextStyle(fontSize: 15, color: Colors.white),
                      ),
                    ],
                  ),

                  SizedBox(width: 30),

                  Column(
                    children: [
                      // daily fluctuation
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            setColorRange(1);
                          },
                          child: Container(
                            width: 120,
                            height: 120,
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: getFluctuationColor(fluctuation),
                              border: Border.all(color: Colors.white, width: 5),
                            ),
                            child: Center(
                              child: Text.rich(
                                textAlign: TextAlign.center,
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: fluctuation.toInt().toString(),
                                      style: TextStyle(
                                        fontSize: 55,
                                        color: Colors.white,
                                        height: 1,
                                      ),
                                    ),
                                    TextSpan(
                                      text: '\nmg/dL',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 5),

                      Text(
                        'Daily\nFluctuation',
                        style: TextStyle(fontSize: 15, color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ],
              ),

              SizedBox(height: 30),

              // selection bar
              // copied from activity.dart
              Container(
                padding: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  color: Color.fromARGB(255, 99, 103, 113),
                ),

                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // day
                    Material(
                      borderRadius: BorderRadius.circular(20),
                      color: (_selected == 0
                          ? Color.fromARGB(255, 134, 144, 156)
                          : Colors.transparent),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          setState(() {
                            _selected = 0;
                          });
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: 5,
                            horizontal: 15,
                          ),
                          child: Text(
                            'Day',
                            style: TextStyle(
                              color: (_selected == 0
                                  ? Color.fromARGB(255, 70, 228, 249)
                                  : Colors.white),
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // week
                    Material(
                      borderRadius: BorderRadius.circular(20),
                      color: (_selected == 1
                          ? Color.fromARGB(255, 134, 144, 156)
                          : Colors.transparent),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          setState(() {
                            _selected = 1;
                          });
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: 5,
                            horizontal: 15,
                          ),
                          child: Text(
                            'Week',
                            style: TextStyle(
                              color: (_selected == 1
                                  ? Color.fromARGB(255, 70, 228, 249)
                                  : Colors.white),
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // month
                    Material(
                      borderRadius: BorderRadius.circular(20),
                      color: (_selected == 2
                          ? Color.fromARGB(255, 134, 144, 156)
                          : Colors.transparent),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          setState(() {
                            _selected = 2;
                          });
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: 5,
                            horizontal: 15,
                          ),
                          child: Text(
                            'Month',
                            style: TextStyle(
                              color: (_selected == 2
                                  ? Color.fromARGB(255, 70, 228, 249)
                                  : Colors.white),
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // day
                    Material(
                      borderRadius: BorderRadius.circular(20),
                      color: (_selected == 3
                          ? Color.fromARGB(255, 134, 144, 156)
                          : Colors.transparent),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          setState(() {
                            _selected = 3;
                          });
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: 5,
                            horizontal: 15,
                          ),
                          child: Text(
                            '6 Months',
                            style: TextStyle(
                              color: (_selected == 3
                                  ? Color.fromARGB(255, 70, 228, 249)
                                  : Colors.white),
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // year
                    Material(
                      borderRadius: BorderRadius.circular(20),
                      color: (_selected == 4
                          ? Color.fromARGB(255, 134, 144, 156)
                          : Colors.transparent),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          setState(() {
                            _selected = 4;
                          });
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: 5,
                            horizontal: 15,
                          ),
                          child: Text(
                            'Year',
                            style: TextStyle(
                              color: (_selected == 4
                                  ? Color.fromARGB(255, 70, 228, 249)
                                  : Colors.white),
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 30),

              // draw the line chart
              Container(
                height: 400,
                padding: EdgeInsets.all(20),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 48, 131, 190),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,

                  reverse: true,
                  child: Container(
                    width: (getLabelsList(_selected).length * 100)
                        .clamp(300, double.infinity)
                        .toDouble(),
                    height: 400,
                    child: LineChart(
                      LineChartData(
                        minX: 0,
                        maxX: getLabelsList(_selected).length.toDouble(),
                        minY: 0,
                        maxY: (getHighList(_selected).reduce(max) > 270)
                            ? getHighList(_selected).reduce(max) + 80
                            : 350,
                        gridData: FlGridData(show: false),
                        extraLinesData: ExtraLinesData(
                          extraLinesOnTop: false,
                          horizontalLines: [
                            HorizontalLine(
                              y: veryHigh,
                              color: Colors.red,
                              strokeWidth: 1,
                            ),
                            HorizontalLine(
                              y: high,
                              color: const Color.fromARGB(255, 200, 200, 0),
                              strokeWidth: 1,
                            ),
                            HorizontalLine(
                              y: low,
                              color: const Color.fromARGB(255, 200, 200, 0),
                              strokeWidth: 1,
                            ),
                            HorizontalLine(
                              y: veryLow,
                              color: Colors.red,
                              strokeWidth: 1,
                            ),
                          ],
                        ),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 1,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                int index = value.toInt();
                                if (index < 0 || index >= getLabelsList(_selected).length) {
                                  return Container();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    getLabelsList(_selected)[index],
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 50,
                              interval: 1,
                              getTitlesWidget: (value, meta) {
                                if (value == high) {
                                  return Text(high.toString());
                                } else if (value == low) {
                                  return Text(low.toString());
                                } else if (value == veryHigh) {
                                  return Text(veryHigh.toString());
                                } else if (value == veryLow) {
                                  return Text(veryLow.toString());
                                } else {
                                  return SizedBox.shrink();
                                }
                              },
                            ),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border(
                            top: BorderSide(color: Colors.black, width: 2),
                            bottom: BorderSide(color: Colors.black, width: 2),
                            left: BorderSide.none,
                            right: BorderSide.none,
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: List.generate(
                              getLabelsList(_selected).length,
                              (index) =>
                                  FlSpot(index.toDouble(), getHighList(_selected)[index]),
                            ),
                            isCurved: false,
                            color: Colors.white,
                            barWidth: 1,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) {
                                return FlDotCirclePainter(
                                  radius: 3,
                                  color: getBGLColor(getHighList(_selected)[index]),
                                  strokeColor: Colors.black,
                                  strokeWidth: 1.5,
                                );
                              },
                            ),
                          ),
                          if (_selected != 0)
                            LineChartBarData(
                              spots: List.generate(
                                getLabelsList(_selected).length,
                                (index) =>
                                  FlSpot(index.toDouble(), getLowList(_selected)[index]),
                              ),
                              isCurved: false,
                              color: Colors.white,
                              barWidth: 1,
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, barData, index) {
                                  return FlDotCirclePainter(
                                    radius: 3,
                                    color: getBGLColor(getLowList(_selected)[index]),
                                    strokeColor: Colors.black,
                                    strokeWidth: 1.5,
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(height:20),

              // ai tips, dummy text, needs to implement later
              // copied from activity.dart
              Container(
                padding: EdgeInsets.all(20),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 31, 85, 134),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Transform.rotate(
                          angle: pi,
                          child: Icon(
                            Icons.wb_incandescent_outlined,
                            size: 32,
                            color: Colors.white,
                          ),
                        ),

                        SizedBox(width: 10),

                        Text(
                          'AI Tips',
                          style: TextStyle(fontSize: 24, color: Colors.white),
                        ),
                      ],
                    ),

                    SizedBox(height: 10),

                    // placeholder, raplace with real ai tips later
                    Text(
                      'Nice work! Stretch your calves and hips, rest your feet, stay hydrated, maitain good posture, and aim for consistency-10,000+ steps daily keeps your heart and joints strong.',
                      style: TextStyle(fontSize: 20, color: Colors.white),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 120),
            ],
          ),
        ),
      ),

      // totally coppied from caloriesMain, better to refactor later
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 30),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 100),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      width: double.infinity,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AssistantPage(),
                            ),
                          );
                        },
                        child: Center(
                          child: Icon(
                            Icons.auto_awesome,
                            size: 28,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
