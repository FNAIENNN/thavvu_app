import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../models/hod_workflow_models.dart';
import '../../../services/device_file_picker.dart';
import '../../../services/hod_site_workspace_service.dart';
import '../../../services/hod_workflow_store.dart';
import '../../../services/supabase_maps_repository.dart';
import '../../../services/thavvu_workflow_seed_service.dart';

class HodMapsScreen extends StatefulWidget {
  const HodMapsScreen({super.key});

  @override
  State<HodMapsScreen> createState() => _HodMapsScreenState();
}

class _HodMapsScreenState extends State<HodMapsScreen> {
  static const String _hodId = 'HOD-001';
  final HodWorkflowStore _store = HodWorkflowStore();
  final HodSiteWorkspaceService _siteWorkspaceService =
      HodSiteWorkspaceService();
  final SupabaseMapsRepository _mapsRepo = SupabaseMapsRepository();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  late final ThavvuWorkflowSeedService _seedService;
  late Future<_HodMapsData> _future;
  String _selectedSiteId = 'SITE-VJA-001';
  String? _pickedFileName;
  String? _pickedFileType;
  String? _pickedFileSizeLabel;
  Uint8List? _pickedFileBytes;
  bool _isPublishing = false;

  @override
  void initState() {
    super.initState();
    _seedService = ThavvuWorkflowSeedService(store: _store);
    _future = _loadData();
  }

  Future<_HodMapsData> _loadData() async {
    await _seedService.ensureSeeded();
    var sites = await _store.sites();
    if (sites.isEmpty) {
      final adminSites = await _siteWorkspaceService.adminCreatedSites();
      sites = adminSites
          .map((site) => ThavvuSite(
                id: site.id,
                name: site.name,
                place: site.place,
              ))
          .toList(growable: false);
    }
    if (sites.isNotEmpty && !sites.any((site) => site.id == _selectedSiteId)) {
      _selectedSiteId = sites.first.id;
    }
    // Fetch from Supabase
    final uploads = await _mapsRepo.fetchMapUploads();
    final requests = (await _store.requestsForHod(_hodId))
        .where((request) => request.module == 'Maps')
        .toList();
    return _HodMapsData(sites: sites, uploads: uploads, requests: requests);
  }

  Future<void> _pickDeviceFile() async {
    final file = await pickHodMapDeviceFile();
    if (file == null) return;

    if (!isAllowedHodMapExtension(file.extension)) {
      _showMessage('Only PDF, JPG, JPEG and PNG map files are allowed.');
      return;
    }

    if (file.bytes.isEmpty) {
      _showMessage('Could not read the selected file. Please pick it again.');
      return;
    }

    setState(() {
      _pickedFileType = file.extension;
      _pickedFileName = file.name;
      _pickedFileSizeLabel = _formatFileSize(file.size);
      _pickedFileBytes = file.bytes;
    });
  }

  Future<void> _publishMap() async {
    if (_isPublishing) return;

    final title = _titleController.text.trim();
    final siteId = _selectedSiteId;
    final fileName = _pickedFileName;
    final fileType = _pickedFileType;
    final fileBytes = _pickedFileBytes;
    if (title.isEmpty ||
        fileName == null ||
        fileType == null ||
        fileBytes == null) {
      _showMessage('Enter title and select a PDF/JPG/PNG file from device.');
      return;
    }

    final now = DateTime.now().toUtc();
    setState(() => _isPublishing = true);
    final uploadedFilePath = await _mapsRepo.uploadMapFile(
      siteId: siteId,
      fileName: fileName,
      fileType: fileType,
      bytes: fileBytes,
      uploadedAt: now,
    );

    if (uploadedFilePath == null) {
      if (mounted) setState(() => _isPublishing = false);
      _showMessage('File upload failed. Please try again.');
      return;
    }
    if (!mounted) return;

    final success = await _mapsRepo.saveMapUpload(HodMapUploadRecord(
      id: '', // Supabase will generate UUID
      siteId: siteId,
      uploadedById: _hodId,
      title: title,
      note: _noteController.text.trim(),
      fileName: fileName,
      fileType: fileType,
      filePath: uploadedFilePath,
      uploadedAt: now,
    ));

    if (!success) {
      if (mounted) setState(() => _isPublishing = false);
      _showMessage('Failed to publish map.');
      return;
    }
    if (!mounted) return;

    _titleController.clear();
    _noteController.clear();
    setState(() {
      _pickedFileName = null;
      _pickedFileType = null;
      _pickedFileSizeLabel = null;
      _pickedFileBytes = null;
      _isPublishing = false;
      _future = _loadData();
    });
    _showMessage('Map published to supervisor.');
  }

