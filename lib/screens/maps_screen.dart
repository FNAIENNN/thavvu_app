import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/shared_widgets.dart';

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
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polygon> _polygons = {};
  final Set<Polyline> _polylines = {};
  
  String _selectedMapType = 'Standard';
  bool _isLoading = true;
  
  // Mock location points from HOD
  final List<Map<String, dynamic>> _locationPoints = [
    {
      'id': 'LOC-001',
      'name': 'Site A - Main Office',
      'latitude': 28.6139,
      'longitude': 77.2090,
      'type': 'office',
      'status': 'active',
      'lastUpdated': '2024-05-13',
    },
    {
      'id': 'LOC-002',
      'name': 'Site B - Warehouse',
      'latitude': 28.6120,
      'longitude': 77.2105,
      'type': 'warehouse',
      'status': 'active',
      'lastUpdated': '2024-05-13',
    },
    {
      'id': 'LOC-003',
      'name': 'Site C - Field Office',
      'latitude': 28.6145,
      'longitude': 77.2080,
      'type': 'field',
      'status': 'active',
      'lastUpdated': '2024-05-12',
    },
    {
      'id': 'LOC-004',
      'name': 'Equipment Depot',
      'latitude': 28.6155,
      'longitude': 77.2110,
      'type': 'depot',
      'status': 'inactive',
      'lastUpdated': '2024-05-10',
    },
  ];

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
    
    _initializeMarkers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _initializeMarkers() {
    for (var point in _locationPoints) {
      final marker = Marker(
        markerId: MarkerId(point['id']),
        position: LatLng(point['latitude'], point['longitude']),
        infoWindow: InfoWindow(
          title: point['name'],
          snippet: 'Type: ${point['type']}\nStatus: ${point['status']}\nUpdated: ${point['lastUpdated']}',
        ),
        icon: _getMarkerIcon(point['type'], point['status']),
      );
      _markers.add(marker);
    }
    setState(() => _isLoading = false);
  }

  BitmapDescriptor _getMarkerIcon(String type, String status) {
    return BitmapDescriptor.defaultMarkerWithHue(
      status == 'active' ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
    );
  }

  void _refreshMap() {
    setState(() {
      _markers.clear();
      _initializeMarkers();
    });
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
            _buildMapTab(),
            _buildSpecificationsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildMapTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        _buildMapControls(),
        Expanded(
          child: GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(28.6139, 77.2090),
              zoom: 14.0,
            ),
            markers: _markers,
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
                  items: ['Standard', 'Satellite', 'Terrain'].map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type),
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

  Widget _buildSpecificationsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildInfoCard(),
          const SizedBox(height: 20),
          _buildSpecificationsList(),
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

  Widget _buildSpecificationsList() {
    final specifications = [
      {'title': 'Total Active Sites', 'value': '3', 'icon': Icons.location_on, 'color': AppTheme.success},
      {'title': 'Total Inactive Sites', 'value': '1', 'icon': Icons.location_off, 'color': AppTheme.danger},
      {'title': 'Last Updated', 'value': '2024-05-13 09:30 AM', 'icon': Icons.update, 'color': AppTheme.info},
      {'title': 'Total Area Covered', 'value': '245 sq km', 'icon': Icons.area_chart, 'color': AppTheme.warning},
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
