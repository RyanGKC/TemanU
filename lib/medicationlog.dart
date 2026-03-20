import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:temanu/api_service.dart';

class MedicationLog extends StatefulWidget {
  const MedicationLog({super.key});

  @override
  State<MedicationLog> createState() => _MedicationLogState();
}

class _MedicationLogState extends State<MedicationLog> {
  List<dynamic> _medications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMedications();
  }

  Future<void> _fetchMedications() async {
    setState(() => _isLoading = true);
    final meds = await ApiService.getMedications();
    if (mounted) {
      setState(() {
        _medications = meds;
        _isLoading = false;
      });
    }
  }

  // --- THE NEW, BEAUTIFIED, DIGITAL-ONLY DIALOG ---
  void _showAddMedicationDialog() {
    final nameController = TextEditingController();
    final dosageController = TextEditingController();
    final inventoryController = TextEditingController();
    final unitController = TextEditingController(text: "pills"); 
    
    List<String> selectedTimes = [];

    String selectedHour = "08";
    String selectedMinute = "00";
    String selectedPeriod = "AM";

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8), // Darken the background
      builder: (context) {
        // StatefulBuilder is necessary to update the dropdowns inside the dialog
        return StatefulBuilder(
          builder: (context, setDialogState) {
            
            // Reusable Input Field Decoration
            InputDecoration inputDecoration(String label) => InputDecoration(
              labelText: label,
              labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
              filled: true,
              fillColor: const Color(0xff040F31).withValues(alpha: 0.4),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            );

            // Digital Time Picker Input Matrix
            Widget buildTimeMatrix() {
              final List<String> hours = List.generate(12, (i) => (i + 1).toString().padLeft(2, '0'));
              final List<String> minutes = List.generate(60, (i) => i.toString().padLeft(2, '0'));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Scheduled Time(s)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),
                  // The Time Selector Matrix
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xff040F31).withValues(alpha: 0.4), borderRadius: BorderRadius.circular(18)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        // Hour
                        DropdownButton<String>(
                          value: selectedHour,
                          underline: const SizedBox(),
                          dropdownColor: const Color(0xff1A3F6B),
                          borderRadius: BorderRadius.circular(15), // Native rounded corners!
                          style: const TextStyle(color: Color(0xff00E5FF), fontSize: 18, fontWeight: FontWeight.bold),
                          onChanged: (val) => setDialogState(() => selectedHour = val!),
                          items: hours.map((h) => DropdownMenuItem(value: h, child: Text(h))).toList(),
                        ),
                        const Text(":", style: TextStyle(color: Colors.white38, fontSize: 22)),
                        // Minute
                        DropdownButton<String>(
                          value: selectedMinute,
                          underline: const SizedBox(),
                          dropdownColor: const Color(0xff1A3F6B),
                          borderRadius: BorderRadius.circular(15), 
                          style: const TextStyle(color: Color(0xff00E5FF), fontSize: 18, fontWeight: FontWeight.bold),
                          onChanged: (val) => setDialogState(() => selectedMinute = val!),
                          items: minutes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                        ),
                        // AM/PM
                        DropdownButton<String>(
                          value: selectedPeriod,
                          underline: const SizedBox(),
                          dropdownColor: const Color(0xff1A3F6B),
                          borderRadius: BorderRadius.circular(15),
                          style: const TextStyle(color: Color(0xff00E5FF), fontSize: 18, fontWeight: FontWeight.bold),
                          onChanged: (val) => setDialogState(() => selectedPeriod = val!),
                          items: ["AM", "PM"].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                        ),
                        // Confirm Time Button
                        GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              selectedTimes.add("$selectedHour:$selectedMinute $selectedPeriod");
                              // Optional: Sort times alphabetically/chronologically
                              selectedTimes.sort();
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(color: Color(0xff00E5FF), shape: BoxShape.circle),
                            child: const Icon(Icons.add, color: Color(0xff040F31), size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  // The list of selected times
                  if (selectedTimes.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: selectedTimes.map((time) {
                        return Chip(
                          backgroundColor: const Color(0xff00E5FF).withValues(alpha: 0.15),
                          side: const BorderSide(color: Color(0xff00E5FF)),
                          label: Text(time, style: const TextStyle(color: Color(0xff00E5FF), fontWeight: FontWeight.w600)),
                          deleteIcon: const Icon(Icons.close, color: Color(0xff00E5FF), size: 16),
                          onDeleted: () => setDialogState(() => selectedTimes.remove(time)),
                        );
                      }).toList(),
                    ),
                ],
              );
            }

            return Dialog(
              backgroundColor: const Color(0xff1A3F6B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25), side: const BorderSide(color: Colors.white12, width: 1.5)),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 25, 22, 30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Matrix
                    Row(
                      children: const [
                        Icon(Icons.add_task, color: Color(0xff00E5FF), size: 24),
                        SizedBox(width: 12),
                        Text("Add Medication", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 25),

                    // Inputs Matrix
                    TextField(
                      controller: nameController, 
                      style: const TextStyle(color: Colors.white), 
                      decoration: inputDecoration("Medication Name")
                    ),
                    const SizedBox(height: 15),
                    
                    // --- UPDATED: Dosage strictly accepts numbers/decimals ---
                    TextField(
                      controller: dosageController, 
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*')),
                      ],
                      style: const TextStyle(color: Colors.white), 
                      decoration: inputDecoration("Dosage Amount (e.g. 50, 1.5)")
                    ),
                    const SizedBox(height: 15),
                    
                    Row(
                      children: [
                        // --- UPDATED: Inventory strictly accepts numbers/decimals ---
                        Expanded(
                          flex: 2, 
                          child: TextField(
                            controller: inventoryController, 
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*')),
                            ],
                            style: const TextStyle(color: Colors.white), 
                            decoration: inputDecoration("Total Amount Left")
                          )
                        ),
                        const SizedBox(width: 15),
                        
                        Expanded(
                          flex: 1, 
                          child: TextField(
                            controller: unitController, 
                            style: const TextStyle(color: Colors.white), 
                            decoration: inputDecoration("Unit (mg, ml, pills)")
                          )
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),

                    // Time Picker Matrix
                    buildTimeMatrix(),
                    
                    const SizedBox(height: 35),

                    // Action Buttons Matrix
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white24, width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Cancel", style: TextStyle(color: Colors.white, fontSize: 16)),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xff00E5FF),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            onPressed: () async {
                              final name = nameController.text.trim();
                              final dosage = dosageController.text.trim();
                              final inv = double.tryParse(inventoryController.text) ?? 0.0;
                              final unit = unitController.text.trim();
                              
                              if (name.isNotEmpty) {
                                Navigator.pop(context);
                                // Fallback if no times are set
                                if (selectedTimes.isEmpty) selectedTimes.add("Anytime");
                                bool success = await ApiService.addMedication(name, dosage, inv, unit, selectedTimes);
                                if (success) _fetchMedications();
                              }
                            },
                            child: const Text("Save", style: TextStyle(color: Color(0xff040F31), fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }
        );
      },
    );
  }

  // ... [Keep the entire build() and list item methods exact as they were] ...
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xff1A3F6B), borderRadius: BorderRadius.circular(25)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Daily Medications", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              GestureDetector(
                onTap: _showAddMedicationDialog,
                child: const Icon(Icons.add_circle, color: Color(0xff00E5FF), size: 28),
              ),
            ],
          ),
          const SizedBox(height: 15),
          
          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator(color: Color(0xff00E5FF))))
          else if (_medications.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20.0),
              child: Center(child: Text("No medications scheduled.", style: TextStyle(color: Colors.white54))),
            )
          else
            ..._medications.map((med) {
              int totalDoses = (med['times'] as List).length;
              int dosesTaken = med['doses_taken_today'];
              bool isFullyTaken = dosesTaken >= totalDoses;
              
              num inventory = med['inventory'];
              String unit = med['unit'];
              
              // 1. Safely extract the dosage as a decimal number
              double dosageAmount = double.tryParse(med['dosage'].toString()) ?? 1.0;
              
              // --- THE NEW LOGIC: Alert if they don't have enough for 5 more doses ---
              bool lowStock = (inventory / dosageAmount) < 5; 

              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: isFullyTaken ? const Color(0xff00E676).withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05),
                  border: Border.all(color: isFullyTaken ? const Color(0xff00E676).withValues(alpha: 0.5) : Colors.transparent),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    // Dynamic checkboxes
                    Row(
                      children: List.generate(totalDoses, (index) {
                        bool isChecked = index < dosesTaken;
                        return GestureDetector(
                          onTap: isChecked ? null : () async {
                            bool success = await ApiService.takeMedication(med['id']);
                            if (success) _fetchMedications(); 
                          },
                          child: Container(
                            height: 28, width: 28,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: isChecked ? const Color(0xff00E676) : Colors.transparent,
                              border: Border.all(color: isChecked ? const Color(0xff00E676) : Colors.white54, width: 2),
                              shape: BoxShape.circle,
                            ),
                            child: isChecked ? const Icon(Icons.check, color: Color(0xff040F31), size: 18) : null,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(width: 8),
                    
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            med['name'],
                            style: TextStyle(
                              color: isFullyTaken ? Colors.white70 : Colors.white,
                              fontSize: 16, fontWeight: FontWeight.bold,
                              decoration: isFullyTaken ? TextDecoration.lineThrough : TextDecoration.none,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // --- UPDATED: Combines Dosage Number and Unit! ---
                          Text(
                            "${med['dosage']} $unit • ${(med['times'] as List).join(', ')}",
                            style: const TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                          // -------------------------------------------------
                        ],
                      ),
                    ),
                    
                    // Inventory Alert & Delete Button Column
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // --- NEW: Delete Button ---
                        GestureDetector(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: const Color(0xff1A3F6B),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                title: const Text("Delete Medication?", style: TextStyle(color: Colors.white)),
                                content: Text("Are you sure you want to remove ${med['name']} from your schedule?", style: const TextStyle(color: Colors.white70)),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      Navigator.pop(context); // Close dialog
                                      bool success = await ApiService.deleteMedication(med['id']);
                                      if (success) _fetchMedications(); // Refresh list!
                                    },
                                    child: const Text("Delete", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: const Padding(
                            padding: EdgeInsets.only(bottom: 8.0),
                            child: Icon(Icons.delete_outline, color: Colors.white24, size: 20),
                          ),
                        ),
                        // --------------------------
                        
                        if (lowStock)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.orangeAccent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.orangeAccent),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 14),
                                const SizedBox(width: 4),
                                Text("$inventory left", style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          )
                        else
                          Text("$inventory left", style: const TextStyle(color: Colors.white38, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }
}