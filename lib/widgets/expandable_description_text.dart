import 'package:flutter/material.dart';

class ExpandableDescriptionText extends StatefulWidget {
  final String text;
  
  const ExpandableDescriptionText({
    Key? key,
    required this.text,
  }) : super(key: key);

  @override
  State<ExpandableDescriptionText> createState() => _ExpandableDescriptionTextState();
}

class _ExpandableDescriptionTextState extends State<ExpandableDescriptionText> {
  bool _expanded = false;
  
  @override
  Widget build(BuildContext context) {
    // If text is empty, show a placeholder
    if (widget.text.isEmpty) {
      return Text(
        "No description added. Click 'Edit Description' to add one.",
        style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Description text
        InkWell(
          onTap: () {
            setState(() {
              _expanded = !_expanded;
            });
          },
          child: Text(
            widget.text,
            maxLines: _expanded ? null : 2,
            overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: TextStyle(
              color: _expanded ? Colors.black : Colors.black87,
            ),
          ),
        ),
        
        // Show More button at the left side for longer descriptions
        if (widget.text.length > 80)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: InkWell(
              onTap: () {
                setState(() {
                  _expanded = !_expanded;
                });
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 16,
                    color: Colors.deepPurple,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _expanded ? 'Show Less' : 'Show More',
                    style: TextStyle(
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}