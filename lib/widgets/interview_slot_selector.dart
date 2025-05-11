// lib/widgets/interview_slot_selector.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/interview_slot.dart';

class InterviewSlotSelector extends StatefulWidget {
  final Function(List<InterviewSlot>) onSlotsSelected;
  final DateTime? jobDeadline; // Add deadline parameter
  
  const InterviewSlotSelector({
    Key? key, 
    required this.onSlotsSelected,
    this.jobDeadline, // Add this parameter
  }) : super(key: key);
  
  @override
  State<InterviewSlotSelector> createState() => _InterviewSlotSelectorState();
}

class _InterviewSlotSelectorState extends State<InterviewSlotSelector> {
  List<DateTime> selectedDates = [];
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  String meetingLink = '';
  List<InterviewSlot> generatedSlots = [];
  
  // Custom date picker with multiple selection
  Future<void> _showMultipleDatePicker() async {
    // Determine the latest date for date picker
    DateTime lastDate = DateTime.now().add(Duration(days: 90));
    
    // If there's a job deadline, don't allow interview dates beyond the deadline
    if (widget.jobDeadline != null) {
      lastDate = widget.jobDeadline!;
    }
    
    final result = await showDialog<List<DateTime>>(
      context: context,
      builder: (BuildContext context) {
        return MultipleDatePickerDialog(
          initialDates: selectedDates,
          firstDate: DateTime.now(),
          lastDate: lastDate, // Updated to consider deadline
        );
      },
    );
    
    if (result != null) {
      setState(() {
        selectedDates = result;
        selectedDates.sort(); // Keep dates in order
      });
    }
  }
  
  void _generateTimeSlots() {
    if (selectedDates.isEmpty || startTime == null || endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select dates and time range')),
      );
      return;
    }
    
