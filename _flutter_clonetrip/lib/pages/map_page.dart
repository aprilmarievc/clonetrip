import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final Completer<GoogleMapController> _controller = Completer();
  final Set<Marker> _markers = {};
  final List<String> _filters = ['☕', '🍜', '🏛️', '🌊'];
  String? _activeFilter;

  @override
  void initState() {
    super.initState();
    _seedMockMarkers();
  }

  void _seedMockMarkers() {
    final base = const LatLng(35.6762, 139.6503); // Tokyo
    final mock = <(String, LatLng, String)>[
      (
        '☕',
        LatLng(base.latitude + 0.01, base.longitude + 0.01),
        'Blue Bottle Coffee',
      ),
      (
        '🍜',
        LatLng(base.latitude - 0.008, base.longitude + 0.002),
        'Ramen Ichiran',
      ),
      (
        '🏛️',
        LatLng(base.latitude + 0.004, base.longitude - 0.01),
        'Museum of Emerging Science',
      ),
      (
        '🌊',
        LatLng(base.latitude - 0.012, base.longitude - 0.006),
        'Odaiba Seaside',
      ),
    ];
    _markers.clear();
    for (final (emoji, pos, title) in mock) {
      if (_activeFilter != null && _activeFilter != emoji) continue;
      _markers.add(
        Marker(
          markerId: MarkerId('$emoji-$title'),
          position: pos,
          infoWindow: InfoWindow(title: '$emoji $title'),
        ),
      );
    }
  }

  void _toggleFilter(String? emoji) {
    setState(() {
      _activeFilter = _activeFilter == emoji ? null : emoji;
      _seedMockMarkers();
    });
  }

  @override
  Widget build(BuildContext context) {
    const camera = CameraPosition(target: LatLng(35.6762, 139.6503), zoom: 12);
    return Scaffold(
      appBar: AppBar(title: const Text('Map')),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: camera,
            markers: _markers,
            onMapCreated: (c) => _controller.complete(c),
            myLocationButtonEnabled: false,
            compassEnabled: false,
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              color: Theme.of(context).cardColor,
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const Text('Filter:'),
                    const SizedBox(width: 8),
                    Wrap(
                      spacing: 8,
                      children: _filters
                          .map(
                            (e) => FilterChip(
                              label: Text(
                                e,
                                style: const TextStyle(fontSize: 18),
                              ),
                              selected: _activeFilter == e,
                              onSelected: (_) => _toggleFilter(e),
                            ),
                          )
                          .toList(),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.layers_outlined),
                      onPressed: () {},
                      tooltip: 'Layers',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
