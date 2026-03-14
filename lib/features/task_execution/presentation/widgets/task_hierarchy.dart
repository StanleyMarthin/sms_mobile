import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

class TaskHierarchyLevel<T> {
  const TaskHierarchyLevel({
    required this.keyOf,
    required this.labelOf,
    required this.icon,
    this.countLabel,
  });

  final String Function(T item) keyOf;
  final String Function(T item) labelOf;
  final IconData icon;
  final String Function(List<T> items)? countLabel;
}

class ExpandableTaskHierarchy<T> extends StatelessWidget {
  const ExpandableTaskHierarchy({
    super.key,
    required this.items,
    required this.levels,
    required this.itemBuilder,
  });

  final List<T> items;
  final List<TaskHierarchyLevel<T>> levels;
  final Widget Function(BuildContext context, T item) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _buildGroups(context, items, 0),
    );
  }

  List<Widget> _buildGroups(BuildContext context, List<T> entries, int levelIndex) {
    if (levelIndex >= levels.length) {
      return entries
          .map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: itemBuilder(context, entry),
            ),
          )
          .toList();
    }

    final level = levels[levelIndex];
    final grouped = <String, List<T>>{};
    for (final entry in entries) {
      grouped.putIfAbsent(level.keyOf(entry), () => []).add(entry);
    }

    final sortedGroups = grouped.entries.toList()
      ..sort((a, b) => level.labelOf(a.value.first).compareTo(level.labelOf(b.value.first)));

    return sortedGroups.map((groupEntry) {
      final groupItems = groupEntry.value;
      final title = level.labelOf(groupItems.first);
      final countText = level.countLabel?.call(groupItems) ?? '${groupItems.length}';

      return Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          color: levelIndex == 0 ? AppColors.surfaceCard : AppColors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: levelIndex == 0 ? AppColors.border : AppColors.borderSubtle,
          ),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            collapsedIconColor: AppColors.textMuted,
            iconColor: AppColors.gold,
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            childrenPadding: const EdgeInsets.only(bottom: 8),
            leading: Icon(level.icon, color: AppColors.gold, size: 18),
            title: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _HierarchyCountBadge(value: countText),
                const SizedBox(width: 4),
                const Icon(Icons.expand_more_rounded),
              ],
            ),
            children: _buildGroups(context, groupItems, levelIndex + 1),
          ),
        ),
      );
    }).toList();
  }
}

class _HierarchyCountBadge extends StatelessWidget {
  const _HierarchyCountBadge({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        value,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.gold,
        ),
      ),
    );
  }
}