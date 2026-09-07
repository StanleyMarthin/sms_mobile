/*
Tujuan: Halaman monitoring mobile untuk daftar unit dan ringkasan progres divisi.
Caller: GoRouter route /monitoring.
Dependensi: MonitoringRepository, SessionManager, AppNotification, Date/route focus params.
Main Functions: MonitoringPage, _loadCars, _openReport.
Side Effects: HTTP read monitoring, navigasi route, menampilkan dialog/report.
*/
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/errors/error_message.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/utils/snackbar_helper.dart';
import '../../domain/entities/monitoring_entities.dart';
import '../../domain/repositories/monitoring_repository.dart';

class MonitoringPage extends StatefulWidget {
  const MonitoringPage({super.key, this.focusCarId});

  final String? focusCarId;

  @override
  State<MonitoringPage> createState() => _MonitoringPageState();
}

class _MonitoringPageState extends State<MonitoringPage> {
  late final MonitoringRepository _repository;
  List<MonitoringCar> _items = [];
  bool _isLoading = true;
  bool _focusHandled = false;
  String _scope = 'all';
  CancelToken? _loadCancelToken;

  @override
  void initState() {
    super.initState();
    _repository = sl<MonitoringRepository>();
    _loadCars();
  }

  @override
  void dispose() {
    _loadCancelToken?.cancel('Monitoring page disposed');
    super.dispose();
  }

  Future<void> _loadCars() async {
    _loadCancelToken?.cancel('Monitoring reload');
    final cancelToken = CancelToken();
    _loadCancelToken = cancelToken;

    final session = sl<SessionManager>();
    final division = session.divisionName;
    final canSeeAll = session.canViewAssignedUnits || session.canViewAllUnits;
    try {
      final items = await _repository.getCars(
        canSeeAll: canSeeAll,
        division: division,
        cancelToken: cancelToken,
      );
      if (!mounted || cancelToken.isCancelled) return;

      setState(() {
        _items = _sortItems(items);
        _isLoading = false;
      });
      _openFocusedCar();
    } catch (e) {
      if (!mounted || cancelToken.isCancelled) return;
      setState(() => _isLoading = false);
      AppNotification.showError(
        context,
        friendlyMessage(e, fallback: 'Gagal memuat monitoring'),
      );
    }
  }

  List<MonitoringCar> _sortItems(List<MonitoringCar> items) {
    final ordered = List<MonitoringCar>.from(items);
    ordered.sort((a, b) {
      final byDays = _daysToDelivery(a).compareTo(_daysToDelivery(b));
      if (byDays != 0) return byDays;
      return a.unitName.compareTo(b.unitName);
    });

    if (widget.focusCarId == null) return ordered;
    ordered.sort((a, b) {
      final aFocus = a.carId == widget.focusCarId ? 1 : 0;
      final bFocus = b.carId == widget.focusCarId ? 1 : 0;
      return bFocus.compareTo(aFocus);
    });
    return ordered;
  }

