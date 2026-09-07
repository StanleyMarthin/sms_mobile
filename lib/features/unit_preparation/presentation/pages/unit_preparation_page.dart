/*
Tujuan: Halaman mobile Unit Preparation untuk search-first catalog dan pendataan item.
Caller: GoRouter route /unit-preparation.
Dependensi: ApiClient, SessionManager, UploadService, InAppCameraPage, RemoteUnitPreparationDatasource, UnitPreparationCatalogHelper.
Main Functions: load catalog detail, search item, draft survey, confirm survey, annotate foto aktual.
Side Effects: HTTP request pendataan dan materialization ke be_sms.
*/

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/errors/error_message.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/upload_service.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/widgets/in_app_camera_page.dart';
import '../../data/datasources/remote_unit_preparation_datasource.dart';
import '../../domain/entities/unit_preparation_models.dart';
import '../utils/unit_preparation_catalog_helper.dart';

class UnitPreparationPage extends StatefulWidget {
  const UnitPreparationPage({
    super.key,
    this.initialUnitId,
    this.initialUnitName,
    this.initialCustomerName,
  });

  final String? initialUnitId;
  final String? initialUnitName;
  final String? initialCustomerName;

  @override
  State<UnitPreparationPage> createState() => _UnitPreparationPageState();
}

class _UnitPreparationPageState extends State<UnitPreparationPage> {
  late final RemoteUnitPreparationDatasource datasource;
  late final UploadService uploadService;
  late final SessionManager sessionManager;
  late final TextEditingController unitController;
  late final TextEditingController queryController;
  late final ScrollController resultScrollController;
  Timer? searchDebounce;

  List<CatalogReference> references = const [];
  List<CatalogSearchEntry> searchEntries = const [];
  String selectedComponent = '';
  String selectedPanel = '';
  String query = '';
  bool catalogLoaded = false;
  bool loading = false;
  String? message;

