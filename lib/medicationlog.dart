import 'package:flutter/material.dart';

class MedicationLog extends StatefulWidget {

  const MedicationLog({super.key});

  @override
  State<MedicationLog> createState () => _MedicationLogState();
}

class _MedicationLogState extends State<MedicationLog> {
  @override
  Widget build (BuildContext contexr) {
    return Container (

      decoration: BoxDecoration(
        color: Colors.cyan,
        borderRadius: BorderRadius.circular(12),
      ),

      width: double.infinity,
      padding: EdgeInsets.all(20.0),
      child: Column( 
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Medication Log',
            style: TextStyle(
              color:Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20
            )
          ), 

          SizedBox(height: 10,),

          Text(
            '10:00 AM',
            style: TextStyle(
              color:Colors.white,
            )
          ),
          MedicationLogEntry(text:'Metformin\n1pill'),
          MedicationLogEntry(text:'Sulfonylureas\n1pill'),

          Text(
            '10:00 PM',
            style: TextStyle(
              color:Colors.white,
            )
          ),
          MedicationLogEntry(text:'Metformin\n1pill'),
          MedicationLogEntry(text:'Sulfonylureas\n1pill'),

          IconButton(
            icon: Icon(Icons.edit_square),
            iconSize: 30.0,
            color: Colors.white,
            onPressed: () {
              //to be implemented
            },
          ),
        ]
      )
    );
  }
}

class MedicationLogEntry extends StatefulWidget{

  final String text;

  const MedicationLogEntry({super.key, required this.text});
  @override
  State<MedicationLogEntry> createState () => _MedicationLogEntryState();

}

class _MedicationLogEntryState extends State<MedicationLogEntry> {
  late String _text;
  bool isChecked = false;

  @override
  void initState() {
    super.initState();
    _text = widget.text;
  }
  @override
  Widget build (BuildContext contexr) {
    return Row(
      children:[
        Expanded(
          child: Container(
            padding:EdgeInsets.all(10.0),
            margin: EdgeInsets.all(5.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.white.withValues(alpha: 0.5)
            ),
            child: Row(//icon and medicine
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Icon(
                  Icons.healing,
                  size: 40,
                ),
                Text(
                  _text
                )
              ]
            )
          )
        ),

        SizedBox(width:20),

        //the checkbox
        Transform.scale(
          scale: 1.7,
          child: Checkbox(
            value: isChecked, 
            onChanged: (newValue){
              setState(() {
                isChecked = newValue ?? false;
              });
            })
        )
      ]
    );
  }
}