  void _openFocusedCar() {
    if (_focusHandled || widget.focusCarId == null) return;
    final target = _items
        .where((item) => item.carId == widget.focusCarId)
        .toList();
    if (target.isEmpty) return;

    _focusHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openUnitReport(context, target.first);
    });
  }

  List<MonitoringCar> get _visibleItems {
    if (_scope == 'margin') {
      return _items.where((item) => item.isMargin).toList();
    }
    if (_scope == 'nonMargin') {
      return _items.where((item) => !item.isMargin).toList();
    }
    return _items;
  }

  int _daysToDelivery(MonitoringCar car) {
    final delivery = DateTime.tryParse(car.deliveryDate ?? '');
    if (delivery == null) return 99999;
    return delivery.difference(DateTime.now()).inDays;
  }

  double _weeklyTotalHours(MonitoringCar car) {
    return car.divisions.fold<double>(
      0,
      (sum, division) => sum + division.weeklyWorkHours,
    );
  }

  double _remainingTotalHours(MonitoringCar car) {
    if (car.remainingWorkHours > 0) return car.remainingWorkHours;
    return car.divisions.fold<double>(
      0,
      (sum, division) => sum + division.remainingHours,
    );
  }

  String _deliveryCountdownLabel(MonitoringCar car) {
    final days = _daysToDelivery(car);
    if (days == 99999) return 'DL belum diisi';
    if (days < 0) return 'Terlambat ${days.abs()} hari';
    if (days == 0) return 'DL hari ini';
    return '$days hari lagi';
  }

  String _formatDate(String? value) {
    final parsed = DateTime.tryParse(value ?? '');
    if (parsed == null) return '-';
    final d = parsed.day.toString().padLeft(2, '0');
    final m = parsed.month.toString().padLeft(2, '0');
    final y = parsed.year.toString();
    return '$d/$m/$y';
  }

  Future<void> _openUnitReport(BuildContext context, MonitoringCar car) async {
    List<MonitoringDivisionProgress> divisions;
    try {
      divisions = car.divisions.isNotEmpty
          ? car.divisions
          : await _repository.getCarDivisions(car.carId);
    } catch (e) {
      if (!context.mounted) return;
      AppNotification.showError(
        context,
        friendlyMessage(e, fallback: 'Gagal memuat detail monitoring'),
      );
      return;
    }
    if (!context.mounted) return;

    final weeklyTotal = divisions.fold<double>(
      0,
      (sum, item) => sum + item.weeklyWorkHours,
    );
    final remainingTotal = car.remainingWorkHours > 0
        ? car.remainingWorkHours
        : divisions.fold<double>(0, (sum, item) => sum + item.remainingHours);
    final estimatedWeeks = weeklyTotal <= 0
        ? 0.0
        : remainingTotal / weeklyTotal;
    final daysToDl = _daysToDelivery(car);

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (screenContext) => Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.surfaceCard,
            foregroundColor: AppColors.textPrimary,
            title: Text('${car.unitName} - Weekly Report'),
          ),
          body: ListView(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${car.unitName} • ${car.owner}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 8),
                    _summaryRow(
                      'Kategori',
                      car.isMargin ? 'Margin' : 'Non Margin',
                    ),
                    _summaryRow('DL', _formatDate(car.deliveryDate)),
                    _summaryRow(
                      'Sisa hari ke DL',
                      _deliveryCountdownLabel(car),
                    ),
                    _summaryRow(
                      'Sisa jam kerja total',
                      '${remainingTotal.toStringAsFixed(1)} jam',
                    ),
                    _summaryRow(
                      'Total jam kerja minggu ini',
                      '${weeklyTotal.toStringAsFixed(1)} jam',
                    ),
                    _summaryRow(
                      'Estimasi selesai',
                      '${estimatedWeeks.toStringAsFixed(1)} minggu',
                    ),
                    _summaryRow(
                      'Progress unit',
                      '${car.avgProgressPercentage}%',
                    ),
                    if (car.nextMilestone != null)
                      _summaryRow('Milestone berikutnya', car.nextMilestone!),
                    if (daysToDl != 99999 && weeklyTotal > 0)
                      _buildProjectionHint(daysToDl, estimatedWeeks),
                  ],
                ),
              ),
              SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard,
                  border: Border.all(color: AppColors.border),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 34,
                    dataRowMinHeight: 34,
                    dataRowMaxHeight: 44,
                    horizontalMargin: 10,
                    columnSpacing: 16,
                    columns: [
                      DataColumn(label: Text('Divisi')),
                      DataColumn(label: Text('Jam Minggu Ini')),
                      DataColumn(label: Text('Sisa Jam')),
                      DataColumn(label: Text('Est. Minggu')),
                      DataColumn(label: Text('Progress')),
                    ],
                    rows: [
                      ...divisions.map((division) {
                        final estWeeks = division.weeklyWorkHours <= 0
                            ? 0
                            : division.remainingHours /
                                  division.weeklyWorkHours;
                        return DataRow(
                          cells: [
                            DataCell(Text(division.divisionName)),
                            DataCell(
                              Text(
                                '${division.weeklyWorkHours.toStringAsFixed(1)} jam',
                              ),
                            ),
                            DataCell(
                              Text(
                                '${division.remainingHours.toStringAsFixed(1)} jam',
                              ),
                            ),
                            DataCell(
                              Text('${estWeeks.toStringAsFixed(1)} minggu'),
                            ),
                            DataCell(Text('${division.progressPercentage}%')),
                          ],
                        );
                      }),
                      DataRow(
                        color: WidgetStateProperty.all(
                          AppColors.gold.withValues(alpha: 0.12),
                        ),
                        cells: [
                          DataCell(
                            Text(
                              'TOTAL',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          DataCell(
                            Text(
                              '${weeklyTotal.toStringAsFixed(1)} jam',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          DataCell(
                            Text(
                              '${remainingTotal.toStringAsFixed(1)} jam',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          DataCell(
                            Text(
                              '${estimatedWeeks.toStringAsFixed(1)} minggu',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          DataCell(
                            Text(
                              '${car.avgProgressPercentage}%',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () =>
                      context.push('/countdown?carId=${car.carId}'),
                  icon: Icon(Icons.timer_rounded, size: 16),
                  label: Text('Buka di Countdown'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.gold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectionHint(int daysToDl, double estimatedWeeks) {
    final estDays = (estimatedWeeks * 7).round();
    final safe = estDays <= daysToDl;
    final color = safe ? AppColors.statusDone : AppColors.statusLocked;
    final text = safe
        ? 'Estimasi saat ini masih masuk target DL.'
        : 'Estimasi saat ini melewati DL, perlu tambah kapasitas/penyesuaian target.';

    return Padding(
      padding: EdgeInsets.only(top: 8),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          border: Border.all(color: color.withValues(alpha: 0.28)),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildScopeChip(String key, String label) {
    final selected = _scope == key;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _scope = key),
      selectedColor: AppColors.gold.withValues(alpha: 0.16),
      backgroundColor: AppColors.surfaceCard,
      side: BorderSide(color: selected ? AppColors.gold : AppColors.border),
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? AppColors.gold : AppColors.textMuted,
      ),
    );
  }

  Widget _buildUnitListRow(MonitoringCar car) {
    final remainingHours = _remainingTotalHours(car);
    final weeklyHours = _weeklyTotalHours(car);
    final estWeeks = weeklyHours <= 0 ? 0 : remainingHours / weeklyHours;

    return InkWell(
      onTap: () => _openUnitReport(context, car),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    car.unitName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    car.owner,
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Text(
                car.isMargin ? 'Margin' : 'Non',
                style: TextStyle(
                  fontSize: 11,
                  color: car.isMargin ? AppColors.statusDone : AppColors.orange,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: Text(
                _formatDate(car.deliveryDate),
                style: TextStyle(fontSize: 11, color: AppColors.textPrimary),
              ),
            ),
            Expanded(
              child: Text(
                _deliveryCountdownLabel(car),
                style: TextStyle(
                  fontSize: 11,
                  color: _daysToDelivery(car) < 0
                      ? AppColors.statusLocked
                      : AppColors.textPrimary,
                ),
              ),
            ),
            Expanded(
              child: Text(
                '${remainingHours.toStringAsFixed(0)} j',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: Text(
                '${estWeeks.toStringAsFixed(1)} mg',
                style: TextStyle(fontSize: 11, color: AppColors.textPrimary),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = sl<SessionManager>();
    final division = session.divisionName;
    final canSeeAll = session.canViewAssignedUnits || session.canViewAllUnits;

    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    final visible = _visibleItems;

    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            canSeeAll
                ? 'Monitoring Unit - Referensi Planning PM'
                : 'Monitoring Unit Divisi ${division ?? '-'}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildScopeChip('all', 'Semua Unit'),
            _buildScopeChip('margin', 'Margin'),
            _buildScopeChip('nonMargin', 'Non Margin'),
          ],
        ),
        SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Container(
                color: AppColors.background,
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        'Unit',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Tipe',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'DL',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Sisa Hari',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Sisa Jam',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'Est',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                  ],
                ),
              ),
              if (visible.isEmpty)
                Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Tidak ada unit untuk filter ini.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                )
              else
                ...visible.map(_buildUnitListRow),
            ],
          ),
        ),
      ],
    );
  }
}