  @override
  void initState() {
    super.initState();
    sessionManager = sl<SessionManager>();
    datasource = RemoteUnitPreparationDatasource(
      apiClient: sl<ApiClient>(),
      sessionManager: sessionManager,
    );
    uploadService = sl<UploadService>();
    unitController = TextEditingController(text: widget.initialUnitId ?? '');
    queryController = TextEditingController();
    resultScrollController = ScrollController();
    if (unitController.text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => loadCatalog());
    }
  }

  @override
  void dispose() {
    searchDebounce?.cancel();
    unitController.dispose();
    queryController.dispose();
    resultScrollController.dispose();
    super.dispose();
  }

  List<CatalogSearchEntry> get filteredEntries =>
      UnitPreparationCatalogHelper.searchEntries(
        searchEntries,
        query: query,
        componentFilter: selectedComponent,
        panelFilter: selectedPanel,
      );

  String get currentUnitId => unitController.text.trim();

  String get unitTitle {
    final title = widget.initialUnitName?.trim();
    if (title != null && title.isNotEmpty) return title;
    return currentUnitId.isEmpty ? 'Pilih unit' : currentUnitId;
  }

  String get unitSubtitle {
    final owner = widget.initialCustomerName?.trim();
    if (owner != null && owner.isNotEmpty) return owner;
    return currentUnitId.isEmpty ? 'Belum ada unit aktif' : 'Unit aktif';
  }

  Future<void> loadCatalog({String? nextUnitId}) async {
    if (nextUnitId != null) unitController.text = nextUnitId;
    final unitId = currentUnitId;
    if (unitId.isEmpty) {
      setState(() {
        message = 'Pilih unit dulu.';
        catalogLoaded = false;
        references = const [];
        searchEntries = const [];
      });
      return;
    }

    setState(() {
      loading = true;
      message = null;
    });

    try {
      final catalog = await datasource.getCatalog(unitId);
      final hydrated = await Future.wait(
        catalog.map((reference) async {
          if (reference.items.isNotEmpty) return reference;
          try {
            return await datasource.getReference(unitId, reference.id);
          } catch (_) {
            return reference;
          }
        }),
      );
      if (!mounted) return;
      setState(() {
        catalogLoaded = true;
        references = hydrated;
        searchEntries = UnitPreparationCatalogHelper.buildSearchEntries(
          hydrated,
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        message = _unitPreparationErrorMessage(
          error,
          fallback: 'Gagal memuat catalog.',
        );
        catalogLoaded = searchEntries.isNotEmpty;
      });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> refreshReference(CatalogReference reference) async {
    try {
      final detail = await datasource.getReference(
        unitController.text.trim(),
        reference.id,
      );
      if (!mounted) return;
      final nextReferences = [
        for (final entry in references) entry.id == detail.id ? detail : entry,
      ];
      setState(() {
        references = nextReferences;
        searchEntries = UnitPreparationCatalogHelper.buildSearchEntries(
          nextReferences,
        );
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => message = _unitPreparationErrorMessage(
            error,
            fallback: 'Gagal memperbarui item.',
          ),
        );
      }
    }
  }

  Future<void> openSurvey(CatalogSearchEntry entry) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SurveySheet(
        item: entry.item,
        unitId: currentUnitId,
        reference: entry.reference,
        uploadService: uploadService,
        onAddPhoto: (fileUrl, caption) => datasource.addActualPhoto(
          unitId: currentUnitId,
          itemId: entry.item.id,
          fileUrl: fileUrl,
          caption: caption,
        ),
        onSaveDraft: (survey) => datasource.saveDraft(
          unitId: currentUnitId,
          itemId: entry.item.id,
          survey: survey,
        ),
        onConfirm: (survey) => datasource.confirmSurvey(
          unitId: currentUnitId,
          itemId: entry.item.id,
          survey: survey,
        ),
      ),
    );
    if (result != null) {
      await refreshReference(entry.reference);
      if (!mounted) return;
      final nextEntry = UnitPreparationCatalogHelper.nextSurveyEntry(
        filteredEntries,
        entry.item.id,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result == 'confirm' ? 'Item sudah didata.' : 'Draft tersimpan.',
          ),
          action: nextEntry == null
              ? null
              : SnackBarAction(
                  label: 'Item Berikutnya',
                  onPressed: () => openSurvey(nextEntry),
                ),
        ),
      );
    }
  }

  Future<void> openCountdown(CatalogItem item) async {
    final panelId = item.promotedPanelId;
    if (panelId == null || panelId <= 0) {
      setState(() => message = 'Master Panel belum tersedia untuk item ini.');
      return;
    }
    setState(() {
      loading = true;
      message = null;
    });
    try {
      final panel = await datasource.getMasterPanel(currentUnitId, panelId);
      if (!mounted) return;
      final result = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (context) => _CountdownSheet(
          panel: panel,
          onSubmit: (job) => datasource.createJobdescs(
            unitId: currentUnitId,
            panelId: panelId,
            jobs: [job],
          ),
        ),
      );
      if (result == true) {
        await loadCatalog();
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => message = _unitPreparationErrorMessage(
            error,
            fallback: 'Gagal membuka pekerjaan.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = filteredEntries;
    final hasCatalog = catalogLoaded && searchEntries.isNotEmpty;
    return Column(
      children: [
        _UnitContextHeader(
          title: unitTitle,
          subtitle: unitSubtitle,
          itemCount: searchEntries.length,
          loading: loading,
          onChangeUnit: showUnitPicker,
        ),
        if (message != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: _InlineError(message: message!),
          ),
        if (loading) const LinearProgressIndicator(minHeight: 2),
        if (hasCatalog)
          _CatalogFilters(
            queryController: queryController,
            selectedComponent: selectedComponent,
            selectedPanel: selectedPanel,
            resultCount: results.length,
            onQueryChanged: scheduleSearch,
            onClearQuery: () {
              queryController.clear();
              searchDebounce?.cancel();
              setState(() => query = '');
            },
            onComponentChanged: (value) {
              setState(() => selectedComponent = value);
              if (resultScrollController.hasClients) {
                resultScrollController.jumpTo(0);
              }
            },
            onPanelPressed: showPanelPicker,
          ),
        Expanded(
          child: !catalogLoaded && loading
              ? const _CatalogSkeletonList()
              : currentUnitId.isEmpty
              ? _EmptyCatalogState(
                  message: 'Pilih unit untuk mulai pendataan catalog.',
                  actionLabel: 'Ganti Unit',
                  onAction: showUnitPicker,
                )
              : catalogLoaded && searchEntries.isEmpty
              ? _EmptyCatalogState(
                  message: 'Belum ada item Catalog untuk unit ini.',
                  actionLabel: 'Kembali ke Unit',
                  onAction: () => context.go('/home'),
                )
              : catalogLoaded && results.isEmpty
              ? const _EmptyCatalogState(
                  message: 'Item catalog tidak ditemukan.',
                )
              : ListView.separated(
                  controller: resultScrollController,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  itemCount: results.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final entry = results[index];
                    return _CatalogResultCard(
                      entry: entry,
                      onSelect: () => openSurvey(entry),
                      onCountdown:
                          !entry.item.isConfirmed ||
                              entry.item.promotedPanelId == null
                          ? null
                          : () => openCountdown(entry.item),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void scheduleSearch(String value) {
    searchDebounce?.cancel();
    searchDebounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      setState(() => query = value);
    });
  }

  Future<void> showPanelPicker() async {
    final panel = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _PanelPickerSheet(
        panels: UnitPreparationCatalogHelper.panelOptions(references),
        selectedPanel: selectedPanel,
      ),
    );
    if (panel == null || !mounted) return;
    setState(() => selectedPanel = panel);
    if (resultScrollController.hasClients) {
      resultScrollController.jumpTo(0);
    }
  }

  Future<void> showUnitPicker() async {
    final unitId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _UnitPickerSheet(
        units: sessionManager.managedUnitIds,
        initialUnitId: currentUnitId,
      ),
    );
    if (unitId == null || !mounted) return;
    setState(() {
      selectedComponent = '';
      selectedPanel = '';
      query = '';
      queryController.clear();
    });
    await loadCatalog(nextUnitId: unitId);
  }
}

class _CatalogResultCard extends StatelessWidget {
  const _CatalogResultCard({
    required this.entry,
    required this.onSelect,
    this.onCountdown,
  });

  final CatalogSearchEntry entry;
  final VoidCallback onSelect;
  final VoidCallback? onCountdown;

  @override
  Widget build(BuildContext context) {
    final item = entry.item;
    final title = UnitPreparationCatalogHelper.resolveItemLabel(
      item,
      entry.reference,
    );
    final subtitle = item.partName == title
        ? item.partNumber ?? entry.reference.panelName
        : item.partName ?? item.partNumber ?? entry.reference.panelName;

    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 48,
                child: Text(
                  item.positionCode ?? '-',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (item.partNumber != null) item.partNumber,
                        entry.reference.componentName,
                      ].whereType<String>().join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StatusPill(item: item),
                  const SizedBox(height: 4),
                  if (onCountdown != null)
                    IconButton(
                      tooltip: 'Buat pekerjaan',
                      constraints: const BoxConstraints(
                        minHeight: 44,
                        minWidth: 44,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: onCountdown,
                      icon: const Icon(Icons.playlist_add_check_rounded),
                    )
                  else
                    const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnitContextHeader extends StatelessWidget {
  const _UnitContextHeader({
    required this.title,
    required this.subtitle,
    required this.itemCount,
    required this.loading,
    required this.onChangeUnit,
  });

  final String title;
  final String subtitle;
  final int itemCount;
  final bool loading;
  final VoidCallback onChangeUnit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  itemCount > 0
                      ? '$subtitle • $itemCount item catalog'
                      : subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: loading ? null : onChangeUnit,
            icon: const Icon(Icons.swap_horiz_rounded),
            label: const Text('Ganti Unit'),
          ),
        ],
      ),
    );
  }
}

class _CatalogFilters extends StatelessWidget {
  const _CatalogFilters({
    required this.queryController,
    required this.selectedComponent,
    required this.selectedPanel,
    required this.resultCount,
    required this.onQueryChanged,
    required this.onClearQuery,
    required this.onComponentChanged,
    required this.onPanelPressed,
  });

  final TextEditingController queryController;
  final String selectedComponent;
  final String selectedPanel;
  final int resultCount;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearQuery;
  final ValueChanged<String> onComponentChanged;
  final VoidCallback onPanelPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: queryController,
            minLines: 1,
            decoration: InputDecoration(
              labelText: 'Cari nama, part number, atau code',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: queryController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: onClearQuery,
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
            onChanged: onQueryChanged,
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _FilterChip(
                  label: 'Semua',
                  selected: selectedComponent.isEmpty,
                  onSelected: () => onComponentChanged(''),
                ),
                for (final value
                    in UnitPreparationCatalogHelper.componentFilters)
                  _FilterChip(
                    label: _componentLabel(value),
                    selected: selectedComponent == value,
                    onSelected: () => onComponentChanged(value),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPanelPressed,
                  icon: const Icon(Icons.view_agenda_outlined),
                  label: Text(
                    selectedPanel.isEmpty
                        ? 'Panel: Semua Panel'
                        : 'Panel: $selectedPanel',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('$resultCount item'),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.item});

  final CatalogItem item;

  @override
  Widget build(BuildContext context) {
    final confirmed = item.isConfirmed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: confirmed
            ? AppColors.statusDone.withValues(alpha: 0.15)
            : AppColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        confirmed
            ? '✓ Sudah didata'
            : UnitPreparationCatalogHelper.surveyStatusLabel(item.surveyStatus),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: confirmed ? AppColors.statusDone : AppColors.gold,
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
      ),
    );
  }
}

