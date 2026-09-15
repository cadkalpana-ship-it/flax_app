// Add this class to your existing models/flax.dart.
// It assumes Flax already has a `Flax.fromJson(Map<String, dynamic>)`
// factory, since fetchFlaxes() must already be parsing individual
// flax objects the same way.

import 'package:flax_app/models/flax.dart';

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
