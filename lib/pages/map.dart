import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:pulchowkx_app/models/chatbot_response.dart';
import 'package:pulchowkx_app/widgets/chat_bot_widget.dart';
import 'package:pulchowkx_app/widgets/custom_app_bar.dart'
    show CustomAppBar, AppPage;

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  MapLibreMapController? _controller;
  String? _styleString;

  @override
  void initState() {
    super.initState();
    _loadStyle();
  }

  Future<void> _loadStyle() async {
    try {
      final style = await rootBundle.loadString(
        'assets/style/pulchowk_style.json',
      );
      setState(() {
        _styleString = style;
      });
    } catch (e) {
      debugPrint("Failed to load map style: $e");
    }
  }

  Future<void> _onStyleLoaded() async {
    if (_controller == null) return;

    try {
      final pulchowkData = await rootBundle.loadString(
        'assets/geojson/pulchowk.json',
      );
      final maskData = await rootBundle.loadString(
        'assets/geojson/pulchowk_mask.json',
      );

      await _controller!.addSource(
        "pulchowk",
        GeojsonSourceProperties(data: pulchowkData),
      );

      await _controller!.addSource(
        "mask",
        GeojsonSourceProperties(data: maskData),
      );

      await _controller!.addFillLayer(
        "mask",
        "mask-layer",
        const FillLayerProperties(fillColor: "#000000", fillOpacity: 0.6),
      );

      await _controller!.addFillLayer(
        "pulchowk",
        "pulchowk-fill",
        const FillLayerProperties(fillColor: "#4CAF50", fillOpacity: 0.25),
      );

      await _controller!.addLineLayer(
        "pulchowk",
        "pulchowk-outline",
        const LineLayerProperties(lineColor: "#2E7D32", lineWidth: 3.0),
      );
    } catch (e) {
      debugPrint("Error adding sources/layers: $e");
    }
  }

  /// Handle locations returned from the chatbot
  void _handleChatBotLocations(List<ChatBotLocation> locations, String action) {
    if (_controller == null || locations.isEmpty) return;

    if (action == 'show_route' && locations.length >= 2) {
      // For route: find start and end, fit bounds to show both
      final startLoc = locations.firstWhere(
        (l) => l.role == 'start',
        orElse: () => locations.first,
      );
      final endLoc = locations.firstWhere(
        (l) => l.role == 'end',
        orElse: () => locations.last,
      );

      // Fit map to show both points with padding
      final bounds = LatLngBounds(
        southwest: LatLng(
          startLoc.lat < endLoc.lat ? startLoc.lat : endLoc.lat,
          startLoc.lng < endLoc.lng ? startLoc.lng : endLoc.lng,
        ),
        northeast: LatLng(
          startLoc.lat > endLoc.lat ? startLoc.lat : endLoc.lat,
          startLoc.lng > endLoc.lng ? startLoc.lng : endLoc.lng,
        ),
      );

      _controller!.animateCamera(
        CameraUpdate.newLatLngBounds(
          bounds,
          left: 50,
          right: 50,
          top: 100,
          bottom: 100,
        ),
      );
    } else {
      // For single location or multiple locations, fly to the first one
      final location = locations.first;
      _controller!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(location.lat, location.lng), zoom: 19),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_styleString == null) {
      return Scaffold(
        appBar: const CustomAppBar(currentPage: AppPage.map),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: const CustomAppBar(currentPage: AppPage.map),
      body: Stack(
        children: [
          // Map
          MapLibreMap(
            styleString: _styleString!,
            initialCameraPosition: const CameraPosition(
              target: LatLng(27.6816, 85.3180),
              zoom: 17.5,
            ),
            minMaxZoomPreference: const MinMaxZoomPreference(16, 19.5),
            onMapCreated: (controller) {
              _controller = controller;
            },
            onStyleLoadedCallback: _onStyleLoaded,
          ),

          // Chatbot Widget Overlay
          ChatBotWidget(onLocationsReturned: _handleChatBotLocations),
        ],
      ),
    );
  }
}
