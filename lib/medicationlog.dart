import 'dart:ui';
import 'package:flutter/material.dart';

// 1. DATA MODEL
class Medication {
  String id;
  String name;
  String amount;
  TimeOfDay time;
  bool isTaken;

  Medication({
    required this.id,
    required this.name,
    required this.amount,
    required this.time,
    this.isTaken = false,
  });
}

class MedicationLog extends StatefulWidget {
  const MedicationLog({super.key});

  @override
  State<MedicationLog> createState() => _MedicationLogState();
}

class _MedicationLogState extends State<MedicationLog> {
  bool _isEditing = false;

  // Initial mock data
  List<Medication> _medications = [
    Medication(id: '1', name: 'Metformin', amount: '1 pill', time: const TimeOfDay(hour: 10, minute: 0)),
    Medication(id: '2', name: 'Sulfonylureas', amount: '1 pill', time: const TimeOfDay(hour: 10, minute: 0)),
    Medication(id: '3', name: 'Metformin', amount: '1 pill', time: const TimeOfDay(hour: 22, minute: 0)),
    Medication(id: '4', name: 'Sulfonylureas', amount: '1 pill', time: const TimeOfDay(hour: 22, minute: 0)),
  ];

  // Helper to group medications by time and sort them chronologically
  Map<TimeOfDay, List<Medication>> _getGroupedMedications() {
    Map<TimeOfDay, List<Medication>> grouped = {};
    for (var med in _medications) {
      grouped.putIfAbsent(med.time, () => []).add(med);
    }
    return grouped;
  }

  // DIALOG: Add or Edit Medication
  void _showMedicationDialog({Medication? existingMedication}) {
    final TextEditingController nameController = TextEditingController(text: existingMedication?.name ?? '');
    final TextEditingController amountController = TextEditingController(text: existingMedication?.amount ?? '');
    TimeOfDay selectedTime = existingMedication?.time ?? TimeOfDay.now();

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      color: const Color(0xff1A3F6B).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          existingMedication == null ? "Add Medication" : "Edit Medication",
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 20),
                        
                        // Name Input
                        _buildDialogTextField("Medication Name", "e.g., Metformin", nameController),
                        const SizedBox(height: 15),
                        
                        // Amount Input
                        _buildDialogTextField("Amount", "e.g., 1 pill", amountController),
                        const SizedBox(height: 15),

                        // Time Selector
                        const Text("Schedule", style: TextStyle(color: Colors.white54, fontSize: 13)),
                        const SizedBox(height: 5),
                        GestureDetector(
                          onTap: () async {
                            final TimeOfDay? time = await showTimePicker(
                              context: context,
                              initialTime: selectedTime,
                            );
                            if (time != null) {
                              setDialogState(() => selectedTime = time);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xff00E5FF).withValues(alpha: 0.5)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  selectedTime.format(context),
                                  style: const TextStyle(color: Colors.white, fontSize: 16),
                                ),
                                const Icon(Icons.access_time, color: Color(0xff00E5FF)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),

                        // Buttons
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.white38),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: const Text("Cancel", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  if (nameController.text.isEmpty || amountController.text.isEmpty) return;

                                  setState(() {
                                    if (existingMedication == null) {
                                      // Add new
                                      _medications.add(Medication(
                                        id: DateTime.now().toString(),
                                        name: nameController.text,
                                        amount: amountController.text,
                                        time: selectedTime,
                                      ));
                                    } else {
                                      // Update existing
                                      existingMedication.name = nameController.text;
                                      existingMedication.amount = amountController.text;
                                      existingMedication.time = selectedTime;
                                    }
                                  });
                                  Navigator.pop(context);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: const Color(0xff00E5FF),
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: const Text("Save", style: TextStyle(color: Color(0xff040F31), fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDialogTextField(String label, String hint, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.1),
            contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xff00E5FF))),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupedMedications = _getGroupedMedications();
    // Sort times chronologically
    final sortedTimes = groupedMedications.keys.toList()
      ..sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xff1A3F6B),
        borderRadius: BorderRadius.circular(25),
      ),
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Edit/Done Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Medication Log',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)
              ),
              IconButton(
                icon: Icon(_isEditing ? Icons.check : Icons.edit_note, color: _isEditing ? const Color(0xff00E5FF) : Colors.white, size: 28),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  setState(() => _isEditing = !_isEditing);
                },
              ),
            ],
          ),
          const SizedBox(height: 15),

          if (_medications.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text("No medications scheduled.", style: TextStyle(color: Colors.white54))),
            ),

          // Render grouped medications
          ...sortedTimes.map((time) {
            final medsForTime = groupedMedications[time]!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  time.format(context),
                  style: const TextStyle(color: Color(0xff00E5FF), fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...medsForTime.map((med) => MedicationLogEntry(
                  medication: med,
                  isEditing: _isEditing,
                  onEdit: () => _showMedicationDialog(existingMedication: med),
                  onDelete: () {
                    setState(() => _medications.remove(med));
                  },
                  onToggle: (val) {
                    setState(() => med.isTaken = val);
                  },
                )),
                const SizedBox(height: 15),
              ],
            );
          }),

          // Add Medication Button (Only visible in Edit Mode)
          if (_isEditing)
            GestureDetector(
              onTap: () => _showMedicationDialog(), // Pass null to add a new one
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xff00E5FF), width: 1.5),
                  borderRadius: BorderRadius.circular(15),
                  color: const Color(0xff00E5FF).withValues(alpha: 0.1),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, color: Color(0xff00E5FF)),
                    SizedBox(width: 8),
                    Text("Add Medication", style: TextStyle(color: Color(0xff00E5FF), fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
            )
        ]
      )
    );
  }
}

// 2. ENTRY WIDGET
class MedicationLogEntry extends StatelessWidget {
  final Medication medication;
  final bool isEditing;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Function(bool) onToggle;

  const MedicationLogEntry({
    super.key,
    required this.medication,
    required this.isEditing,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
  });
  
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
              color: Colors.white.withValues(alpha: 0.08),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const Icon(Icons.healing, size: 28, color: Colors.white70),
                const SizedBox(width: 15),
                Expanded(
                  child: Text(
                    "${medication.name}\n${medication.amount}",
                    style: TextStyle(
                      color: medication.isTaken && !isEditing ? Colors.white54 : Colors.white, 
                      fontSize: 16,
                      decoration: medication.isTaken && !isEditing ? TextDecoration.lineThrough : null,
                    ),
                  ),
                )
              ]
            )
          )
        ),
        const SizedBox(width: 15),

        // Toggle between Edit Controls and Checkbox
        if (isEditing)
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white70),
                onPressed: onEdit,
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.only(right: 8),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: onDelete,
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          )
        else
          Transform.scale(
            scale: 1.3,
            child: Checkbox(
              value: medication.isTaken,
              activeColor: const Color(0xff00E5FF),
              checkColor: const Color(0xff040F31),
              side: const BorderSide(color: Colors.white54, width: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              onChanged: (newValue) => onToggle(newValue ?? false),
            ),
          )
      ]
    );
  }
}