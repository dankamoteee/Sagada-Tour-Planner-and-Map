import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/poi_search_delegate.dart'; // Ensure this path is correct

class EventEditorScreen extends StatefulWidget {
  final String itineraryId;
  final DocumentSnapshot? eventDoc; // Pass the event document if editing
  final Map<String, dynamic>? initialPoiData;

  const EventEditorScreen({
    super.key,
    required this.itineraryId,
    this.eventDoc,
    this.initialPoiData,
  });

  @override
  State<EventEditorScreen> createState() => _EventEditorScreenState();
}

class _EventEditorScreenState extends State<EventEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  bool get _isEditing => widget.eventDoc != null;

  // Form controllers and state variables
  final TextEditingController _notesController = TextEditingController();
  DateTime? _selectedDateTime;
  Map<String, dynamic>? _selectedDestination;
  Map<String, dynamic>? _selectedStartPoint;
  bool _includeStartPoint = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // If we are editing an existing event, pre-fill the form
    if (_isEditing) {
      final data = widget.eventDoc!.data() as Map<String, dynamic>;
      _notesController.text = data['notes'] ?? '';
      _selectedDateTime = (data['eventTime'] as Timestamp?)?.toDate();
      _includeStartPoint = data['hasStartDestination'] ?? false;

      // Store POI data for display
      _selectedDestination = {
        'id': data['destinationPoiId'],
        'name': data['destinationPoiName'],
      };
      if (_includeStartPoint) {
        _selectedStartPoint = {
          'id': data['startPoiId'],
          'name': data['startPoiName'],
        };
      }
    } else if (widget.initialPoiData != null) {
      // --- THIS IS THE NEW LOGIC FOR "ADD TO PLAN" ---
      // Pre-fill the destination with the data passed from the POI sheet
      setState(() {
        _selectedDestination = {
          'id': widget.initialPoiData!['id'],
          'name': widget.initialPoiData!['name'],
        };
        // Set a default day and time
        _selectedDateTime = DateTime.now();
      });
    }
  }

  // --- UI HELPER: To select a POI using search ---
  Future<void> _selectPoi(bool isDestination) async {
    final result = await showSearch<Map<String, dynamic>?>(
      context: context,
      delegate: POISearchDelegate(),
    );
    if (result != null) {
      setState(() {
        if (isDestination) {
          _selectedDestination = result;
        } else {
          _selectedStartPoint = result;
        }
      });
    }
  }

  // --- UI HELPER: To show date and time pickers ---
  Future<void> _selectDateTime() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) return;

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime ?? DateTime.now()),
    );
    if (time != null) {
      setState(() {
        _selectedDateTime = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
      });
    }
  }

  // --- FIRESTORE LOGIC: To save or update the event ---
  // In event_editor_screen.dart -> inside _EventEditorScreenState

  // In lib/screens/event_editor_screen.dart -> inside _EventEditorScreenState

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDestination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a destination.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // --- START OF SIMPLIFIED LOGIC ---

    // 1. Create the event data map with default values.
    final Map<String, dynamic> eventData = {
      'eventTime':
          _selectedDateTime != null
              ? Timestamp.fromDate(_selectedDateTime!)
              : Timestamp.now(),
      'destinationPoiId': _selectedDestination!['id'],
      'destinationPoiName': _selectedDestination!['name'],
      'hasStartDestination': _includeStartPoint,
      'startPoiId': null,
      'startPoiName': null,
      'notes': _notesController.text,
      'userId': user.uid,
    };

    // 2. Use a simple 'if' statement to add the start point data.
    // This is clearer and avoids any compiler confusion.
    if (_includeStartPoint && _selectedStartPoint != null) {
      eventData['startPoiId'] = _selectedStartPoint!['id'];
      eventData['startPoiName'] = _selectedStartPoint!['name'];
    }

    // --- END OF SIMPLIFIED LOGIC ---

    final itineraryRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('itineraries')
        .doc(widget.itineraryId);

    try {
      final batch = FirebaseFirestore.instance.batch();
      batch.set(itineraryRef, {
        'lastModified': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (_isEditing) {
        final eventRef = itineraryRef
            .collection('events')
            .doc(widget.eventDoc!.id);
        batch.update(eventRef, eventData);
      } else {
        final newEventRef = itineraryRef.collection('events').doc();
        eventData['order'] = DateTime.now().millisecondsSinceEpoch;
        batch.set(newEventRef, eventData);
      }

      await batch.commit();

      if (mounted) {
        final successMessage =
            _isEditing
                ? "Updated '${eventData['destinationPoiName']}'"
                : "Added '${eventData['destinationPoiName']}' to your plan!";
        Navigator.pop(context, successMessage);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save event: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- FIRESTORE LOGIC: To delete the event ---
  Future<void> _deleteEvent() async {
    if (!_isEditing) return;

    // 1. Show a confirmation dialog to the user
    final bool? didConfirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Event?'),
            content: const Text(
              'Are you sure you want to permanently delete this event from your itinerary?',
            ),
            actions: [
              TextButton(
                child: const Text('Cancel'),
                onPressed:
                    () => Navigator.of(context).pop(false), // Return false
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
                onPressed: () => Navigator.of(context).pop(true), // Return true
              ),
            ],
          ),
    );

    // 2. Only proceed if the user confirmed
    if (didConfirm == true) {
      try {
        // Delete the document from Firestore
        await widget.eventDoc!.reference.delete();

        // Pop the screen and send back a success message
        if (mounted) {
          Navigator.pop(context, 'Event deleted successfully!');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to delete event: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Event' : 'Add New Event'),
        actions: [
          if (_isEditing)
            IconButton(icon: const Icon(Icons.delete), onPressed: _deleteEvent),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Day Number
            const SizedBox(height: 16),
            // Date and Time
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey.shade400),
              ),
              leading: const Icon(Icons.calendar_today),
              title: const Text('Date & Time'),
              subtitle: Text(
                _selectedDateTime != null
                    ? DateFormat.yMMMd().add_jm().format(_selectedDateTime!)
                    : 'Tap to select',
              ),
              onTap: _selectDateTime,
            ),
            const SizedBox(height: 16),
            // Destination
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey.shade400),
              ),
              leading: const Icon(Icons.location_on, color: Colors.red),
              title: const Text('Destination'),
              subtitle: Text(
                _selectedDestination?['name'] ?? 'Tap to select a destination',
              ),
              trailing: const Icon(Icons.search),
              onTap: () => _selectPoi(true),
            ),
            const SizedBox(height: 16),
            // Include Start Point Checkbox
            CheckboxListTile(
              title: const Text('Include Starting Destination'),
              value: _includeStartPoint,
              onChanged:
                  (value) =>
                      setState(() => _includeStartPoint = value ?? false),
            ),
            // Start Point (conditional)
            if (_includeStartPoint)
              Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade400),
                  ),
                  leading: const Icon(Icons.my_location, color: Colors.green),
                  title: const Text('Starting Point'),
                  subtitle: Text(
                    _selectedStartPoint?['name'] ??
                        'Tap to select a starting point',
                  ),
                  trailing: const Icon(Icons.search),
                  onTap: () => _selectPoi(false),
                ),
              ),
            // Notes
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            // Save Button
            ElevatedButton(
              onPressed: _isLoading ? null : _saveEvent,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child:
                  _isLoading
                      ? const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      )
                      : Text(_isEditing ? 'Update Event' : 'Add Event'),
            ),
          ],
        ),
      ),
    );
  }
}
