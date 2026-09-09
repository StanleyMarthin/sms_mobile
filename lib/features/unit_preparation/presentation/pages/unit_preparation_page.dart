/*
Tujuan: Halaman mobile Unit Preparation untuk navigasi unit -> component -> panel -> survey catalog.
Caller: GoRouter route /unit-preparation.
Dependensi: ApiClient, SessionManager, UploadService, InAppCameraPage, RemoteUnitPreparationDatasource, UnitPreparationCatalogHelper.
Main Functions: load units, load catalog hierarchy, add panel/items, survey, confirm, annotate foto.
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
  List<CatalogComponent> components = const [];
  List<CatalogReference> references = const [];
  List<CatalogSearchEntry> searchEntries = const [];
  UnitPreparationUnit? selectedUnit;
  String selectedComponent = '';
  CatalogReference? selectedReference;
  int? highlightedItemId;
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

  List<CatalogComponentSummary> get componentSummaries {
    final summaries = UnitPreparationCatalogHelper.componentSummaries(
      references,
    );
    if (components.isEmpty) return summaries;
    return components.map((component) {
      final summary = summaries.where((item) {
        final name = item.componentName.toLowerCase();
        return name == component.code.toLowerCase() ||
            name == component.componentName.toLowerCase();
      }).firstOrNull;
      return summary ??
          CatalogComponentSummary(
            componentName: component.code,
            panelCount: 0,
            partCount: 0,
            doneCount: 0,
          );
    }).toList();
  }

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

  CatalogComponent? componentByCode(String code) {
    final normalized = code.toLowerCase();
    return components.where((component) {
      return component.code.toLowerCase() == normalized ||
          component.componentName.toLowerCase() == normalized;
    }).firstOrNull;
  }

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
      highlightedItemId = null;
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
      final componentRows = components.isEmpty
          ? await _loadComponentsOrDerive(catalog)
          : components;
      if (!mounted) return;
      setState(() {
        components = componentRows;
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

  Future<List<CatalogComponent>> _loadComponentsOrDerive(
    List<CatalogReference> catalog,
  ) async {
    try {
      final rows = await datasource.getComponents();
      if (rows.isNotEmpty) return rows;
    } catch (_) {
      // Catalog runtime lives in sm_countdown; component master is optional.
    }
    return UnitPreparationCatalogHelper.componentsFromReferences(catalog);
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

  void upsertReference(CatalogReference reference) {
    final exists = references.any((item) => item.id == reference.id);
    final nextReferences = exists
        ? [
            for (final item in references)
              item.id == reference.id ? reference : item,
          ]
        : [...references, reference];
    setState(() {
      references = nextReferences;
      selectedReference = reference;
      searchEntries = UnitPreparationCatalogHelper.buildSearchEntries(
        nextReferences,
      );
    });
  }

  Future<void> openAddPanel() async {
    final component = componentByCode(selectedComponent);
    final result = await showModalBottomSheet<_PanelCreateResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PanelCreateSheet(componentName: selectedComponent),
    );
    if (result == null || result.panelName.trim().isEmpty) return;

    setState(() {
      loading = true;
      message = null;
    });
    try {
      var reference = await datasource.openPanel(
        unitId: currentUnitId,
        componentCode: component?.code ?? selectedComponent,
        panelName: result.panelName.trim(),
      );
      if (result.imagePath != null) {
        final imageUrl = await uploadService.uploadPhoto(
          localPath: result.imagePath!,
          unit: currentUnitId,
          division: 'Unit Preparation',
          job: 'Catalog Panel',
          panel: reference.panelName,
          type: 'referensi',
        );
        if (imageUrl != null && imageUrl.isNotEmpty) {
          await datasource.addPanelReferenceImage(
            unitId: currentUnitId,
            panelId: reference.id,
            fileUrl: imageUrl,
          );
          reference = CatalogReference(
            id: reference.id,
            componentName: reference.componentName,
            panelName: reference.panelName,
            itemCount: reference.itemCount,
            surveyedCount: reference.surveyedCount,
            media: [
              ...reference.media,
              CatalogMedia(id: 0, fileUrl: imageUrl),
            ],
            items: reference.items,
          );
        }
      }
      if (!mounted) return;
      upsertReference(reference);
      setState(() => step = _PreparationStep.panel);
    } catch (error) {
      if (mounted) {
        setState(
          () => message = _unitPreparationErrorMessage(
            error,
            fallback: 'Gagal menambah panel.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void showAdditionalEndpointGap() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Item tambahan final membutuhkan endpoint unit_additional_items.',
        ),
      ),
    );
  }

  Future<void> savePositionMarker(
    CatalogSearchEntry entry,
    CatalogMapping? mapping,
  ) async {
    try {
      final updated = await datasource.savePanelItemsBatch(
        unitId: currentUnitId,
        panelId: entry.reference.id,
        items: [
          {
            'id': entry.item.id,
            'code': entry.item.code,
            'partNumber': entry.item.partNumber,
            'itemName': entry.item.partName ?? entry.item.namePart,
            'position': mapping == null
                ? null
                : UnitPreparationCatalogHelper.encodePositionMarker(mapping),
            'qtyNormal': entry.item.qtyNormal,
          },
        ],
      );
      if (!mounted) return;
      upsertReference(updated);
    } catch (error) {
      if (mounted) {
        setState(
          () => message = _unitPreparationErrorMessage(
            error,
            fallback: 'Gagal menyimpan posisi.',
          ),
        );
      }
    }
  }

  Future<void> selectComponent(String component) async {
    setState(() {
      selectedComponent = component;
      selectedReference = null;
      highlightedItemId = null;
      panelQuery = '';
      panelSearchController.clear();
      step = _PreparationStep.panels;
    });
    await hydrateComponent(component);
  }

  Future<void> selectPanel(CatalogReference reference) async {
    setState(() {
      selectedReference = reference;
      highlightedItemId = null;
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

  Future<void> openPartDetail(CatalogSearchEntry entry) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PartDetailSheet(entry: entry),
    );
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
        onSave: (survey) => datasource.saveSurvey(
          unitId: currentUnitId,
          itemId: entry.item.id,
          survey: survey,
        ),
        onSavePosition: (mapping) => savePositionMarker(entry, mapping),
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
            result == 'backend-gap'
                ? 'Data dikirim, server belum menyimpan survey lengkap.'
                : 'Data tersimpan.',
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
                    setState(() => highlightedItemId = entry.item.id);
                  },
                ),
              ),
            ),
        ] else ...[
          if (componentSummaries.isEmpty)
            const _EmptyCatalogState(message: 'Belum ada component Catalog.')
          else
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      children: [
        _UnitSummaryHeader(
          title: unitTitle,
          subtitle: selectedComponent,
          onBack: () => setState(() => step = _PreparationStep.components),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: panelSearchController,
          decoration: const InputDecoration(
            labelText: 'Cari panel',
            prefixIcon: Icon(Icons.search_rounded),
          ),
          onChanged: (value) => setState(() => panelQuery = value),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: openAddPanel,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Tambah Panel'),
        ),
        const SizedBox(height: 8),
        if (panels.isEmpty)
          const _EmptyCatalogState(message: 'Panel tidak ditemukan.')
        else
          for (final panel in panels)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _PanelCard(
                summary: panel,
                onTap: () => selectPanel(panel.reference),
              ),
            ),
      ],
    );
  }

  Widget buildPanelWorkspace() {
    final reference = currentReference;
    if (reference == null) {
      return const _EmptyCatalogState(message: 'Panel tidak ditemukan.');
    }
    final mediaQuery = MediaQuery.of(context);
    final keyboardVisible = mediaQuery.viewInsets.bottom > 0;
    final panelImageHeight = UnitPreparationCatalogHelper.panelImageHeight(
      availableHeight:
          mediaQuery.size.height -
          mediaQuery.padding.vertical -
          mediaQuery.viewInsets.bottom,
      keyboardVisible: keyboardVisible,
    );
    final entries = panelEntries;
    final highlightedEntry = highlightedItemId == null
        ? null
        : entries
              .where((entry) => entry.item.id == highlightedItemId)
              .firstOrNull;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _UnitSummaryHeader(
                title: '${reference.componentName} > ${reference.panelName}',
                subtitle: unitTitle,
                onBack: () => setState(() => step = _PreparationStep.panels),
              ),
              const SizedBox(height: 12),
              _SectionLabel('Gambar Referensi Panel'),
              const SizedBox(height: 8),
              _ReferenceImageStrip(
                media: reference.media,
                selectedEntry: highlightedEntry,
                height: panelImageHeight,
              ),
              if (highlightedEntry != null) ...[
                const SizedBox(height: 6),
                _SelectedPartInfo(entry: highlightedEntry),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${reference.itemCount} Part',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: showAdditionalEndpointGap,
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
            ],
          ),
        ),
        Expanded(
          child: entries.isEmpty
              ? const _EmptyCatalogState(message: 'Part tidak ditemukan.')
              : ListView.separated(
                  controller: partScrollController,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return _PartRow(
                      entry: entry,
                      selected: entry.item.id == highlightedItemId,
                      onTap: () =>
                          setState(() => highlightedItemId = entry.item.id),
                      onDetail: () => openPartDetail(entry),
                      onSurvey: entry.item.isPromoted
                          ? null
                          : () => openSurvey(entry),
                    );
                  },
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
}

class _PanelCreateResult {
  const _PanelCreateResult({required this.panelName, this.imagePath});

  final String panelName;
  final String? imagePath;
}

class _PanelCreateSheet extends StatefulWidget {
  const _PanelCreateSheet({required this.componentName});

  final String componentName;

  @override
  State<_PanelCreateSheet> createState() => _PanelCreateSheetState();
}

class _PanelCreateSheetState extends State<_PanelCreateSheet> {
  final panelController = TextEditingController();
  String? imagePath;

  @override
  void dispose() {
    panelController.dispose();
    super.dispose();
  }

  Future<void> pickImage() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );
    if (!mounted || file == null) return;
    setState(() => imagePath = file.path);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tambah Panel ${widget.componentName}',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: panelController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nama Panel'),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: pickImage,
              icon: const Icon(Icons.image_outlined),
              label: Text(imagePath == null ? 'Tambah Gambar' : 'Ganti Gambar'),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Kembali'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(
                      context,
                      _PanelCreateResult(
                        panelName: panelController.text,
                        imagePath: imagePath,
                      ),
                    ),
                    child: const Text('Simpan'),
                  ),
                ),
              ],
            ),
          ],
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
      trailing: UnitPreparationCatalogHelper.hasCommittedSurvey(entry.item)
          ? 'Sudah didata'
          : 'Belum didata',
      onTap: onTap,
    );
  }
}

class _ReferenceImageStrip extends StatelessWidget {
  const _ReferenceImageStrip({
    required this.media,
    this.selectedEntry,
    this.marker,
    this.height = 220,
    this.zoomEnabled = true,
    this.onTapUp,
    this.onPageChanged,
  });

  final List<CatalogMedia> media;
  final CatalogSearchEntry? selectedEntry;
  final CatalogMapping? marker;
  final double height;
  final bool zoomEnabled;
  final void Function(TapUpDetails details, BoxConstraints constraints)?
  onTapUp;
  final ValueChanged<int>? onPageChanged;

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) {
      return Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('Belum ada gambar referensi'),
      );
    }
    return SizedBox(
      height: height,
      child: PageView(
        onPageChanged: (index) => onPageChanged?.call(index + 1),
        children: [
          for (var index = 0; index < media.length; index++)
            LayoutBuilder(
              builder: (context, constraints) {
                final image = media[index];
                final visibleMarker = marker ?? _markerFor(selectedEntry);
                final showMarker =
                    visibleMarker != null && visibleMarker.page == index + 1;
                final imageWidget = Image.network(
                  UnitPreparationCatalogHelper.imageUrl(image.fileUrl),
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      const Center(child: Icon(Icons.broken_image_outlined)),
                );
                final markerOffset = showMarker
                    ? UnitPreparationCatalogHelper.panelMarkerOffset(
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        xPercent: visibleMarker.xPercent,
                        yPercent: visibleMarker.yPercent,
                      )
                    : null;
                final imageWithMarker = Stack(
                  fit: StackFit.expand,
                  children: [
                    imageWidget,
                    if (markerOffset != null)
                      Positioned(
                        left: markerOffset.left,
                        top: markerOffset.top,
                        child: const Icon(
                          Icons.push_pin,
                          color: Colors.redAccent,
                          size: 30,
                        ),
                      ),
                  ],
                );
                final content = ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: zoomEnabled
                      ? InteractiveViewer(
                          minScale: 1,
                          maxScale: 3,
                          child: SizedBox(
                            width: constraints.maxWidth,
                            height: constraints.maxHeight,
                            child: imageWithMarker,
                          ),
                        )
                      : imageWithMarker,
                );
                if (onTapUp == null) return content;
                return GestureDetector(
                  onTapUp: (details) => onTapUp!(details, constraints),
                  child: content,
                );
              },
            ),
        ],
      ),
    );
  }

  CatalogMapping? _markerFor(CatalogSearchEntry? entry) {
    if (entry == null) return null;
    return UnitPreparationCatalogHelper.decodePositionMarker(
          entry.item.positionCode,
        ) ??
        entry.item.mappings.firstOrNull;
  }
}

class _PartRow extends StatelessWidget {
  const _PartRow({
    required this.entry,
    required this.selected,
    required this.onTap,
    required this.onDetail,
    required this.onSurvey,
  });

  final CatalogSearchEntry entry;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDetail;
  final VoidCallback? onSurvey;

  @override
  Widget build(BuildContext context) {
    final item = entry.item;
    final alias = UnitPreparationCatalogHelper.itemPrimaryLabel(
      item,
      entry.reference,
    );
    final originalName = UnitPreparationCatalogHelper.itemOriginalLabel(item);
    return Material(
      color: selected
          ? AppColors.gold.withValues(alpha: 0.06)
          : Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: selected ? AppColors.gold : Theme.of(context).dividerColor,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (alias.isNotEmpty) ...[
                      Text(
                        alias,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      originalName,
                      style: TextStyle(
                        fontWeight: alias.isEmpty
                            ? FontWeight.w800
                            : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.code ?? 'Code belum diisi',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    if (item.partNumber?.trim().isNotEmpty == true)
                      Text(
                        item.partNumber!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              _StatusPill(item: item),
              IconButton(
                tooltip: 'Detail',
                onPressed: onDetail,
                icon: const Icon(Icons.description_outlined),
              ),
              if (onSurvey != null)
                IconButton(
                  tooltip: 'Data',
                  onPressed: onSurvey,
                  icon: const Icon(Icons.fact_check_outlined),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedPartInfo extends StatelessWidget {
  const _SelectedPartInfo({required this.entry});

  final CatalogSearchEntry entry;

  @override
  Widget build(BuildContext context) {
    final item = entry.item;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: DefaultTextStyle(
        style: Theme.of(context).textTheme.bodySmall!.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.code?.trim().isNotEmpty == true) Text(item.code!),
            Text(
              UnitPreparationCatalogHelper.itemOriginalLabel(item),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
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
    final surveyed = UnitPreparationCatalogHelper.hasCommittedSurvey(item);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: surveyed
            ? AppColors.statusDone.withValues(alpha: 0.15)
            : AppColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        surveyed ? '✓ Sudah didata' : 'Belum didata',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: surveyed ? AppColors.statusDone : AppColors.gold,
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

class _PartDetailSheet extends StatelessWidget {
  const _PartDetailSheet({required this.entry});

  final CatalogSearchEntry entry;

  @override
  Widget build(BuildContext context) {
    final item = entry.item;
    final alias = UnitPreparationCatalogHelper.hasCommittedSurvey(item)
        ? item.aliasName
        : null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Detail Part',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            _DetailLine(label: 'Code', value: item.code ?? '-'),
            _DetailLine(
              label: 'Original Name',
              value: UnitPreparationCatalogHelper.itemOriginalLabel(item),
            ),
            if (alias != null && alias.trim().isNotEmpty)
              _DetailLine(label: 'Alias Name', value: alias),
            _DetailLine(
              label: 'Part Number',
              value: UnitPreparationCatalogHelper.itemSecondaryLabel(item),
            ),
            _DetailLine(
              label: 'Qty Normal',
              value: item.qtyNormal?.toString() ?? '-',
            ),
            _DetailLine(
              label: 'Reference Panel',
              value:
                  '${entry.reference.componentName} > ${entry.reference.panelName}',
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
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
    required this.onSave,
    required this.onSavePosition,
  });

  final CatalogItem item;
  final CatalogReference reference;
  final String unitId;
  final UploadService uploadService;
  final Future<void> Function(String fileUrl, String? caption) onAddPhoto;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> survey)
  onSave;
  final Future<void> Function(CatalogMapping? mapping) onSavePosition;

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
  bool masukProgress = false;
  bool needsOrder = false;
  String? photoPath;
  String? existingPhotoUrl;
  CatalogAnnotationMarker? actualMarker;
  CatalogMapping? referenceMarker;
  int referencePage = 1;
  bool referenceMarkerChanged = false;
  bool pickingReferenceMarker = false;
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
    needsOrder = widget.item.surveyData?['needsOrder'] == true;
    masukProgress =
        widget.item.isRestoration || widget.item.conditionStatus == 'RESTORE';
    existingPhotoUrl = UnitPreparationCatalogHelper.pickActualPhoto(
      widget.item.media,
    )?.fileUrl;
    final markers = UnitPreparationCatalogHelper.decodeActualPhotoMarkers(
      widget.item.media,
    );
    actualMarker = markers.isEmpty ? null : markers.last;
    referenceMarker =
        UnitPreparationCatalogHelper.decodePositionMarker(
          widget.item.positionCode,
        ) ??
        widget.item.mappings.firstOrNull;
    referencePage = referenceMarker?.page ?? 1;
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
    return UnitPreparationCatalogHelper.finalSurveyPayload(
      qtyOpname: double.tryParse(qtyController.text.trim()),
      actualName: actualNameController.text,
      availabilityStatus: availability,
      conditionStatus: condition,
      isRestoration: masukProgress,
      needsOrder: needsOrder,
      location: locationController.text,
      notes: notesController.text,
    );
  }

  Future<void> save() async {
    setState(() => submitting = true);

    try {
      if (photoPath != null || (markerChanged && existingPhotoUrl != null)) {
        throw StateError(
          'Foto survey normal belum didukung server aktif. Simpan tanpa foto dulu.',
        );
      }
      final survey = buildSurvey();
      if (referenceMarkerChanged) {
        await widget.onSavePosition(referenceMarker);
      }
      final response = await widget.onSave(survey);
      final hasSurveyData =
          response['survey_data'] != null ||
          response['surveyData'] != null ||
          response['item'] is Map && (response['item']['survey_data'] != null);

      if (mounted) {
        Navigator.pop(context, hasSurveyData ? 'save' : 'backend-gap');
      }
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
          slot: 'unit_preparation_part',
          label: 'Foto Part',
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

  void placeReferenceMarker(TapUpDetails details, BoxConstraints constraints) {
    if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0) return;
    setState(() {
      referenceMarker = CatalogMapping(
        id: referenceMarker?.id ?? 0,
        catalogReferenceMediaId:
            referencePage > 0 && referencePage <= widget.reference.media.length
            ? widget.reference.media[referencePage - 1].id
            : 0,
        xPercent: (details.localPosition.dx / constraints.maxWidth * 100)
            .clamp(0.0, 100.0)
            .toDouble(),
        yPercent: (details.localPosition.dy / constraints.maxHeight * 100)
            .clamp(0.0, 100.0)
            .toDouble(),
        page: referencePage,
      );
      referenceMarkerChanged = true;
      pickingReferenceMarker = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final title = widget.item.code?.trim().isNotEmpty == true
        ? widget.item.code!
        : UnitPreparationCatalogHelper.itemOriginalLabel(widget.item);
    final canEdit = !widget.item.isPromoted;
    final referenceImageHeight = UnitPreparationCatalogHelper.panelImageHeight(
      availableHeight:
          mediaQuery.size.height -
          mediaQuery.padding.vertical -
          mediaQuery.viewInsets.bottom,
      keyboardVisible: mediaQuery.viewInsets.bottom > 0,
    );
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
        child: SizedBox(
          height: mediaQuery.size.height * 0.92,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _ReferenceImageStrip(
                  media: widget.reference.media,
                  height: referenceImageHeight,
                  selectedEntry: CatalogSearchEntry(
                    reference: widget.reference,
                    item: widget.item,
                  ),
                  marker: referenceMarker,
                  zoomEnabled: !pickingReferenceMarker,
                  onPageChanged: (page) => referencePage = page,
                  onTapUp: canEdit && pickingReferenceMarker
                      ? placeReferenceMarker
                      : null,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SelectedPartInfo(
                      entry: CatalogSearchEntry(
                        reference: widget.reference,
                        item: widget.item,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: submitting || !canEdit
                          ? null
                          : () => setState(
                              () => pickingReferenceMarker =
                                  !pickingReferenceMarker,
                            ),
                      icon: const Icon(Icons.push_pin_outlined),
                      label: Text(
                        pickingReferenceMarker
                            ? 'Ketuk Gambar'
                            : 'Tandai Letak pada Gambar',
                      ),
                    ),
                  ],
                ),
              ),
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
                                title,
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
                                'Original: ${UnitPreparationCatalogHelper.itemOriginalLabel(widget.item)}',
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
                        'UNKNOWN': 'Tidak Ditemukan',
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
                      },
                      onChanged: (value) => setState(() => condition = value),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      value: masukProgress,
                      onChanged: canEdit
                          ? (value) =>
                                setState(() => masukProgress = value ?? false)
                          : null,
                      title: const Text('Masuk Progress Restorasi'),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    CheckboxListTile(
                      value: needsOrder,
                      onChanged: canEdit
                          ? (value) =>
                                setState(() => needsOrder = value ?? false)
                          : null,
                      title: const Text('Perlu Order / Penggantian'),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 12),
                    _SectionLabel('Foto Part'),
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
                    TextField(
                      controller: locationController,
                      enabled: canEdit,
                      decoration: const InputDecoration(labelText: 'Lokasi'),
                    ),
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
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: submitting
                                      ? null
                                      : () => Navigator.pop(context),
                                  child: const Text('Kembali'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton(
                                  onPressed: submitting ? null : save,
                                  child: Text(
                                    submitting ? 'Menyimpan...' : 'Simpan Data',
                                  ),
                                ),
                              ),
                            ],
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
          InkWell(
            onTap: enabled ? () => onChanged(entry.key) : null,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: value == entry.key
                      ? AppColors.gold
                      : Theme.of(context).dividerColor,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    value == entry.key
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    size: 20,
                    color: value == entry.key ? AppColors.gold : null,
                  ),
                  const SizedBox(width: 8),
                  Text(entry.value),
                ],
              ),
            ),
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
                ? const Center(child: Text('Belum ada foto part'))
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      if (hasLocal)
                        Image.file(File(localPath!), fit: BoxFit.contain)
                      else
                        Image.network(
                          UnitPreparationCatalogHelper.imageUrl(remoteUrl!),
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
                            Icons.push_pin,
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
