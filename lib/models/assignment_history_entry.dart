class AssignmentHistoryEntry {
  final int id;
  final String flaxNo;
  final String treeNo;
  final String treeName;
  final DateTime? assignedOn;
  final DateTime? releasedOn;
  final DateTime? removedOn;
  final String status; // 'Assigned' | 'Released' | 'Removed'

  AssignmentHistoryEntry({
    required this.id,
    required this.flaxNo,
    required this.treeNo,
    required this.treeName,
    required this.assignedOn,
    required this.releasedOn,
    required this.removedOn,
    required this.status,
  });

  bool get isActive => status == 'Assigned';

  factory AssignmentHistoryEntry.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      return DateTime.tryParse(value.toString())?.toLocal();
    }

    return AssignmentHistoryEntry(
      id: json['id'] as int,
      flaxNo: (json['flax_no'] as String?) ?? '',
      treeNo: (json['tree_no'] as String?) ?? '',
      treeName: (json['tree_name'] as String?) ?? '',
      assignedOn: parseDate(json['assigned_on']),
      releasedOn: parseDate(json['released_on']),
      removedOn: parseDate(json['removed_on']),
      status: (json['status'] as String?) ?? 'Assigned',
    );
  }

  String get timeDisplay {
    final dt = assignedOn;
    if (dt == null) return '-';

    String two(int v) => v.toString().padLeft(2, '0');

    return '${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }
}