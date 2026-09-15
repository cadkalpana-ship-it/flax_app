/// A single row in the Tree Module Details table, held in local state
/// between ENTER (adds to the in-app list) and SUBMIT (sends the whole
/// list to the backend as one batch).
class TreeModuleRow {
  final int slNo;
  final String styleNo;
  final String bagNo;
  final String treeNo;
  final String treeWt;
  final String purity;
  final String colour;

  // Manual for now — no formula wired in yet.
  final String requireMetal;
  final String reqPureMetal;
  final String requireAlloy;

  TreeModuleRow({
    required this.slNo,
    required this.styleNo,
    required this.bagNo,
    required this.treeNo,
    required this.treeWt,
    required this.purity,
    required this.colour,
    required this.requireMetal,
    required this.reqPureMetal,
    required this.requireAlloy,
  });

  /// Matches TreeModuleDetailSerializer's fields on the backend.
  /// Numeric-looking strings are parsed to num; empty ones are sent as
  /// null rather than "", since the backend fields are DecimalField.
  Map<String, dynamic> toJson() {
    num? asNum(String value) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return num.tryParse(trimmed);
    }

    return {
      'sl_no': slNo,
      'style_no': styleNo,
      'bag_no': bagNo,
      'tree_no': treeNo,
      'tree_wt': asNum(treeWt),
      'purity': purity,
      'colour': colour,
      'require_metal': asNum(requireMetal),
      'req_pure_metal': asNum(reqPureMetal),
      'require_alloy': asNum(requireAlloy),
    };
  }
}