    // Check if any selected dates are beyond the deadline
    if (widget.jobDeadline != null) {
      for (DateTime date in selectedDates) {
        if (date.isAfter(widget.jobDeadline!)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please select interview dates before the job deadline (${DateFormat('MMM d, yyyy').format(widget.jobDeadline!)})'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
    }
    
    List<InterviewSlot> slots = [];
    
    for (DateTime date in selectedDates) {
      DateTime currentSlotStart = DateTime(
        date.year,
        date.month,
        date.day,
        startTime!.hour,
        startTime!.minute,
      );
      
      DateTime dayEndTime = DateTime(
        date.year,
        date.month,
        date.day,
        endTime!.hour,
        endTime!.minute,
      );
      
      while (currentSlotStart.isBefore(dayEndTime)) {
        DateTime slotEnd = currentSlotStart.add(Duration(minutes: 30));
        
        slots.add(InterviewSlot(
          id: '${date.millisecondsSinceEpoch}_${currentSlotStart.hour}_${currentSlotStart.minute}',
          startTime: currentSlotStart,
          endTime: slotEnd,
          meetingLink: meetingLink.isNotEmpty ? meetingLink : null,
        ));
        
        currentSlotStart = slotEnd;
      }
    }
    
    setState(() {
      generatedSlots = slots;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    // Check if job deadline has passed
    bool isDeadlinePassed = false;
    if (widget.jobDeadline != null) {
      isDeadlinePassed = DateTime.now().isAfter(widget.jobDeadline!);
    }
    
    if (isDeadlinePassed) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.red, size: 48),
          SizedBox(height: 16),
          Text(
            'Cannot set interview slots for this job',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'The job deadline (${DateFormat('MMM d, yyyy').format(widget.jobDeadline!)}) has passed.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red),
          ),
        ],
      );
    }
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Add deadline warning if close to deadline
          if (widget.jobDeadline != null) ...[
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              margin: EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Interview slots must be scheduled before the job deadline: ${DateFormat('MMM d, yyyy').format(widget.jobDeadline!)}',
                      style: TextStyle(color: Colors.blue.shade800),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // Multiple date picker
          Text(
            'Select Interview Dates:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          SizedBox(height: 8),
          ElevatedButton.icon(
            icon: Icon(Icons.calendar_today),
            onPressed: _showMultipleDatePicker,
            label: Text('Select Interview Dates'),
          ),
          
          // Show selected dates with ability to remove
          if (selectedDates.isNotEmpty) ...[
            SizedBox(height: 12),
            Text(
              'Selected Dates (${selectedDates.length}):',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: selectedDates.map((date) => Chip(
                label: Text(DateFormat('MMM d, yyyy').format(date)),
                deleteIcon: Icon(Icons.close, size: 18),
                onDeleted: () {
                  setState(() {
                    selectedDates.remove(date);
                  });
                },
                backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              )).toList(),
            ),
          ],
          
          SizedBox(height: 20),
          
          // Time range selector
          Text(
            'Set Time Range:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(Icons.access_time),
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(hour: 9, minute: 0),
                    );
                    if (picked != null) {
                      setState(() {
                        startTime = picked;
                      });
                    }
                  },
                  label: Text(startTime != null 
                    ? 'Start: ${startTime!.format(context)}'
                    : 'Select Start Time'),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(Icons.access_time),
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(hour: 17, minute: 0),
                    );
                    if (picked != null) {
                      setState(() {
                        endTime = picked;
                      });
                    }
                  },
                  label: Text(endTime != null 
                    ? 'End: ${endTime!.format(context)}'
                    : 'Select End Time'),
                ),
              ),
            ],
          ),
          
          SizedBox(height: 20),
          
          // Meeting link input
          Text(
            'Meeting Link:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          SizedBox(height: 8),
          TextField(
            decoration: InputDecoration(
              labelText: 'Meeting Link',
              hintText: 'https://meet.google.com/xyz-abc-def',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.link),
              suffixIcon: meetingLink.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          meetingLink = '';
                        });
                      },
                    )
                  : null,
            ),
            onChanged: (value) {
              setState(() {
                meetingLink = value;
              });
            },
          ),
          
          SizedBox(height: 24),
          
          // Generate slots button
          Center(
            child: ElevatedButton.icon(
              icon: Icon(Icons.schedule),
              onPressed: _generateTimeSlots,
              label: Text('Generate Time Slots'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ),
          
          // Preview generated slots
          if (generatedSlots.isNotEmpty) ...[
            SizedBox(height: 24),
            Divider(),
            Text(
              'Generated Slots (${generatedSlots.length} slots):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 8),
            Container(
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                padding: EdgeInsets.all(8),
                itemCount: generatedSlots.length,
                itemBuilder: (context, index) {
                  final slot = generatedSlots[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text('${index + 1}'),
                      ),
                      title: Text(DateFormat('MMM d, yyyy').format(slot.startTime)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${DateFormat('h:mm a').format(slot.startTime)} - ${DateFormat('h:mm a').format(slot.endTime)}'
                          ),
                          if (slot.meetingLink != null && slot.meetingLink!.isNotEmpty)
                            Text(
                              'Meeting Link: ${slot.meetingLink}',
                              style: TextStyle(fontSize: 12, color: Colors.blue),
                            ),
                        ],
                      ),
                      trailing: Icon(Icons.access_time, color: Colors.blue),
                    ),
                  );
                },
              ),
            ),
            
            SizedBox(height: 16),
            
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  icon: Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      generatedSlots.clear();
                    });
                  },
                  label: Text('Clear All'),
                ),
                ElevatedButton.icon(
                  icon: Icon(Icons.check),
                  onPressed: () {
                    widget.onSlotsSelected(generatedSlots);
                  },
                  label: Text('Confirm Slots'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// Custom Multiple Date Picker Dialog
class MultipleDatePickerDialog extends StatefulWidget {
  final List<DateTime> initialDates;
  final DateTime firstDate;
  final DateTime lastDate;
  
  const MultipleDatePickerDialog({
    Key? key,
    required this.initialDates,
    required this.firstDate,
    required this.lastDate,
  }) : super(key: key);
  
  @override
  State<MultipleDatePickerDialog> createState() => _MultipleDatePickerDialogState();
}

class _MultipleDatePickerDialogState extends State<MultipleDatePickerDialog> {
  late List<DateTime> selectedDates;
  late DateTime displayMonth;
  
  @override
  void initState() {
    super.initState();
    selectedDates = List.from(widget.initialDates);
    displayMonth = widget.firstDate;
  }
  
  void _toggleDateSelection(DateTime date) {
    setState(() {
      // Normalize the date to remove time component
      DateTime normalizedDate = DateTime(date.year, date.month, date.day);
      
      // Check if date is already selected
      int existingIndex = selectedDates.indexWhere((d) => 
        d.year == normalizedDate.year && 
        d.month == normalizedDate.month && 
        d.day == normalizedDate.day
      );
      
      if (existingIndex >= 0) {
        // Date is already selected, remove it
        selectedDates.removeAt(existingIndex);
      } else {
        // Date is not selected, add it
        selectedDates.add(normalizedDate);
      }
      
      selectedDates.sort();
    });
  }
  
  bool _isDateSelected(DateTime date) {
    return selectedDates.any((d) => 
      d.year == date.year && 
      d.month == date.month && 
      d.day == date.day
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Dates',
                    style: TextStyle(
                      color: const Color.fromARGB(190, 0, 0, 0),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${selectedDates.length} selected',
                    style: TextStyle(
                      color: const Color.fromARGB(190, 0, 0, 0),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            // Month navigation
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.chevron_left),
                    onPressed: () {
                      setState(() {
                        displayMonth = DateTime(displayMonth.year, displayMonth.month - 1);
                      });
                    },
                  ),
                  Text(
                    DateFormat('MMMM yyyy').format(displayMonth),
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  IconButton(
                    icon: Icon(Icons.chevron_right),
                    onPressed: () {
                      setState(() {
                        displayMonth = DateTime(displayMonth.year, displayMonth.month + 1);
                      });
                    },
                  ),
                ],
              ),
            ),
            
            // Calendar grid
            Container(
              height: 280,
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: _buildCalendarGrid(),
            ),
            
            // Action buttons
            Container(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Cancel'),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(selectedDates);
                    },
                    child: Text('OK'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCalendarGrid() {
    final daysInMonth = DateTime(displayMonth.year, displayMonth.month + 1, 0).day;
    final firstDay = DateTime(displayMonth.year, displayMonth.month, 1);
    final startingDay = firstDay.weekday % 7;
    
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.0,
      ),
      itemCount: 42, // 6 weeks
      itemBuilder: (context, index) {
        final day = index - startingDay + 1;
        
        if (day < 1 || day > daysInMonth) {
          return SizedBox(); // Empty cell
        }
        
        final date = DateTime(displayMonth.year, displayMonth.month, day);
        final isSelected = _isDateSelected(date);
        final isDisabled = date.isBefore(widget.firstDate) || date.isAfter(widget.lastDate);
        
        return GestureDetector(
          onTap: isDisabled ? null : () => _toggleDateSelection(date),
          child: Container(
            margin: EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected 
                  ? Theme.of(context).primaryColor 
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                day.toString(),
                style: TextStyle(
                  color: isSelected 
                      ? Colors.black 
                      : isDisabled 
                          ? Colors.grey 
                          : Colors.black,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}