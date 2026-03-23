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
  
  // --- Tab State (0 = Schedule, 1 = Manage) ---
  int _activeTab = 0; 

  @override
  void initState() {
    super.initState();
    _fetchMedications();
  }

  // ── Full load (shows spinner only on the very first load) ─────────────────
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

  // ── Silent refresh — data is updated in the background with no spinner ────
  Future<void> _silentRefresh() async {
    final meds = await ApiService.getMedications();
    if (mounted) {
      setState(() => _medications = meds);
    }
  }

  // --- Smart Add/Edit Dialog ---
  void _showMedicationDialog({Map<String, dynamic>? existingMed}) {
    final bool isEditing = existingMed != null;
    
    final nameController = TextEditingController(text: isEditing ? existingMed['name'] : "");
    final dosageController = TextEditingController(text: isEditing ? existingMed['dosage'].toString() : "");
    final inventoryController = TextEditingController(text: isEditing ? existingMed['inventory'].toString() : "");
    final unitController = TextEditingController(text: isEditing ? existingMed['unit'] : "pills"); 
    
    List<String> selectedTimes = isEditing ? List<String>.from(existingMed['times']) : [];

    String selectedHour = "08";
    String selectedMinute = "00";
    String selectedPeriod = "AM";

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            
            InputDecoration inputDecoration(String label) => InputDecoration(
              labelText: label,
              labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
              filled: true,
              fillColor: const Color(0xff040F31).withValues(alpha: 0.4),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            );

            Widget buildTimeMatrix() {
              final List<String> hours = List.generate(12, (i) => (i + 1).toString().padLeft(2, '0'));
              final List<String> minutes = List.generate(12, (i) => (i * 5).toString().padLeft(2, '0'));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Scheduled Times", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xff040F31).withValues(alpha: 0.4), borderRadius: BorderRadius.circular(18)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        DropdownButton<String>(
                          value: selectedHour,
                          underline: const SizedBox(),
                          dropdownColor: const Color(0xff1A3F6B),
                          borderRadius: BorderRadius.circular(15), 
                          style: const TextStyle(color: Color(0xff00E5FF), fontSize: 18, fontWeight: FontWeight.bold),
                          onChanged: (val) => setDialogState(() => selectedHour = val!),
                          items: hours.map((h) => DropdownMenuItem(value: h, child: Text(h))).toList(),
                        ),
                        const Text(":", style: TextStyle(color: Colors.white38, fontSize: 22)),
                        DropdownButton<String>(
                          value: selectedMinute,
                          underline: const SizedBox(),
                          dropdownColor: const Color(0xff1A3F6B),
                          borderRadius: BorderRadius.circular(15), 
                          style: const TextStyle(color: Color(0xff00E5FF), fontSize: 18, fontWeight: FontWeight.bold),
                          onChanged: (val) => setDialogState(() => selectedMinute = val!),
                          items: minutes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                        ),
                        DropdownButton<String>(
                          value: selectedPeriod,
                          underline: const SizedBox(),
                          dropdownColor: const Color(0xff1A3F6B),
                          borderRadius: BorderRadius.circular(15),
                          style: const TextStyle(color: Color(0xff00E5FF), fontSize: 18, fontWeight: FontWeight.bold),
                          onChanged: (val) => setDialogState(() => selectedPeriod = val!),
                          items: ["AM", "PM"].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                        ),
                        GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              if (!selectedTimes.contains("$selectedHour:$selectedMinute $selectedPeriod")) {
                                selectedTimes.add("$selectedHour:$selectedMinute $selectedPeriod");
                                selectedTimes.sort((a, b) => _timeToMinutes(a).compareTo(_timeToMinutes(b)));
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(color: Color(0xff00E5FF), shape: BoxShape.circle),
                            child: const Icon(Icons.check, color: Color(0xff040F31), size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),
                  if (selectedTimes.isNotEmpty)
                    Wrap(
                      spacing: 8, runSpacing: 8,
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
                    Row(
                      children: [
                        Icon(isEditing ? Icons.edit : Icons.add_task, color: const Color(0xff00E5FF), size: 24),
                        const SizedBox(width: 12),
                        Text(isEditing ? "Edit Medication" : "Add Medication", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 25),
                    TextField(controller: nameController, style: const TextStyle(color: Colors.white), decoration: inputDecoration("Medication Name")),
                    const SizedBox(height: 15),
                    TextField(
                      controller: dosageController, 
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))],
                      style: const TextStyle(color: Colors.white), decoration: inputDecoration("Dosage Amount (e.g. 50, 1.5)")
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                          flex: 2, 
                          child: TextField(
                            controller: inventoryController, 
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*'))],
                            style: const TextStyle(color: Colors.white), decoration: inputDecoration("Total Amount Left")
                          )
                        ),
                        const SizedBox(width: 15),
                        Expanded(flex: 1, child: TextField(controller: unitController, style: const TextStyle(color: Colors.white), decoration: inputDecoration("Unit (ml, pills)"))),
                      ],
                    ),
                    const SizedBox(height: 30),
                    buildTimeMatrix(),
                    const SizedBox(height: 35),
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
                              backgroundColor: const Color(0xff00E5FF), elevation: 0,
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
                                if (selectedTimes.isEmpty) selectedTimes.add("Anytime");
                                
                                bool success;
                                if (isEditing) {
                                  success = await ApiService.editMedication(existingMed['id'], name, dosage, inv, unit, selectedTimes);
                                } else {
                                  success = await ApiService.addMedication(name, dosage, inv, unit, selectedTimes);
                                }
                                
                                if (success) _silentRefresh();
                              }
                            },
                            child: Text(isEditing ? "Update" : "Save", style: const TextStyle(color: Color(0xff040F31), fontSize: 16, fontWeight: FontWeight.bold)),
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

  // --- Chronological Helper ---
  int _timeToMinutes(String timeStr) {
    if (timeStr.toLowerCase() == "anytime") return 9999; 
    try {
      final parts = timeStr.split(' ');
      final timeParts = parts[0].split(':');
      int h = int.parse(timeParts[0]);
      int m = int.parse(timeParts[1]);
      if (parts[1].toUpperCase() == 'PM' && h != 12) h += 12;
      if (parts[1].toUpperCase() == 'AM' && h == 12) h = 0;
      return (h * 60) + m;
    } catch (e) {
      return 9999;
    }
  }

  // --- TAB 1: GENERATE SCHEDULE ---
  List<Map<String, dynamic>> _generateChronologicalSchedule() {
    List<Map<String, dynamic>> schedule = [];
    
    for (var med in _medications) {
      List<String> times = List<String>.from(med['times'] ?? []);
      int dosesTaken = med['doses_taken_today'];
      
      times.sort((a, b) => _timeToMinutes(a).compareTo(_timeToMinutes(b)));
      
      for (int i = 0; i < times.length; i++) {
        if (i >= dosesTaken) {
          schedule.add({
            'med': med,
            'time_str': times[i],
            'time_val': _timeToMinutes(times[i]),
          });
        }
      }
    }
    
    schedule.sort((a, b) => a['time_val'].compareTo(b['time_val']));
    return schedule;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xff1A3F6B), borderRadius: BorderRadius.circular(25)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Medications", 
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
              ),
              GestureDetector(
                onTap: () => _showMedicationDialog(), 
                child: const Icon(Icons.add_circle, color: Color(0xff00E5FF), size: 28),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // --- THE CUSTOM TABS ---
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xff040F31).withValues(alpha: 0.4), 
              borderRadius: BorderRadius.circular(30)
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _activeTab = 0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _activeTab == 0 ? const Color(0xff3183BE) : Colors.transparent,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: const Center(child: Text("Today's Schedule", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _activeTab = 1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _activeTab == 1 ? const Color(0xff3183BE) : Colors.transparent,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: const Center(child: Text("Manage List", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          
          // --- TAB CONTENT ---
          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator(color: Color(0xff00E5FF))))
          else if (_medications.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20.0),
              child: Center(child: Text("No medications scheduled.", style: TextStyle(color: Colors.white54))),
            )
          else
            // --- NEW: LayoutBuilder makes the tabs responsive! ---
            LayoutBuilder(
              builder: (context, constraints) {
                // If screen is wide, calculate width for 2 columns. Otherwise, take full width.
                // Subtracting 16 pixels accounts for the gap between the columns.
                bool isWideScreen = MediaQuery.of(context).size.width > 800;
                double itemWidth = isWideScreen 
                    ? ((constraints.maxWidth - 16) / 2).floorToDouble() 
                    : constraints.maxWidth;

                if (_activeTab == 0) {
                  return _buildScheduleTab(itemWidth);
                } else {
                  return _buildManageTab(itemWidth);
                }
              },
            ),
        ],
      ),
    );
  }

  // --- TAB 1: SCHEDULE VIEW ---
  Widget _buildScheduleTab(double itemWidth) {
    final schedule = _generateChronologicalSchedule();
    
    if (schedule.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 30),
        alignment: Alignment.center,
        child: Column(
          children: const [
            Icon(Icons.check_circle_outline, color: Color(0xff00E676), size: 40),
            SizedBox(height: 10),
            Text("All caught up for today!", style: TextStyle(color: Color(0xff00E676), fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    // --- NEW: Using Wrap instead of Column ---
    return Wrap(
      spacing: 15, // Horizontal gap between columns
      runSpacing: 12, // Vertical gap between rows
      children: schedule.map((event) {
        final med = event['med'];
        return SizedBox(
          width: itemWidth,
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(15)),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () async {
                    setState(() {
                      final idx = _medications.indexWhere((m) => m['id'] == med['id']);
                      if (idx != -1) {
                        final current = _medications[idx]['doses_taken_today'] as int? ?? 0;
                        _medications[idx] = Map<String, dynamic>.from(_medications[idx])
                          ..['doses_taken_today'] = current + 1;
                      }
                    });
                    final success = await ApiService.takeMedication(med['id']);
                    if (success) _silentRefresh();
                  },
                  child: Container(
                    height: 28, width: 28,
                    decoration: BoxDecoration(border: Border.all(color: Colors.white54, width: 2), shape: BoxShape.circle),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(med['name'], style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text("Take ${med['dosage']} ${med['unit']} at ${event['time_str']}", style: const TextStyle(color: Color(0xff00E5FF), fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // --- TAB 2: MANAGE VIEW ---
  Widget _buildManageTab(double itemWidth) {
    // --- NEW: Using Wrap instead of Column ---
    return Wrap(
      spacing: 15,
      runSpacing: 12,
      children: _medications.map((med) {
        num inventory = med['inventory'];
        String unit = med['unit'];
        double dosageAmount = double.tryParse(med['dosage'].toString()) ?? 1.0;
        bool lowStock = (inventory / dosageAmount) < 5; 

        return SizedBox(
          width: itemWidth,
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(15)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(med['name'], style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 8),
                          Builder(
                            builder: (context) {
                              int adherence = med['adherence_score'] ?? 100;
                              
                              Color badgeColor = adherence >= 80 ? const Color(0xff00E676) 
                                               : adherence >= 50 ? Colors.orangeAccent 
                                               : Colors.redAccent;
                              
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: badgeColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
                                ),
                                child: Text(
                                  "$adherence%", 
                                  style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold)
                                ),
                              );
                            }
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text("${med['dosage']} $unit • ${(med['times'] as List).join(', ')}", style: const TextStyle(color: Colors.white54, fontSize: 13)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => _showMedicationDialog(existingMed: med), 
                          child: const Padding(padding: EdgeInsets.all(6.0), child: Icon(Icons.edit, color: Color(0xff00E5FF), size: 20)),
                        ),
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
                                  TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.white54))),
                                  TextButton(
                                    onPressed: () async {
                                      Navigator.pop(context);
                                      bool success = await ApiService.deleteMedication(med['id']);
                                      if (success) _silentRefresh();
                                    },
                                    child: const Text("Delete", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: const Padding(padding: EdgeInsets.all(6.0), child: Icon(Icons.delete_outline, color: Colors.white24, size: 20)),
                        ),
                      ],
                    ),
                    if (lowStock)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.orangeAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orangeAccent)),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 12),
                            const SizedBox(width: 4),
                            Text("$inventory left", style: const TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text("$inventory left", style: const TextStyle(color: Colors.white38, fontSize: 12)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}