import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/collapsible_tab_scaffold.dart';
import '../services/supabase_maps_repository.dart';
import '../utils/web_launcher.dart';

// ══════════════════════════════════════════════════════════════════════════════
// MAPS / PLACE INFORMATION MODULE
// ══════════════════════════════════════════════════════════════════════════════
//
// Purpose:
// - HOD uploads PDF/JPG/PNG place information files through backend/API.
// - Supervisor can view those uploaded files inside the Map View tab.
// - The previous fake/live interactive map is removed completely.
// - Existing theme colors and visual style are maintained.
//
// Backend integration points:
// - Replace _loadMockHodUploadedFiles() with API response.
// - Use PlaceInfoFile.fromJson() for uploaded files.
// - HOD upload sheet currently stores metadata locally; connect _saveHodFile()
//   to your upload API when backend is ready.

// ══════════════════════════════════════════════════════════════════════════════
// MODELS
// ══════════════════════════════════════════════════════════════════════════════

enum PlaceFileType { pdf, jpg, png }

extension PlaceFileTypeX on PlaceFileType {
  String get label {
    switch (this) {
      case PlaceFileType.pdf:
        return 'PDF';
      case PlaceFileType.jpg:
        return 'JPG';
      case PlaceFileType.png:
        return 'PNG';
    }
  }

  String get extension {
    switch (this) {
      case PlaceFileType.pdf:
        return '.pdf';
      case PlaceFileType.jpg:
        return '.jpg';
      case PlaceFileType.png:
        return '.png';
    }
  }

  IconData get icon {
    switch (this) {
      case PlaceFileType.pdf:
        return Icons.picture_as_pdf_rounded;
      case PlaceFileType.jpg:
      case PlaceFileType.png:
        return Icons.image_rounded;
    }
  }

  Color get color {
    switch (this) {
      case PlaceFileType.pdf:
        return const Color(0xFFE53935);
      case PlaceFileType.jpg:
        return const Color(0xFF1976D2);
      case PlaceFileType.png:
        return const Color(0xFF0FA37A);
    }
  }

  static PlaceFileType fromString(String value) {
    final normalized = value.toLowerCase().replaceAll('.', '').trim();
    switch (normalized) {
      case 'pdf':
        return PlaceFileType.pdf;
      case 'jpg':
      case 'jpeg':
        return PlaceFileType.jpg;
      case 'png':
        return PlaceFileType.png;
      default:
        return PlaceFileType.pdf;
    }
  }
}

class PlaceLocation {
  final String id;
  final String name;
  final String coordinatesDisplay;
  final String type;
  final String status;
  final Color color;
  final IconData icon;
  final String description;
  final String lastUpdated;
  final String updatedBy;
  final String specifications;

  const PlaceLocation({
    required this.id,
    required this.name,
    required this.coordinatesDisplay,
    required this.type,
    required this.status,
    required this.color,
    required this.icon,
    required this.description,
    required this.lastUpdated,
    required this.updatedBy,
    required this.specifications,
  });

  factory PlaceLocation.fromJson(Map<String, dynamic> json) {
    return PlaceLocation(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      coordinatesDisplay: json['coordinatesDisplay']?.toString() ?? '',
      type: json['type']?.toString() ?? 'Work Area',
      status: json['status']?.toString() ?? 'Active',
      color: json['color'] is Color ? json['color'] as Color : const Color(0xFF1976D2),
      icon: json['icon'] is IconData ? json['icon'] as IconData : Icons.location_on_rounded,
      description: json['description']?.toString() ?? '',
      lastUpdated: json['lastUpdated']?.toString() ?? '',
      updatedBy: json['updatedBy']?.toString() ?? '',
      specifications: json['specifications']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'coordinatesDisplay': coordinatesDisplay,
      'type': type,
      'status': status,
      'description': description,
      'lastUpdated': lastUpdated,
      'updatedBy': updatedBy,
      'specifications': specifications,
    };
  }
}

class PlaceInfoFile {
  final String id;
  final String locationId;
  final String title;
  final String description;
  final String fileName;
  final PlaceFileType fileType;
  final String fileSizeLabel;
  final String uploadedBy;
  final DateTime uploadedAt;
  final String version;
  final String? fileUrl;
  final String? thumbnailUrl;
  final bool isVerified;

