class Tree {
  final int id;
  final String treeId;
  final String treeNo;
  final String treeName;
  final String category;
  final String status;
  final DateTime? createdOn;
  final DateTime? updatedOn;

  Tree({
    required this.id,
    required this.treeId,
    required this.treeNo,
    required this.treeName,
    required this.category,
    required this.status,
    required this.createdOn,
    required this.updatedOn,
  });

  factory Tree.fromJson(Map<String, dynamic> json) {
    return Tree(
      id: json['id'] as int,
      treeId: (json['tree_id'] as String?) ?? '',
      treeNo: (json['tree_no'] as String?) ?? '',
      treeName: (json['tree_name'] as String?) ?? '',
      category: (json['category'] as String?) ?? '',
      status: (json['status'] as String?) ?? 'Active',
      createdOn: json['created_on'] != null
          ? DateTime.tryParse(json['created_on'] as String)
          : null,
      updatedOn: json['updated_on'] != null
          ? DateTime.tryParse(json['updated_on'] as String)
          : null,
    );
  }

  /// What shows in pickers — falls back to the tree number if no name is set.
  String get displayLabel => treeName.isNotEmpty ? '$treeNo — $treeName' : treeNo;
}