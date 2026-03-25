import 'dart:ui';
import 'dart:async'; // <-- NEW: for debounce timer
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:temanu/theme.dart';
import 'package:temanu/button.dart';
import 'package:temanu/api_service.dart'; 

// ==========================================
// DATA MODELS 
// ==========================================
class Doctor {
  final String id;
  final String name;
  final String specialty;
  final String qualifications;
  final String clinicName;
  final String communicationType; 
  final String communicationUrl;
  final String imageUrl;

  Doctor({
    required this.id,
    required this.name,
    required this.specialty,
    required this.qualifications,
    required this.clinicName,
    required this.communicationType,
    required this.communicationUrl,
    required this.imageUrl,
  });
}

class Appointment {
  final String id;
  final DateTime dateTime;
  final String status; 
  final String purpose;
  bool hasReminder; 

  Appointment({
    required this.id, 
    required this.dateTime, 
    required this.status, 
    required this.purpose,
    this.hasReminder = false, 
  });
}

class MedicalRecord {
  final String id;
  final String fileName;
  final DateTime uploadDate;
  final String type; 

  MedicalRecord({required this.id, required this.fileName, required this.uploadDate, required this.type});
}

// ==========================================
// PAGE 1: MY DOCTORS LIST
// ==========================================
class MyDoctorsPage extends StatefulWidget {
  const MyDoctorsPage({super.key});

  @override
  State<MyDoctorsPage> createState() => _MyDoctorsPageState();
}

class _MyDoctorsPageState extends State<MyDoctorsPage> {
  bool _isLoading = true;
  List<Doctor> _myDoctors = [];

  @override
  void initState() {
    super.initState();
    _fetchLinkedDoctors();
  }

  Future<void> _fetchLinkedDoctors() async {
    setState(() => _isLoading = true);
    
    final dbDoctors = await ApiService.getLinkedDoctors();
    
    if (mounted) {
      setState(() {
        _myDoctors = dbDoctors.map((docData) => Doctor(
          id: docData['id'].toString(),
          name: docData['name'] ?? 'Unknown Doctor',
          specialty: docData['specialisation'] ?? 'General Practitioner',
          qualifications: docData['qualifications'] ?? '',
          clinicName: docData['clinic_name'] ?? 'Clinic',
          communicationType: docData['messaging_platform'] ?? 'WhatsApp',
          communicationUrl: docData['platform_link'] ?? '',
          imageUrl: docData['profile_image_url'] ?? '',
        )).toList();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        title: const Text(
          'My Care Team',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w600,
            color: AppTheme.secondaryColor,
          )
        ),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Container(color: AppTheme.background.withValues(alpha: 0.5)),
          ),
        ),
        // --- NEW: Add Doctor Button ---
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppTheme.primaryColor),
            onPressed: () async {
              // Navigate to search page. When it pops back, refresh the list!
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchDoctorPage()),
              );
              _fetchLinkedDoctors();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : RefreshIndicator(
              color: AppTheme.primaryColor,
              backgroundColor: AppTheme.cardBackground,
              onRefresh: _fetchLinkedDoctors,
              child: _myDoctors.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      itemCount: _myDoctors.length,
                      itemBuilder: (context, index) {
                        return _buildDoctorCard(_myDoctors[index]);
                      },
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.medical_services_outlined, size: 80, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
          const SizedBox(height: 20),
          const Text("No Doctors Linked", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text("Tap the + icon to find your doctor.", style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildDoctorCard(Doctor doctor) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => DoctorProfilePage(doctor: doctor)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
              backgroundImage: doctor.imageUrl.isNotEmpty ? NetworkImage(doctor.imageUrl) : null,
              child: doctor.imageUrl.isEmpty 
                  ? Text(doctor.name.isNotEmpty ? doctor.name[0] : 'D', style: const TextStyle(color: AppTheme.primaryColor, fontSize: 24, fontWeight: FontWeight.bold))
                  : null,
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(doctor.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(doctor.specialty, style: const TextStyle(color: AppTheme.primaryColor, fontSize: 14)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.local_hospital, color: AppTheme.textSecondary, size: 14),
                      const SizedBox(width: 4),
                      Expanded(child: Text(doctor.clinicName, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// NEW PAGE: SEARCH DOCTORS DIRECTORY
// ==========================================
class SearchDoctorPage extends StatefulWidget {
  const SearchDoctorPage({super.key});

  @override
  State<SearchDoctorPage> createState() => _SearchDoctorPageState();
}

class _SearchDoctorPageState extends State<SearchDoctorPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Doctor> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Fetch all doctors on initial load
    _performSearch("");
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    // Wait 500ms after user stops typing to avoid spamming the API
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isSearching = true);
    
    final results = await ApiService.searchDoctors(query);
    
    if (mounted) {
      setState(() {
        _searchResults = results.map((docData) => Doctor(
          id: docData['id'].toString(),
          name: docData['name'] ?? 'Unknown Doctor',
          specialty: docData['specialisation'] ?? 'General Practitioner',
          qualifications: docData['qualifications'] ?? '',
          clinicName: docData['clinic_name'] ?? 'Clinic',
          communicationType: docData['messaging_platform'] ?? 'WhatsApp',
          communicationUrl: docData['platform_link'] ?? '',
          imageUrl: docData['profile_image_url'] ?? '',
        )).toList();
        _isSearching = false;
      });
    }
  }

  Future<void> _addDoctor(String doctorId) async {
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)));
    
    final success = await ApiService.linkDoctor(doctorId);
    
    if (mounted) {
      Navigator.pop(context); // Dismiss loading dialog
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Doctor added to Care Team!"), backgroundColor: Color(0xff00E676)));
        Navigator.pop(context); // Go back to MyDoctorsPage
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not add doctor. They may already be linked."), backgroundColor: Colors.redAccent));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        title: const Text("Directory", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(20),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Search by name, specialty, or clinic...",
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: AppTheme.cardBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          
          // Results
          Expanded(
            child: _isSearching
              ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
              : _searchResults.isEmpty
                ? const Center(child: Text("No doctors found.", style: TextStyle(color: Colors.white54, fontSize: 16)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final doc = _searchResults[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBackground,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 25,
                              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                              backgroundImage: doc.imageUrl.isNotEmpty ? NetworkImage(doc.imageUrl) : null,
                              child: doc.imageUrl.isEmpty 
                                  ? Text(doc.name.isNotEmpty ? doc.name[0] : 'D', style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold))
                                  : null,
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(doc.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2),
                                  Text(doc.specialty, style: const TextStyle(color: AppTheme.primaryColor, fontSize: 13)),
                                  const SizedBox(height: 4),
                                  Text(doc.clinicName, style: const TextStyle(color: Colors.white54, fontSize: 12), overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle, color: Color(0xff00E676), size: 30),
                              onPressed: () => _addDoctor(doc.id),
                            )
                          ],
                        ),
                      );
                    },
                  ),
          )
        ],
      ),
    );
  }
}