class _EmptyCatalogState extends StatelessWidget {
  const _EmptyCatalogState({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _CatalogSkeletonList extends StatelessWidget {
  const _CatalogSkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: 6,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, _) => Container(
        height: 78,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class _PanelPickerSheet extends StatefulWidget {
  const _PanelPickerSheet({required this.panels, required this.selectedPanel});

  final List<String> panels;
  final String selectedPanel;

  @override
  State<_PanelPickerSheet> createState() => _PanelPickerSheetState();
}

class _PanelPickerSheetState extends State<_PanelPickerSheet> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = controller.text.trim().toLowerCase();
    final panels = widget.panels
        .where((panel) => query.isEmpty || panel.toLowerCase().contains(query))
        .toList();
    return _PickerSheet(
      title: 'Pilih Panel',
      controller: controller,
      hint: 'Cari panel',
      children: [
        ListTile(
          minVerticalPadding: 12,
          title: const Text('Semua Panel'),
          trailing: widget.selectedPanel.isEmpty
              ? const Icon(Icons.check_rounded)
              : null,
          onTap: () => Navigator.pop(context, ''),
        ),
        for (final panel in panels)
          ListTile(
            minVerticalPadding: 12,
            title: Text(panel),
            trailing: panel == widget.selectedPanel
                ? const Icon(Icons.check_rounded)
                : null,
            onTap: () => Navigator.pop(context, panel),
          ),
      ],
      onChanged: () => setState(() {}),
    );
  }
}

class _UnitPickerSheet extends StatefulWidget {
  const _UnitPickerSheet({required this.units, required this.initialUnitId});

  final List<String> units;
  final String initialUnitId;

  @override
  State<_UnitPickerSheet> createState() => _UnitPickerSheetState();
}

class _UnitPickerSheetState extends State<_UnitPickerSheet> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initialUnitId);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = controller.text.trim().toLowerCase();
    final units = widget.units
        .where((unit) => query.isEmpty || unit.toLowerCase().contains(query))
        .toList();
    return _PickerSheet(
      title: 'Ganti Unit',
      controller: controller,
      hint: 'Cari atau isi Unit ID',
      children: [
        ListTile(
          minVerticalPadding: 12,
          leading: const Icon(Icons.check_circle_outline_rounded),
          title: Text(
            query.isEmpty ? 'Gunakan Unit ID' : controller.text.trim(),
          ),
          onTap: () {
            final text = controller.text.trim();
            if (text.isNotEmpty) Navigator.pop(context, text);
          },
        ),
        for (final unit in units)
          ListTile(
            minVerticalPadding: 12,
            title: Text(unit),
            onTap: () => Navigator.pop(context, unit),
          ),
      ],
      onChanged: () => setState(() {}),
    );
  }
}

