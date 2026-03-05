import 'dart:math';
import 'package:flutter/material.dart';

class BloodPressurePage extends StatefulWidget {
  const BloodPressurePage({super.key});

  @override
  State<BloodPressurePage> createState() => _BloodPressurePageState();
}

class _BloodPressurePageState extends State<BloodPressurePage> {

  List<Map<String, int>> records = [
    {"sys":118,"dia":76},
    {"sys":120,"dia":78},
    {"sys":122,"dia":80},
    {"sys":119,"dia":77},
  ];

  void addRecord(int sys,int dia){
    setState(() {
      records.add({"sys":sys,"dia":dia});
      if(records.length>10){
        records.removeAt(0);
      }
    });
  }

  void showAddDialog(){

    TextEditingController sys=TextEditingController();
    TextEditingController dia=TextEditingController();

    showDialog(
      context: context,
      builder:(context){
        return AlertDialog(
          title: const Text("Add Blood Pressure"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              TextField(
                controller: sys,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Systolic (SYS)",
                ),
              ),

              TextField(
                controller: dia,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Diastolic (DIA)",
                ),
              )

            ],
          ),

          actions: [

            TextButton(
              onPressed: (){
                Navigator.pop(context);
              },
              child: const Text("Cancel"),
            ),

            ElevatedButton(
              onPressed: (){
                int s=int.parse(sys.text);
                int d=int.parse(dia.text);
                addRecord(s,d);
                Navigator.pop(context);
              },
              child: const Text("Save"),
            )

          ],
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: const Color(0xff040F31),

      appBar: AppBar(
        title: const Text("Blood Pressure"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xff00E5FF),
        onPressed: showAddDialog,
        child: const Icon(Icons.add),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xff1A3F6B),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [

                  const Text(
                    "Latest Reading",
                    style: TextStyle(color: Colors.white70),
                  ),

                  const SizedBox(height:10),

                  Text(
                    "${records.last["sys"]}/${records.last["dia"]}",
                    style: const TextStyle(
                      fontSize:32,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  )

                ],
              ),
            ),

            const SizedBox(height:20),

            SizedBox(
              height:150,
              child: CustomPaint(
                painter: ChartPainter(records),
              ),
            ),

            const SizedBox(height:20),

            Expanded(
              child: ListView.builder(

                itemCount: records.length,

                itemBuilder:(context,index){

                  var r=records.reversed.toList()[index];

                  return Container(
                    margin: const EdgeInsets.only(bottom:10),
                    padding: const EdgeInsets.all(15),

                    decoration: BoxDecoration(
                      color: const Color(0xff1A3F6B),
                      borderRadius: BorderRadius.circular(15),
                    ),

                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [

                        const Text(
                          "Blood Pressure",
                          style: TextStyle(color: Colors.white70),
                        ),

                        Text(
                          "${r["sys"]}/${r["dia"]}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        )

                      ],
                    ),

                  );

                }

              ),
            )

          ],
        ),
      ),
    );
  }
}


class ChartPainter extends CustomPainter{

  final List<Map<String,int>> data;

  ChartPainter(this.data);

  @override
  void paint(Canvas canvas,Size size){

    Paint line=Paint()
      ..color=const Color(0xff00E5FF)
      ..strokeWidth=3
      ..style=PaintingStyle.stroke;

    if(data.length<2) return;

    double step=size.width/(data.length-1);

    int minValue= data.map((e)=>e["sys"]!).reduce(min);
    int maxValue= data.map((e)=>e["sys"]!).reduce(max);

    double range=max(1,(maxValue-minValue).toDouble());

    Path path=Path();

    for(int i=0;i<data.length;i++){

      double x=i*step;

      double y=size.height-
          ((data[i]["sys"]!-minValue)/range)*size.height;

      if(i==0){
        path.moveTo(x,y);
      }else{
        path.lineTo(x,y);
      }

    }

    canvas.drawPath(path,line);

  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate){
    return true;
  }

}