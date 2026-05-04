import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/view_task_entity.dart';

class ViewTaskCard extends StatelessWidget {
  final ViewTaskEntity task;
  final bool showEmployee;
  final bool showDivision;
  final VoidCallback? onTap;
  final Widget? actionArea;
  final bool isHighlighted;
  final ValueChanged<TaskCheckpointSession>? onCheckpointTap;
  final EdgeInsetsGeometry margin;

  const ViewTaskCard({
    super.key,
    required this.task,
    this.showEmployee = true,
    this.showDivision = true,
    this.onTap,
    this.actionArea,
    this.isHighlighted = false,
    this.onCheckpointTap,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        border: Border.all(
          color: isHighlighted ? AppColors.gold : AppColors.border,
          width: isHighlighted ? 1.2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderRow(),
          _buildMetaRows(),
          if (task.checkpointHistory.isNotEmpty) _buildCheckpointTable(),
          if (task.photosBefore.isNotEmpty || task.photosProcess.isNotEmpty || task.photosAfter.isNotEmpty) _buildPhotosGallery(),
          if (task.finalValidations.isNotEmpty) _buildFinalValidationTable(),
          if (actionArea != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: actionArea!,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }

  Widget _buildHeaderRow() {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.unit.unitName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  task.task.jobName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _statusLabel(task.status),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _statusColor(task.status),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRows() {
    final rows = <List<String>>[
      ['Panel/Part', task.task.namaPanel],
      ['Deskripsi', task.task.jobDescription],
      ['Jam Plan', '${task.task.startTime} - ${task.task.targetFinishTime}'],
      ['Monitoring', '${task.checkpointHistory.length}/${task.maxCheckpointSessions}'],
    ];

    if (showDivision) {
      rows.insert(0, ['Divisi', task.division.divisionName]);
    }
    if (showEmployee) {
      rows.insert(1, ['Personil', task.employee.employeeName]);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(84),
          1: FlexColumnWidth(),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.top,
        children: rows
            .map(
              (row) => TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      row[0],
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      row[1],
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildCheckpointTable() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tableTitle('Check Point'),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 30,
                dataRowMinHeight: 30,
                dataRowMaxHeight: 42,
                columnSpacing: 16,
                horizontalMargin: 8,
                columns: const [
                  DataColumn(label: Text('Sesi')),
                  DataColumn(label: Text('Start')),
                  DataColumn(label: Text('Finish')),
                  DataColumn(label: Text('Check')),
                  DataColumn(label: Text('Durasi')),
                  DataColumn(label: Text('Prog %')),
                  DataColumn(label: Text('Status')),
                ],
                rows: task.checkpointHistory.map((session) {
                  final row = DataRow(
                    cells: [
                      DataCell(Text('${session.sessionNumber}')),
                      DataCell(Text(session.startWorkTime)),
                      DataCell(Text(session.finishWorkTime)),
                      DataCell(Text(session.checkpointTime)),
                      DataCell(Text(session.workedDurationLabel)),
                      DataCell(Text('${session.progress}%')),
                      DataCell(Text(session.jobStatusLabel)),
                    ],
                  );

                  if (onCheckpointTap == null) {
                    return row;
                  }

                  return DataRow.byIndex(
                    index: session.sessionNumber,
                    onSelectChanged: (_) => onCheckpointTap!(session),
                    cells: row.cells,
                  );
                }).toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Text(
                onCheckpointTap == null
                    ? 'Riwayat checkpoint tersimpan.'
                    : 'Klik baris sesi untuk review/edit.',
                style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotosGallery() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tableTitle('Dokumentasi Pekerjaan'),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (task.photosBefore.isNotEmpty)
                      _buildPhotoSection('Before', task.photosBefore),
                    if (task.photosProcess.isNotEmpty)
                      _buildPhotoSection('Progress', task.photosProcess),
                    if (task.photosAfter.isNotEmpty)
                      _buildPhotoSection('After', task.photosAfter),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSection(String label, List<String> urls) {
    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: urls.map((url) => _buildPhotoThumbnail(url)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoThumbnail(String url) {
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 50,
          height: 50,
          color: AppColors.border,
          child: Builder(
            builder: (context) => InkWell(
              onTap: () => _showFullImage(context, url),
              child: Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.broken_image,
                  color: AppColors.textMuted,
                  size: 24,
                ),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.gold),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showFullImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 1.0,
              maxScale: 3.0,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: const Text('Gagal memuat gambar', style: TextStyle(color: Colors.red)),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, shadows: [
                  Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(1, 1))
                ]),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinalValidationTable() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tableTitle('Validasi Akhir'),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 30,
                dataRowMinHeight: 30,
                dataRowMaxHeight: 42,
                columnSpacing: 16,
                horizontalMargin: 8,
                columns: const [
                  DataColumn(label: Text('Role')),
                  DataColumn(label: Text('Nama')),
                  DataColumn(label: Text('Catatan')),
                  DataColumn(label: Text('Waktu')),
                ],
                rows: task.finalValidations
                    .map(
                      (validation) => DataRow(
                        cells: [
                          DataCell(Text(validation.roleLabel)),
                          DataCell(Text(validation.name)),
                          DataCell(Text(
                            validation.note.isEmpty ? '-' : validation.note,
                            overflow: TextOverflow.ellipsis,
                          )),
                          DataCell(Text(_formatIsoTime(validation.time))),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tableTitle(String title) {
    return Container(
      width: double.infinity,
      color: AppColors.background,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'DONE':
        return 'Selesai';
      case 'SUBMITTED':
        return 'Menunggu Checkpoint';
      case 'PROSES':
        return 'Proses';
      case 'CHECK_PROGRESS':
        return 'Sudah Checkpoint';
      case 'CANCEL':
        return 'Batal';
      case 'VALIDATED':
        return 'Tervalidasi';
      case 'REWORK':
        return 'Rework';
      case 'ASSIGNED':
        return 'Belum Mulai';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'DONE':
      case 'VALIDATED':
        return AppColors.statusDone;
      case 'SUBMITTED':
      case 'ASSIGNED':
        return AppColors.orange;
      case 'PROSES':
      case 'CHECK_PROGRESS':
        return AppColors.gold;
      case 'CANCEL':
      case 'REWORK':
        return AppColors.statusLocked;
      default:
        return AppColors.textMuted;
    }
  }

  String _formatIsoTime(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;

    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    final year = parsed.year.toString();
    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }
}