class _PickerSheet extends StatelessWidget {
  const _PickerSheet({
    required this.title,
    required this.controller,
    required this.hint,
    required this.children,
    required this.onChanged,
  });

  final String title;
  final TextEditingController controller;
  final String hint;
  final List<Widget> children;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: hint,
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
                onChanged: (_) => onChanged(),
              ),
              const SizedBox(height: 8),
              Expanded(child: ListView(children: children)),
            ],
          ),
        ),
      ),
    );
  }
}

String _componentLabel(String value) => switch (value) {
  'ENGINE' => 'Engine',
  'UNDERCARRIAGE' => 'Undercarriage',
  'ELECTRICAL' => 'Electrical',
  'BODY' => 'Body',
  'INTERIOR' => 'Interior',
  _ => value,
};

String _unitPreparationErrorMessage(Object error, {required String fallback}) {
  if (error is DioException) {
    final statusCode = error.response?.statusCode;
    final network =
        error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout;
    return UnitPreparationCatalogHelper.errorLabel(
      statusCode: statusCode,
      network: network,
      fallback: fallback,
    );
  }
  return friendlyMessage(error, fallback: fallback);
}

String _panelText(Map<String, dynamic> panel, String snake, String camel) {
  final value = panel[snake] ?? panel[camel];
  final text = '${value ?? ''}'.trim();
  return text.isEmpty ? '-' : text;
}