  Future<void> _updateRequest(
    ApprovalRequestRecord request,
    ApprovalStatus status,
  ) async {
    await _store.updateRequestStatus(
      requestId: request.id,
      status: status,
      actorId: _hodId,
      note: status == ApprovalStatus.approved
          ? 'HOD approved map update request.'
          : 'HOD rejected map update request.',
    );
    setState(() {
      _future = _loadData();
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FC),
      appBar: AppBar(
        title: const Text('HOD Maps'),
        backgroundColor: const Color(0xFF0F3460),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => setState(() {
              _future = _loadData();
            }),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<_HodMapsData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          final data = snapshot.data ?? const _HodMapsData();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildRequestsSection(data.requests),
              const SizedBox(height: 16),
              _buildUploadCard(data.sites),
              const SizedBox(height: 16),
              _buildPublishedSection(data.uploads),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUploadCard(List<ThavvuSite> sites) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'HOD Maps Upload',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text(
              'Upload PDF, JPG or PNG maps/specs. After publish, supervisors assigned to the site can see the file immediately.',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: sites.any((site) => site.id == _selectedSiteId)
                  ? _selectedSiteId
                  : null,
              decoration: const InputDecoration(labelText: 'Site'),
              items: sites
                  .map(
                    (site) => DropdownMenuItem(
                      value: site.id,
                      child: Text('${site.name} · ${site.place}'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _selectedSiteId = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('hodMapTitleField'),
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Map title',
                hintText: 'Example: Updated excavation path map',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('hodMapNoteField'),
              controller: _noteController,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'HOD note',
                hintText: 'Instructions supervisor should follow',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  key: const Key('hodMapPickDeviceButton'),
                  onPressed: _pickDeviceFile,
                  icon: const Icon(Icons.attach_file_rounded),
                  label: const Text('Pick From Device'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F3460),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            if (_pickedFileName != null) ...[
              const SizedBox(height: 10),
              _FileChip(
                title: _pickedFileName!,
                subtitle:
                    '${_pickedFileType!.toUpperCase()} · ${_pickedFileSizeLabel ?? 'ready'} · ready to publish',
                fileType: _pickedFileType!,
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: const Key('hodMapPublishButton'),
                onPressed: _isPublishing ? null : _publishMap,
                icon: _isPublishing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.cloud_upload_rounded),
                label: Text(_isPublishing
                    ? 'Uploading...'
                    : 'Publish Map to Supervisor'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestsSection(List<ApprovalRequestRecord> requests) {
    final pending = requests
        .where((request) => request.status == ApprovalStatus.pending)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Supervisor Map Requests',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        if (pending.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text('No pending map requests.'),
            ),
          )
        else
          ...pending.map(_buildRequestCard),
      ],
    );
  }

  Widget _buildRequestCard(ApprovalRequestRecord request) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(request.title,
                style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(
              request.payload['detail']?.toString() ??
                  'Supervisor requested map update.',
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    key: Key('approveMapRequest_${request.id}'),
                    onPressed: () =>
                        _updateRequest(request, ApprovalStatus.approved),
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0FA37A),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _updateRequest(request, ApprovalStatus.rejected),
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: const Text('Reject'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPublishedSection(List<HodMapUploadRecord> uploads) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Published Maps',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        if (uploads.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text('No maps uploaded yet.'),
            ),
          )
        else
          ...uploads.map(
            (upload) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _FileChip(
                  title: upload.title,
                  subtitle:
                      '${upload.fileName} · ${upload.fileType.toUpperCase()} · ${upload.siteId}',
                  fileType: upload.fileType,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FileChip extends StatelessWidget {
  final String title;
  final String subtitle;
  final String fileType;

  const _FileChip({
    required this.title,
    required this.subtitle,
    required this.fileType,
  });

  @override
  Widget build(BuildContext context) {
    final isPdf = fileType.toLowerCase() == 'pdf';
    final color = isPdf ? const Color(0xFFE53935) : const Color(0xFF0FA37A);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
              color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HodMapsData {
  final List<ThavvuSite> sites;
  final List<HodMapUploadRecord> uploads;
  final List<ApprovalRequestRecord> requests;

  const _HodMapsData({
    this.sites = const [],
    this.uploads = const [],
    this.requests = const [],
  });
}
