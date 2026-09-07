/*
Tujuan: Halaman mobile Unit Preparation untuk navigasi unit -> component -> panel -> survey catalog.
Caller: GoRouter route /unit-preparation.
Dependensi: ApiClient, SessionManager, UploadService, InAppCameraPage, RemoteUnitPreparationDatasource, UnitPreparationCatalogHelper.
Main Functions: load units, load catalog hierarchy, panel workspace, draft survey, confirm survey, annotate foto aktual.
Side Effects: HTTP request pendataan dan materialization ke be_sms.
*/

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
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

enum _PreparationStep { units, components, panels, panel }

class _UnitPreparationPageState extends State<UnitPreparationPage> {
  late final RemoteUnitPreparationDatasource datasource;
  late final UploadService uploadService;
  late final SessionManager sessionManager;
  late final TextEditingController unitSearchController;
  late final TextEditingController catalogSearchController;
  late final TextEditingController panelSearchController;
  late final TextEditingController partSearchController;
  late final ScrollController partScrollController;
  Timer? searchDebounce;

  _PreparationStep step = _PreparationStep.units;
  List<UnitPreparationUnit> units = const [];
  List<CatalogReference> references = const [];
  List<CatalogSearchEntry> searchEntries = const [];
  UnitPreparationUnit? selectedUnit;
  String selectedComponent = '';
  CatalogReference? selectedReference;
  String unitQuery = '';
  String catalogQuery = '';
  String panelQuery = '';
  String partQuery = '';
  bool unitsLoaded = false;
  bool catalogLoaded = false;
  bool loading = false;
  bool searchHydrating = false;
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
    unitSearchController = TextEditingController();
    catalogSearchController = TextEditingController();
    panelSearchController = TextEditingController();
    partSearchController = TextEditingController();
    partScrollController = ScrollController();