class _CountdownSheet extends StatefulWidget {
  const _CountdownSheet({required this.panel, required this.onSubmit});

  final Map<String, dynamic> panel;
  final Future<List<dynamic>> Function(Map<String, dynamic> job) onSubmit;

  @override
  State<_CountdownSheet> createState() => _CountdownSheetState();
}

class _CountdownSheetState extends State<_CountdownSheet> {
  final divisionController = TextEditingController();
  final jobTypeController = TextEditingController();
  final descriptionController = TextEditingController();
  final targetController = TextEditingController();
  bool submitting = false;

  @override
  void dispose() {
    divisionController.dispose();
    jobTypeController.dispose();
    descriptionController.dispose();
    targetController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final divisionId = int.tryParse(divisionController.text.trim());
    final targetHours = double.tryParse(targetController.text.trim());
    if (divisionId == null ||
        jobTypeController.text.trim().isEmpty ||
        descriptionController.text.trim().isEmpty ||
        targetHours == null ||
        targetHours <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Divisi, jenis, deskripsi, dan target wajib diisi.'),
        ),
      );
      return;
    }
    setState(() => submitting = true);
    try {
      await widget.onSubmit({
        'divisionId': divisionId,
        'jobTypeId': jobTypeController.text.trim(),
        'description': descriptionController.text.trim(),
        'targetHoursInitial': targetHours,
        'taskCategory': 'MAIN',
      });
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: ListView(
        shrinkWrap: true,
        children: [
          Text('Buat Countdown', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Component: ${_panelText(widget.panel, 'component_name', 'componentName')}',
          ),
          Text('Panel: ${_panelText(widget.panel, 'name', 'name')}'),
          Text(
            'Part Number: ${_panelText(widget.panel, 'part_number', 'partNumber')}',
          ),
          Text(
            'Position Code: ${_panelText(widget.panel, 'position_code', 'positionCode')}',
          ),
          Text(
            'Initial Condition: ${_panelText(widget.panel, 'initial_condition', 'initialCondition')}',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: divisionController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Division ID'),
          ),
          TextField(
            controller: jobTypeController,
            decoration: const InputDecoration(labelText: 'Job Type ID'),
          ),
          TextField(
            controller: descriptionController,
            decoration: const InputDecoration(labelText: 'Deskripsi pekerjaan'),
            maxLines: 3,
          ),
          TextField(
            controller: targetController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Target Jam'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: submitting ? null : submit,
            child: const Text('Simpan Countdown'),
          ),
        ],
      ),
    );
  }
}

