import 'package:flutter/material.dart';
import 'dart:math' as math;

class MapsScreen extends StatefulWidget {
  const MapsScreen({super.key});

  @override
  State<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends State<MapsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'All';
  String _searchQuery = '';
  int? _selectedLocationIndex;

  // Location data - would come from HOD via API
  final List<Map<String, dynamic>> _locations = [
    {
      'id': 'LOC-001',
      'name': 'Site A - Main Entrance',
      'coordinates': {'lat': 12.9716, 'lng': 77.5946},
      'coordinatesDisplay': '12.9716° N, 77.5946° E',
      'type': 'Entry',
      'status': 'Active',
      'color': const Color(0xFF0FA37A),
      'icon': Icons.login_rounded,
      'description': 'Main gate with security checkpoint and vehicle weighing station',
      'lastUpdated': '2 hours ago',
      'updatedBy': 'HOD - Mr. Sharma',
      'specifications': '24/7 access · CCTV monitored · Boom barrier',
      'imageCount': 3,
    },
    {
      'id': 'LOC-002',
      'name': 'Site B - North Wing Construction',
      'coordinates': {'lat': 12.9718, 'lng': 77.5950},
      'coordinatesDisplay': '12.9718° N, 77.5950° E',
      'type': 'Work Area',
      'status': 'Active',
      'color': const Color(0xFFE6A817),
      'icon': Icons.construction_rounded,
      'description': 'Heavy machinery zone - Excavators & Loaders active',
      'lastUpdated': '5 hours ago',
      'updatedBy': 'HOD - Mr. Sharma',
      'specifications': 'Restricted access · Safety gear mandatory · 4 active machines',
      'imageCount': 5,
    },
    {
      'id': 'LOC-003',
      'name': 'Storage Warehouse C',
      'coordinates': {'lat': 12.9720, 'lng': 77.5948},
      'coordinatesDisplay': '12.9720° N, 77.5948° E',
      'type': 'Storage',
      'status': 'Maintenance',
      'color': const Color(0xFF1976D2),
      'icon': Icons.warehouse_rounded,
      'description': 'Raw material storage with 3 sheds',
      'lastUpdated': '1 day ago',
      'updatedBy': 'HOD - Mr. Sharma',
      'specifications': '3 sheds · Capacity 500 tons · Under renovation',
      'imageCount': 2,
    },
    {
      'id': 'LOC-004',
      'name': 'Site D - South Exit Gate',
      'coordinates': {'lat': 12.9714, 'lng': 77.5952},
      'coordinatesDisplay': '12.9714° N, 77.5952° E',
      'type': 'Exit',
      'status': 'Active',
      'color': const Color(0xFFE53935),
      'icon': Icons.logout_rounded,
      'description': 'Emergency exit and dedicated vehicle passage',
      'lastUpdated': '3 days ago',
      'updatedBy': 'HOD - Mr. Sharma',
      'specifications': 'Emergency exit · Vehicle passage · Fire lane',
      'imageCount': 1,
    },
    {
      'id': 'LOC-005',
      'name': 'Fuel Station Area',
      'coordinates': {'lat': 12.9719, 'lng': 77.5955},
      'coordinatesDisplay': '12.9719° N, 77.5955° E',
      'type': 'Storage',
      'status': 'Active',
      'color': const Color(0xFF9C27B0),
      'icon': Icons.local_gas_station_rounded,
      'description': 'Diesel and petrol dispensing point for all vehicles',
      'lastUpdated': '12 hours ago',
      'updatedBy': 'HOD - Mr. Sharma',
      'specifications': 'Underground tanks · 24/7 · Fire safety equipped',
      'imageCount': 4,
    },
    {
      'id': 'LOC-006',
      'name': 'Worker Assembly Point',
      'coordinates': {'lat': 12.9722, 'lng': 77.5944},
      'coordinatesDisplay': '12.9722° N, 77.5944° E',
      'type': 'Work Area',
      'status': 'Active',
      'color': const Color(0xFF00897B),
      'icon': Icons.groups_rounded,
      'description': 'Daily briefing and attendance marking area',
      'lastUpdated': '6 hours ago',
      'updatedBy': 'HOD - Mr. Sharma',
      'specifications': 'Capacity 100 workers · PA system · Notice board',
      'imageCount': 2,
    },
  ];

