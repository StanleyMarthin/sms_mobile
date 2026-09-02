/*
Tujuan: Halaman mobile Unit Preparation untuk catalog dan pendataan item.
Caller: GoRouter route /unit-preparation.
Dependensi: ApiClient, SessionManager, UploadService, InAppCameraPage, RemoteUnitPreparationDatasource.
Main Functions: load catalog/reference, draft survey, confirm survey otomatis materialize.
Side Effects: HTTP request pendataan dan materialization ke be_sms.
*/

import 'package:flutter/material.dart';
import 'dart:io';

import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/upload_service.dart';
import '../../../../core/session/session_manager.dart';
import '../../../../core/widgets/in_app_camera_page.dart';
import '../../data/datasources/remote_unit_preparation_datasource.dart';
import '../../domain/entities/unit_preparation_models.dart';

class UnitPreparationPage extends StatefulWidget {
  const UnitPreparationPage({super.key, this.initialUnitId});

  final String? initialUnitId;

  @override
  State<UnitPreparationPage> createState() => _UnitPreparationPageState();
}

class _UnitPreparationPageState extends State<UnitPreparationPage> {
  late final RemoteUnitPreparationDatasource datasource;
  late final UploadService uploadService;
  late final TextEditingController unitController;
  List<CatalogReference> references = const [];
  CatalogReference? selectedReference;
  bool loading = false;
  String? message;

