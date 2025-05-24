// // lib/widgets/interview_slot_selector.dart
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import '../models/interview_slot.dart';

// class InterviewSlotSelector extends StatefulWidget {
//   final Function(List<InterviewSlot>) onSlotsSelected;
//   final DateTime? jobDeadline;
  
//   const InterviewSlotSelector({
//     Key? key, 
//     required this.onSlotsSelected,
//     this.jobDeadline,
//   }) : super(key: key);
  
//   @override
//   State<InterviewSlotSelector> createState() => _InterviewSlotSelectorState();
// }

// class _InterviewSlotSelectorState extends State<InterviewSlotSelector> {
//   List<DateTime> selectedDates = [];
//   TimeInterval? startTime;
//   TimeInterval? endTime;
//   String meetingLink = '';
//   List<InterviewSlot> generatedSlots = [];
  
//   // Custom date picker with better error handling
//   Future<void> _showMultipleDatePicker() async {
//     try {
//       // Determine the latest date for date picker
//       DateTime lastDate = DateTime.now().add(Duration(days: 90));
      
//       // If there's a job deadline, don't allow interview dates beyond the deadline
//       if (widget.jobDeadline != null) {
//         lastDate = widget.jobDeadline!;
//       }
      
//       final result = await showDialog<List<DateTime>>(
//         context: context,
//         barrierDismissible: true,
//         builder: (BuildContext context) {
//           return Material(
//             type: MaterialType.transparency,
//             child: MultipleDatePickerDialog(
//               initialDates: selectedDates,
//               firstDate: DateTime.now(),
//               lastDate: lastDate,
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // Simplified Calendar Grid to avoid the rendering problems
// class SimplifiedCalendarGrid extends StatelessWidget {
//   final DateTime displayMonth;
//   final DateTime firstDate;
//   final DateTime lastDate;
//   final List<DateTime> selectedDates;
//   final Function(DateTime) onDateSelected;
  
//   const SimplifiedCalendarGrid({
//     Key? key,
//     required this.displayMonth,
//     required this.firstDate,
//     required this.lastDate,
//     required this.selectedDates,
//     required this.onDateSelected,
//   }) : super(key: key);
  
//   @override
//   Widget build(BuildContext context) {
//     // Build the days of the week headers
//     final daysOfWeek = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
//     final daysInMonth = DateTime(displayMonth.year, displayMonth.month + 1, 0).day;
//     final firstDay = DateTime(displayMonth.year, displayMonth.month, 1);
//     final startingDayOffset = firstDay.weekday % 7;
    
//     return Column(
//       children: [
//         // Days of week headers
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceAround,
//           children: daysOfWeek.map((day) => 
//             Expanded(
//               child: Center(
//                 child: Text(
//                   day,
//                   style: TextStyle(fontWeight: FontWeight.bold),
//                 ),
//               ),
//             )
//           ).toList(),
//         ),
//         SizedBox(height: 8),
        
//         // Calendar grid
//         Expanded(
//           child: GridView.builder(
//             shrinkWrap: true,
//             physics: NeverScrollableScrollPhysics(),
//             gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//               crossAxisCount: 7,
//               childAspectRatio: 1.0,
//             ),
//             itemCount: 42, // 6 weeks
//             itemBuilder: (context, index) {
//               final day = index - startingDayOffset + 1;
              
//               if (day < 1 || day > daysInMonth) {
//                 return SizedBox(); // Empty cell
//               }
              
//               final date = DateTime(displayMonth.year, displayMonth.month, day);
//               final isSelected = _isDateSelected(date);
//               final isDisabled = date.isBefore(firstDate) || date.isAfter(lastDate);
              