  List<Map<String, dynamic>> get _filteredLocations {
    return _locations.where((loc) {
      final matchesFilter = _selectedFilter == 'All' || loc['type'] == _selectedFilter;
      final matchesSearch = _searchQuery.isEmpty ||
          (loc['name'] as String).toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (loc['id'] as String).toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesFilter && matchesSearch;
    }).toList();
  }

  int get _activeCount => _locations.where((l) => l['status'] == 'Active').length;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FC),
      appBar: AppBar(
        title: const Text('Maps & Specifications'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () => setState(() {}),
            tooltip: 'Refresh locations',
          ),
          IconButton(
            icon: const Icon(Icons.filter_list_rounded, color: Colors.white),
            onPressed: _showFilterSheet,
            tooltip: 'Filter',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.map_outlined, size: 20), text: 'Map View'),
            Tab(icon: Icon(Icons.format_list_bulleted, size: 20), text: 'List View'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMapView(),
          _buildListView(),
        ],
      ),
    );
  }

  // ─── MAP VIEW ────────────────────────────────────────────────────
  Widget _buildMapView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchBar(),
          const SizedBox(height: 12),
          _buildFilterChips(),
          const SizedBox(height: 16),
          _buildInteractiveMap(),
          const SizedBox(height: 16),
          _buildStatsRow(),
          const SizedBox(height: 16),
          _buildHODUpdateBanner(),
        ],
      ),
    );
  }

  // ─── LIST VIEW ───────────────────────────────────────────────────
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

  // ─── SEARCH BAR ──────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return TextField(
      onChanged: (v) => setState(() => _searchQuery = v),
      decoration: InputDecoration(
        hintText: 'Search locations by name or ID...',
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

  // ─── FILTER CHIPS ────────────────────────────────────────────────
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
              label: Text(f, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF555555))),
              selectedColor: const Color(0xFF1976D2),
              backgroundColor: Colors.white,
              side: BorderSide(color: isSelected ? const Color(0xFF1976D2) : const Color(0xFFE0E4F0)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              onSelected: (_) => setState(() => _selectedFilter = f),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── INTERACTIVE MAP ─────────────────────────────────────────────
  Widget _buildInteractiveMap() {
    return Container(
      height: 320,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0E4F0)),
        color: const Color(0xFFE8EDF5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Grid pattern background
            CustomPaint(
              size: Size.infinite,
              painter: _MapGridPainter(),
            ),
            // Location markers positioned based on coordinates
            ..._filteredLocations.map((loc) {
              final coords = loc['coordinates'] as Map<String, double>;
              // Convert lat/lng to relative positions on the map
              final x = ((coords['lng']! - 77.5940) * 800).clamp(30.0, 280.0);
              final y = ((12.9725 - coords['lat']!) * 600).clamp(30.0, 250.0);
              final color = loc['color'] as Color;
              final isSelected = _selectedLocationIndex == _filteredLocations.indexOf(loc);
              
              return Positioned(
                left: x,
                top: y,
                child: GestureDetector(
                  onTap: () => setState(() => _selectedLocationIndex = _filteredLocations.indexOf(loc)),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: isSelected ? 36 : 30,
                    height: isSelected ? 36 : 30,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: isSelected ? 3 : 2),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.5),
                          blurRadius: isSelected ? 12 : 6,
                          spreadRadius: isSelected ? 2 : 0,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Icon(loc['icon'] as IconData, size: isSelected ? 18 : 14, color: Colors.white),
                  ),
                ),
              );
            }),
            // Selected location info popup
            if (_selectedLocationIndex != null && _selectedLocationIndex! < _filteredLocations.length)
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: _buildMapPopup(_filteredLocations[_selectedLocationIndex!]),
              ),
            // Map controls overlay
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.map, size: 14, color: Color(0xFF1976D2)),
                    SizedBox(width: 6),
                    Text('Live Site Map', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0A1628))),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF0FA37A), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    const Text('Updated by HOD', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapPopup(Map<String, dynamic> loc) {
    final color = loc['color'] as Color;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                alignment: Alignment.center,
                child: Icon(loc['icon'] as IconData, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(loc['name'] as String, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0A1628))),
                    Text(loc['coordinatesDisplay'] as String, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _selectedLocationIndex = null),
                child: const Icon(Icons.close, size: 18, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('📍 ${loc['specifications']}', style: const TextStyle(fontSize: 12, color: Color(0xFF555555))),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.update, size: 12, color: Colors.grey),
              const SizedBox(width: 4),
              Text('Updated ${loc['lastUpdated']} by ${loc['updatedBy']}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  // ─── STATS ROW ───────────────────────────────────────────────────
  Widget _buildStatsRow() {
    return Row(
      children: [
        _buildStatCard('Total Sites', '${_locations.length}', Icons.location_city_rounded, const Color(0xFF1976D2)),
        const SizedBox(width: 10),
        _buildStatCard('Active', '$_activeCount', Icons.check_circle_rounded, const Color(0xFF0FA37A)),
        const SizedBox(width: 10),
        _buildStatCard('Images', '${_locations.fold<int>(0, (sum, l) => sum + (l['imageCount'] as int))}', Icons.photo_library_rounded, const Color(0xFFE6A817)),
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

  // ─── HOD UPDATE BANNER ───────────────────────────────────────────
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('HOD Managed Locations', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                SizedBox(height: 2),
                Text('Map points and specifications are updated exclusively by HOD. Changes reflect in real-time for all supervisors.',
                  style: TextStyle(fontSize: 11, color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── LOCATION CARD ───────────────────────────────────────────────
  Widget _buildLocationCard(Map<String, dynamic> loc) {
    final color = loc['color'] as Color;
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
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(loc['icon'] as IconData, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(loc['name'] as String, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0A1628))),
                      ),
                      _buildStatusBadge(loc['status'] as String),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(loc['coordinatesDisplay'] as String, style: const TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'monospace')),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.update, size: 10, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('Updated ${loc['lastUpdated']}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      const SizedBox(width: 12),
                      Icon(Icons.photo, size: 10, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('${loc['imageCount']} photos', style: const TextStyle(fontSize: 10, color: Colors.grey)),
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
      child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
          color: isActive ? const Color(0xFF0FA37A) : const Color(0xFFE6A817))),
    );
  }

  // ─── FILTER BOTTOM SHEET ─────────────────────────────────────────
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
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
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

  // ─── LOCATION DETAILS ────────────────────────────────────────────
  void _showLocationDetails(Map<String, dynamic> loc) {
    final color = loc['color'] as Color;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (_, scrollCtrl) {
            return SingleChildScrollView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16)),
                        alignment: Alignment.center,
                        child: Icon(loc['icon'] as IconData, color: color, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(loc['name'] as String, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0A1628))),
                            const SizedBox(height: 4),
                            Text(loc['id'] as String, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                      _buildStatusBadge(loc['status'] as String),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8EDF5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.map_rounded, size: 48, color: color.withValues(alpha: 0.3)),
                        const SizedBox(height: 8),
                        Text(loc['coordinatesDisplay'] as String, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF555555))),
                        const SizedBox(height: 4),
                        Text('${loc['imageCount']} site photos available', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildDetailRow(Icons.description_rounded, 'Description', loc['description'] as String),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.build_rounded, 'Specifications', loc['specifications'] as String),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.person_rounded, 'Updated By', loc['updatedBy'] as String),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.schedule_rounded, 'Last Updated', loc['lastUpdated'] as String),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.directions, size: 18),
                          label: const Text('Navigate'),
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
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.share_rounded, size: 18),
                          label: const Text('Share Location'),
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
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 2),
            SizedBox(
              width: MediaQuery.of(context).size.width - 100,
              child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF0A1628)))),
          ],
        ),
      ],
    );
  }
}

// ─── MAP GRID PAINTER ──────────────────────────────────────────────
class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD0D5E0)
      ..strokeWidth = 0.5;

    for (double x = 0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
