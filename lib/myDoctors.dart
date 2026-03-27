import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:temanu/theme.dart';
import 'package:temanu/api_service.dart';
import 'package:temanu/notification_service.dart';

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
  final bool isRestricted;

  Doctor({
    required this.id,
    required this.name,
    required this.specialty,
    required this.qualifications,
    required this.clinicName,
    required this.communicationType,
    required this.communicationUrl,
    required this.imageUrl,
    this.isRestricted = false,
  });
}

class Appointment {
  final int id;
  final DateTime dateTime;
  final String status; 
  final String purpose;
  final String doctorName;
  final String doctorSpecialisation;
  bool hasReminder; 

  Appointment({
    required this.id, 
    required this.dateTime, 
    required this.status, 
    required this.purpose,
    required this.doctorName,
    required this.doctorSpecialisation,
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
// PAGE 1: MY DOCTORS LIST (WITH TABS)
// ==========================================
class MyDoctorsPage extends StatefulWidget {
  const MyDoctorsPage({super.key});

  @override
  State<MyDoctorsPage> createState() => _MyDoctorsPageState();
}

class _MyDoctorsPageState extends State<MyDoctorsPage> {
  bool _isLoadingDoctors = true;
  bool _isLoadingAppointments = true;
  int _pendingRequestsCount = 0;
  List<Doctor> _myDoctors = [];
  List<Appointment> _appointments = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    _fetchPendingRequests();
    _fetchLinkedDoctors();
    _fetchAppointments();
  }

  Future<void> _fetchPendingRequests() async {
    final requests = await ApiService.getPendingRequests();
    if (mounted) {
      setState(() {
        _pendingRequestsCount = requests.length;
      });
    }
  }

  Future<void> _fetchLinkedDoctors() async {
    setState(() => _isLoadingDoctors = true);
    final dbDoctors = await ApiService.getLinkedDoctors();
    
    final futures = dbDoctors.map((docData) async {
      final String docId = docData['id'].toString();
      final perms = await ApiService.getPermissions(docId);
      
      bool restricted = false;
      if (perms != null) {
        if (perms['can_view_heart_rate'] == false ||
            perms['can_view_blood_pressure'] == false ||
            perms['can_view_blood_glucose'] == false ||
            perms['can_view_oxygen_saturation'] == false ||
            perms['can_view_body_weight'] == false ||
            perms['can_view_medications'] == false ||
            perms['can_view_activity'] == false) {
          restricted = true;
        }
      }

      return Doctor(
        id: docId,
        name: docData['name'] ?? 'Unknown Doctor',
        specialty: docData['specialisation'] ?? 'General Practitioner',
        qualifications: docData['qualifications'] ?? '',
        clinicName: docData['clinic_name'] ?? 'Clinic',
        communicationType: docData['messaging_platform'] ?? 'WhatsApp',
        communicationUrl: docData['platform_link'] ?? '',
        imageUrl: docData['profile_image_url'] ?? '',
        isRestricted: restricted,
      );
    }).toList();

    final parsedDoctors = await Future.wait(futures);

    if (mounted) {
      setState(() {
        _myDoctors = parsedDoctors;
        _isLoadingDoctors = false;
      });
    }
  }

  Future<void> _fetchAppointments() async {
    setState(() => _isLoadingAppointments = true);
    final apptsData = await ApiService.getMyAppointments();
    final prefs = await SharedPreferences.getInstance();

    if (mounted) {
      setState(() {
        _appointments = apptsData.map((a) {
          final int id = a['id'];
          final hasReminder = prefs.getBool('reminder_$id') ?? false;
          
          // 1. Safely extract the nested doctor dictionary (default to empty map if null)
          final doctorInfo = a['doctor'] ?? {}; 

          return Appointment(
            id: id,
            dateTime: DateTime.parse(a['appointment_time']).toLocal(),
            status: a['status'] ?? 'Unknown',
            purpose: a['purpose'] ?? 'Consultation',
            
            // 2. Read the names and specialisation from the nested dictionary!
            doctorName: doctorInfo['preferred_name'] ?? doctorInfo['name'] ?? 'Unknown Doctor',
            doctorSpecialisation: doctorInfo['specialisation'] ?? '',
            
            hasReminder: hasReminder,
          );
        }).toList();
        _isLoadingAppointments = false;
      });
    }
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
          automaticallyImplyLeading: false,
          title: const Text(
            'My Care',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w600,
              color: AppTheme.secondaryColor,
            )
          ),
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(color: AppTheme.background.withOpacity(0.5)),
            ),
          ),
          bottom: const TabBar(
            indicatorColor: AppTheme.primaryColor,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorWeight: 3,
            tabs: [
              Tab(text: "Care Team"),
              Tab(text: "Appointments"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildCareTeamTab(),
            _buildAppointmentsTab(),
          ],
        ),
      ),
    );
  }

  // ─── TAB 1: CARE TEAM ───
  Widget _buildCareTeamTab() {
    if (_isLoadingDoctors && _pendingRequestsCount == 0 && _myDoctors.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
    }
    
    return RefreshIndicator(
      color: AppTheme.primaryColor,
      backgroundColor: AppTheme.cardBackground,
      onRefresh: _fetchData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          if (_pendingRequestsCount > 0) _buildPendingRequestsBanner(),
          if (_myDoctors.isEmpty && !_isLoadingDoctors)
            _buildEmptyStateDoctors()
          else
            ..._myDoctors.map((doc) => _buildDoctorCard(doc)),
        ],
      ),
    );
  }

  Widget _buildPendingRequestsBanner() {
    final bool isPlural = _pendingRequestsCount > 1;
    return GestureDetector(
      onTap: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (context) => const PendingRequestsPage()));
        _fetchData(); // refresh when returning
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        decoration: BoxDecoration(
          // Changed banner from blue/cyan accents to theme red
          color: AppTheme.primaryColor.withOpacity(0.15),
          border: Border.all(color: AppTheme.primaryColor, width: 1.5),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            const Icon(Icons.notifications_active, color: AppTheme.primaryColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isPlural ? '$_pendingRequestsCount doctors want to join your care team' : '1 doctor wants to join your care team',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            const Text("View", style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward_ios, color: AppTheme.primaryColor, size: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyStateDoctors() {
    return Center(
      heightFactor: 1.5,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.medical_services_outlined, size: 80, color: AppTheme.textSecondary.withOpacity(0.5)),
          const SizedBox(height: 20),
          const Text("No Doctors Linked", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text("Doctors can request to join your care team.", style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
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
          border: Border.all(color: AppTheme.textSecondary.withOpacity(0.1)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SafeProfileAvatar(
              imageUrl: doctor.imageUrl,
              name: doctor.name,
              radius: 30,
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
                  if (doctor.isRestricted) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('Restricted Data', style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                    )
                  ]
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.tune, color: AppTheme.primaryColor, size: 22),
                  onPressed: () => _openPermissionsSheet(doctor.id, doctor.name),
                  tooltip: 'Manage Permissions',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(8),
                ),
                IconButton(
                  icon: const Icon(Icons.person_remove, color: Colors.white38, size: 20),
                  onPressed: () => _showRemoveDialog(doctor),
                  tooltip: 'Remove from care team',
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(8),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _openPermissionsSheet(String doctorId, String doctorName, {int? requestIdForApproval}) async {
    Map<String, dynamic>? currentPerms;
    
    // If we're editing an existing doc, fetch their current permissions
    if (requestIdForApproval == null) {
      showDialog(context: context, barrierDismissible: false, builder: (ctx) => const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)));
      currentPerms = await ApiService.getPermissions(doctorId);
      if (mounted) Navigator.pop(context); // close loader
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PermissionsSheet(
        doctorId: doctorId,
        doctorName: doctorName,
        requestIdForApproval: requestIdForApproval,
        initialPerms: currentPerms,
        onSuccess: () {
          _fetchData();
        },
      )
    );
  }

  void _showRemoveDialog(Doctor doctor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove Doctor', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        content: Text(
          'Remove ${doctor.name} from your care team?\n\nThey will no longer be able to view your health data, medications, or medical records.',
          style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
        ),
        // Added padding to give the buttons some breathing room at the bottom
        actionsPadding: const EdgeInsets.only(left: 20, right: 20, bottom: 20, top: 10),
        actions: [
          Row(
            children: [
              // Cancel Button
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white12, // A subtle grey/transparent background
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
              
              const SizedBox(width: 12), // Spacing between the buttons
              
              // Remove Button
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context); // close dialog immediately
                    final success = await ApiService.removePersonalDoctor(doctor.id);
                    if (mounted) {
                      if (success) {
                        _fetchData(); // refresh everything
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('${doctor.name} removed from your care team'),
                          backgroundColor: const Color(0xff00E676),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: const Text('Failed to remove doctor. Please try again.'),
                          backgroundColor: Colors.redAccent,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent, 
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Remove', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── TAB 2: APPOINTMENTS ───
  Widget _buildAppointmentsTab() {
    if (_isLoadingAppointments) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
    
    final upcoming = _appointments.where((a) => a.status == 'Upcoming').toList();
    final past = _appointments.where((a) => a.status != 'Upcoming').toList();

    return RefreshIndicator(
      color: AppTheme.primaryColor,
      backgroundColor: AppTheme.cardBackground,
      onRefresh: _fetchAppointments,
      child: _appointments.isEmpty
          ? _buildEmptyStateAppointments()
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                if (upcoming.isNotEmpty) ...[
                  const Text("Upcoming", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...upcoming.map(_buildAppointmentCard),
                  const SizedBox(height: 20),
                ],
                if (past.isNotEmpty) ...[
                  const Text("Past", style: TextStyle(color: AppTheme.textSecondary, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...past.map(_buildAppointmentCard),
                ],
              ],
            ),
    );
  }

  Widget _buildEmptyStateAppointments() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_note, size: 80, color: AppTheme.textSecondary.withOpacity(0.5)),
          const SizedBox(height: 20),
          const Text("No Appointments", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text("Your doctor will schedule appointments here.", style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
        ],
            ),
    );
  }

  Widget _buildAppointmentCard(Appointment appt) {
    final isUpcoming = appt.status == 'Upcoming';
    final formattedDate = DateFormat('EEEE, d MMM yyyy · h:mm a').format(appt.dateTime);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.textSecondary.withOpacity(0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(appt.doctorName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                if (appt.doctorSpecialisation.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(appt.doctorSpecialisation, style: const TextStyle(color: AppTheme.primaryColor, fontSize: 13)),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.access_time, color: Colors.white54, size: 14),
                    const SizedBox(width: 4),
                    Text(formattedDate, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(appt.purpose, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isUpcoming ? const Color(0xff00E676).withOpacity(0.1) : (appt.status == 'Cancelled' ? Colors.redAccent.withOpacity(0.1) : Colors.white12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    appt.status,
                    style: TextStyle(
                      color: isUpcoming ? const Color(0xff00E676) : (appt.status == 'Cancelled' ? Colors.redAccent : Colors.white54),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isUpcoming)
            IconButton(
              icon: Icon(
                appt.hasReminder ? Icons.notifications : Icons.notifications_outlined,
                color: appt.hasReminder ? AppTheme.primaryColor : Colors.white54,
                size: 26,
              ),
              onPressed: () => _showReminderDialog(appt),
            ),
        ],
      ),
    );
  }

  void _showReminderDialog(Appointment appt) {
    int selectedOption = 0; 
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: AppTheme.cardBackground,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Set Reminder', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('When would you like to be reminded about this appointment?', style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 20),
                RadioListTile<int>(
                  value: 0,
                  groupValue: selectedOption,
                  onChanged: (v) => setDialogState(() => selectedOption = v!),
                  title: const Text('1 hour before', style: TextStyle(color: Colors.white)),
                  activeColor: AppTheme.primaryColor,
                  contentPadding: EdgeInsets.zero,
                ),
                RadioListTile<int>(
                  value: 1,
                  groupValue: selectedOption,
                  onChanged: (v) => setDialogState(() => selectedOption = v!),
                  title: const Text('1 day before', style: TextStyle(color: Colors.white)),
                  activeColor: AppTheme.primaryColor,
                  contentPadding: EdgeInsets.zero,
                ),
                RadioListTile<int>(
                  value: 2,
                  groupValue: selectedOption,
                  onChanged: (v) => setDialogState(() => selectedOption = v!),
                  title: const Text('Both (1 hour and 1 day)', style: TextStyle(color: Colors.white)),
                  activeColor: AppTheme.primaryColor,
                  contentPadding: EdgeInsets.zero,
                ),
                if (appt.hasReminder) ...[
                  const Divider(color: Colors.white24),
                  RadioListTile<int>(
                    value: 3,
                    groupValue: selectedOption,
                    onChanged: (v) => setDialogState(() => selectedOption = v!),
                    title: const Text('Cancel existing reminder', style: TextStyle(color: Colors.redAccent)),
                    activeColor: Colors.redAccent,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ],
            ),
            // --- UPDATED ACTIONS SECTION ---
            actionsPadding: const EdgeInsets.only(left: 20, right: 20, bottom: 20, top: 10),
            actions: [
              Row(
                children: [
                  // Cancel Button (Left)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white12, // Subtle background matching the theme
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  
                  const SizedBox(width: 12), // Spacing between buttons
                  
                  // Set Reminder / Confirm Button (Right)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _handleReminderSelection(appt, selectedOption, ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        selectedOption == 3 ? 'Confirm' : 'Set Reminder', 
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        }
      ),
    );
  }

  Future<void> _handleReminderSelection(Appointment appt, int option, BuildContext ctx) async {
    Navigator.pop(ctx);
    final prefs = await SharedPreferences.getInstance();
    final notifId = NotificationService.notificationIdFromAppointmentId(appt.id);
    
    if (option == 3) {
      await NotificationService.cancelReminder(notifId);
      await NotificationService.cancelReminder(notifId + 1); 
      await prefs.setBool('reminder_${appt.id}', false);
      setState(() => appt.hasReminder = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Reminder cancelled'),
          backgroundColor: Colors.white24,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
      return;
    }

    await NotificationService.cancelReminder(notifId); 
    await NotificationService.cancelReminder(notifId + 1);

    if (option == 0 || option == 2) {
      await NotificationService.scheduleAppointmentReminder(
        id: notifId,
        doctorName: appt.doctorName,
        purpose: appt.purpose,
        appointmentTime: appt.dateTime,
        minutesBefore: 60,
      );
    }
    if (option == 1 || option == 2) {
      await NotificationService.scheduleAppointmentReminder(
        id: notifId + 1,
        doctorName: appt.doctorName,
        purpose: appt.purpose,
        appointmentTime: appt.dateTime,
        minutesBefore: 1440,
      );
    }

    await prefs.setBool('reminder_${appt.id}', true);
    setState(() => appt.hasReminder = true);
    
    if (mounted) {
      String msg = option == 0 ? '1 hour before' : (option == 1 ? '1 day before' : '1 hour and 1 day before');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Reminder set for $msg'),
        backgroundColor: const Color(0xff00E676),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }
}

// ==========================================
// PENDING REQUESTS PAGE
// ==========================================
class PendingRequestsPage extends StatefulWidget {
  const PendingRequestsPage({super.key});

  @override
  State<PendingRequestsPage> createState() => _PendingRequestsPageState();
}

class _PendingRequestsPageState extends State<PendingRequestsPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    setState(() => _isLoading = true);
    final requests = await ApiService.getPendingRequests();
    if (mounted) {
      setState(() {
        _requests = requests;
        _isLoading = false;
      });
    }
  }

  Future<void> _declineRequest(int requestId) async {
    // Show confirmation
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        title: const Text("Decline Request", style: TextStyle(color: Colors.white)),
        content: const Text("Are you sure you want to decline this care team request?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("Decline", style: TextStyle(color: Colors.white)))
        ],
      )
    );

    if (confirm != true) return;
    
    // Proceed with decline
    final success = await ApiService.declineRequest(requestId);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request declined'), backgroundColor: Colors.white24));
      _fetchRequests();
    }
  }

  void _reviewAndAccept(int requestId, String doctorId, String doctorName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PermissionsSheet(
        doctorId: doctorId,
        doctorName: doctorName,
        requestIdForApproval: requestId,
        onSuccess: () {
          _fetchRequests();
        },
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text("Pending Requests", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
        : _requests.isEmpty
          ? const Center(child: Text("No pending requests.", style: TextStyle(color: Colors.white54, fontSize: 16)))
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _requests.length,
              itemBuilder: (context, index) {
                final req = _requests[index];
                final String docName = req['doctor_name'] ?? 'Doctor';
                final String docId = req['doctor_id'];
                final int reqId = req['id'];
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBackground,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.textSecondary.withOpacity(0.1)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          SafeProfileAvatar(
                            imageUrl: req['doctor_profile_image_url']?.toString() ?? '',
                            name: docName,
                            radius: 30,
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(docName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text(req['doctor_specialisation'] ?? 'Doctor', style: const TextStyle(color: AppTheme.primaryColor, fontSize: 13)),
                                const SizedBox(height: 2),
                                Text(req['doctor_clinic'] ?? 'Clinic', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      const Text("Wants to add you to their care team.", style: TextStyle(color: Colors.white, fontSize: 14)),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _declineRequest(reqId),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.redAccent,
                                side: const BorderSide(color: Colors.redAccent),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text("Decline", style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _reviewAndAccept(reqId, docId, docName),
                              style: ElevatedButton.styleFrom(
                                // Changed request buttons from blue to theme accents
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text("Review & Accept", style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                );
              },
            ),
    );
  }
}

// ==========================================
// PERMISSIONS SHEET WIDGET
// ==========================================
class PermissionsSheet extends StatefulWidget {
  final String doctorId;
  final String doctorName;
  final int? requestIdForApproval; // If not null -> Approving a request. If null -> Editing existing permissions.
  final Map<String, dynamic>? initialPerms;
  final VoidCallback onSuccess;

  const PermissionsSheet({
    super.key, 
    required this.doctorId, 
    required this.doctorName, 
    this.requestIdForApproval, 
    this.initialPerms,
    required this.onSuccess,
  });

  @override
  State<PermissionsSheet> createState() => _PermissionsSheetState();
}

class _PermissionsSheetState extends State<PermissionsSheet> {
  bool _hr = true;
  bool _bp = true;
  bool _bg = true;
  bool _spo2 = true;
  bool _weight = true;
  bool _meds = true;
  bool _activity = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialPerms != null) {
      _hr = widget.initialPerms!['can_view_heart_rate'] ?? true;
      _bp = widget.initialPerms!['can_view_blood_pressure'] ?? true;
      _bg = widget.initialPerms!['can_view_blood_glucose'] ?? true;
      _spo2 = widget.initialPerms!['can_view_oxygen_saturation'] ?? true;
      _weight = widget.initialPerms!['can_view_body_weight'] ?? true;
      _meds = widget.initialPerms!['can_view_medications'] ?? true;
      _activity = widget.initialPerms!['can_view_activity'] ?? true;
    }
  }

  void _toggleAll(bool value) {
    setState(() {
      _hr = value;
      _bp = value;
      _bg = value;
      _spo2 = value;
      _weight = value;
      _meds = value;
      _activity = value;
    });
  }

  Future<void> _submit() async {
    final Map<String, bool> perms = {
      'can_view_heart_rate': _hr,
      'can_view_blood_pressure': _bp,
      'can_view_blood_glucose': _bg,
      'can_view_oxygen_saturation': _spo2,
      'can_view_body_weight': _weight,
      'can_view_medications': _meds,
      'can_view_activity': _activity,
    };

    bool success = false;
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor)));

    if (widget.requestIdForApproval != null) {
      success = await ApiService.approveRequest(widget.requestIdForApproval!, perms);
    } else {
      success = await ApiService.updatePermissions(widget.doctorId, perms);
    }

    if (mounted) {
      Navigator.pop(context); // Close loading spinner
      if (success) {
        Navigator.pop(context); // Close bottom sheet
        widget.onSuccess();
        final msg = widget.requestIdForApproval != null 
            ? "${widget.doctorName} added to your care team" 
            : "Permissions updated";
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: const Color(0xff00E676),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Failed to save permissions. Please try again.'),
          backgroundColor: Colors.redAccent,
        ));
      }
    }
  }

  Widget _buildToggleRow(String label, IconData icon, bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.textSecondary.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 24),
          const SizedBox(width: 15),
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 15))),
          Switch(
            value: value,
            onChanged: onChanged,
            // Changed switch accent from blue to theme red
            activeColor: AppTheme.primaryColor,
            inactiveTrackColor: Colors.white12,
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool allOn = _hr && _bp && _bg && _spo2 && _weight && _meds && _activity;

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.background, // Match dark aesthetic
        borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
      ),
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 50,
              height: 5,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
            ),
          ),
          Text(widget.requestIdForApproval != null ? "Request Approval" : "Manage Permissions", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(
            widget.requestIdForApproval != null 
                ? "${widget.doctorName} wants to view your health data.\nChoose what information they can access:"
                : "Choose what data ${widget.doctorName} can access:", 
            style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4)
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => _toggleAll(!allOn),
                // Changed text accent from blue to theme red
                style: TextButton.styleFrom(foregroundColor: AppTheme.primaryColor),
                child: Text(allOn ? "Deselect All" : "Select All", style: const TextStyle(fontWeight: FontWeight.bold)),
              )
            ],
          ),
          Expanded(
            child: ListView(
              children: [
                _buildToggleRow("Heart Rate", Icons.favorite, _hr, (v) => setState(() => _hr = v)),
                _buildToggleRow("Blood Pressure", Icons.monitor_heart, _bp, (v) => setState(() => _bp = v)),
                _buildToggleRow("Blood Glucose", Icons.water_drop, _bg, (v) => setState(() => _bg = v)),
                // Changed icon from Icons.air to Icons.opacity
                _buildToggleRow("Oxygen Saturation", Icons.opacity, _spo2, (v) => setState(() => _spo2 = v)),
                _buildToggleRow("Body Weight", Icons.scale, _weight, (v) => setState(() => _weight = v)),
                _buildToggleRow("Medications", Icons.medication, _meds, (v) => setState(() => _meds = v)),
                _buildToggleRow("Activity & Steps", Icons.directions_walk, _activity, (v) => setState(() => _activity = v)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                // Changed button from blue accents to theme accents
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: Text(widget.requestIdForApproval != null ? "Accept & Add" : "Save Changes", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 20),
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

class _DoctorProfilePageState extends State<DoctorProfilePage> {
  bool _isLoadingRecords = true;
  List<MedicalRecord> _records = [];

  @override
  void initState() {
    super.initState();
    _fetchRecords();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            child: Container(color: AppTheme.background.withOpacity(0.5)),
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
              border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
            ),
            child: Column(
              children: [
                SafeProfileAvatar(
                  imageUrl: widget.doctor.imageUrl,
                  name: widget.doctor.name,
                  radius: 45, // Make it bigger for the profile page!
                  fontSize: 36,
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
                        side: BorderSide(color: AppTheme.textSecondary.withOpacity(0.2)),
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
          
          Container(
            padding: const EdgeInsets.all(20),
            alignment: Alignment.centerLeft,
            child: const Text("Medical Records", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          
          Expanded(
            child: _buildRecordsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordsList() {
    if (_isLoadingRecords) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));

    return Stack(
      children: [
        if (_records.isEmpty)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open_outlined, size: 60, color: Colors.white.withOpacity(0.2)),
                const SizedBox(height: 15),
                const Text("No Records Uploaded", style: TextStyle(color: Colors.white54, fontSize: 16)),
              ],
            ),
          )
        else
          ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            itemCount: _records.length,
            itemBuilder: (context, index) {
              final rec = _records[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: AppTheme.textSecondary.withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
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

  String _formatDate(DateTime dt) {
    return "${dt.day} ${_getMonth(dt.month)} ${dt.year}";
  }
}

class SafeProfileAvatar extends StatelessWidget {
  final String imageUrl;
  final String name;
  final double radius;
  final double fontSize;

  const SafeProfileAvatar({
    super.key,
    required this.imageUrl,
    required this.name,
    this.radius = 30,
    this.fontSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    final String initial = name.isNotEmpty ? name[0].toUpperCase() : 'D';

    return ClipOval(
      child: Container(
        width: radius * 2,
        height: radius * 2,
        color: AppTheme.primaryColor.withOpacity(0.2),
        child: imageUrl.isNotEmpty
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _fallbackLetter(initial),
              )
            : _fallbackLetter(initial),
      ),
    );
  }

  Widget _fallbackLetter(String letter) {
    return Center(
      child: Text(
        letter,
        style: TextStyle(
          color: AppTheme.primaryColor,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}