// ==========================================
// PAGE 3: DOCTOR PROFILE & RECORDS (Same as before)
// ==========================================
class DoctorProfilePage extends StatefulWidget {
  final Doctor doctor;

  const DoctorProfilePage({super.key, required this.doctor});

  @override
  State<DoctorProfilePage> createState() => _DoctorProfilePageState();
}

class _DoctorProfilePageState extends State<DoctorProfilePage> with SingleTickerProviderStateMixin {
  bool _isLoadingAppts = true;
  bool _isLoadingRecords = true;

  List<Appointment> _appointments = [];
  List<MedicalRecord> _records = [];
  
  String _appointmentFilter = 'Upcoming'; 

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
    _fetchRecords();
  }

  Future<void> _fetchAppointments() async {
    setState(() => _isLoadingAppts = true);
    
    final apptsData = await ApiService.getAppointments();
    
    if (mounted) {
      setState(() {
        _appointments = apptsData
            .where((a) => a['doctor_id'].toString() == widget.doctor.id)
            .map((a) => Appointment(
                  id: a['id'].toString(),
                  dateTime: DateTime.parse(a['appointment_time']).toLocal(),
                  status: a['status'] ?? 'Upcoming',
                  purpose: a['purpose'] ?? 'Consultation',
                  hasReminder: false, 
                ))
            .toList();
            
        _isLoadingAppts = false;
      });
    }
  }

  Future<void> _bookAppointment(DateTime date, String purpose) async {
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)));
    
    final success = await ApiService.bookAppointment(
      doctorId: widget.doctor.id,
      appointmentTime: date,
      purpose: purpose,
    );
    
    if (mounted) {
      Navigator.pop(context); 
      if (success) {
        await _fetchAppointments(); 
        setState(() {
          _appointmentFilter = 'Upcoming'; 
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Appointment Requested Successfully!"), backgroundColor: Color(0xff00E676)));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to book appointment. Please try again."), backgroundColor: Colors.redAccent));
      }
    }
  }

  void _toggleReminder(Appointment appt) {
    setState(() {
      appt.hasReminder = !appt.hasReminder;
    });
    
    if (appt.hasReminder) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Reminder set for ${appt.purpose}"), 
          backgroundColor: AppTheme.primaryColor,
          duration: const Duration(seconds: 2),
        )
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Reminder removed"), 
          backgroundColor: Colors.white24,
          duration: Duration(seconds: 2),
        )
      );
    }
  }

  Future<void> _fetchRecords() async {
    setState(() => _isLoadingRecords = true);
    
    final recordsData = await ApiService.getMedicalRecords();
    
    if (mounted) {
      setState(() {
        _records = recordsData
            .where((r) => r['doctor_id'].toString() == widget.doctor.id)
            .map((r) => MedicalRecord(
                  id: r['id'].toString(),
                  fileName: r['file_name'] ?? 'Document',
                  uploadDate: DateTime.parse(r['created_at']).toLocal(),
                  type: r['record_type'] ?? 'Uploaded Document',
                ))
            .toList();
            
        _isLoadingRecords = false;
      });
    }
  }

  Future<void> _uploadRecord() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png', 'jpeg'],
    );

    if (result != null) {
      showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)));
      
      String mockFileUrl = "https://example.com/mock_storage/${result.files.single.name}";
      
      final success = await ApiService.saveMedicalRecord(
        doctorId: widget.doctor.id,
        fileName: result.files.single.name,
        recordType: 'Uploaded Document',
        fileUrl: mockFileUrl,
      );
      
      if (mounted) {
        Navigator.pop(context); 
        if (success) {
          await _fetchRecords(); 
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Document Uploaded Securely"), backgroundColor: Color(0xff00E676)));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to upload document. Please try again."), backgroundColor: Colors.redAccent));
        }
      }
    }
  }

  Future<void> _launchCommunication() async {
    final Uri url = Uri.parse(widget.doctor.communicationUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch messaging app.'), backgroundColor: Colors.redAccent));
      }
    }
  }

  void _showBookingDialog() async {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 10, minute: 0);
    TextEditingController purposeController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 25, right: 25, top: 25),
              decoration: const BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Book Appointment", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Select Date", style: TextStyle(color: Colors.white70)),
                    subtitle: Text("${selectedDate.day}/${selectedDate.month}/${selectedDate.year}", style: const TextStyle(color: Colors.white, fontSize: 16)),
                    trailing: const Icon(Icons.calendar_today, color: AppTheme.primaryColor),
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setModalState(() => selectedDate = picked);
                    },
                  ),
                  Divider(color: Colors.white.withValues(alpha: 0.1)),
                  
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text("Select Time", style: TextStyle(color: Colors.white70)),
                    subtitle: Text(selectedTime.format(context), style: const TextStyle(color: Colors.white, fontSize: 16)),
                    trailing: const Icon(Icons.access_time, color: AppTheme.primaryColor),
                    onTap: () async {
                      final TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (picked != null) setModalState(() => selectedTime = picked);
                    },
                  ),
                  Divider(color: Colors.white.withValues(alpha: 0.1)),
                  
                  const SizedBox(height: 10),
                  TextField(
                    controller: purposeController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: "Reason for visit",
                      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                      enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryColor)),
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: MyRoundedButton(
                      text: "Request Appointment",
                      backgroundColor: AppTheme.primaryColor,
                      textColor: AppTheme.textPrimary,
                      onPressed: () {
                        if (purposeController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a reason for the visit.")));
                          return;
                        }
                        Navigator.pop(context);
                        
                        final finalDateTime = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, selectedTime.hour, selectedTime.minute);
                        _bookAppointment(finalDateTime, purposeController.text);
                      },
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          title: const Text(
            "Doctor Profile",
            style: TextStyle(color: AppTheme.primaryColor, fontSize: 22, fontWeight: FontWeight.w600),
          ),
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(color: AppTheme.background.withValues(alpha: 0.5)),
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppTheme.primaryColor),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Column(
          children: [
            // --- HEADER PROFILE SECTION ---
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 25),
              decoration: BoxDecoration(
                color: AppTheme.background,
                border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 45,
                    backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                    backgroundImage: widget.doctor.imageUrl.isNotEmpty ? NetworkImage(widget.doctor.imageUrl) : null,
                    child: widget.doctor.imageUrl.isEmpty 
                        ? Text(widget.doctor.name.isNotEmpty ? widget.doctor.name[0] : 'D', style: const TextStyle(color: AppTheme.primaryColor, fontSize: 36, fontWeight: FontWeight.bold))
                        : null,
                  ),
                  const SizedBox(height: 15),
                  Text(widget.doctor.name, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Text("${widget.doctor.specialty} • ${widget.doctor.clinicName}", style: const TextStyle(color: AppTheme.primaryColor, fontSize: 14)),
                  const SizedBox(height: 15),
                  Text(
                    widget.doctor.qualifications,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.cardBackground,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: BorderSide(color: AppTheme.textSecondary.withValues(alpha: 0.2)),
                        ),
                        elevation: 0,
                      ),
                      icon: Icon(widget.doctor.communicationType.toLowerCase() == 'whatsapp' ? Icons.chat : Icons.send, size: 20, color: const Color(0xff00E676)),
                      label: Text("Message on ${widget.doctor.communicationType}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _launchCommunication,
                    ),
                  ),
                ],
              ),
            ),
            
            const TabBar(
              indicatorColor: AppTheme.primaryColor,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorWeight: 3,
              tabs: [
                Tab(text: "Appointments"),
                Tab(text: "Medical Records"),
              ],
            ),
            
            Expanded(
              child: TabBarView(
                children: [
                  _buildAppointmentsTab(),
                  _buildRecordsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: APPOINTMENTS
  // ==========================================
  Widget _buildAppointmentsTab() {
    if (_isLoadingAppts) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));

    final filteredAppts = _appointments.where((appt) {
      if (_appointmentFilter == 'Upcoming') {
        return appt.status == 'Upcoming';
      } else {
        return appt.status == 'Completed' || appt.status == 'Cancelled';
      }
    }).toList();

    return Stack(
      children: [
        Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                children: [
                  _buildFilterChip('Upcoming'),
                  const SizedBox(width: 10),
                  _buildFilterChip('Past'),
                ],
              ),
            ),
            
            Expanded(
              child: filteredAppts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_busy, size: 60, color: Colors.white.withValues(alpha: 0.2)),
                        const SizedBox(height: 15),
                        Text("No $_appointmentFilter Appointments", style: const TextStyle(color: Colors.white54, fontSize: 16)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                    itemCount: filteredAppts.length,
                    itemBuilder: (context, index) {
                      final appt = filteredAppts[index];
                      final isUpcoming = appt.status == 'Upcoming';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBackground,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(15)),
                              child: Column(
                                children: [
                                  Text(_getMonth(appt.dateTime.month), style: const TextStyle(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
                                  Text(appt.dateTime.day.toString(), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(appt.purpose, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 5),
                                  Row(
                                    children: [
                                      const Icon(Icons.access_time, color: Colors.white54, size: 14),
                                      const SizedBox(width: 4),
                                      Text(_formatTime(appt.dateTime), style: const TextStyle(color: Colors.white54, fontSize: 13)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (isUpcoming) 
                              IconButton(
                                icon: Icon(
                                  appt.hasReminder ? Icons.notifications_active : Icons.notifications_none,
                                  color: appt.hasReminder ? AppTheme.primaryColor : Colors.white54,
                                ),
                                onPressed: () => _toggleReminder(appt),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                                child: Text(appt.status, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
            ),
          ],
        ),
        
        Positioned(
          bottom: 30,
          left: 20,
          right: 20,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            onPressed: _showBookingDialog,
            child: const Text("Book New Appointment", style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _appointmentFilter == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _appointmentFilter = label);
      },
      backgroundColor: AppTheme.background,
      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2), 
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primaryColor : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary.withValues(alpha: 0.2),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  // ==========================================
  // TAB 2: MEDICAL RECORDS
  // ==========================================
  Widget _buildRecordsTab() {
    if (_isLoadingRecords) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));

    return Stack(
      children: [
        if (_records.isEmpty)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open_outlined, size: 60, color: Colors.white.withValues(alpha: 0.2)),
                const SizedBox(height: 15),
                const Text("No Records Uploaded", style: TextStyle(color: Colors.white54, fontSize: 16)),
              ],
            ),
          )
        else
          ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            itemCount: _records.length,
            itemBuilder: (context, index) {
              final rec = _records[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: AppTheme.textSecondary.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10)),
                      child: Icon(
                        rec.fileName.endsWith('.pdf') ? Icons.picture_as_pdf : Icons.image, 
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(rec.fileName, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text("${rec.type} • ${_formatDate(rec.uploadDate)}", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.download_rounded, color: Colors.white70),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Downloading ${rec.fileName}...")));
                      },
                    ),
                  ],
                ),
              );
            },
          ),

        Positioned(
          bottom: 30,
          left: 20,
          right: 20,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              backgroundColor: AppTheme.cardBackground,
              foregroundColor: Colors.white,
              side: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            icon: const Icon(Icons.upload_file, color: AppTheme.primaryColor),
            label: const Text("Upload Lab Result / Report", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            onPressed: _uploadRecord,
          ),
        ),
      ],
    );
  }

  String _getMonth(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  String _formatTime(DateTime dt) {
    int hour = dt.hour;
    String ampm = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;
    String minute = dt.minute.toString().padLeft(2, '0');
    return "$hour:$minute $ampm";
  }

  String _formatDate(DateTime dt) {
    return "${dt.day} ${_getMonth(dt.month)} ${dt.year}";
  }
}