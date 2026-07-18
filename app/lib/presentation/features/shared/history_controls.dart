import 'package:flutter/material.dart';

/// Which subset of past trips to show in a Trip History list.
enum HistoryFilter {
  all('All'),
  completed('Completed'),
  cancelled('Cancelled');

  const HistoryFilter(this.label);
  final String label;
}

/// Ordering of a Trip History list (by creation / acceptance time).
enum HistorySort {
  newest('Newest first'),
  oldest('Oldest first');

  const HistorySort(this.label);
  final String label;
}

/// The maximum number of past trips shown in a Trip History list. History can
/// grow unbounded, so we cap the view to the most recent trips (design ask:
/// "show up to last 15 trips").
const int kHistoryPageSize = 15;

/// A compact filter + sort bar shown at the top of a Trip History list. Both
/// controls are labelled dropdowns (accessible) that report changes back via
/// [onFilterChanged] / [onSortChanged].
class HistoryControls extends StatelessWidget {
  const HistoryControls({
    super.key,
    required this.filter,
    required this.sort,
    required this.onFilterChanged,
    required this.onSortChanged,
  });

  final HistoryFilter filter;
  final HistorySort sort;
  final ValueChanged<HistoryFilter> onFilterChanged;
  final ValueChanged<HistorySort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              label: 'Filter trips',
              excludeSemantics: true,
              child: DropdownButtonFormField<HistoryFilter>(
                value: filter,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Filter',
                  isDense: true,
                ),
                items: [
                  for (final f in HistoryFilter.values)
                    DropdownMenuItem(value: f, child: Text(f.label)),
                ],
                onChanged: (v) => v == null ? null : onFilterChanged(v),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Semantics(
              label: 'Sort trips',
              excludeSemantics: true,
              child: DropdownButtonFormField<HistorySort>(
                value: sort,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Sort',
                  isDense: true,
                ),
                items: [
                  for (final s in HistorySort.values)
                    DropdownMenuItem(value: s, child: Text(s.label)),
                ],
                onChanged: (v) => v == null ? null : onSortChanged(v),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
