import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../models/app_models.dart';
import '../providers/app_store.dart';
import '../theme/app_theme.dart';

class MapsScreen extends StatefulWidget {
  const MapsScreen({super.key});

  @override
  State<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends State<MapsScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  // Map related variables
  // Controller retained for future camera moves / fit-bounds.
  // ignore: unused_field
  GoogleMapController? _mapController;
  final Set<Polygon> _polygons = {};
  final Set<Polyline> _polylines = {};
  
  String _selectedMapType = 'normal';

  static const Map<String, MapType> _mapTypeOptions = {
    'normal': MapType.normal,
    'satellite': MapType.satellite,
    'terrain': MapType.terrain,
    'hybrid': MapType.hybrid,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Set<Marker> _buildMarkers(List<MapLocation> locations) {
    return locations.map((point) {
      return Marker(
        markerId: MarkerId(point.id),
        position: LatLng(point.lat, point.lng),
        infoWindow: InfoWindow(
          title: point.title,
          snippet: '${point.category} · ${point.description}',
        ),
        icon: _getMarkerIcon(point.category),
      );
    }).toSet();
  }

  BitmapDescriptor _getMarkerIcon(String category) {
    final hue = switch (category) {
      'warehouse' => BitmapDescriptor.hueOrange,
      'office' => BitmapDescriptor.hueAzure,
      _ => BitmapDescriptor.hueGreen,
    };
    return BitmapDescriptor.defaultMarkerWithHue(hue);
  }

  Future<void> _refreshMap() async {
    final store = context.read<AppStore>();
    await store.syncMapLocations();
    if (!mounted) return;
    setState(() {});
    _showSnackbar('Map refreshed with latest data from HOD', AppTheme.success);
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapLocations = context.watch<AppStore>().mapLocations;
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Maps & Specifications'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshMap,
            tooltip: 'Refresh from HOD',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          indicatorWeight: 2.5,
          tabs: const [
            Tab(text: 'Map View', icon: Icon(Icons.map)),
            Tab(text: 'Specifications', icon: Icon(Icons.description)),
          ],
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildMapTab(mapLocations),
            _buildSpecificationsTab(mapLocations),
          ],
        ),
      ),
    );
  }

  Widget _buildMapTab(List<MapLocation> mapLocations) {
    final initialTarget = mapLocations.isNotEmpty
        ? LatLng(mapLocations.first.lat, mapLocations.first.lng)
        : const LatLng(13.0827, 80.2707);

    return Column(
      children: [
        _buildMapControls(),
        Expanded(
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: initialTarget,
              zoom: 13.0,
            ),
            mapType: _mapTypeOptions[_selectedMapType] ?? MapType.normal,
            markers: _buildMarkers(mapLocations),
            polygons: _polygons,
            polylines: _polylines,
            onMapCreated: (controller) => _mapController = controller,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
            compassEnabled: true,
          ),
        ),
        _buildLegendCard(),
      ],
    );
  }

  Widget _buildMapControls() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedMapType,
                  isExpanded: true,
                  items: _mapTypeOptions.keys.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type[0].toUpperCase() + type.substring(1)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedMapType = value!);
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.infoBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.sync, size: 14, color: AppTheme.info),
                const SizedBox(width: 4),
                Text(
                  'Live Data',
                  style: TextStyle(fontSize: 11, color: AppTheme.info),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        boxShadow: [AppTheme.cardShadow.first],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildLegendItem(Colors.green, 'Active Sites'),
          _buildLegendItem(Colors.red, 'Inactive Sites'),
          _buildLegendItem(Colors.blue, 'Office'),
          _buildLegendItem(Colors.orange, 'Warehouse'),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
        ),
      ],
    );
  }

  Widget _buildSpecificationsTab(List<MapLocation> mapLocations) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildInfoCard(),
          const SizedBox(height: 20),
          _buildSpecificationsList(mapLocations),
          const SizedBox(height: 20),
          _buildUpdateInfo(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.info.withOpacity(0.15), AppTheme.info.withOpacity(0.05)],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          alignment: Alignment.center,
          child: const Text('🗺️', style: TextStyle(fontSize: 28)),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Site Specifications', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              SizedBox(height: 4),
              Text('Location details and specifications updated by HOD', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.infoBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.info.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppTheme.info, size: 22),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('HOD Updates', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                Text('Location points and specifications are managed by HOD and sync automatically', style: TextStyle(fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.success,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('Live', style: TextStyle(fontSize: 10, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecificationsList(List<MapLocation> mapLocations) {
    final siteCount = mapLocations.where((l) => l.category == 'site').length;
    final warehouseCount = mapLocations.where((l) => l.category == 'warehouse').length;
    final specifications = [
      {'title': 'Total Locations', 'value': '${mapLocations.length}', 'icon': Icons.location_on, 'color': AppTheme.success},
      {'title': 'Sites', 'value': '$siteCount', 'icon': Icons.location_city, 'color': AppTheme.info},
      {'title': 'Warehouses', 'value': '$warehouseCount', 'icon': Icons.warehouse, 'color': AppTheme.warning},
      {'title': 'Last Updated', 'value': 'Just now', 'icon': Icons.update, 'color': AppTheme.info},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Key Specifications', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        ...specifications.map((spec) => _buildSpecCard(spec)),
      ],
    );
  }

  Widget _buildSpecCard(Map<String, dynamic> spec) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (spec['color'] as Color).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(spec['icon'], color: spec['color'], size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(spec['title'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                Text(spec['value'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateInfo() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(color: AppTheme.warning, width: 3),
          top: BorderSide(color: AppTheme.border, width: 0.5),
          right: BorderSide(color: AppTheme.border, width: 0.5),
          bottom: BorderSide(color: AppTheme.border, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.sync, size: 18, color: AppTheme.warning),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Specifications are synced with HOD updates. Pull to refresh for latest changes.',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: _refreshMap,
            child: const Text('Sync Now', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }
}
