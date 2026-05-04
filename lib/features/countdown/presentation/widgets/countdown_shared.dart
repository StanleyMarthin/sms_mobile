import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../utils/countdown_helper.dart';

/// Data class used by [RevisionStatusBanner].
class RevisionBannerData {
  const RevisionBannerData({
    required this.color,
    required this.icon,
    required this.title,
    required this.detail,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String detail;
}

class CountdownStatusChip extends StatelessWidget {
  const CountdownStatusChip({super.key, required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final visual = CountdownHelper.statusVisual(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: visual.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: visual.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(visual.icon, size: 12, color: visual.color),
          const SizedBox(width: 6),
          Text(
            visual.shortLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: visual.color,
            ),
          ),
        ],
      ),
    );
  }
}

class CountdownEmptyMessage extends StatelessWidget {
  const CountdownEmptyMessage({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        message,
        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
      ),
    );
  }
}

class RevisionStatusBanner extends StatelessWidget {
  const RevisionStatusBanner({super.key, required this.banner});
  final RevisionBannerData banner;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: banner.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: banner.color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(banner.icon, size: 16, color: banner.color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  banner.title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: banner.color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  banner.detail,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CountdownNavCard extends StatelessWidget {
  const CountdownNavCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class RevisionSectionHeader extends StatelessWidget {
  const RevisionSectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class CountdownFilterBar extends StatelessWidget {
  const CountdownFilterBar({
    super.key,
    required this.selectedSection,
    required this.selectedPanel,
    required this.selectedStatus,
    required this.selectedSort,
    required this.sectionOptions,
    required this.panelOptions,
    required this.onSectionChanged,
    required this.onPanelChanged,
    required this.onStatusChanged,
    required this.onSortChanged,
    required this.onReset,
  });

  final String selectedSection;
  final String selectedPanel;
  final String selectedStatus;
  final String selectedSort;
  final List<String> sectionOptions;
  final List<String> panelOptions;
  final ValueChanged<String> onSectionChanged;
  final ValueChanged<String> onPanelChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onSortChanged;
  final VoidCallback onReset;

  static String sortLabel(String value) {
    switch (value) {
      case 'deadline_asc':
        return 'Deadline Terdekat';
      case 'deadline_desc':
        return 'Deadline Terjauh';
      case 'progress_desc':
        return 'Progress Tertinggi';
      case 'progress_asc':
        return 'Progress Terendah';
      case 'panel_asc':
        return 'Panel A-Z';
      default:
        return 'Urutan Default';
    }
  }

  Widget _buildDropdownFilter({
    required String label,
    required String value,
    required List<String> items,
    required String Function(String value) labelBuilder,
    required ValueChanged<String?> onChanged,
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        initialValue: items.contains(value) ? value : items.first,
        decoration: InputDecoration(labelText: label),
        dropdownColor: AppColors.surfaceCard,
        items: items
            .map(
              (item) => DropdownMenuItem<String>(
                value: item,
                child: Text(labelBuilder(item)),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filter Jobdesc',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 560;
              final fields = [
                _buildDropdownFilter(
                  label: 'Section',
                  value: selectedSection,
                  items: sectionOptions,
                  labelBuilder: (value) => value == 'all' ? 'Semua Section' : value,
                  onChanged: (value) => onSectionChanged(value ?? 'all'),
                  width: isCompact ? double.infinity : 220,
                ),
                _buildDropdownFilter(
                  label: 'Panel',
                  value: selectedPanel,
                  items: panelOptions,
                  labelBuilder: (value) => value == 'all' ? 'Semua Panel' : value,
                  onChanged: (value) => onPanelChanged(value ?? 'all'),
                  width: isCompact ? double.infinity : 220,
                ),
                _buildDropdownFilter(
                  label: 'Status / Progress',
                  value: selectedStatus,
                  items: const [
                    'all',
                    'plan',
                    'proses',
                    'qcready',
                    'done',
                    'below50',
                    'above50',
                    'full',
                  ],
                  labelBuilder: CountdownHelper.statusProgressLabel,
                  onChanged: (value) => onStatusChanged(value ?? 'all'),
                  width: isCompact ? double.infinity : 220,
                ),
                  _buildDropdownFilter(
                    label: 'Urutkan',
                    value: selectedSort,
                    items: const [
                      'deadline_asc',
                      'deadline_desc',
                      'progress_desc',
                      'progress_asc',
                      'panel_asc',
                    ],
                    labelBuilder: sortLabel,
                    onChanged: (value) => onSortChanged(value ?? 'deadline_asc'),
                    width: isCompact ? double.infinity : 220,
                  ),
              ];

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...fields.expand((field) => [field, const SizedBox(height: 12)]),
                    OutlinedButton.icon(
                      onPressed: onReset,
                      icon: const Icon(Icons.refresh, size: 16, color: AppColors.gold),
                      label: const Text('Reset', style: TextStyle(color: AppColors.gold)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.gold),
                        foregroundColor: AppColors.gold,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ],
                );
              }

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ...fields,
                  OutlinedButton.icon(
                    onPressed: onReset,
                    icon: const Icon(Icons.refresh, size: 16, color: AppColors.gold),
                    label: const Text('Reset', style: TextStyle(color: AppColors.gold)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.gold),
                      foregroundColor: AppColors.gold,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
