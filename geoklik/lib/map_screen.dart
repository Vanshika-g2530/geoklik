import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapScreen extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String timestamp;
  final String hash;

  const MapScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.hash,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  late LatLng _photoLocation;

  @override
  void initState() {
    super.initState();
    _photoLocation = LatLng(widget.latitude, widget.longitude);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF031926),
      appBar: AppBar(
        backgroundColor: const Color(0xFF031926),
        title: const Text(
          'Photo Location',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // MAP VIEW
          Expanded(
            flex: 3,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _photoLocation,
                zoom: 16,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
                _mapController?.animateCamera(
                  CameraUpdate.newLatLngZoom(_photoLocation, 16),
                );
              },
              markers: {
                Marker(
                  markerId: const MarkerId('photo_location'),
                  position: _photoLocation,
                  infoWindow: InfoWindow(
                    title: 'GeoKlik Photo',
                    snippet: widget.timestamp,
                  ),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueYellow,
                  ),
                ),
              },
              mapType: MapType.normal,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: true,
            ),
          ),

          // INFO CARDS
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // coordinates card
                  _infoCard(
                    Icons.location_on,
                    'Coordinates',
                    'Lat: ${widget.latitude.toStringAsFixed(6)}\nLon: ${widget.longitude.toStringAsFixed(6)}',
                  ),
                  const SizedBox(height: 10),
                  // timestamp card
                  _infoCard(Icons.access_time, 'Captured At', widget.timestamp),
                  const SizedBox(height: 10),
                  // hash card
                  _infoCard(
                    Icons.lock,
                    'SHA-256 Hash',
                    widget.hash,
                    mono: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(
    IconData icon,
    String label,
    String value, {
    bool mono = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFFDEB841), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontFamily: mono ? 'monospace' : null,
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
