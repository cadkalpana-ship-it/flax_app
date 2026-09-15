enum FlaxAssignmentStatus {
  available,
  assigned,
  underMaintenance,
}

extension FlaxAssignmentStatusX on FlaxAssignmentStatus {
  String get apiValue {
    switch (this) {
      case FlaxAssignmentStatus.available:
        return 'Available';

      case FlaxAssignmentStatus.assigned:
        return 'Assigned';

      case FlaxAssignmentStatus.underMaintenance:
        return 'Under Maintenance';
    }
  }

  String get label {
    switch (this) {
      case FlaxAssignmentStatus.available:
        return 'Available';

      case FlaxAssignmentStatus.assigned:
        return 'Assigned';

      case FlaxAssignmentStatus.underMaintenance:
        return 'Under Maintenance';
    }
  }

  static FlaxAssignmentStatus fromApi(String? value) {
    switch (value?.trim().toUpperCase()) {
      case 'AVAILABLE':
        return FlaxAssignmentStatus.available;

      case 'ASSIGNED':
        return FlaxAssignmentStatus.assigned;

      case 'UNDER MAINTENANCE':
      case 'UNDER_MAINTENANCE':
        return FlaxAssignmentStatus.underMaintenance;

      default:
        return FlaxAssignmentStatus.available;
    }
  }
}

class Flax {
  final int id;
  final String flaxNo;
  final String flaxSize;
  final String? designName;
  final String? category;
  final String? treeNo;
  final String assignmentStatus;
  final String remarks;
  final String processStatus;
  final DateTime? assignedOn;
  final DateTime? releasedOn;
  final DateTime createdOn;
  final DateTime updatedOn;

  // Captured at release time — see FlaxRelease's Tunch Report section.
  // Optional/nullable since older records won't have these.
  final String? topTunchReport;
  final String? bottomTunchReport;
  final List<String> releaseImageUrls;

  const Flax({
    required this.id,
    required this.flaxNo,
    required this.flaxSize,
    this.designName,
    this.category,
    this.treeNo,
    required this.assignmentStatus,
    this.remarks = '',
    required this.processStatus,
    this.assignedOn,
    this.releasedOn,
    required this.createdOn,
    required this.updatedOn,
    this.topTunchReport,
    this.bottomTunchReport,
    this.releaseImageUrls = const [],
  });

  factory Flax.fromJson(Map<String, dynamic> json) {
    return Flax(
      id: json['id'] as int,
      flaxNo: json['flax_no'] as String,
      flaxSize: json['flax_size'] as String,
      designName: json['design_name'] as String?,
      category: json['category'] as String?,
      treeNo: json['tree_no'] as String?,
      assignmentStatus: json['assignment_status'] as String,
      remarks: json['remarks'] as String? ?? '',
      processStatus: json['process_status'] as String,
      assignedOn: json['assigned_on'] != null
          ? DateTime.parse(json['assigned_on'])
          : null,
      releasedOn: json['released_on'] != null
          ? DateTime.parse(json['released_on'])
          : null,
      createdOn: DateTime.parse(json['created_on']),
      updatedOn: DateTime.parse(json['updated_on']),
      topTunchReport: json['top_tunch_report'] as String?,
      bottomTunchReport: json['bottom_tunch_report'] as String?,
      releaseImageUrls: _parseReleaseImageUrls(json),
    );
  }

  /// Backend may return these under a few different shapes depending on
  /// how the release view is implemented — handle the common ones:
  /// a single `release_image` / `release_image_url` string, or a list
  /// under `release_images` / `images` of strings or {image_url: ...}.
  static List<String> _parseReleaseImageUrls(Map<String, dynamic> json) {
    final urls = <String>[];

    final single = json['release_image_url'] ?? json['release_image'];
    if (single != null && single.toString().trim().isNotEmpty) {
      urls.add(single.toString().trim());
    }

    final list = json['release_images'] ?? json['images'];
    if (list is List) {
      for (final item in list) {
        if (item is String && item.trim().isNotEmpty) {
          urls.add(item.trim());
        } else if (item is Map) {
          final url = item['image_url'] ?? item['image'];
          if (url != null && url.toString().trim().isNotEmpty) {
            urls.add(url.toString().trim());
          }
        }
      }
    }

    return urls;
  }

  String get condition {
    final status = assignmentStatus.trim().toLowerCase();

    if (status == 'under maintenance') {
      return 'Inactive';
    }

    // Available, Assigned, In Use etc.
    return 'Active';
  }
}

// Add this getter to your existing Flax class in models/flax.dart.
// No new fields needed now — `assignmentStatus` and `treeNo` already exist
// in your model (confirmed against the real API response you shared), and
// `condition`/`remarks` are no longer used per your choice to reuse
// assignment_status instead.
//
// This assumes your model already has a `createdOn` DateTime (parsed from
// the API's `created_on`). If it doesn't yet, parse it in Flax.fromJson as:
//   createdOn: DateTime.tryParse(json['created_on'] as String? ?? ''),

// Add this class to your existing models/flax.dart.
// It assumes Flax already has a `Flax.fromJson(Map<String, dynamic>)`
// factory, since fetchFlaxes() must already be parsing individual
// flax objects the same way.

class FlaxPage {
  final List<Flax> results;
  final String? next;
  final String? previous;
  final int count;

  FlaxPage({
    required this.results,
    required this.next,
    required this.previous,
    required this.count,
  });

  factory FlaxPage.fromJson(Map<String, dynamic> json) {
    return FlaxPage(
      results: (json['results'] as List)
          .map((e) => Flax.fromJson(e as Map<String, dynamic>))
          .toList(),
      next: json['next'] as String?,
      previous: json['previous'] as String?,
      count: json['count'] as int? ?? 0,
    );
  }
}

extension FlaxDisplay on Flax {
  String get createdDateDisplay {
    if (createdOn == null) return '-';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(createdOn!.day)}-${two(createdOn!.month)}-${createdOn!.year}';
  }
}