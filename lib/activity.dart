import 'dart:ui';
import 'package:flutter/material.dart';
import 'assistantpage.dart';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';

class Activity extends StatefulWidget {
  const Activity({super.key});

  @override
  State<Activity> createState() => _ActivityState();
}

class _ActivityState extends State<Activity> {
  // dummy values
  //////////////////////////////////////////////////
  int currentSteps = 8240;
  int averageSteps = 10140;

  List<String> dailyLabels = ['12AM', '4AM', '8AM', '12PM', '4PM', '8PM', '12AM'];
  List<double> dailyValues = [612, 839, 619, 619, 852, 970, 789];

  List<String> weeklyLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thur', 'Fri', 'Sat'];
  List<double> weeklyValues = [6837, 1242, 3337, 6569, 10200, 123, 8890];

  List<String> monthlyLabels = ['1/3', '2/3', '3/3', '4/3', '5/3', '6/3', '7/3', '8/3', '9/3', '10/3',
                                '11/3', '12/3', '13/3', '14/3', '15/3', '16/3', '17/3', '18/3', '19/3', '20/3',
                                '21/3', '22/3', '23/3', '24/3', '25/3', '26/3', '27/3', '28/3', '29/3', '30/3',
                                '31/3'];
  List<double> monthlyValues = [1245, 3632, 4356, 4323, 5678, 5630, 1082, 3456, 2636, 1009,
                                940, 10234, 2240, 5325, 2948, 3399, 3528, 5862, 5839, 3428,
                                1250, 3860, 3432, 5893, 2049, 3248, 8295, 2489, 2422, 8898,
                                2789];

  List<String> sixMonthLabels = ['Oct', 'Nov', 'Dec', 'Jan', 'Feb', 'Mar'];
  List<double> sixMonthValues = [9540, 3950, 2300, 5496, 3289, 3894];

  List<String> yearlyLabels = ['Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', 'Jan', 'Feb', 'Mar'];
  List<double> yearlyValues = [6938, 1893, 3009, 6593, 6859, 2858, 9540, 3950, 2300, 5496, 3289, 4493];

  List<String> monthlyAverageLabels = ['Sept', 'Oct'];
  List<double> monthlyAverageValues = [8500, 10050];

  List<String> yearlyAverageLabels = ['2024', '2025'];
  List<double> yearlyAverageValues = [8050, 9050];


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

  List<double> getValuesList(int selected) {
    switch (selected) {
      case 0:
        return dailyValues;
      case 1:
        return weeklyValues;
      case 2:
        return monthlyValues;
      case 3:
        return sixMonthValues;
      case 4:
        return yearlyValues;
      default:
        return [];
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
          'Activity',
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
              // the header, including current steps and the button to add tracking devices
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Current\n',
                          style: TextStyle(color: Colors.white, fontSize: 24),
                        ),
                        TextSpan(
                          text: '$currentSteps',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text: 'steps',
                          style: TextStyle(color: Colors.white, fontSize: 24),
                        ),
                      ],
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    icon: Icon(
                      Icons.add_box_outlined,
                      color: Colors.white,
                      size: 40,
                    ),
                    onPressed: () {
                      // add code for adding device here
                    },
                  ),
                  Text(
                    'Add tracking device',
                    style: TextStyle(color: Colors.white, fontSize: 24),
                  ),
                ],
              ),

              SizedBox(height: 30),

              // selection bar
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

              SizedBox(height: 20),

              // bar chart
              Container(
                height: 400,
                padding: EdgeInsets.all(20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 48, 131, 190),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: MyBarChart(
                  labels: getLabelsList(_selected),
                  values: getValuesList(_selected),
                  showSideLabels: true,
                ),
              ),

              SizedBox(height: 20),

              // average steps this week
              Container(
                padding: EdgeInsets.all(20),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 48, 131, 190),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Your average steps this week is $averageSteps steps!',
                  style: TextStyle(color: Colors.white, fontSize: 20),
                ),
              ),

              SizedBox(height: 20),

              Row(
                children: [
                  // left: Monthly Average
                  Expanded(
                    child: Container(
                      height: 300,
                      padding: EdgeInsets.all(20),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 48, 131, 190),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: MyBarChart(
                        values: monthlyAverageValues,
                        labels: monthlyAverageLabels,
                        showSideLabels: false,
                      ),
                    ),
                  ),

                  SizedBox(width: 10),

                  // right: Yearly Average
                  Expanded(
                    child: Container(
                      height: 300,
                      padding: EdgeInsets.all(20),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 48, 131, 190),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: MyBarChart(
                        values: yearlyAverageValues,
                        labels: yearlyAverageLabels,
                        showSideLabels: false,
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 20),

              // ai tips, dummy text, needs to implement later
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

class MyBarChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final bool showSideLabels;

  const MyBarChart({
    super.key,
    required this.values,
    required this.labels,
    required this.showSideLabels,
  });

  @override
  Widget build(BuildContext context) {
    return BarChart(
      BarChartData(
        maxY: (values.reduce(max) * 11 / 30).ceilToDouble() * 3,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          drawHorizontalLine: true,
          drawVerticalLine: false,
          horizontalInterval: (values.reduce(max) * 11 / 30).ceilToDouble(),
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: const Color.fromARGB(160, 255, 255, 255),
              strokeWidth: (value >= (values.reduce(max) * 11 / 30).ceilToDouble() * 3) ? 0 : 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, _) {
                return Text(
                  (labels.length > 20 && value % 7 != 0) ? '' : labels[value.toInt()],
                  style: TextStyle(color: Colors.white),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: showSideLabels,
              reservedSize: 40,
              interval: (values.reduce(max) * 11 / 30).ceilToDouble(),
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(color: Colors.white, fontSize: 12),
                );
              },
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(values.length, (index) {
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: values[index],
                width:
                    MediaQuery.of(context).size.width / (values.length == 2 ? 5 : values.length) * .5,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                  bottomLeft: Radius.circular(0),
                  bottomRight: Radius.circular(0),
                ),
                color: (index % 2 == 1
                    ? Color.fromARGB(255, 91, 199, 255)
                    : Color.fromARGB(255, 215, 241, 255)),
              ),
            ],
          );
        }),
      ),
      duration: Duration(milliseconds: 0),
    );
  }
}