class _SurveySheet extends StatefulWidget {
  const _SurveySheet({
    required this.item,
    required this.reference,
    required this.unitId,
    required this.uploadService,
    required this.onAddPhoto,
    required this.onSaveDraft,
    required this.onConfirm,
  });

  final CatalogItem item;
  final CatalogReference reference;
  final String unitId;
  final UploadService uploadService;
  final Future<void> Function(String fileUrl, String? caption) onAddPhoto;
  final Future<CatalogItem> Function(Map<String, dynamic> survey) onSaveDraft;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> survey)
  onConfirm;

  @override
  State<_SurveySheet> createState() => _SurveySheetState();
}

class _SurveySheetState extends State<_SurveySheet> {
  final qtyController = TextEditingController();
  final actualNameController = TextEditingController();
  final locationController = TextEditingController();
  final notesController = TextEditingController();
  String availability = 'UNKNOWN';
  String condition = 'UNKNOWN';
  String action = 'UNDECIDED';
  String? photoPath;
  String? existingPhotoUrl;
  CatalogAnnotationMarker? actualMarker;
  bool markerChanged = false;
  bool submitting = false;

  @override
  void initState() {
    super.initState();
    qtyController.text = widget.item.qtyOpname?.toString() ?? '';
    actualNameController.text = widget.item.actualName ?? '';
    locationController.text = widget.item.location ?? '';
    notesController.text = widget.item.notes ?? '';
    availability = widget.item.availabilityStatus;
    condition = widget.item.conditionStatus;
    action = widget.item.actionType;
    existingPhotoUrl = UnitPreparationCatalogHelper.pickActualPhoto(
      widget.item.media,
    )?.fileUrl;
    final markers = UnitPreparationCatalogHelper.decodeActualPhotoMarkers(
      widget.item.media,
    );
    actualMarker = markers.isEmpty ? null : markers.last;
  }

  @override
  void dispose() {
    qtyController.dispose();
    actualNameController.dispose();
    locationController.dispose();
    notesController.dispose();
    super.dispose();
  }

  Map<String, dynamic> buildSurvey() {
    final existingMapping = widget.item.mappings.isEmpty
        ? null
        : widget.item.mappings.first;
    return {
      'qtyOpname': double.tryParse(qtyController.text.trim()),
      'actualName': actualNameController.text.trim().isEmpty
          ? null
          : actualNameController.text.trim(),
      'availabilityStatus': availability,
      'conditionStatus': condition,
      'actionType': action,
      'location': locationController.text.trim().isEmpty
          ? null
          : locationController.text.trim(),
      'notes': notesController.text.trim().isEmpty
          ? null
          : notesController.text.trim(),
      if (existingMapping != null)
        'mapping': {
          'catalogReferenceMediaId': existingMapping.catalogReferenceMediaId,
          'xPercent': existingMapping.xPercent,
          'yPercent': existingMapping.yPercent,
        },
    };
  }

  Future<void> submit({required bool confirm}) async {
    setState(() => submitting = true);

    try {
      final survey = buildSurvey();
      if (confirm) {
        await widget.onConfirm(survey);
      } else {
        await widget.onSaveDraft(survey);
      }

      if (photoPath != null) {
        final photoUrl = await widget.uploadService.uploadPhoto(
          localPath: photoPath!,
          unit: widget.unitId,
          division: 'Unit Preparation',
          job: UnitPreparationCatalogHelper.resolveItemLabel(
            widget.item,
            widget.reference,
          ),
          panel: widget.reference.panelName,
          type: 'actual',
        );
        if (photoUrl == null || photoUrl.isEmpty) {
          throw Exception('Upload foto aktual gagal.');
        }
        await widget.onAddPhoto(
          photoUrl,
          actualMarker == null
              ? null
              : UnitPreparationCatalogHelper.encodeActualPhotoCaption([
                  actualMarker!,
                ]),
        );
      } else if (markerChanged && existingPhotoUrl != null) {
        await widget.onAddPhoto(
          existingPhotoUrl!,
          actualMarker == null
              ? null
              : UnitPreparationCatalogHelper.encodeActualPhotoCaption([
                  actualMarker!,
                ]),
        );
      }

      if (mounted) Navigator.pop(context, confirm ? 'confirm' : 'draft');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _unitPreparationErrorMessage(
              error,
              fallback: 'Gagal menyimpan pendataan.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  Future<void> pickCameraPhoto() async {
    final path = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const InAppCameraPage(
          slot: 'unit_preparation_actual',
          label: 'Foto Aktual Pendataan',
        ),
        fullscreenDialog: true,
      ),
    );
    if (!mounted || path == null) return;
    setState(() {
      photoPath = path;
      actualMarker = null;
      markerChanged = true;
    });
  }

