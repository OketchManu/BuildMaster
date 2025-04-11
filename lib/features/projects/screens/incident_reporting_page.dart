import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class IncidentReportingPage extends StatefulWidget {
  const IncidentReportingPage({super.key});

  @override
  IncidentReportingPageState createState() => IncidentReportingPageState();
}

class IncidentReportingPageState extends State<IncidentReportingPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  List<String> incidentTypes = [
    'Safety Hazard',
    'Security Breach',
    'Equipment Failure',
    'Environmental Issue',
    'Other'
  ];
  String? selectedIncidentType;

  List<String> severityLevels = ['Low', 'Medium', 'High', 'Critical'];
  String? selectedSeverityLevel;

  bool _isSubmitting = false;
  String? _lastSavedReportPath;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<String> _saveReportLocally(Map<String, dynamic> incidentData) async {
    try {
      if (await Permission.storage.request().isGranted) {
        final directory = await getExternalStorageDirectory();
        if (directory == null) throw Exception('Could not access storage');
        
        final filePath = '${directory.path}/incident_${DateTime.now().millisecondsSinceEpoch}.txt';
        final file = File(filePath);
        
        final reportContent = '''
Incident Report
Title: ${incidentData['title']}
Type: ${incidentData['incidentType']}
Severity: ${incidentData['severityLevel']}
Location: ${incidentData['location']}
Description: ${incidentData['description']}
Reported by: ${incidentData['email']}
Date: ${DateTime.now().toString()}
''';
        
        await file.writeAsString(reportContent);
        return filePath;
      } else {
        throw Exception('Storage permission denied');
      }
    } catch (e) {
      throw Exception('Failed to save report locally: $e');
    }
  }

  Future<void> _submitIncident() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        throw Exception('User not authenticated');
      }

      bool hasInternet = await _checkInternetConnection();
      if (!hasInternet) {
        throw Exception('No internet connection');
      }

      final incidentData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'location': _locationController.text.trim(),
        'incidentType': selectedIncidentType,
        'severityLevel': selectedSeverityLevel,
        'email': user.email,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
        'createdBy': user.uid,
        'createdByEmail': user.email,
      };

      // Save to Firestore
      await FirebaseFirestore.instance.collection('incidents').add(incidentData);

      // Save locally and store the path
      _lastSavedReportPath = await _saveReportLocally(incidentData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incident Submitted and Saved Successfully'),
            backgroundColor: Colors.green,
          ),
        );

        _formKey.currentState!.reset();
        setState(() {
          selectedIncidentType = null;
          selectedSeverityLevel = null;
          _isSubmitting = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error during submission: $e');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _downloadLastReport() {
    if (_lastSavedReportPath != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Report saved at: $_lastSavedReportPath'),
          backgroundColor: Colors.blue,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No report available to download'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Incident Reporting'),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: user == null
            ? const Center(
                child: Card(
                  color: Colors.grey,
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('Please sign in to submit an incident report.'),
                  ),
                ),
              )
            : Form(
                key: _formKey,
                child: Card(
                  color: Colors.grey[800],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.report_problem, size: 80, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Incident Report Form',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(color: Colors.white),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            labelText: 'Incident Title',
                            prefixIcon: const Icon(Icons.title),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            filled: true,
                            fillColor: Colors.grey[700],
                          ),
                          style: const TextStyle(color: Colors.white),
                          validator: (value) =>
                              value?.trim().isEmpty ?? true ? 'Please enter a title' : null,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: 'Incident Type',
                            prefixIcon: const Icon(Icons.category),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            filled: true,
                            fillColor: Colors.grey[700],
                          ),
                          value: selectedIncidentType,
                          items: incidentTypes
                              .map((type) => DropdownMenuItem(
                                    value: type,
                                    child: Text(type, style: const TextStyle(color: Colors.white)),
                                  ))
                              .toList(),
                          onChanged: (value) => setState(() => selectedIncidentType = value),
                          validator: (value) => value == null ? 'Select a type' : null,
                          dropdownColor: Colors.grey[800],
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: 'Severity Level',
                            prefixIcon: const Icon(Icons.warning),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            filled: true,
                            fillColor: Colors.grey[700],
                          ),
                          value: selectedSeverityLevel,
                          items: severityLevels
                              .map((level) => DropdownMenuItem(
                                    value: level,
                                    child: Text(level, style: const TextStyle(color: Colors.white)),
                                  ))
                              .toList(),
                          onChanged: (value) => setState(() => selectedSeverityLevel = value),
                          validator: (value) => value == null ? 'Select a level' : null,
                          dropdownColor: Colors.grey[800],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _locationController,
                          decoration: InputDecoration(
                            labelText: 'Incident Location',
                            prefixIcon: const Icon(Icons.location_on),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            filled: true,
                            fillColor: Colors.grey[700],
                          ),
                          style: const TextStyle(color: Colors.white),
                          validator: (value) =>
                              value?.trim().isEmpty ?? true ? 'Enter a location' : null,
                        ),
                        const SizedBox(height: 16),
                        Text('Reported by: ${user.email ?? 'Not available'}',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.white70)),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: 'Incident Description',
                            prefixIcon: const Icon(Icons.description),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            filled: true,
                            fillColor: Colors.grey[700],
                          ),
                          style: const TextStyle(color: Colors.white),
                          validator: (value) =>
                              value?.trim().isEmpty ?? true ? 'Enter a description' : null,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitIncident,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Submit Incident Report',
                                  style: TextStyle(fontSize: 16, color: Colors.white)),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _lastSavedReportPath != null ? _downloadLastReport : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Download Last Report',
                              style: TextStyle(fontSize: 16, color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}