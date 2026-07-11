import 'package:flutter/material.dart';

// Event 'status' field values stay 'active' | 'closed' | 'upcoming' in Firestore
// for backward compatibility; these helpers map them to the user-facing labels
// Ongoing / Past / Upcoming.
String eventStatusLabel(String? status) {
  switch (status) {
    case 'upcoming':
      return 'Upcoming';
    case 'closed':
      return 'Past';
    default:
      return 'Ongoing';
  }
}

Color eventStatusColor(String? status) {
  switch (status) {
    case 'upcoming':
      return Colors.blue.shade600;
    case 'closed':
      return Colors.grey.shade600;
    default:
      return Colors.green.shade600;
  }
}