//               return GestureDetector(
//                 onTap: isDisabled ? null : () => onDateSelected(date),
//                 child: Container(
//                   margin: EdgeInsets.all(2),
//                   decoration: BoxDecoration(
//                     color: isSelected 
//                         ? Theme.of(context).primaryColor 
//                         : Colors.transparent,
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   child: Center(
//                     child: Text(
//                       day.toString(),
//                       style: TextStyle(
//                         color: isSelected 
//                             ? Colors.black 
//                             : isDisabled 
//                                 ? Colors.grey 
//                                 : Colors.black,
//                         fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
//                       ),
//                     ),
//                   ),
//                 ),
//               );
//             },
//           ),
//         ),
//       ],
//     );
//   }
  
//   bool _isDateSelected(DateTime date) {
//     return selectedDates.any((d) => 
//       d.year == date.year && 
//       d.month == date.month && 
//       d.day == date.day
//     );
//   }
// }
//           );
//         },
//       );
      
//       if (result != null) {
//         setState(() {
//           selectedDates = result;
//           selectedDates.sort();
//         });
//       }
//     } catch (e) {
//       print('Error in date picker: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error selecting dates. Please try again.')),
//       );
//     }
//   }
  
//   // Show custom time picker with better error handling
//   Future<void> _showCustomTimePicker(bool isStartTime) async {
//     try {
//       final result = await showDialog<TimeInterval>(
//         context: context,
//         barrierDismissible: true,
//         builder: (BuildContext context) {
//           return Material(
//             type: MaterialType.transparency,
//             child: CustomTimePickerDialog(
//               initialTime: isStartTime ? startTime : endTime,
//               title: isStartTime ? 'Select Start Time' : 'Select End Time',
//             ),
//           );
//         },
//       );
      
//       if (result != null) {
//         setState(() {
//           if (isStartTime) {
//             startTime = result;
//             // If start time is set after end time, clear end time
//             if (endTime != null && result.totalMinutes >= endTime!.totalMinutes) {
//               endTime = null;
//             }
//           } else {
//             endTime = result;
//           }
//         });
//       }
//     } catch (e) {
//       print('Error in time picker: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error selecting time. Please try again.')),
//       );
//     }
//   }
  
//   void _generateTimeSlots() {
//     try {
//       if (selectedDates.isEmpty || startTime == null || endTime == null) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Please select dates and time range')),
//         );
//         return;
//       }
      
//       // Check if any selected dates are beyond the deadline
//       if (widget.jobDeadline != null) {
//         for (DateTime date in selectedDates) {
//           if (date.isAfter(widget.jobDeadline!)) {
//             ScaffoldMessenger.of(context).showSnackBar(
//               SnackBar(
//                 content: Text('Please select interview dates before the job deadline (${DateFormat('MMM d, yyyy').format(widget.jobDeadline!)})'),
//                 backgroundColor: Colors.red,
//               ),
//             );
//             return;
//           }
//         }
//       }
      
//       // Validate start time is before end time
//       if (startTime!.totalMinutes >= endTime!.totalMinutes) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Start time must be before end time'),
//             backgroundColor: Colors.red,
//           ),
//         );
//         return;
//       }
      
//       List<InterviewSlot> slots = [];
      
//       for (DateTime date in selectedDates) {
//         DateTime currentSlotStart = DateTime(
//           date.year,
//           date.month,
//           date.day,
//           startTime!.hour,
//           startTime!.minute,
//         );
        
//         DateTime dayEndTime = DateTime(
//           date.year,
//           date.month,
//           date.day,
//           endTime!.hour,
//           endTime!.minute,
//         );
        
//         while (currentSlotStart.isBefore(dayEndTime)) {
//           DateTime slotEnd = currentSlotStart.add(Duration(minutes: 30));
          
//           // Don't create slot if it goes beyond the end time
//           if (slotEnd.isAfter(dayEndTime)) break;
          
//           slots.add(InterviewSlot(
//             id: '${date.millisecondsSinceEpoch}_${currentSlotStart.hour}_${currentSlotStart.minute}',
//             startTime: currentSlotStart,
//             endTime: slotEnd,
//             meetingLink: meetingLink.isNotEmpty ? meetingLink : null,
//           ));
          
//           currentSlotStart = slotEnd;
//         }
//       }
      
//       setState(() {
//         generatedSlots = slots;
//       });
//     } catch (e) {
//       print('Error generating slots: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error generating time slots. Please try again.')),
//       );
//     }
//   }
  
//   @override
//   Widget build(BuildContext context) {
//     // Check if job deadline has passed
//     bool isDeadlinePassed = false;
//     if (widget.jobDeadline != null) {
//       isDeadlinePassed = DateTime.now().isAfter(widget.jobDeadline!);
//     }
    
//     if (isDeadlinePassed) {
//       return Container(
//         constraints: BoxConstraints(maxHeight: 300),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Icon(Icons.error_outline, color: Colors.red, size: 48),
//             SizedBox(height: 16),
//             Text(
//               'Cannot set interview slots for this job',
//               style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
//             ),
//             SizedBox(height: 8),
//             Text(
//               'The job deadline (${DateFormat('MMM d, yyyy').format(widget.jobDeadline!)}) has passed.',
//               textAlign: TextAlign.center,
//               style: TextStyle(color: Colors.red),
//             ),
//           ],
//         ),
//       );
//     }
    
//     return Container(
//       constraints: BoxConstraints(
//         maxHeight: MediaQuery.of(context).size.height * 0.8,
//         maxWidth: MediaQuery.of(context).size.width * 0.9,
//       ),
//       child: SingleChildScrollView(
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             // Add deadline warning if close to deadline
//             if (widget.jobDeadline != null) ...[
//               Container(
//                 width: double.infinity,
//                 padding: EdgeInsets.all(12),
//                 margin: EdgeInsets.only(bottom: 16),
//                 decoration: BoxDecoration(
//                   color: Colors.blue.shade50,
//                   borderRadius: BorderRadius.circular(8),
//                   border: Border.all(color: Colors.blue.shade200),
//                 ),
//                 child: Row(
//                   children: [
//                     Icon(Icons.info_outline, color: Colors.blue.shade700),
//                     SizedBox(width: 8),
//                     Expanded(
//                       child: Text(
//                         'Interview slots must be scheduled before the job deadline: ${DateFormat('MMM d, yyyy').format(widget.jobDeadline!)}',
//                         style: TextStyle(color: Colors.blue.shade800),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
            
//             // Date picker
//             Text(
//               'Select Interview Dates:',
//               style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
//             ),
//             SizedBox(height: 8),
//             ElevatedButton.icon(
//               icon: Icon(Icons.calendar_today),
//               onPressed: _showMultipleDatePicker,
//               label: Text('Select Interview Dates'),
//             ),
            
//             // Show selected dates
//             if (selectedDates.isNotEmpty) ...[
//               SizedBox(height: 12),
//               Text(
//                 'Selected Dates (${selectedDates.length}):',
//                 style: TextStyle(fontWeight: FontWeight.w500),
//               ),
//               SizedBox(height: 8),
//               Container(
//                 constraints: BoxConstraints(maxHeight: 100),
//                 child: SingleChildScrollView(
//                   scrollDirection: Axis.horizontal,
//                   child: Wrap(
//                     spacing: 8,
//                     runSpacing: 8,
//                     children: selectedDates.map((date) => Chip(
//                       label: Text(DateFormat('MMM d, yyyy').format(date)),
//                       deleteIcon: Icon(Icons.close, size: 18),
//                       onDeleted: () {
//                         setState(() {
//                           selectedDates.remove(date);
//                         });
//                       },
//                   ),
//                 ],
//               ),
//             ),
            
//             // Calendar grid - replaced with simplified calendar view
//             Container(
//               height: 280,
//               child: SimplifiedCalendarGrid(
//                 displayMonth: displayMonth,
//                 firstDate: widget.firstDate,
//                 lastDate: widget.lastDate,
//                 selectedDates: selectedDates,
//                 onDateSelected: _toggleDateSelection,
//               ),
//             ),
            
//             // Action buttons
//             Container(
//               padding: EdgeInsets.all(16),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.end,
//                 children: [
//                   TextButton(
//                     onPressed: () => Navigator.of(context).pop(),
//                     child: Text('Cancel'),
//                   ),
//                   SizedBox(width: 8),
//                   ElevatedButton(
//                     onPressed: () {
//                       Navigator.of(context).pop(selectedDates);
//                     },
//                     child: Text('OK'),
//                   ),
//                 ],
//               ),
//             ),
//                       backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
//                     )).toList(),
//                   ),
//                 ),
//               ),
//             ],
            
//             SizedBox(height: 20),
            
//             // Time range selector
//             Text(
//               'Set Time Range:',
//               style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
//             ),
//             SizedBox(height: 8),
//             Row(
//               children: [
//                 Expanded(
//                   child: OutlinedButton.icon(
//                     icon: Icon(Icons.access_time),
//                     onPressed: () => _showCustomTimePicker(true),
//                     label: Text(startTime != null 
//                       ? 'Start: ${startTime!.toString()}'
//                       : 'Select Start Time'),
//                   ),
//                 ),
//                 SizedBox(width: 8),
//                 Expanded(
//                   child: OutlinedButton.icon(
//                     icon: Icon(Icons.access_time),
//                     onPressed: () => _showCustomTimePicker(false),
//                     label: Text(endTime != null 
//                       ? 'End: ${endTime!.toString()}'
//                       : 'Select End Time'),
//                   ),
//                 ),
//               ],
//             ),
            
//             SizedBox(height: 20),
            
//             // Meeting link input
//             Text(
//               'Meeting Link:',
//               style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
//             ),
//             SizedBox(height: 8),
//             TextField(
//               decoration: InputDecoration(
//                 labelText: 'Meeting Link',
//                 hintText: 'https://meet.google.com/xyz-abc-def',
//                 border: OutlineInputBorder(),
//                 prefixIcon: Icon(Icons.link),
//                 suffixIcon: meetingLink.isNotEmpty
//                     ? IconButton(
//                         icon: Icon(Icons.clear),
//                         onPressed: () {
//                           setState(() {
//                             meetingLink = '';
//                           });
//                         },
//                       )
//                     : null,
//               ),
//               onChanged: (value) {
//                 setState(() {
//                   meetingLink = value;
//                 });
//               },
//             ),
            
//             SizedBox(height: 24),
            
//             // Generate slots button
//             Center(
//               child: ElevatedButton.icon(
//                 icon: Icon(Icons.schedule),
//                 onPressed: _generateTimeSlots,
//                 label: Text('Generate Time Slots'),
//                 style: ElevatedButton.styleFrom(
//                   padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
//                 ),
//               ),
//             ),
            
//             // Preview generated slots
//             if (generatedSlots.isNotEmpty) ...[
//               SizedBox(height: 24),
//               Divider(),
//               Text(
//                 'Generated Slots (${generatedSlots.length} slots):',
//                 style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
//               ),
//               SizedBox(height: 8),
//               Container(
//                 height: 300,
//                 decoration: BoxDecoration(
//                   border: Border.all(color: Colors.grey.shade300),
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: ListView.separated(
//                   padding: EdgeInsets.all(8),
//                   itemCount: generatedSlots.length,
//                   separatorBuilder: (context, index) => SizedBox(height: 8),
//                   itemBuilder: (context, index) {
//                     final slot = generatedSlots[index];
//                     return Card(
//                       child: ListTile(
//                         leading: CircleAvatar(
//                           backgroundColor: Theme.of(context).primaryColor,
//                           child: Text('${index + 1}', style: TextStyle(color: Colors.white)),
//                         ),
//                         title: Text(DateFormat('MMM d, yyyy').format(slot.startTime)),
//                         subtitle: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(
//                               '${DateFormat('h:mm a').format(slot.startTime)} - ${DateFormat('h:mm a').format(slot.endTime)}'
//                             ),
//                             if (slot.meetingLink != null && slot.meetingLink!.isNotEmpty)
//                               Text(
//                                 'Meeting Link: ${slot.meetingLink}',
//                                 style: TextStyle(fontSize: 12, color: Colors.blue),
//                               ),
//                           ],
//                         ),
//                         trailing: Icon(Icons.access_time, color: Colors.blue),
//                       ),
//                     );
//                   },
//                 ),
//               ),
              
//               SizedBox(height: 16),
              
//               // Action buttons
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                 children: [
//                   TextButton.icon(
//                     icon: Icon(Icons.clear),
//                     onPressed: () {
//                       setState(() {
//                         generatedSlots.clear();
//                       });
//                     },
//                     label: Text('Clear All'),
//                   ),
//                   ElevatedButton.icon(
//                     icon: Icon(Icons.check),
//                     onPressed: () {
//                       widget.onSlotsSelected(generatedSlots);
//                     },
//                     label: Text('Confirm Slots'),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.green,
//                       padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ],
//         ),
//       ),
//     );
//   }
// }

// // Custom Time Picker Dialog with better error handling
// class CustomTimePickerDialog extends StatefulWidget {
//   final TimeInterval? initialTime;
//   final String title;
  
//   const CustomTimePickerDialog({
//     Key? key,
//     this.initialTime,
//     required this.title,
//   }) : super(key: key);
  
//   @override
//   State<CustomTimePickerDialog> createState() => _CustomTimePickerDialogState();
// }

// class _CustomTimePickerDialogState extends State<CustomTimePickerDialog> {
//   late FixedExtentScrollController _hourController;
//   late FixedExtentScrollController _halfController;
  
//   late int selectedHour;
//   late int selectedHalf; // 0 for :00, 1 for :30
//   late int selectedPeriod; // 0 for AM, 1 for PM
  
//   // Track the current index
//   late int _hourIndex;
//   late int _halfIndex;
  
//   @override
//   void initState() {
//     super.initState();
    
//     // Initialize with current time or provided time
//     if (widget.initialTime != null) {
//       selectedHour = widget.initialTime!.hour % 12;
//       selectedHour = selectedHour == 0 ? 12 : selectedHour;
//       selectedHalf = widget.initialTime!.minute == 30 ? 1 : 0;
//       selectedPeriod = widget.initialTime!.hour >= 12 ? 1 : 0;
//     } else {
//       selectedHour = 9;
//       selectedHalf = 0;
//       selectedPeriod = 0;
//     }
    
//     // Calculate initial indices (start at middle position)
//     _hourIndex = (selectedHour - 1) + 48; 
//     _halfIndex = selectedHalf + 28; 
    
//     // Initialize controllers with try-catch
//     try {
//       _hourController = FixedExtentScrollController(
//         initialItem: _hourIndex,
//       );
//       _halfController = FixedExtentScrollController(
//         initialItem: _halfIndex,
//       );
//     } catch (e) {
//       print('Error initializing scroll controllers: $e');
//       _hourController = FixedExtentScrollController();
//       _halfController = FixedExtentScrollController();
//     }
//   }
  
//   @override
//   void dispose() {
//     _hourController.dispose();
//     _halfController.dispose();
//     super.dispose();
//   }
  
//   TimeInterval _getSelectedTime() {
//     final realHour = selectedPeriod == 1 
//         ? (selectedHour == 12 ? 12 : selectedHour + 12)
//         : (selectedHour == 12 ? 0 : selectedHour);
//     final minute = selectedHalf == 1 ? 30 : 0;
//     return TimeInterval(realHour, minute);
//   }
  
//   @override
//   Widget build(BuildContext context) {
//     return Dialog(
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       child: Container(
//         constraints: BoxConstraints(
//           maxHeight: MediaQuery.of(context).size.height * 0.6,
//           maxWidth: 400,
//         ),
//         padding: EdgeInsets.all(24),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Text(
//               widget.title,
//               style: TextStyle(
//                 fontSize: 18, 
//                 fontWeight: FontWeight.bold,
//                 color: Colors.black,
//               ),
//             ),
//             SizedBox(height: 24),
            
//             // Time picker with AM/PM buttons
//             Container(
//               height: 200,
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   // Hour wheel
//                   _buildScrollWheel(
//                     controller: _hourController,
//                     itemBuilder: (index) {
//                       final hour = (index % 12) + 1;
//                       return Text(
//                         '$hour',
//                         style: TextStyle(
//                           fontSize: 24,
//                           fontWeight: FontWeight.w600,
//                           color: Colors.black,
//                         ),
//                       );
//                     },
//                     onSelectedItemChanged: (index) {
//                       setState(() {
//                         _hourIndex = index;
//                         selectedHour = (index % 12) + 1;
//                       });
//                     },
//                   ),
                  
//                   // Colon separator
//                   Container(
//                     width: 20,
//                     child: Center(
//                       child: Text(
//                         ':',
//                         style: TextStyle(
//                           fontSize: 24,
//                           fontWeight: FontWeight.w600,
//                           color: Colors.black,
//                         ),
//                       ),
//                     ),
//                   ),
                  
//                   // Half-hour wheel (00/30)
//                   _buildScrollWheel(
//                     controller: _halfController,
//                     itemBuilder: (index) {
//                       final minute = (index % 2) == 0 ? '00' : '30';
//                       return Text(
//                         minute,
//                         style: TextStyle(
//                           fontSize: 24,
//                           fontWeight: FontWeight.w600,
//                           color: Colors.black,
//                         ),
//                       );
//                     },
//                     onSelectedItemChanged: (index) {
//                       setState(() {
//                         _halfIndex = index;
//                         selectedHalf = index % 2;
//                       });
//                     },
//                   ),
                  
//                   SizedBox(width: 20),
                  
//                   // AM/PM toggle buttons
//                   _buildAmPmSelector(),
//                 ],
//               ),
//             ),
            
//             SizedBox(height: 32),
            
//             // Action buttons
//             Row(
//               mainAxisAlignment: MainAxisAlignment.end,
//               children: [
//                 TextButton(
//                   onPressed: () => Navigator.of(context).pop(),
//                   child: Text(
//                     'Cancel',
//                     style: TextStyle(color: Colors.black),
//                   ),
//                 ),
//                 SizedBox(width: 8),
//                 ElevatedButton(
//                   onPressed: () {
//                     Navigator.of(context).pop(_getSelectedTime());
//                   },
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: Colors.white,
//                     foregroundColor: Colors.black,
//                     side: BorderSide(color: Colors.grey.shade300),
//                   ),
//                   child: Text('OK'),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
  
//   Widget _buildScrollWheel({
//     required FixedExtentScrollController controller,
//     required Widget Function(int) itemBuilder,
//     required Function(int) onSelectedItemChanged,
//   }) {
//     return Container(
//       width: 60,
//       height: 200,
//       child: Stack(
//         children: [
//           Positioned(
//             top: 75,
//             left: 0,
//             right: 0,
//             height: 50,
//             child: Container(
//               decoration: BoxDecoration(
//                 color: Colors.lightBlue.withOpacity(0.3),
//                 borderRadius: BorderRadius.circular(8),
//               ),
//             ),
//           ),
//           ListWheelScrollView.useDelegate(
//             controller: controller,
//             itemExtent: 50,
//             perspective: 0.005,
//             diameterRatio: 1.2,
//             physics: FixedExtentScrollPhysics(),
//             onSelectedItemChanged: onSelectedItemChanged,
//             childDelegate: ListWheelChildBuilderDelegate(
//               builder: (context, index) {
//                 return Center(child: itemBuilder(index));
//               },
//               childCount: 120,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
  
//   Widget _buildAmPmSelector() {
//     return Container(
//       width: 70,
//       height: 200,
//       child: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             // AM button
//             GestureDetector(
//               onTap: () {
//                 setState(() {
//                   selectedPeriod = 0;
//                 });
//               },
//               child: Container(
//                 width: 50,
//                 height: 40,
//                 decoration: BoxDecoration(
//                   color: selectedPeriod == 0 
//                       ? Colors.lightBlue.withOpacity(0.3)
//                       : Colors.transparent,
//                   borderRadius: BorderRadius.circular(8),
//                   border: Border.all(
//                     color: selectedPeriod == 0 
//                         ? Colors.lightBlue
//                         : Colors.transparent,
//                   ),
//                 ),
//                 child: Center(
//                   child: Text(
//                     'AM',
//                     style: TextStyle(
//                       fontSize: 20,
//                       fontWeight: FontWeight.w600,
//                       color: Colors.black,
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//             SizedBox(height: 8),
//             // PM button
//             GestureDetector(
//               onTap: () {
//                 setState(() {
//                   selectedPeriod = 1;
//                 });
//               },
//               child: Container(
//                 width: 50,
//                 height: 40,
//                 decoration: BoxDecoration(
//                   color: selectedPeriod == 1 
//                       ? Colors.lightBlue.withOpacity(0.3)
//                       : Colors.transparent,
//                   borderRadius: BorderRadius.circular(8),
//                   border: Border.all(
//                     color: selectedPeriod == 1 
//                         ? Colors.lightBlue
//                         : Colors.transparent,
//                   ),
//                 ),
//                 child: Center(
//                   child: Text(
//                     'PM',
//                     style: TextStyle(
//                       fontSize: 20,
//                       fontWeight: FontWeight.w600,
//                       color: Colors.black,
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // Updated TimeInterval class with proper validation
// class TimeInterval {
//   final int hour;
//   final int minute;
  
//   TimeInterval(this.hour, this.minute) {
//     // Validate that minute is either 0 or 30
//     assert(minute == 0 || minute == 30, 'Minute must be 0 or 30');
//     // Validate hour range
//     assert(hour >= 0 && hour <= 23, 'Hour must be between 0 and 23');
//   }
  
//   int get totalMinutes => hour * 60 + minute;
  
//   @override
//   String toString() {
//     final period = hour >= 12 ? 'PM' : 'AM';
//     final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
//     final displayMinute = minute == 0 ? '00' : '30';
//     return '$displayHour:$displayMinute $period';
//   }
  
//   @override
//   bool operator ==(Object other) =>
//       identical(this, other) ||
//       other is TimeInterval &&
//           runtimeType == other.runtimeType &&
//           hour == other.hour &&
//           minute == other.minute;
  
//   @override
//   int get hashCode => hour.hashCode ^ minute.hashCode;
// }

// // Simplified Multiple Date Picker Dialog with better error handling
// class MultipleDatePickerDialog extends StatefulWidget {
//   final List<DateTime> initialDates;
//   final DateTime firstDate;
//   final DateTime lastDate;
  
//   const MultipleDatePickerDialog({
//     Key? key,
//     required this.initialDates,
//     required this.firstDate,
//     required this.lastDate,
//   }) : super(key: key);
  
//   @override
//   State<MultipleDatePickerDialog> createState() => _MultipleDatePickerDialogState();
// }

// class _MultipleDatePickerDialogState extends State<MultipleDatePickerDialog> {
//   late List<DateTime> selectedDates;
//   late DateTime displayMonth;
  
//   @override
//   void initState() {
//     super.initState();
//     selectedDates = List.from(widget.initialDates);
//     displayMonth = widget.firstDate;
//   }
  
//   void _toggleDateSelection(DateTime date) {
//     setState(() {
//       try {
//         // Normalize the date to remove time component
//         DateTime normalizedDate = DateTime(date.year, date.month, date.day);
        
//         // Check if date is already selected
//         int existingIndex = selectedDates.indexWhere((d) => 
//           d.year == normalizedDate.year && 
//           d.month == normalizedDate.month && 
//           d.day == normalizedDate.day
//         );
        
//         if (existingIndex >= 0) {
//           // Date is already selected, remove it
//           selectedDates.removeAt(existingIndex);
//         } else {
//           // Date is not selected, add it
//           selectedDates.add(normalizedDate);
//         }
        
//         selectedDates.sort();
//       } catch (e) {
//         print('Error toggling date selection: $e');
//       }
//     });
//   }
  
//   bool _isDateSelected(DateTime date) {
//     return selectedDates.any((d) => 
//       d.year == date.year && 
//       d.month == date.month && 
//       d.day == date.day
//     );
//   }
  
//   @override
//   Widget build(BuildContext context) {
//     return Dialog(
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//       child: Container(
//         width: 320,
//         constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             // Header
//             Container(
//               padding: EdgeInsets.all(16),
//               decoration: BoxDecoration(
//                 color: Theme.of(context).primaryColor,
//                 borderRadius: BorderRadius.only(
//                   topLeft: Radius.circular(16),
//                   topRight: Radius.circular(16),
//                 ),
//               ),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Text(
//                     'Select Dates',
//                     style: TextStyle(
//                       color: const Color.fromARGB(190, 0, 0, 0),
//                       fontSize: 18,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   Text(
//                     '${selectedDates.length} selected',
//                     style: TextStyle(
//                       color: const Color.fromARGB(190, 0, 0, 0),
//                       fontSize: 14,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
            
//             // Month navigation
//             Container(
//               padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   IconButton(
//                     icon: Icon(Icons.chevron_left),
//                     onPressed: () {
//                       setState(() {
//                         displayMonth = DateTime(displayMonth.year, displayMonth.month - 1);
//                       });
//                     },
//                   ),
//                   Text(
//                     DateFormat('MMMM yyyy').format(displayMonth),
//                     style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
//                   ),
//                   IconButton(
//                     icon: Icon(Icons.chevron_right),
//                     onPressed: () {
//                       setState(() {
//                         displayMonth = DateTime(displayMonth.year, displayMonth.month + 1);
//                       });
//                     },
//                     ),
//                 ],
//               ),
//             ),
            
//             // Calendar grid
//             Container(
//               height: 280,
//               padding: EdgeInsets.symmetric(horizontal: 16),
//               child: _buildCalendarGrid(),
//             ),
            
//             // Action buttons
//             Container(
//               padding: EdgeInsets.all(16),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.end,
//                 children: [
//                   TextButton(
//                     onPressed: () => Navigator.of(context).pop(),
//                     child: Text('Cancel'),
//                   ),
//                   SizedBox(width: 8),
//                   ElevatedButton(
//                     onPressed: () {
//                       Navigator.of(context).pop(selectedDates);
//                     },
//                     child: Text('OK'),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
  
//   Widget _buildCalendarGrid() {
//     final daysInMonth = DateTime(displayMonth.year, displayMonth.month + 1, 0).day;
//     final firstDay = DateTime(displayMonth.year, displayMonth.month, 1);
//     final startingDay = firstDay.weekday % 7;
    
//     return GridView.builder(
//       gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
//         crossAxisCount: 7,
//         childAspectRatio: 1.0,
//       ),
//       itemCount: 42, // 6 weeks
//       itemBuilder: (context, index) {
//         final day = index - startingDay + 1;
        
//         if (day < 1 || day > daysInMonth) {
//           return SizedBox(); // Empty cell
//         }
        
//         final date = DateTime(displayMonth.year, displayMonth.month, day);
//         final isSelected = _isDateSelected(date);
//         final isDisabled = date.isBefore(widget.firstDate) || date.isAfter(widget.lastDate);
        
//         return GestureDetector(
//           onTap: isDisabled ? null : () => _toggleDateSelection(date),
//           child: Container(
//             margin: EdgeInsets.all(2),
//             decoration: BoxDecoration(
//               color: isSelected 
//                   ? Theme.of(context).primaryColor 
//                   : Colors.transparent,
//               borderRadius: BorderRadius.circular(8),
//             ),
//             child: Center(
//               child: Text(
//                 day.toString(),
//                 style: TextStyle(
//                   color: isSelected 
//                       ? Colors.black 
//                       : isDisabled 
//                           ? Colors.grey 
//                           : Colors.black,
//                   fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
//                 ),
//               ),
//             ),
//           ),
//         );
//       },
//     );
//   }
// }