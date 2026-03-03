import 'package:flutter/material.dart';

class MedicationLog extends StatefulWidget {
  const MedicationLog({super.key});

  @override
  State<MedicationLog> createState() => _MedicationLogState();
}

class _MedicationLogState extends State<MedicationLog> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xff1A3F6B), // Matched to Health Cards
        borderRadius: BorderRadius.circular(25), // Matched to 25px corners
      ),
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Edit Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Medication Log',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                )
              ),
              IconButton(
                icon: const Icon(Icons.edit_note, color: Colors.white, size: 28),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(), // Shrinks the button footprint
                onPressed: () {
                  // to be implemented
                },
              ),
            ],
          ),

          const SizedBox(height: 15),

          const Text(
            '10:00 AM',
            style: TextStyle(
              color: Color(0xff00E5FF), 
              fontSize: 18,
              fontWeight: FontWeight.bold
            ) // Cyan accent
          ),
          const SizedBox(height: 8),
          const MedicationLogEntry(text: 'Metformin\n1 pill'),
          const MedicationLogEntry(text: 'Sulfonylureas\n1 pill'),

          const SizedBox(height: 15),

          const Text(
            '10:00 PM',
            style: TextStyle(
              color: Color(0xff00E5FF),
              fontSize: 18,
              fontWeight: FontWeight.bold
            ) // Cyan accent
          ),
          const SizedBox(height: 8),
          const MedicationLogEntry(text: 'Metformin\n1 pill'),
          const MedicationLogEntry(text: 'Sulfonylureas\n1 pill'),
        ]
      )
    );
  }
}

class MedicationLogEntry extends StatefulWidget {
  final String text;

  const MedicationLogEntry({super.key, required this.text});
  
  @override
  State<MedicationLogEntry> createState() => _MedicationLogEntryState();
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
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 12.0),
            margin: const EdgeInsets.only(bottom: 8.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color: Colors.white.withValues(alpha: 0.08), // Subtle glass-like inner box
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const Icon(
                  Icons.healing,
                  size: 28,
                  color: Colors.white70,
                ),
                const SizedBox(width: 15),
                Text(
                  _text,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                )
              ]
            )
          )
        ),

        const SizedBox(width: 15),

        // Custom styled checkbox
        Transform.scale(
          scale: 1.3,
          child: Checkbox(
            value: isChecked,
            activeColor: const Color(0xff00E5FF), // Cyan when checked
            checkColor: const Color(0xff040F31), // Dark checkmark
            side: const BorderSide(color: Colors.white54, width: 2), // Unchecked border
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            onChanged: (newValue) {
              setState(() {
                isChecked = newValue ?? false;
              });
            }
          ),
        )
      ]
    );
  }
}