  @override
  void initState() {
    super.initState();
    datasource = RemoteUnitPreparationDatasource(
      apiClient: sl<ApiClient>(),
      sessionManager: sl<SessionManager>(),
    );
    uploadService = sl<UploadService>();
    unitController = TextEditingController(text: widget.initialUnitId ?? '');
    if (unitController.text.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => loadCatalog());
    }
  }

  @override
  void dispose() {
    unitController.dispose();
    super.dispose();
  }

  Future<void> loadCatalog() async {
    setState(() {
      loading = true;
      message = null;
      selectedReference = null;
    });
    try {
      references = await datasource.getCatalog(unitController.text.trim());
    } catch (error) {
      message = '$error';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> loadReference(CatalogReference reference) async {
    setState(() {
      loading = true;
      message = null;
    });
    try {
      final detail = await datasource.getReference(
        unitController.text.trim(),
        reference.id,
      );
      setState(() => selectedReference = detail);
    } catch (error) {
      setState(() => message = '$error');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> openSurvey(CatalogItem item, {CatalogMapping? marker}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SurveySheet(
        item: item,
        marker: marker,
        unitId: unitController.text.trim(),
        reference: selectedReference,
        uploadService: uploadService,
        onAddPhoto: (fileUrl) => datasource.addActualPhoto(
          unitId: unitController.text.trim(),
          itemId: item.id,
          fileUrl: fileUrl,
          caption: 'Foto aktual pendataan',
        ),
        onSubmit: (survey) => datasource.confirmSurvey(
          unitId: unitController.text.trim(),
          itemId: item.id,
          survey: survey,
        ),
      ),
    );
    if (result == true && selectedReference != null) {
      await loadReference(selectedReference!);
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
      final panel = await datasource.getMasterPanel(
        unitController.text.trim(),
        panelId,
      );
      if (!mounted) return;
      final result = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (context) => _CountdownSheet(
          panel: panel,
          onSubmit: (job) => datasource.createJobdescs(
            unitId: unitController.text.trim(),
            panelId: panelId,
            jobs: [job],
          ),
        ),
      );
      if (result == true && selectedReference != null) {
        await loadReference(selectedReference!);
      }
    } catch (error) {
      if (mounted) setState(() => message = '$error');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> handleImageTap(
    TapUpDetails details,
    BoxConstraints constraints,
    CatalogMedia media,
  ) async {
    final item = selectedReference?.items.firstWhere(
      (entry) => !entry.isConfirmed,
      orElse: () => const CatalogItem(id: 0),
    );
    if (item == null || item.id == 0) return;
    final marker = CatalogMapping(
      id: 0,
      catalogReferenceMediaId: media.id,
      xPercent: details.localPosition.dx / constraints.maxWidth * 100,
      yPercent: details.localPosition.dy / constraints.maxHeight * 100,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Tandai posisi ini untuk item ${item.partName ?? item.positionCode ?? item.id}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (confirmed == true) await openSurvey(item, marker: marker);
  }

  @override
  Widget build(BuildContext context) {
    final reference = selectedReference;
    return Scaffold(
      appBar: AppBar(title: const Text('Persiapan Unit')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: unitController,
                    decoration: const InputDecoration(labelText: 'Unit ID'),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: loading ? null : loadCatalog,
                  child: const Text('Load'),
                ),
              ],
            ),
          ),
          if (message != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(message!, style: const TextStyle(color: Colors.red)),
            ),
          if (loading) const LinearProgressIndicator(),
          Expanded(
            child: Row(
              children: [
                SizedBox(
                  width: 220,
                  child: ListView(
                    children: references
                        .map(
                          (reference) => ListTile(
                            title: Text(reference.componentName),
                            subtitle: Text(reference.panelName),
                            onTap: () => loadReference(reference),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: reference == null
                      ? const Center(child: Text('Pilih catalog'))
                      : _ReferenceWorkspace(
                          reference: reference,
                          onDataItem: openSurvey,
                          onCreateCountdown: openCountdown,
                          onImageTap: handleImageTap,
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

class _ReferenceWorkspace extends StatelessWidget {
  const _ReferenceWorkspace({
    required this.reference,
    required this.onDataItem,
    required this.onCreateCountdown,
    required this.onImageTap,
  });

  final CatalogReference reference;
  final Future<void> Function(CatalogItem item, {CatalogMapping? marker})
  onDataItem;
  final Future<void> Function(CatalogItem item) onCreateCountdown;
  final Future<void> Function(
    TapUpDetails details,
    BoxConstraints constraints,
    CatalogMedia media,
  )
  onImageTap;

  @override
  Widget build(BuildContext context) {
    final image = reference.media.isEmpty ? null : reference.media.first;
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: ListView(
                  children: reference.items
                      .map(
                        (item) => ListTile(
                          title: Text(
                            item.partName ??
                                item.positionCode ??
                                'Item ${item.id}',
                          ),
                          subtitle: Text(
                            '${item.surveyStatus} - ${item.actionType}',
                          ),
                          trailing: item.isConfirmed
                              ? Wrap(
                                  spacing: 4,
                                  children: [
                                    const Icon(Icons.check_circle),
                                    TextButton(
                                      onPressed: item.promotedPanelId == null
                                          ? null
                                          : () => onCreateCountdown(item),
                                      child: const Text('Countdown'),
                                    ),
                                  ],
                                )
                              : TextButton(
                                  onPressed: () => onDataItem(item),
                                  child: const Text('Data Item'),
                                ),
                          onTap: item.isConfirmed
                              ? () => onDataItem(item)
                              : null,
                        ),
                      )
                      .toList(),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: image == null
                    ? const Center(child: Text('Tidak ada gambar catalog'))
                    : LayoutBuilder(
                        builder: (context, constraints) => GestureDetector(
                          onTapUp: (details) =>
                              onImageTap(details, constraints, image),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(image.fileUrl, fit: BoxFit.contain),
                              for (final item in reference.items)
                                for (final marker in item.mappings.where(
                                  (entry) =>
                                      entry.catalogReferenceMediaId == image.id,
                                ))
                                  Positioned(
                                    left:
                                        marker.xPercent /
                                            100 *
                                            constraints.maxWidth -
                                        6,
                                    top:
                                        marker.yPercent /
                                            100 *
                                            constraints.maxHeight -
                                        6,
                                    child: const Icon(
                                      Icons.location_on,
                                      color: Colors.red,
                                    ),
                                  ),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
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
    required this.onSubmit,
    required this.unitId,
    required this.uploadService,
    required this.onAddPhoto,
    this.reference,
    this.marker,
  });

  final CatalogItem item;
  final CatalogReference? reference;
  final CatalogMapping? marker;
  final String unitId;
  final UploadService uploadService;
  final Future<void> Function(String fileUrl) onAddPhoto;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> survey)
  onSubmit;

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
  }

  @override
  void dispose() {
    qtyController.dispose();
    actualNameController.dispose();
    locationController.dispose();
    notesController.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() => submitting = true);
    final marker = widget.marker;
    final survey = {
      'qtyOpname': double.tryParse(qtyController.text),
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
      if (marker != null)
        'mapping': {
          'catalogReferenceMediaId': marker.catalogReferenceMediaId,
          'xPercent': marker.xPercent,
          'yPercent': marker.yPercent,
        },
    };
    try {
      if (photoPath != null) {
        final photoUrl = await widget.uploadService.uploadPhoto(
          localPath: photoPath!,
          unit: widget.unitId,
          division: 'Unit Preparation',
          job: widget.item.partName ?? widget.item.actualName ?? 'Pendataan',
          panel: widget.reference?.panelName,
          type: 'actual',
        );
        if (photoUrl == null || photoUrl.isEmpty) {
          throw Exception('Upload foto aktual gagal.');
        }
        await widget.onAddPhoto(photoUrl);
      }
      await widget.onSubmit(survey);
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  Future<void> pickPhoto() async {
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
    setState(() => photoPath = path);
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
          Text(
            widget.item.partName ?? 'Pendataan Item',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          TextField(
            controller: qtyController,
            decoration: const InputDecoration(labelText: 'Qty Opname'),
            keyboardType: TextInputType.number,
          ),
          TextField(
            controller: actualNameController,
            decoration: const InputDecoration(labelText: 'Nama Aktual'),
          ),
          DropdownButtonFormField<String>(
            initialValue: availability,
            decoration: const InputDecoration(labelText: 'Availability'),
            items: const ['UNKNOWN', 'AVAILABLE', 'NOT_AVAILABLE']
                .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)),
                )
                .toList(),
            onChanged: (value) =>
                setState(() => availability = value ?? availability),
          ),
          DropdownButtonFormField<String>(
            initialValue: condition,
            decoration: const InputDecoration(labelText: 'Condition'),
            items: const ['UNKNOWN', 'GOOD', 'RESTORE', 'NOT_USABLE']
                .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)),
                )
                .toList(),
            onChanged: (value) =>
                setState(() => condition = value ?? condition),
          ),
          DropdownButtonFormField<String>(
            initialValue: action,
            decoration: const InputDecoration(labelText: 'Action'),
            items: const ['UNDECIDED', 'NO_ACTION', 'JOBDESC', 'JOBDESC_ORDER']
                .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)),
                )
                .toList(),
            onChanged: (value) => setState(() => action = value ?? action),
          ),
          TextField(
            controller: locationController,
            decoration: const InputDecoration(labelText: 'Lokasi'),
          ),
          TextField(
            controller: notesController,
            decoration: const InputDecoration(labelText: 'Notes'),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: submitting ? null : pickPhoto,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: photoPath == null
                  ? const Center(child: Text('Tap untuk ambil foto aktual'))
                  : Image.file(File(photoPath!), fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: submitting ? null : submit,
            child: const Text('Simpan Pendataan'),
          ),
        ],
      ),
    );
  }
}
