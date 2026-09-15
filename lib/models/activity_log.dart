class ActivityLogEntry {
  final int id;
  final String activityType;
  final String flaxNo;
  final String treeNo;
  final String message;
  final String performedBy;
  final DateTime? createdAt;

  ActivityLogEntry({
    required this.id,
    required this.activityType,
    required this.flaxNo,
    required this.treeNo,
    required this.message,
    required this.performedBy,
    required this.createdAt,
  });

  factory ActivityLogEntry.fromJson(Map<String, dynamic> json) {
    return ActivityLogEntry(
      id: json['id'] as int,
      activityType: (json['activity_type'] as String?) ?? '',
      flaxNo: (json['flax_no'] as String?) ?? '',
      treeNo: (json['tree_no'] as String?) ?? '',
      message: (json['message'] as String?) ?? '',
      performedBy: (json['performed_by'] as String?) ?? 'Admin',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  String get timeDisplay {
    if (createdAt == null) return '';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(createdAt!.day)}-${two(createdAt!.month)} ${two(createdAt!.hour)}:${two(createdAt!.minute)}';
  }
}