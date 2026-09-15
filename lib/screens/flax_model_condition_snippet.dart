// Add these fields to your existing Flax class in models/flax.dart, and
// merge the parsing into your existing Flax.fromJson(...).
//
// ASSUMPTION (please verify against your backend): your API's flax objects
// currently return assignment_status, process_status, created_on, etc.
// (confirmed from your earlier sample response) but do NOT yet return
// `condition` or `remarks` — those are new fields the mockup needs. Until
// your backend adds them, fromJson below falls back to safe defaults
// ("Active" / "-") so the app keeps working, but the toggle/edit actions
// in the new screen won't persist anything server-side until the backend
// supports them.

class Flax {
  // ...keep your existing fields (id, flaxNo, flaxSize, assignmentStatus, etc.)...

  final String condition;   // "Active" | "Inactive" — NEW
  final String remarks;     // free text, "-" when empty — NEW
  final DateTime? createdOn; // you may already have this — reuse if so

  Flax({
    // ...your existing required params...
    required this.condition,
    required this.remarks,
    required this.createdOn,
  });

  factory Flax.fromJson(Map<String, dynamic> json) {
    return Flax(
      // ...your existing field parsing...
      condition: (json['condition'] as String?) ?? 'Active',
      remarks: (json['remarks'] as String?)?.trim().isNotEmpty == true
          ? json['remarks'] as String
          : '-',
      createdOn: json['created_on'] != null
          ? DateTime.tryParse(json['created_on'] as String)
          : null,
    );
  }

  // Handy for display — matches the "dd-MM-yyyy" format in the mockup.
  String get createdDateDisplay {
    if (createdOn == null) return '-';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(createdOn!.day)}-${two(createdOn!.month)}-${createdOn!.year}';
  }
}