    final initialUnitId = widget.initialUnitId?.trim();
    if (initialUnitId != null && initialUnitId.isNotEmpty) {
      selectedUnit = UnitPreparationUnit(
        carId: initialUnitId,
        unitName: widget.initialUnitName?.trim().isNotEmpty == true
            ? widget.initialUnitName!.trim()
            : initialUnitId,
        customerName: widget.initialCustomerName,
      );
      step = _PreparationStep.components;
      WidgetsBinding.instance.addPostFrameCallback((_) => loadCatalog());
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => loadUnits());
    }
  }

  @override
  void dispose() {
    searchDebounce?.cancel();
    unitSearchController.dispose();
    catalogSearchController.dispose();
    panelSearchController.dispose();
    partSearchController.dispose();
    partScrollController.dispose();
    super.dispose();
  }

  String get currentUnitId => selectedUnit?.carId ?? '';

  String get unitTitle {
    final unit = selectedUnit;
    if (unit == null) return 'Persiapan Unit';
    return unit.unitName;
  }

  String get unitSubtitle {
    final unit = selectedUnit;
    if (unit == null) return sessionManager.roleLabel;
    return [
      unit.customerName,
      unit.plateNumber,
      unit.status,
      unit.deliveryDate == null ? null : 'Target ${unit.deliveryDate}',
    ].whereType<String>().where((text) => text.trim().isNotEmpty).join(' • ');
  }

  List<UnitPreparationUnit> get filteredUnits =>
      UnitPreparationCatalogHelper.searchUnits(units, unitQuery);

  List<CatalogComponentSummary> get componentSummaries =>
      UnitPreparationCatalogHelper.componentSummaries(references);

  List<CatalogPanelSummary> get panelSummaries =>
      UnitPreparationCatalogHelper.panelSummaries(
        references,
        selectedComponent,
        query: panelQuery,
      );

  CatalogReference? get currentReference {
    final reference = selectedReference;
    if (reference == null) return null;
    return references.firstWhere(
      (item) => item.id == reference.id,
      orElse: () => reference,
    );
  }

  List<CatalogSearchEntry> get panelEntries {
    final reference = currentReference;
    if (reference == null) return const [];
    return UnitPreparationCatalogHelper.panelPartEntries(
      UnitPreparationCatalogHelper.buildSearchEntries([reference]),
      referenceId: reference.id,
      query: partQuery,
    );
  }

  List<CatalogSearchEntry> get globalSearchResults =>
      UnitPreparationCatalogHelper.globalCatalogSearch(
        searchEntries,
        catalogQuery,
      );

  Future<void> loadUnits() async {
    setState(() {
      loading = true;
      message = null;
    });
    try {
      final rows = await datasource.getUnits();
      if (!mounted) return;
      setState(() {
        units = rows;
        unitsLoaded = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        unitsLoaded = true;
        message = _unitPreparationErrorMessage(
          error,
          fallback: 'Gagal memuat unit.',
        );
      });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> selectUnit(UnitPreparationUnit unit) async {
    setState(() {
      selectedUnit = unit;
      step = _PreparationStep.components;
      selectedComponent = '';
      selectedReference = null;
      catalogQuery = '';
      panelQuery = '';
      partQuery = '';
      catalogSearchController.clear();
      panelSearchController.clear();
      partSearchController.clear();
    });
    await loadCatalog();
  }

  Future<void> loadCatalog() async {
    final unitId = currentUnitId;
    if (unitId.isEmpty) {
      await loadUnits();
      return;
    }

    setState(() {
      loading = true;
      message = null;
    });

    try {
      final catalog = await datasource.getCatalog(unitId);
      if (!mounted) return;
      setState(() {
        catalogLoaded = true;
        references = catalog;
        searchEntries = UnitPreparationCatalogHelper.buildSearchEntries(
          catalog,
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

  Future<CatalogReference> hydrateReference(
    CatalogReference reference, {
    bool force = false,
  }) async {
    if (!force && reference.items.isNotEmpty) return reference;
    final detail = await datasource.getReference(currentUnitId, reference.id);
    if (!mounted) return detail;
    final nextReferences = [
      for (final entry in references) entry.id == detail.id ? detail : entry,
    ];
    setState(() {
      references = nextReferences;
      selectedReference = selectedReference?.id == detail.id
          ? detail
          : selectedReference;
      searchEntries = UnitPreparationCatalogHelper.buildSearchEntries(
        nextReferences,
      );
    });
    return detail;
  }

  Future<void> hydrateComponent(String component) async {
    final targets = references
        .where(
          (reference) =>
              reference.componentName.toUpperCase() == component.toUpperCase(),
        )
        .where((reference) => reference.items.isEmpty)
        .toList();
    if (targets.isEmpty) return;
    setState(() => loading = true);
    try {
      final hydrated = await Future.wait(targets.map(hydrateReference));
      if (!mounted || hydrated.isEmpty) return;
    } catch (error) {
      if (mounted) {
        setState(
          () => message = _unitPreparationErrorMessage(
            error,
            fallback: 'Gagal memuat panel.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> hydrateAllForSearch() async {
    if (searchHydrating ||
        catalogQuery.trim().isEmpty ||
        references.every((reference) => reference.items.isNotEmpty)) {
      return;
    }
    setState(() => searchHydrating = true);
    try {
      await Future.wait(
        references
            .where((reference) => reference.items.isEmpty)
            .map(hydrateReference),
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => message = _unitPreparationErrorMessage(
            error,
            fallback: 'Gagal memperbarui item.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => searchHydrating = false);
    }
  }

  Future<void> refreshReference(CatalogReference reference) async {
    try {
      await hydrateReference(reference, force: true);
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

  Future<void> selectComponent(String component) async {
    setState(() {
      selectedComponent = component;
      selectedReference = null;
      panelQuery = '';
      panelSearchController.clear();
      step = _PreparationStep.panels;
    });
    await hydrateComponent(component);
  }

  Future<void> selectPanel(CatalogReference reference) async {
    setState(() {
      selectedReference = reference;
      partQuery = '';
      partSearchController.clear();
      step = _PreparationStep.panel;
    });
    try {
      await hydrateReference(reference);
    } catch (error) {
      if (mounted) {
        setState(
          () => message = _unitPreparationErrorMessage(
            error,
            fallback: 'Gagal memuat part panel.',
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
        panelEntries,
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
    return Column(
      children: [
        if (message != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: _InlineError(message: message!),
          ),
        if (loading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: switch (step) {
            _PreparationStep.units => buildUnitList(),
            _PreparationStep.components => buildComponentList(),
            _PreparationStep.panels => buildPanelList(),
            _PreparationStep.panel => buildPanelWorkspace(),
          },
        ),
      ],
    );
  }

  Widget buildUnitList() {
    final results = filteredUnits;
    if (!unitsLoaded && loading) return const _CatalogSkeletonList();
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      itemCount: results.isEmpty ? 2 : results.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == 0) {
          return TextField(
            controller: unitSearchController,
            decoration: const InputDecoration(
              labelText: 'Cari unit, customer, atau plat',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: (value) => setState(() => unitQuery = value),
          );
        }
        if (results.isEmpty) {
          return const _EmptyCatalogState(message: 'Unit tidak ditemukan.');
        }
        final unit = results[index - 1];
        return _UnitCard(unit: unit, onTap: () => selectUnit(unit));
      },
    );
  }

  Widget buildComponentList() {
    if (!catalogLoaded && loading) return const _CatalogSkeletonList();
    if (catalogLoaded && references.isEmpty) {
      return const _EmptyCatalogState(
        message: 'Belum ada item Catalog untuk unit ini.',
      );
    }
    final searchResults = globalSearchResults;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      children: [
        _UnitSummaryHeader(
          title: unitTitle,
          subtitle: unitSubtitle,
          onBack: widget.initialUnitId?.trim().isNotEmpty == true
              ? null
              : () => setState(() => step = _PreparationStep.units),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: catalogSearchController,
          decoration: InputDecoration(
            labelText: 'Cari panel atau part',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: searchHydrating
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
          onChanged: scheduleCatalogSearch,
        ),
        const SizedBox(height: 12),
        if (catalogQuery.trim().isNotEmpty) ...[
          if (searchResults.isEmpty && searchHydrating)
            const _CatalogSkeletonList()
          else if (searchResults.isEmpty)
            const _EmptyCatalogState(
              message: 'Panel atau part tidak ditemukan.',
            )
          else
            ...searchResults.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _GlobalCatalogResultCard(
                  entry: entry,
                  onTap: () async {
                    await selectPanel(entry.reference);
                    if (!mounted) return;
                    await openSurvey(entry);
                  },
                ),
              ),
            ),
        ] else ...[
          for (final component in componentSummaries)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ComponentCard(
                summary: component,
                onTap: () => selectComponent(component.componentName),
              ),
            ),
        ],
      ],
    );
  }

  Widget buildPanelList() {
    final panels = panelSummaries;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      itemCount: panels.length + 2,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _UnitSummaryHeader(
            title: unitTitle,
            subtitle: selectedComponent,
            onBack: () => setState(() => step = _PreparationStep.components),
          );
        }
        if (index == 1) {
          return TextField(
            controller: panelSearchController,
            decoration: const InputDecoration(
              labelText: 'Cari panel',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: (value) => setState(() => panelQuery = value),
          );
        }
        final panel = panels[index - 2];
        return _PanelCard(
          summary: panel,
          onTap: () => selectPanel(panel.reference),
        );
      },
    );
  }

  Widget buildPanelWorkspace() {
    final reference = currentReference;
    if (reference == null) {
      return const _EmptyCatalogState(message: 'Panel tidak ditemukan.');
    }
    final entries = panelEntries;
    return ListView(
      controller: partScrollController,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      children: [
        _UnitSummaryHeader(
          title: '${reference.componentName} > ${reference.panelName}',
          subtitle: unitTitle,
          onBack: () => setState(() => step = _PreparationStep.panels),
        ),
        const SizedBox(height: 12),
        _SectionLabel('Gambar Referensi Panel'),
        const SizedBox(height: 8),
        _ReferenceImageStrip(media: reference.media),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                '${reference.itemCount} Part',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            OutlinedButton.icon(
              onPressed: showAdditionalItemGap,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Item Tambahan'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: partSearchController,
          decoration: const InputDecoration(
            labelText: 'Cari part',
            prefixIcon: Icon(Icons.search_rounded),
          ),
          onChanged: (value) => setState(() => partQuery = value),
        ),
        const SizedBox(height: 8),
        if (entries.isEmpty)
          const _EmptyCatalogState(message: 'Part tidak ditemukan.')
        else
          ...entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _PartRow(
                entry: entry,
                onTap: () => openSurvey(entry),
                onCountdown:
                    !entry.item.isConfirmed ||
                        entry.item.promotedPanelId == null
                    ? null
                    : () => openCountdown(entry.item),
              ),
            ),
          ),
      ],
    );
  }

  void scheduleCatalogSearch(String value) {
    searchDebounce?.cancel();
    searchDebounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      setState(() => catalogQuery = value);
      unawaited(hydrateAllForSearch());
    });
  }

  void showAdditionalItemGap() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Item tambahan butuh endpoint mobile unit_additional_items.',
        ),
      ),
    );
  }
}

class _UnitCard extends StatelessWidget {
  const _UnitCard({required this.unit, required this.onTap});

  final UnitPreparationUnit unit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      unit.unitName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      unit.customerName ?? '-',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        unit.plateNumber,
                        unit.status,
                        unit.deliveryDate == null
                            ? null
                            : 'Target ${unit.deliveryDate}',
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
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnitSummaryHeader extends StatelessWidget {
  const _UnitSummaryHeader({
    required this.title,
    required this.subtitle,
    this.onBack,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onBack != null) ...[
          IconButton(
            tooltip: 'Kembali',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (subtitle.trim().isNotEmpty)
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ComponentCard extends StatelessWidget {
  const _ComponentCard({required this.summary, required this.onTap});

  final CatalogComponentSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _NavRow(
      title: summary.componentName,
      subtitle: '${summary.panelCount} Panel',
      trailing: summary.partCount > 0
          ? '${summary.partCount} Part'
          : '${summary.doneCount} didata',
      onTap: onTap,
    );
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({required this.summary, required this.onTap});

  final CatalogPanelSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _NavRow(
      title: summary.panelName,
      subtitle: '${summary.partCount} Part',
      trailing: summary.doneCount > 0
          ? '${summary.doneCount} sudah didata'
          : '',
      onTap: onTap,
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    trailing,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlobalCatalogResultCard extends StatelessWidget {
  const _GlobalCatalogResultCard({required this.entry, required this.onTap});

  final CatalogSearchEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _NavRow(
      title: UnitPreparationCatalogHelper.resolveItemLabel(
        entry.item,
        entry.reference,
      ),
      subtitle: [
        UnitPreparationCatalogHelper.hierarchyLabel(entry),
        entry.item.partNumber,
      ].whereType<String>().join(' • '),
      trailing: UnitPreparationCatalogHelper.surveyStatusLabel(
        entry.item.surveyStatus,
      ),
      onTap: onTap,
    );
  }
}

class _ReferenceImageStrip extends StatelessWidget {
  const _ReferenceImageStrip({required this.media});

  final List<CatalogMedia> media;

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) {
      return Container(
        height: 160,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('Belum ada gambar referensi'),
      );
    }
    return SizedBox(
      height: 220,
      child: PageView(
        children: [
          for (final image in media)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 3,
                child: Image.network(
                  image.fileUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      const Center(child: Icon(Icons.broken_image_outlined)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PartRow extends StatelessWidget {
  const _PartRow({required this.entry, required this.onTap, this.onCountdown});

  final CatalogSearchEntry entry;
  final VoidCallback onTap;
  final VoidCallback? onCountdown;

  @override
  Widget build(BuildContext context) {
    final item = entry.item;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
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
                      item.partNumber ?? '-',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      UnitPreparationCatalogHelper.resolveItemLabel(
                        item,
                        entry.reference,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Qty Normal: ${item.qtyNormal?.toStringAsFixed(0) ?? '-'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusPill(item: item),
              if (onCountdown == null)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.chevron_right_rounded),
                )
              else
                IconButton(
                  tooltip: 'Buat pekerjaan',
                  onPressed: onCountdown,
                  icon: const Icon(Icons.playlist_add_check_rounded),
                ),
            ],
          ),
        ),
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
  const _EmptyCatalogState({required this.message});

  final String message;

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
                        'NOT_AVAILABLE': 'Tidak Ditemukan',
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
                        'GOOD': 'Layak',
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
                        'NO_ACTION': 'Tidak Ada',
                        'JOBDESC': 'Jobdesc',
                        'JOBDESC_ORDER': 'Jobdesc + Order',
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