  const PlaceInfoFile({
    required this.id,
    required this.locationId,
    required this.title,
    required this.description,
    required this.fileName,
    required this.fileType,
    required this.fileSizeLabel,
    required this.uploadedBy,
    required this.uploadedAt,
    this.version = 'v1.0',
    this.fileUrl,
    this.thumbnailUrl,
    this.isVerified = true,
  });

  bool get isImage => fileType == PlaceFileType.jpg || fileType == PlaceFileType.png;

  factory PlaceInfoFile.fromJson(Map<String, dynamic> json) {
    return PlaceInfoFile(
      id: json['id']?.toString() ?? '',
      locationId: json['locationId']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      fileName: json['fileName']?.toString() ?? '',
      fileType: PlaceFileTypeX.fromString(json['fileType']?.toString() ?? 'pdf'),
      fileSizeLabel: json['fileSizeLabel']?.toString() ?? '0 KB',
      uploadedBy: json['uploadedBy']?.toString() ?? 'HOD',
      uploadedAt: DateTime.tryParse(json['uploadedAt']?.toString() ?? '') ?? DateTime.now(),
      version: json['version']?.toString() ?? 'v1.0',
      fileUrl: json['fileUrl']?.toString(),
      thumbnailUrl: json['thumbnailUrl']?.toString(),
      isVerified: json['isVerified'] != false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'locationId': locationId,
      'title': title,
      'description': description,
      'fileName': fileName,
      'fileType': fileType.label,
      'fileSizeLabel': fileSizeLabel,
      'uploadedBy': uploadedBy,
      'uploadedAt': uploadedAt.toIso8601String(),
      'version': version,
      'fileUrl': fileUrl,
      'thumbnailUrl': thumbnailUrl,
      'isVerified': isVerified,
    };
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class MapsScreen extends StatefulWidget {
  final bool isHOD;
  final List<PlaceInfoFile> initialUploadedFiles;

  const MapsScreen({
    super.key,
    this.isHOD = false,
    this.initialUploadedFiles = const [],
  });

  @override
  State<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends State<MapsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'All';
  String _searchQuery = '';

  final TextEditingController _uploadTitleController = TextEditingController();
  final TextEditingController _uploadFileNameController = TextEditingController();
  final TextEditingController _uploadDescriptionController = TextEditingController();
  final TextEditingController _uploadSizeController = TextEditingController(text: '1.2 MB');

  String? _uploadLocationId;
  PlaceFileType _uploadFileType = PlaceFileType.pdf;

  // Location data - replace with backend API response later.
  final List<PlaceLocation> _locations = const [
    PlaceLocation(
      id: 'LOC-001',
      name: 'Site A - Main Entrance',
      coordinatesDisplay: '12.9716° N, 77.5946° E',
      type: 'Entry',
      status: 'Active',
      color: Color(0xFF0FA37A),
      icon: Icons.login_rounded,
      description: 'Main gate with security checkpoint and vehicle weighing station',
      lastUpdated: '2 hours ago',
      updatedBy: 'HOD - Mr. Sharma',
      specifications: '24/7 access · CCTV monitored · Boom barrier',
    ),
    PlaceLocation(
      id: 'LOC-002',
      name: 'Site B - North Wing Construction',
      coordinatesDisplay: '12.9718° N, 77.5950° E',
      type: 'Work Area',
      status: 'Active',
      color: Color(0xFFE6A817),
      icon: Icons.construction_rounded,
      description: 'Heavy machinery zone - Excavators & Loaders active',
      lastUpdated: '5 hours ago',
      updatedBy: 'HOD - Mr. Sharma',
      specifications: 'Restricted access · Safety gear mandatory · 4 active machines',
    ),
    PlaceLocation(
      id: 'LOC-003',
      name: 'Storage Warehouse C',
      coordinatesDisplay: '12.9720° N, 77.5948° E',
      type: 'Storage',
      status: 'Maintenance',
      color: Color(0xFF1976D2),
      icon: Icons.warehouse_rounded,
      description: 'Raw material storage with 3 sheds',
      lastUpdated: '1 day ago',
      updatedBy: 'HOD - Mr. Sharma',
      specifications: '3 sheds · Capacity 500 tons · Under renovation',
    ),
    PlaceLocation(
      id: 'LOC-004',
      name: 'Site D - South Exit Gate',
      coordinatesDisplay: '12.9714° N, 77.5952° E',
      type: 'Exit',
      status: 'Active',
      color: Color(0xFFE53935),
      icon: Icons.logout_rounded,
      description: 'Emergency exit and dedicated vehicle passage',
      lastUpdated: '3 days ago',
      updatedBy: 'HOD - Mr. Sharma',
      specifications: 'Emergency exit · Vehicle passage · Fire lane',
    ),
    PlaceLocation(
      id: 'LOC-005',
      name: 'Fuel Station Area',
      coordinatesDisplay: '12.9719° N, 77.5955° E',
      type: 'Storage',
      status: 'Active',
      color: Color(0xFF9C27B0),
      icon: Icons.local_gas_station_rounded,
      description: 'Diesel and petrol dispensing point for all vehicles',
      lastUpdated: '12 hours ago',
      updatedBy: 'HOD - Mr. Sharma',
      specifications: 'Underground tanks · 24/7 · Fire safety equipped',
    ),
    PlaceLocation(
      id: 'LOC-006',
      name: 'Worker Assembly Point',
      coordinatesDisplay: '12.9722° N, 77.5944° E',
      type: 'Work Area',
      status: 'Active',
      color: Color(0xFF00897B),
      icon: Icons.groups_rounded,
      description: 'Daily briefing and attendance marking area',
      lastUpdated: '6 hours ago',
      updatedBy: 'HOD - Mr. Sharma',
      specifications: 'Capacity 100 workers · PA system · Notice board',
    ),
  ];

  final List<PlaceInfoFile> _hodUploadedFiles = [];
  final SupabaseMapsRepository _mapsRepo = SupabaseMapsRepository();

  List<PlaceLocation> get _filteredLocations {
    return _locations.where((loc) {
      final matchesFilter = _selectedFilter == 'All' || loc.type == _selectedFilter;
      final matchesSearch = _searchQuery.trim().isEmpty ||
          loc.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          loc.id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          loc.type.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesFilter && matchesSearch;
    }).toList();
  }

  List<PlaceInfoFile> get _filteredFiles {
    return _hodUploadedFiles.where((file) {
      final location = _locationById(file.locationId);
      final matchesSearch = _searchQuery.trim().isEmpty ||
          file.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          file.fileName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          file.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (location?.name.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          file.locationId.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesSearch;
    }).toList()
      ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
  }

  int get _activeCount => _locations.where((loc) => loc.status == 'Active').length;

  int get _imageFileCount => _hodUploadedFiles.where((file) => file.isImage).length;

  int get _pdfFileCount => _hodUploadedFiles.where((file) => file.fileType == PlaceFileType.pdf).length;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _uploadLocationId = _locations.isNotEmpty ? _locations.first.id : null;
    _loadMapsFromSupabase();
  }

  Future<void> _loadMapsFromSupabase() async {
    final records = await _mapsRepo.fetchMapUploads();
    setState(() {
      _hodUploadedFiles.clear();
      _hodUploadedFiles.addAll(records.map((r) {
        // filePath may already be a full public URL (stored that way by HOD upload)
        // or just a storage path — handle both cases
        final publicUrl = r.filePath.isEmpty
            ? null
            : r.filePath.startsWith('http')
                ? r.filePath
                : _mapsRepo.getPublicUrl(r.filePath);
        return PlaceInfoFile(
          id: r.id,
          locationId: r.siteId,
          title: r.title,
          description: r.note,
          fileName: r.fileName,
          fileType: PlaceFileTypeX.fromString(r.fileType),
          fileSizeLabel: 'Unknown',
          uploadedBy: r.uploadedById,
          uploadedAt: r.uploadedAt,
          fileUrl: publicUrl,
        );
      }));
      _hodUploadedFiles.addAll(widget.initialUploadedFiles);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _uploadTitleController.dispose();
    _uploadFileNameController.dispose();
    _uploadDescriptionController.dispose();
    _uploadSizeController.dispose();
    super.dispose();
  }

  PlaceLocation? _locationById(String id) {
    for (final loc in _locations) {
      if (loc.id == id) return loc;
    }
    return null;
  }

  List<PlaceInfoFile> _filesForLocation(String locationId) {
    return _hodUploadedFiles.where((file) => file.locationId == locationId).toList()
      ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
  }

  Map<String, List<PlaceInfoFile>> get _groupedFilteredFiles {
    final grouped = <String, List<PlaceInfoFile>>{};
    for (final file in _filteredFiles) {
      grouped.putIfAbsent(file.locationId, () => []).add(file);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          buildCollapsibleAppBar(
            title: 'Maps & Specifications',
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              if (widget.isHOD)
                IconButton(
                  icon: const Icon(Icons.upload_file_rounded),
                  onPressed: _showHodUploadSheet,
                  tooltip: 'Upload place file',
                ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () => setState(() {}),
                tooltip: 'Refresh locations',
              ),
              IconButton(
                icon: const Icon(Icons.filter_list_rounded),
                onPressed: _showFilterSheet,
                tooltip: 'Filter',
              ),
            ],
            controller: _tabController,
            tabs: const [
              Tab(text: 'Map View'),
              Tab(text: 'List View'),
            ],
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildMapView(),
            _buildListView(),
          ],
        ),
      ),
    );
  }

  // ─── MAP VIEW: HOD UPLOADED FILES ONLY ────────────────────────────────────
  Widget _buildMapView() {
    final grouped = _groupedFilteredFiles;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchBar(),
          const SizedBox(height: 12),
          _buildFilterChips(),
          const SizedBox(height: 16),
          _buildStatsRow(),
          const SizedBox(height: 16),
          _buildHODUpdateBanner(),
          const SizedBox(height: 16),
          if (widget.isHOD) ...[
            _buildHodUploadPromptCard(),
            const SizedBox(height: 16),
          ],
          _buildSectionTitle(
            icon: Icons.folder_copy_rounded,
            title: 'HOD Uploaded Place Files',
            subtitle: 'Supervisor can view PDF, JPG and PNG files uploaded by HOD. Live map has been removed from this tab.',
          ),
          const SizedBox(height: 12),
          if (grouped.isEmpty)
            _buildEmptyFilesState()
          else
            ...grouped.entries.map((entry) {
              final location = _locationById(entry.key);
              return _buildLocationFileGroup(
                location: location,
                files: entry.value,
              );
            }),
        ],
      ),
    );
  }

  // ─── LIST VIEW ────────────────────────────────────────────────────────────
  Widget _buildListView() {
    final filtered = _filteredLocations;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchBar(),
          const SizedBox(height: 12),
          _buildFilterChips(),
          const SizedBox(height: 16),
          if (filtered.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(Icons.location_off_rounded, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    const Text('No locations found', style: TextStyle(fontSize: 16, color: Colors.grey)),
                  ],
                ),
              ),
            )
          else
            ...filtered.map((loc) => _buildLocationCard(loc)),
        ],
      ),
    );
  }

  // ─── SEARCH BAR ───────────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return TextField(
      onChanged: (v) => setState(() => _searchQuery = v),
      decoration: InputDecoration(
        hintText: 'Search locations, files or IDs...',
        prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () => setState(() => _searchQuery = ''),
              )
            : null,
      ),
    );
  }

  // ─── FILTER CHIPS ─────────────────────────────────────────────────────────
  Widget _buildFilterChips() {
    final filters = ['All', 'Entry', 'Work Area', 'Storage', 'Exit'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedFilter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              label: Text(
                f,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF555555),
                ),
              ),
              selectedColor: const Color(0xFF1976D2),
              backgroundColor: Colors.white,
              side: BorderSide(
                color: isSelected ? const Color(0xFF1976D2) : const Color(0xFFE0E4F0),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              onSelected: (_) => setState(() => _selectedFilter = f),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── STATS ROW ────────────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    return Row(
      children: [
        _buildStatCard('Total Sites', '${_locations.length}', Icons.location_city_rounded, const Color(0xFF1976D2)),
        const SizedBox(width: 10),
        _buildStatCard('Active', '$_activeCount', Icons.check_circle_rounded, const Color(0xFF0FA37A)),
        const SizedBox(width: 10),
        _buildStatCard('HOD Files', '${_hodUploadedFiles.length}', Icons.folder_copy_rounded, const Color(0xFFE6A817)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  // ─── HOD UPDATE BANNER ────────────────────────────────────────────────────
  Widget _buildHODUpdateBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1976D2), Color(0xFF0D47A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'HOD Managed Place Information',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  'PDF: $_pdfFileCount · Images: $_imageFileCount · Total files: ${_hodUploadedFiles.length}',
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHodUploadPromptCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E4F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF1976D2).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.upload_file_rounded, color: Color(0xFF1976D2)),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Upload PDF / JPG / PNG', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0A1628))),
                SizedBox(height: 2),
                Text('Add place files for supervisors to view in Map View.', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: _showHodUploadSheet,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF1976D2).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF1976D2), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0A1628))),
              const SizedBox(height: 3),
              Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyFilesState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E4F0)),
      ),
      child: Column(
        children: [
          Icon(Icons.folder_off_rounded, size: 54, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          const Text('No HOD files found', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0A1628))),
          const SizedBox(height: 4),
          const Text('Try changing the filter or search keyword.', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildLocationFileGroup({
    required PlaceLocation? location,
    required List<PlaceInfoFile> files,
  }) {
    final color = location?.color ?? const Color(0xFF1976D2);
    final title = location?.name ?? files.first.locationId;
    final subtitle = location == null
        ? files.first.locationId
        : '${location.id} · ${location.type} · ${location.coordinatesDisplay}';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0E4F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(location?.icon ?? Icons.location_on_rounded, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0A1628))),
                    const SizedBox(height: 3),
                    Text(subtitle, style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
                  ],
                ),
              ),
              _buildSmallCountBadge('${files.length} file${files.length == 1 ? '' : 's'}'),
            ],
          ),
          const SizedBox(height: 12),
          ...files.map(_buildPlaceFileCard),
        ],
      ),
    );
  }

  Widget _buildSmallCountBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1976D2).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF1976D2)),
      ),
    );
  }

  Widget _buildPlaceFileCard(PlaceInfoFile file) {
    final color = file.fileType.color;
    final location = _locationById(file.locationId);

    return GestureDetector(
      onTap: () => _showFileDetails(file),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFD),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE0E4F0)),
        ),
        child: Row(
          children: [
            _buildFilePreviewBox(file),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          file.title,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0A1628)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (file.isVerified)
                        const Icon(Icons.verified_rounded, size: 15, color: Color(0xFF0FA37A)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    file.fileName,
                    style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${location?.id ?? file.locationId} · ${file.fileSizeLabel} · ${_formatDateTime(file.uploadedAt)}',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildFilePreviewBox(PlaceInfoFile file) {
    final color = file.fileType.color;
    if (file.isImage && (file.thumbnailUrl?.isNotEmpty ?? false)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          file.thumbnailUrl!,
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFileIconBox(file),
        ),
      );
    }

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(file.fileType.icon, color: color, size: 24),
          const SizedBox(height: 2),
          Text(file.fileType.label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _buildFileIconBox(PlaceInfoFile file) {
    final color = file.fileType.color;
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Icon(file.fileType.icon, color: color, size: 24),
    );
  }

  // ─── LOCATION CARD ────────────────────────────────────────────────────────
  Widget _buildLocationCard(PlaceLocation loc) {
    final files = _filesForLocation(loc.id);
    return GestureDetector(
      onTap: () => _showLocationDetails(loc),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0E4F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: loc.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(loc.icon, color: loc.color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          loc.name,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0A1628)),
                        ),
                      ),
                      _buildStatusBadge(loc.status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    loc.coordinatesDisplay,
                    style: const TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.update, size: 10, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('Updated ${loc.lastUpdated}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      const SizedBox(width: 12),
                      const Icon(Icons.folder_copy_rounded, size: 10, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('${files.length} HOD files', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final isActive = status == 'Active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF0FA37A).withValues(alpha: 0.1) : const Color(0xFFE6A817).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isActive ? const Color(0xFF0FA37A) : const Color(0xFFE6A817),
        ),
      ),
    );
  }

  // ─── FILTER BOTTOM SHEET ──────────────────────────────────────────────────
  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Filter by Type', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: ['All', 'Entry', 'Work Area', 'Storage', 'Exit'].map((f) {
                  final isSelected = _selectedFilter == f;
                  return ChoiceChip(
                    selected: isSelected,
                    label: Text(f),
                    selectedColor: const Color(0xFF1976D2),
                    labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
                    onSelected: (_) {
                      setState(() => _selectedFilter = f);
                      Navigator.pop(ctx);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  // ─── LOCATION DETAILS ─────────────────────────────────────────────────────
  void _showLocationDetails(PlaceLocation loc) {
    final files = _filesForLocation(loc.id);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          maxChildSize: 0.92,
          minChildSize: 0.45,
          expand: false,
          builder: (_, scrollCtrl) {
            return SingleChildScrollView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(color: loc.color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
                        alignment: Alignment.center,
                        child: Icon(loc.icon, color: loc.color, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(loc.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0A1628))),
                            const SizedBox(height: 4),
                            Text(loc.id, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                      _buildStatusBadge(loc.status),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8EDF5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.folder_copy_rounded, size: 42, color: loc.color.withValues(alpha: 0.55)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(loc.coordinatesDisplay, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF555555))),
                              const SizedBox(height: 4),
                              Text('${files.length} HOD uploaded file${files.length == 1 ? '' : 's'} available', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildDetailRow(Icons.description_rounded, 'Description', loc.description),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.build_rounded, 'Specifications', loc.specifications),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.person_rounded, 'Updated By', loc.updatedBy),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.schedule_rounded, 'Last Updated', loc.lastUpdated),
                  const SizedBox(height: 20),
                  const Text('HOD Uploaded Files', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0A1628))),
                  const SizedBox(height: 10),
                  if (files.isEmpty)
                    const Text('No uploaded files for this place yet.', style: TextStyle(fontSize: 12, color: Colors.grey))
                  else
                    ...files.map(_buildPlaceFileCard),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showFileDetails(PlaceInfoFile file) {
    final location = _locationById(file.locationId);
    final color = file.fileType.color;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.62,
          maxChildSize: 0.88,
          minChildSize: 0.38,
          expand: false,
          builder: (_, scrollCtrl) {
            return SingleChildScrollView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: color.withValues(alpha: 0.20)),
                        ),
                        child: Icon(file.fileType.icon, color: color, size: 30),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(file.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF0A1628))),
                            const SizedBox(height: 4),
                            Text(file.fileName, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      if (file.isVerified) const Icon(Icons.verified_rounded, color: Color(0xFF0FA37A), size: 22),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildFilePreviewLarge(file),
                  const SizedBox(height: 20),
                  _buildDetailRow(Icons.location_on_rounded, 'Place', '${location?.name ?? file.locationId} (${file.locationId})'),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.description_rounded, 'File Details', file.description),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.person_rounded, 'Uploaded By', file.uploadedBy),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.schedule_rounded, 'Uploaded On', _formatDateTime(file.uploadedAt)),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.info_outline_rounded, 'Version / Size', '${file.version} · ${file.fileSizeLabel} · ${file.fileType.label}'),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: const Text('Close'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1976D2),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            final url = file.fileUrl;
                            if (url == null || url.isEmpty) {
                              _showSnack('File URL not available.', const Color(0xFFE53935));
                              return;
                            }
                            openUrlInBrowser(url);
                          },
                          icon: Icon(
                            file.fileType == PlaceFileType.pdf
                                ? Icons.picture_as_pdf_rounded
                                : Icons.open_in_new_rounded,
                            size: 18,
                          ),
                          label: Text(
                            file.fileType == PlaceFileType.pdf
                                ? 'Open PDF'
                                : 'Open File',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1976D2),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilePreviewLarge(PlaceInfoFile file) {
    if (file.isImage && (file.fileUrl?.isNotEmpty ?? false)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          file.fileUrl!,
          height: 210,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildDocumentPreviewPlaceholder(file),
        ),
      );
    }

    return _buildDocumentPreviewPlaceholder(file);
  }

  Widget _buildDocumentPreviewPlaceholder(PlaceInfoFile file) {
    final color = file.fileType.color;
    return Container(
      height: 210,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFE8EDF5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E4F0)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(file.fileType.icon, size: 54, color: color.withValues(alpha: 0.75)),
          const SizedBox(height: 10),
          Text(file.fileType == PlaceFileType.pdf ? 'PDF Document Preview' : '${file.fileType.label} Image Preview', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0A1628))),
          const SizedBox(height: 4),
          Text(file.fileName, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF0A1628))),
            ],
          ),
        ),
      ],
    );
  }

  // ─── HOD UPLOAD SHEET ─────────────────────────────────────────────────────
  void _showHodUploadSheet() {
    if (!widget.isHOD) {
      _showSnack('Only HOD can upload place files.', const Color(0xFFE6A817));
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Upload Place Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0A1628))),
                    const SizedBox(height: 4),
                    const Text('Allowed formats: PDF, JPG, PNG', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _uploadLocationId,
                      isExpanded: true,
                      decoration: _inputDecoration('Select Place', Icons.location_on_rounded),
                      items: _locations.map((loc) {
                        return DropdownMenuItem<String>(
                          value: loc.id,
                          child: Text('${loc.id} · ${loc.name}', overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setSheetState(() => _uploadLocationId = value);
                        setState(() => _uploadLocationId = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _uploadTitleController,
                      decoration: _inputDecoration('File title', Icons.title_rounded),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<PlaceFileType>(
                            value: _uploadFileType,
                            decoration: _inputDecoration('File Type', Icons.attach_file_rounded),
                            items: PlaceFileType.values.map((type) {
                              return DropdownMenuItem<PlaceFileType>(
                                value: type,
                                child: Text(type.label),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setSheetState(() => _uploadFileType = value);
                              setState(() => _uploadFileType = value);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _uploadSizeController,
                            decoration: _inputDecoration('File Size', Icons.storage_rounded),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _uploadFileNameController,
                      decoration: _inputDecoration('File name with extension', Icons.insert_drive_file_rounded),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _uploadDescriptionController,
                      minLines: 3,
                      maxLines: 4,
                      decoration: _inputDecoration('Information / remarks', Icons.notes_rounded),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final saved = _saveHodFile();
                          if (saved) Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.cloud_upload_rounded),
                        label: const Text('Save Upload'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1976D2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  bool _saveHodFile() {
    final locationId = _uploadLocationId;
    final title = _uploadTitleController.text.trim();
    final fileName = _uploadFileNameController.text.trim();
    final description = _uploadDescriptionController.text.trim();
    final size = _uploadSizeController.text.trim().isEmpty ? '0 KB' : _uploadSizeController.text.trim();

    if (locationId == null || locationId.isEmpty) {
      _showSnack('Please select a place.', const Color(0xFFE53935));
      return false;
    }
    if (title.isEmpty) {
      _showSnack('Please enter file title.', const Color(0xFFE53935));
      return false;
    }
    if (fileName.isEmpty) {
      _showSnack('Please enter file name.', const Color(0xFFE53935));
      return false;
    }

    final lowerFileName = fileName.toLowerCase();
    final validByExtension = lowerFileName.endsWith('.pdf') || lowerFileName.endsWith('.jpg') || lowerFileName.endsWith('.jpeg') || lowerFileName.endsWith('.png');
    if (!validByExtension) {
      _showSnack('Only PDF, JPG and PNG files are allowed.', const Color(0xFFE53935));
      return false;
    }

    if (!_matchesSelectedFileType(lowerFileName, _uploadFileType)) {
      _showSnack('Selected file type does not match file extension.', const Color(0xFFE6A817));
      return false;
    }

    final now = DateTime.now();
    final file = PlaceInfoFile(
      id: 'FILE-${now.millisecondsSinceEpoch}',
      locationId: locationId,
      title: title,
      description: description.isEmpty ? 'No additional remarks added by HOD.' : description,
      fileName: fileName,
      fileType: _uploadFileType,
      fileSizeLabel: size,
      uploadedBy: 'HOD',
      uploadedAt: now,
      version: 'v1.0',
      isVerified: true,
    );

    setState(() {
      _hodUploadedFiles.insert(0, file);
      _uploadTitleController.clear();
      _uploadFileNameController.clear();
      _uploadDescriptionController.clear();
      _uploadSizeController.text = '1.2 MB';
      _uploadFileType = PlaceFileType.pdf;
    });

    _showSnack('Place file uploaded successfully.', const Color(0xFF0FA37A));
    return true;
  }

  bool _matchesSelectedFileType(String fileName, PlaceFileType type) {
    switch (type) {
      case PlaceFileType.pdf:
        return fileName.endsWith('.pdf');
      case PlaceFileType.jpg:
        return fileName.endsWith('.jpg') || fileName.endsWith('.jpeg');
      case PlaceFileType.png:
        return fileName.endsWith('.png');
    }
  }

  // ─── HELPERS ──────────────────────────────────────────────────────────────
  String _formatDateTime(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year.toString();
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
