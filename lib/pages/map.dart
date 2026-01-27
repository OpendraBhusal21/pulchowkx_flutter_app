import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:pulchowkx_app/models/chatbot_response.dart';
import 'package:pulchowkx_app/widgets/chat_bot_widget.dart';
import 'package:pulchowkx_app/widgets/custom_app_bar.dart'
    show CustomAppBar, AppPage;
import 'package:pulchowkx_app/widgets/location_details_sheet.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  MapLibreMapController? _mapController;
  bool _isStyleLoaded = false;
  bool _isSatellite = true; // Default to satellite view
  List<Map<String, dynamic>> _locations = [];
  Map<String, Uint8List> _iconCache = {}; // Cache for icon images

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _showSuggestions = false;

  // Pulchowk Campus center and bounds
  static const LatLng _pulchowkCenter = LatLng(
    27.68222689200303,
    85.32121137093469,
  );
  static const double _initialZoom = 17.0;

  // Camera bounds to restrict map view to campus area (tightened to actual campus extent)
  static final LatLngBounds _campusBounds = LatLngBounds(
    southwest: const LatLng(27.6792, 85.3165),
    northeast: const LatLng(27.6848, 85.3262),
  );

  // Satellite style (ArcGIS World Imagery)
  static const String _satelliteStyle = '''
{
  "version": 8,
  "sources": {
    "arcgis-world-imagery": {
      "type": "raster",
      "tiles": [
        "https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}"
      ],
      "tileSize": 256
    }
  },
  "layers": [
    {
      "id": "satellite",
      "type": "raster",
      "source": "arcgis-world-imagery",
      "minzoom": 0,
      "maxzoom": 22
    }
  ]
}
''';

  // Map style (CartoDB Voyager - street map)
  static const String _mapStyle =
      'https://basemaps.cartocdn.com/gl/voyager-gl-style/style.json';

  String get _currentStyle => _isSatellite ? _satelliteStyle : _mapStyle;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// Load GeoJSON data from assets
  Future<void> _loadGeoJSON() async {
    try {
      final String jsonString = await rootBundle.loadString(
        'assets/geojson/pulchowk.json',
      );
      final Map<String, dynamic> geojson = json.decode(jsonString);
      final List<dynamic> features = geojson['features'] ?? [];

      // Extract location data (skip first feature which is boundary mask)
      final locations = <Map<String, dynamic>>[];
      for (int i = 1; i < features.length; i++) {
        final feature = features[i];
        final props = feature['properties'] ?? {};
        final geometry = feature['geometry'] ?? {};

        if (props['description'] != null) {
          // Calculate center for polygons, use coordinates for points
          List<double> coords;
          if (geometry['type'] == 'Point') {
            coords = List<double>.from(geometry['coordinates']);
          } else if (geometry['type'] == 'Polygon') {
            coords = _getPolygonCentroid(geometry['coordinates'][0]);
          } else {
            continue;
          }

          locations.add({
            'title': props['description'] ?? props['title'] ?? 'Unknown',
            'description': props['about'] ?? '',
            'images': props['image'],
            'coordinates': coords,
            'icon': _getIconForDescription(props['description'] ?? ''),
          });
        }
      }

      setState(() {
        _locations = locations;
      });

      // Add campus mask and markers to map
      if (_mapController != null && _isStyleLoaded) {
        await _addCampusMask();
        await _addMarkersToMap();
      }
    } catch (e) {
      debugPrint('Error loading GeoJSON: $e');
    }
  }

  List<double> _getPolygonCentroid(List<dynamic> coordinates) {
    double sumLng = 0;
    double sumLat = 0;
    for (var coord in coordinates) {
      sumLng += coord[0];
      sumLat += coord[1];
    }
    return [sumLng / coordinates.length, sumLat / coordinates.length];
  }

  /// Get icon type based on description (matching web logic)
  String _getIconForDescription(String desc) {
    final d = desc.toLowerCase();
    if (d.contains('bank') || d.contains('atm')) return 'bank';
    if (d.contains('mess') || d.contains('canteen') || d.contains('food')) {
      return 'food';
    }
    if (d.contains('library')) return 'library';
    if (d.contains('department')) return 'department';
    if (d.contains('mandir')) return 'temple';
    if (d.contains('gym') || d.contains('sport')) return 'gym';
    if (d.contains('football')) return 'football';
    if (d.contains('cricket')) return 'cricket';
    if (d.contains('basketball') || d.contains('volleyball')) return 'sports';
    if (d.contains('hostel')) return 'hostel';
    if (d.contains('lab')) return 'lab';
    if (d.contains('helicopter')) return 'helipad';
    if (d.contains('parking')) return 'parking';
    if (d.contains('electrical club')) return 'electrical';
    if (d.contains('music club')) return 'music';
    if (d.contains('center for energy studies')) return 'energy';
    if (d.contains('the helm of ioe pulchowk')) return 'helm';
    if (d.contains('pi chautari') ||
        d.contains('park') ||
        d.contains('garden')) {
      return 'garden';
    }
    if (d.contains('store') || d.contains('bookshop')) return 'store';
    if (d.contains('quarter')) return 'quarter';
    if (d.contains('robotics club')) return 'robotics';
    if (d.contains('clinic') || d.contains('health')) return 'clinic';
    if (d.contains('badminton')) return 'badminton';
    if (d.contains('entrance')) return 'entrance';
    if (d.contains('office') ||
        d.contains('ntbns') ||
        d.contains('seds') ||
        d.contains('cids')) {
      return 'office';
    }
    if (d.contains('building')) return 'building';
    if (d.contains('block') || d.contains('embark')) return 'block';
    if (d.contains('cave')) return 'cave';
    if (d.contains('fountain')) return 'fountain';
    if (d.contains('water vending machine') || d.contains('water')) {
      return 'water';
    }
    if (d.contains('workshop')) return 'workshop';
    if (d.contains('toilet') || d.contains('washroom')) return 'toilet';
    if (d.contains('bridge')) return 'bridge';
    return 'marker';
  }

  /// Get marker color based on icon type
  Color _getMarkerColor(String iconType) {
    switch (iconType) {
      case 'food':
        return Colors.orange;
      case 'library':
        return Colors.purple;
      case 'department':
        return Colors.blue;
      case 'hostel':
        return Colors.teal;
      case 'lab':
        return Colors.indigo;
      case 'office':
        return Colors.blueGrey;
      case 'gym':
      case 'football':
      case 'cricket':
      case 'sports':
      case 'badminton':
        return Colors.green;
      case 'parking':
        return Colors.grey;
      case 'clinic':
        return Colors.red;
      case 'garden':
        return Colors.lightGreen;
      case 'store':
        return Colors.amber;
      case 'bank':
        return Colors.blue;
      case 'temple':
        return Colors.deepOrange;
      case 'water':
      case 'fountain':
        return Colors.cyan;
      case 'toilet':
        return Colors.brown;
      case 'entrance':
        return Colors.deepPurple;
      default:
        return Colors.blue;
    }
  }

  /// Add campus boundary mask as a fill layer
  Future<void> _addCampusMask() async {
    if (_mapController == null) return;

    try {
      // Load full pulchowk.json to get the proper polygon-with-hole mask
      final String jsonString = await rootBundle.loadString(
        'assets/geojson/pulchowk.json',
      );
      final Map<String, dynamic> geojson = json.decode(jsonString);

      // Check if mask source/layer already exists and remove if so
      try {
        await _mapController!.removeLayer('campus-mask');
        await _mapController!.removeSource('campus-mask-source');
      } catch (e) {
        // Ignore if not present
      }

      // Add GeoJSON source with full feature collection
      await _mapController!.addGeoJsonSource('campus-mask-source', geojson);

      // Add fill layer with filter for only the mask feature (has no description)
      // The first feature is a polygon-with-hole: outer ring covers world, inner ring is campus
      await _mapController!.addFillLayer(
        'campus-mask-source',
        'campus-mask',
        FillLayerProperties(
          fillColor: '#FFFFFF',
          fillOpacity: 0.98,
          fillOutlineColor: '#4A5568',
        ),
        filter: [
          'all',
          [
            '==',
            ['\$type'],
            'Polygon',
          ],
          [
            '!',
            ['has', 'description'],
          ],
        ],
      );

      debugPrint('Campus mask added successfully');
    } catch (e) {
      debugPrint('Error adding campus mask: $e');
    }
  }

  /// Load icon images for markers
  Future<void> _loadIconImages() async {
    if (_mapController == null) return;

    // Map of icon types to their network image URLs (matching website)
    final iconUrls = {
      'bank':
          'https://png.pngtree.com/png-clipart/20230805/original/pngtree-bank-location-icon-from-business-bicolor-set-money-business-company-vector-picture-image_9698988.png',
      'food': 'https://cdn-icons-png.freepik.com/512/11167/11167112.png',
      'library': 'https://cdn-icons-png.freepik.com/512/7985/7985904.png',
      'department': 'https://cdn-icons-png.flaticon.com/512/7906/7906888.png',
      'temple': 'https://cdn-icons-png.flaticon.com/512/1183/1183391.png',
      'gym': 'https://cdn-icons-png.flaticon.com/512/11020/11020519.png',
      'football': 'https://cdn-icons-png.freepik.com/512/8893/8893610.png',
      'cricket': 'https://i.postimg.cc/cLb6QFC1/download.png',
      'sports': 'https://i.postimg.cc/mDW05pSw-/volleyball.png',
      'hostel': 'https://cdn-icons-png.flaticon.com/512/7804/7804352.png',
      'lab': 'https://cdn-icons-png.flaticon.com/256/12348/12348567.png',
      'helipad': 'https://cdn-icons-png.flaticon.com/512/5695/5695654.png',
      'parking':
          'https://cdn.iconscout.com/icon/premium/png-256-thumb/parking-place-icon-svg-download-png-897308.png',
      'electrical': 'https://cdn-icons-png.flaticon.com/512/9922/9922144.png',
      'music': 'https://cdn-icons-png.flaticon.com/512/5905/5905923.png',
      'energy': 'https://cdn-icons-png.flaticon.com/512/10053/10053795.png',
      'helm':
          'https://png.pngtree.com/png-vector/20221130/ourmid/pngtree-airport-location-pin-in-light-blue-color-png-image_6485369.png',
      'garden': 'https://cdn-icons-png.flaticon.com/512/15359/15359437.png',
      'store': 'https://cdn-icons-png.flaticon.com/512/3448/3448673.png',
      'quarter': 'https://static.thenounproject.com/png/331579-200.png',
      'robotics': 'https://cdn-icons-png.flaticon.com/512/10681/10681183.png',
      'clinic': 'https://cdn-icons-png.flaticon.com/512/10714/10714002.png',
      'badminton': 'https://static.thenounproject.com/png/198230-200.png',
      'entrance': 'https://i.postimg.cc/jjLDcb6p/image-removebg-preview.png',
      'office': 'https://cdn-icons-png.flaticon.com/512/3846/3846807.png',
      'building': 'https://cdn-icons-png.flaticon.com/512/5193/5193760.png',
      'block': 'https://cdn-icons-png.flaticon.com/512/3311/3311565.png',
      'cave': 'https://cdn-icons-png.flaticon.com/512/210/210567.png',
      'fountain':
          'https://cdn.iconscout.com/icon/free/png-256/free-fountain-icon-svg-download-png-449881.png',
      'water':
          'https://static.vecteezy.com/system/resources/thumbnails/044/570/540/small_2x/single-water-drop-on-transparent-background-free-png.png',
      'workshop': 'https://cdn-icons-png.flaticon.com/512/10747/10747285.png',
      'toilet': 'https://cdn-icons-png.flaticon.com/512/5326/5326954.png',
      'bridge': 'https://cdn-icons-png.flaticon.com/512/2917/2917995.png',
      'marker':
          'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-blue.png',
    };

    debugPrint('Starting to load ${iconUrls.length} icons...');
    int loadedCount = 0;
    int cachedCount = 0;
    int failedCount = 0;

    // Load each icon
    for (var entry in iconUrls.entries) {
      try {
        final iconName = '${entry.key}-icon';

        // Check if already in cache
        if (_iconCache.containsKey(entry.key)) {
          await _mapController!.addImage(iconName, _iconCache[entry.key]!);
          cachedCount++;
          continue;
        }

        // Not in cache, download it
        final response = await http.get(Uri.parse(entry.value));
        if (response.statusCode == 200) {
          final bytes = response.bodyBytes;
          _iconCache[entry.key] = bytes; // Add to cache

          await _mapController!.addImage(iconName, bytes);
          loadedCount++;
        } else {
          debugPrint(
            '⚠️  Failed to load icon ${entry.key}: HTTP ${response.statusCode}',
          );
          failedCount++;
        }
      } catch (e) {
        debugPrint('⚠️  Error loading icon ${entry.key}: $e');
        failedCount++;
      }
    }

    debugPrint(
      '✓ Icons: $loadedCount loaded new, $cachedCount from cache ($failedCount failed)',
    );
  }

  /// Add markers to the map using symbol layer with icons
  Future<void> _addMarkersToMap() async {
    if (_mapController == null || _locations.isEmpty) return;

    try {
      debugPrint('Adding markers for ${_locations.length} locations...');

      // Check if markers already exist (to avoid duplicate source error)
      // If they exist, remove them first before re-adding
      try {
        // Try to remove existing source and layer if they exist
        await _mapController!.removeLayer('markers-layer');
        await _mapController!.removeSource('markers-source');
        debugPrint('Removed existing markers layer and source');
      } catch (e) {
        // If removal fails, it means they don't exist yet (first time)
        debugPrint('No existing markers to remove (first time): $e');
      }

      // Load icon images first
      await _loadIconImages();

      // Create GeoJSON for all markers
      final features = _locations.map((location) {
        final coords = location['coordinates'] as List<double>;
        final iconType = location['icon'] as String;

        return {
          'type': 'Feature',
          'properties': {'icon': '$iconType-icon', 'title': location['title']},
          'geometry': {'type': 'Point', 'coordinates': coords},
        };
      }).toList();

      final geojson = {'type': 'FeatureCollection', 'features': features};

      // Add GeoJSON source for markers
      await _mapController!.addGeoJsonSource('markers-source', geojson);

      // Add symbol layer for markers (above the mask)
      await _mapController!.addSymbolLayer(
        'markers-source',
        'markers-layer',
        SymbolLayerProperties(
          iconImage: ['get', 'icon'], // Use the icon property from each feature
          iconSize: 0.15, // Scale down the icons to 15% of original
          iconAllowOverlap: true,
          iconIgnorePlacement: false,
        ),
      );

      debugPrint('✓ Successfully added ${_locations.length} icon markers');
    } catch (e) {
      debugPrint('✗ Error adding markers: $e');
      debugPrint('Stack trace: ${StackTrace.current}');
    }
  }

  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
  }

  void _onStyleLoaded() {
    setState(() {
      _isStyleLoaded = true;
    });
    _loadGeoJSON();
  }

  void _onMapClick(Point<double> point, LatLng coordinates) {
    // Find nearest location to tap
    const double tapRadius = 0.0003; // ~30 meters
    Map<String, dynamic>? nearestLocation;
    double nearestDistance = double.infinity;

    for (var location in _locations) {
      final coords = location['coordinates'] as List<double>;
      final dx = coords[0] - coordinates.longitude;
      final dy = coords[1] - coordinates.latitude;
      final distance = dx * dx + dy * dy;

      if (distance < nearestDistance && distance < tapRadius * tapRadius) {
        nearestDistance = distance;
        nearestLocation = location;
      }
    }

    if (nearestLocation != null) {
      _showLocationDetails(nearestLocation);
    }
  }

  void _showLocationDetails(Map<String, dynamic> location) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => LocationDetailsSheet(
        title: location['title'] ?? 'Unknown Location',
        description: location['description'],
        images: location['images'],
      ),
    );
  }

  /// Fly to a location on the map
  void _flyToLocation(Map<String, dynamic> location) {
    if (_mapController == null) return;

    final coords = location['coordinates'] as List<double>;
    _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(coords[1], coords[0]), 19),
    );

    // Close search suggestions
    setState(() {
      _showSuggestions = false;
      _searchQuery = location['title'];
      _searchController.text = location['title'];
    });
    _searchFocusNode.unfocus();

    // Show location details after animation
    Future.delayed(const Duration(milliseconds: 500), () {
      _showLocationDetails(location);
    });
  }

  /// Get filtered suggestions based on search query
  List<Map<String, dynamic>> get _filteredSuggestions {
    if (_searchQuery.trim().isEmpty) return [];
    final query = _searchQuery.toLowerCase();
    return _locations
        .where((loc) => (loc['title'] as String).toLowerCase().contains(query))
        .take(8)
        .toList();
  }

  /// Handle locations returned from chatbot
  void _handleChatBotLocations(List<ChatBotLocation> locations, String action) {
    if (locations.isEmpty || _mapController == null) return;

    // Fly to the first location
    final first = locations.first;
    _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(first.lat, first.lng), 19),
    );

    debugPrint('Chatbot action: $action at ${locations.length} locations');
  }

  /// Toggle between map and satellite view
  void _toggleMapType() {
    setState(() {
      _isSatellite = !_isSatellite;
      _isStyleLoaded = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: const CustomAppBar(currentPage: AppPage.map),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // MapLibre Map
          MapLibreMap(
            // key: ValueKey(_isSatellite), // Removed to allow smooth style transition without rebuilding view
            styleString: _currentStyle,
            initialCameraPosition: const CameraPosition(
              target: _pulchowkCenter,
              zoom: _initialZoom,
            ),
            onMapCreated: _onMapCreated,
            onStyleLoadedCallback: _onStyleLoaded,
            onMapClick: _onMapClick,
            myLocationEnabled: true,
            myLocationTrackingMode: MyLocationTrackingMode.none,
            myLocationRenderMode: MyLocationRenderMode.compass,
            trackCameraPosition: true,
            compassEnabled: true,
            cameraTargetBounds: CameraTargetBounds(_campusBounds),
            minMaxZoomPreference: MinMaxZoomPreference(
              16,
              _isSatellite
                  ? 18.45
                  : 20, // Restrict satellite to 18.5, map can go to 20
            ),
            scrollGesturesEnabled: true,
            tiltGesturesEnabled: false,
            rotateGesturesEnabled: true,
            doubleClickZoomEnabled: true,
            attributionButtonMargins: const Point(8, 92),
          ),

          // Loading indicator
          if (!_isStyleLoaded)
            Container(
              color: Colors.white,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.blue),
                    SizedBox(height: 16),
                    Text(
                      'Loading map...',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),

          // Search bar
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Column(
              children: [
                // Search input
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(25),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                        _showSuggestions = value.isNotEmpty;
                      });
                    },
                    onTap: () {
                      setState(() {
                        _showSuggestions = _searchQuery.isNotEmpty;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search classrooms, departments...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.grey),
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                  _showSuggestions = false;
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),

                // Suggestions dropdown
                if (_showSuggestions && _filteredSuggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(25),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: _filteredSuggestions.map((location) {
                          final iconType = location['icon'] as String;
                          final color = _getMarkerColor(iconType);
                          return ListTile(
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: color.withAlpha(50),
                              child: Icon(
                                Icons.location_on,
                                size: 18,
                                color: color,
                              ),
                            ),
                            title: Text(
                              location['title'],
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: const Text(
                              'Pulchowk Campus',
                              style: TextStyle(fontSize: 12),
                            ),
                            onTap: () => _flyToLocation(location),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                // No results message
                if (_showSuggestions &&
                    _searchQuery.isNotEmpty &&
                    _filteredSuggestions.isEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(25),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 40,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'No locations found',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Try a different search term',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Map/Satellite Toggle
          Positioned(
            bottom: 100,
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(230),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(25),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Map button
                  GestureDetector(
                    onTap: _isSatellite ? _toggleMapType : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: !_isSatellite
                            ? Colors.blue.withAlpha(25)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Map',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: !_isSatellite
                              ? Colors.blue[700]
                              : Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Satellite button
                  GestureDetector(
                    onTap: !_isSatellite ? _toggleMapType : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _isSatellite
                            ? Colors.blue.withAlpha(25)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Satellite',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _isSatellite
                              ? Colors.blue[700]
                              : Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Chatbot Widget Overlay
          ChatBotWidget(onLocationsReturned: _handleChatBotLocations),
        ],
      ),
    );
  }
}