  Future<void> pickGalleryPhoto() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (!mounted || file == null) return;
      setState(() {
        photoPath = file.path;
        actualMarker = null;
        markerChanged = true;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _unitPreparationErrorMessage(
              error,
              fallback: 'Gagal memilih foto.',
            ),
          ),
        ),
      );
    }
  }

  void placeMarker(TapUpDetails details, BoxConstraints constraints) {
    if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0) return;
    final xPercent = (details.localPosition.dx / constraints.maxWidth * 100)
        .clamp(0.0, 100.0)
        .toDouble();
    final yPercent = (details.localPosition.dy / constraints.maxHeight * 100)
        .clamp(0.0, 100.0)
        .toDouble();

    setState(() {
      actualMarker = CatalogAnnotationMarker(
        name: UnitPreparationCatalogHelper.resolveMarkerName(
          widget.item,
          widget.reference,
        ),
        xPercent: xPercent,
        yPercent: yPercent,
      );
      markerChanged = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = UnitPreparationCatalogHelper.resolveItemLabel(
      widget.item,
      widget.reference,
    );
    final canEdit = !widget.item.isConfirmed;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.92,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${widget.item.positionCode ?? '-'} $title',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.reference.componentName,
                                style: TextStyle(
                                  color: AppColors.gold,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.item.partName ?? 'Nama item belum diisi',
                              ),
                              Text(
                                widget.item.partNumber ??
                                    'Part number belum diisi',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _SectionLabel('Ketersediaan'),
                    _ChoiceWrap(
                      value: availability,
                      enabled: canEdit,
                      options: const {
                        'AVAILABLE': 'Ada',
                        'NOT_AVAILABLE': 'Tidak Ada',
                        'UNKNOWN': 'Belum Tahu',
                      },
                      onChanged: (value) =>
                          setState(() => availability = value),
                    ),
                    _SectionLabel('Kondisi'),
                    _ChoiceWrap(
                      value: condition,
                      enabled: canEdit,
                      options: const {
                        'GOOD': 'Baik',
                        'RESTORE': 'Restorasi',
                        'NOT_USABLE': 'Tidak Layak',
                        'UNKNOWN': 'Belum Tahu',
                      },
                      onChanged: (value) => setState(() => condition = value),
                    ),
                    _SectionLabel('Tindakan'),
                    _ChoiceWrap(
                      value: action,
                      enabled: canEdit,
                      options: const {
                        'NO_ACTION': 'Tidak Perlu',
                        'JOBDESC': 'Buat Pekerjaan',
                        'JOBDESC_ORDER': 'Order',
                        'UNDECIDED': 'Belum Diputuskan',
                      },
                      onChanged: (value) => setState(() => action = value),
                    ),
                    const SizedBox(height: 12),
                    _SectionLabel('Foto Aktual'),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: submitting || !canEdit
                                ? null
                                : pickCameraPhoto,
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: const Text('Ambil Foto'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: submitting || !canEdit
                                ? null
                                : pickGalleryPhoto,
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Galeri'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _ActualPhotoPreview(
                      localPath: photoPath,
                      remoteUrl: existingPhotoUrl,
                      marker: actualMarker,
                      onTapUp:
                          !canEdit ||
                              (photoPath == null && existingPhotoUrl == null)
                          ? null
                          : (details, constraints) =>
                                placeMarker(details, constraints),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            actualMarker == null
                                ? 'Tap foto untuk tandai posisi.'
                                : 'Marker: ${actualMarker!.name}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        if (actualMarker != null && canEdit)
                          TextButton.icon(
                            onPressed: () => setState(() {
                              actualMarker = null;
                              markerChanged = true;
                            }),
                            icon: const Icon(Icons.delete_outline_rounded),
                            label: const Text('Hapus'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _SectionLabel('Qty Opname'),
                    _QtyStepper(controller: qtyController, enabled: canEdit),
                    const SizedBox(height: 12),
                    TextField(
                      controller: actualNameController,
                      enabled: canEdit,
                      decoration: const InputDecoration(
                        labelText: 'Nama Aktual',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: locationController,
                      enabled: canEdit,
                      decoration: const InputDecoration(labelText: 'Lokasi'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notesController,
                      enabled: canEdit,
                      decoration: const InputDecoration(labelText: 'Catatan'),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    top: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                ),
                child: canEdit
                    ? Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: submitting
                                  ? null
                                  : () => submit(confirm: false),
                              child: const Text('Simpan Draft'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              onPressed: submitting
                                  ? null
                                  : () => submit(confirm: true),
                              child: Text(
                                submitting ? 'Menyimpan...' : 'KONFIRMASI',
                              ),
                            ),
                          ),
                        ],
                      )
                    : FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Tutup'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _ChoiceWrap extends StatelessWidget {
  const _ChoiceWrap({
    required this.value,
    required this.options,
    required this.onChanged,
    required this.enabled,
  });

  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in options.entries)
          ChoiceChip(
            label: Text(entry.value),
            selected: value == entry.key,
            onSelected: enabled ? (_) => onChanged(entry.key) : null,
            materialTapTargetSize: MaterialTapTargetSize.padded,
          ),
      ],
    );
  }
}

class _QtyStepper extends StatefulWidget {
  const _QtyStepper({required this.controller, required this.enabled});

  final TextEditingController controller;
  final bool enabled;

  @override
  State<_QtyStepper> createState() => _QtyStepperState();
}

class _QtyStepperState extends State<_QtyStepper> {
  void change(int delta) {
    final current = int.tryParse(widget.controller.text.trim()) ?? 0;
    final next = (current + delta).clamp(0, 999);
    widget.controller.text = '$next';
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.outlined(
          onPressed: widget.enabled ? () => change(-1) : null,
          icon: const Icon(Icons.remove_rounded),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: widget.controller,
            enabled: widget.enabled,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(labelText: 'Qty Opname'),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: widget.enabled ? () => change(1) : null,
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    );
  }
}

class _ActualPhotoPreview extends StatelessWidget {
  const _ActualPhotoPreview({
    this.localPath,
    this.remoteUrl,
    this.marker,
    this.onTapUp,
  });

  final String? localPath;
  final String? remoteUrl;
  final CatalogAnnotationMarker? marker;
  final void Function(TapUpDetails details, BoxConstraints constraints)?
  onTapUp;

  @override
  Widget build(BuildContext context) {
    final hasLocal = localPath != null && localPath!.isNotEmpty;
    final hasRemote = remoteUrl != null && remoteUrl!.isNotEmpty;

    return AspectRatio(
      aspectRatio: 4 / 3,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final content = Container(
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            clipBehavior: Clip.antiAlias,
            child: !hasLocal && !hasRemote
                ? const Center(child: Text('Belum ada foto aktual'))
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      if (hasLocal)
                        Image.file(File(localPath!), fit: BoxFit.contain)
                      else
                        Image.network(
                          remoteUrl!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Center(
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      if (marker != null)
                        Positioned(
                          left:
                              marker!.xPercent / 100 * constraints.maxWidth -
                              12,
                          top:
                              marker!.yPercent / 100 * constraints.maxHeight -
                              24,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 28,
                          ),
                        ),
                    ],
                  ),
          );

          if (onTapUp == null) return content;
          return GestureDetector(
            onTapUp: (details) => onTapUp!(details, constraints),
            child: content,
          );
        },
      ),
    );
  }
}
