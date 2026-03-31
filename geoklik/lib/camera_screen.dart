import 'map_screen.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:gal/gal.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:convert';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isCameraReady = false;
  bool _flashOn = false;
  double _zoomLevel = 1.0;
  String _latitude = '--';
  String _longitude = '--';
  String _currentTime = '';
  String _currentDate = '';
  File? _lastCapturedImage;
  String? _lastHash;
  String? _lastLocation;
  String? _lastTimestamp;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _startLocationUpdates();
    _startTimeUpdates();
  }

  Future<void> _initCamera({CameraDescription? cam}) async {
    await Permission.camera.request();
    _cameras = await availableCameras();
    final desc = cam ?? _cameras!.first;
    _controller = CameraController(
      desc,
      ResolutionPreset.high,
      enableAudio: false,
    );
    await _controller!.initialize();
    if (!mounted) return;
    setState(() => _isCameraReady = true);
  }

  Future<void> _toggleCamera() async {
    if (_cameras == null) return;
    final current = _controller!.description;
    final next = _cameras!.firstWhere(
      (c) => c.lensDirection != current.lensDirection,
    );
    await _controller?.dispose();
    setState(() => _isCameraReady = false);
    await _initCamera(cam: next);
  }

  Future<void> _toggleFlash() async {
    if (_controller == null) return;
    setState(() => _flashOn = !_flashOn);
    await _controller!.setFlashMode(_flashOn ? FlashMode.torch : FlashMode.off);
  }

  Future<void> _startLocationUpdates() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      setState(() {
        _latitude = 'Permission denied';
        _longitude = '';
      });
      await Geolocator.openAppSettings();
      return;
    }
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _latitude = 'GPS is OFF';
        _longitude = 'Turn ON GPS';
      });
      await Geolocator.openLocationSettings();
      return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _latitude = pos.latitude.toStringAsFixed(6);
        _longitude = pos.longitude.toStringAsFixed(6);
      });
    } catch (e) {
      debugPrint('Location error: $e');
    }
  }

  void _startTimeUpdates() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      final now = DateTime.now();
      setState(() {
        _currentTime =
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
        _currentDate = '${now.day}/${now.month}/${now.year}';
      });
      return true;
    });
  }

  String _generateHash(Uint8List bytes) => sha256.convert(bytes).toString();

  Future<void> _capturePhoto() async {
    if (_controller == null || !_isCameraReady) return;
    final XFile file = await _controller!.takePicture();
    final Uint8List rawBytes = await file.readAsBytes();
    final String hash = _generateHash(rawBytes);
    final Uint8List stampedBytes = await _stampImage(
      rawBytes,
      'Lat: $_latitude  Lon: $_longitude',
      '$_currentDate  $_currentTime',
      hash.substring(0, 16),
    );
    await Gal.requestAccess();
    await Gal.putImageBytes(stampedBytes);
    final tempPath = file.path.replaceAll('.jpg', '_stamped.jpg');
    final tempFile = File(tempPath);
    await tempFile.writeAsBytes(stampedBytes);
    if (!mounted) return;
    setState(() {
      _lastCapturedImage = tempFile;
      _lastHash = hash;
      _lastLocation = 'Lat: $_latitude, Lon: $_longitude';
      _lastTimestamp = '$_currentDate  $_currentTime';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Photo saved to gallery!'),
          ],
        ),
        backgroundColor: const Color(0xFF1B7A4A),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<Uint8List> _stampImage(
    Uint8List imageBytes,
    String line1,
    String line2,
    String hashPreview,
  ) async {
    final codec = await ui.instantiateImageCodec(imageBytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImage(image, Offset.zero, Paint());
    final w = image.width.toDouble();
    final h = image.height.toDouble();
    canvas.drawRect(
      Rect.fromLTWH(0, h - 110, w, 110),
      Paint()..color = const Color(0xCC000000),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, h - 110, 6, 110),
      Paint()..color = const Color(0xFFDEB841),
    );
    void drawText(
      String text,
      double x,
      double y,
      double fontSize, {
      Color color = Colors.white,
    }) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(x, y));
    }

    drawText('GeoKlik', 20, h - 105, 28, color: const Color(0xFFDEB841));
    drawText(line1, 20, h - 72, 22);
    drawText(line2, 20, h - 44, 20, color: const Color(0xFFCCCCCC));
    drawText(
      'SHA: $hashPreview...',
      20,
      h - 20,
      16,
      color: const Color(0xFF999999),
    );
    final picture = recorder.endRecording();
    final finalImage = await picture.toImage(image.width, image.height);
    final byteData = await finalImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    return byteData!.buffer.asUint8List();
  }

  // ── SEARCH LOCATION via OpenStreetMap ───────────────────
  Future<List<Map>> _searchLocation(String query) async {
    if (query.length < 3) return [];
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5&addressdetails=1',
      );
      final response = await http.get(
        uri,
        headers: {'User-Agent': 'GeoKlik/1.0'},
      );
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      debugPrint('Search error: $e');
    }
    return [];
  }

  // ── MANUAL LOCATION with DROPDOWN ───────────────────────
  void _showManualLocationDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF031926),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // title
              Row(
                children: [
                  const Icon(
                    Icons.location_searching,
                    color: Color(0xFFDEB841),
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Search Location',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white54,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // typeahead search field
              TypeAheadField<Map>(
                builder: (ctx, controller, focusNode) {
                  return TextField(
                    controller: textController,
                    focusNode: focusNode,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Type city, area or address...',
                      hintStyle: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xFFDEB841),
                        size: 20,
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.07),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFDEB841)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: Color(0xFFDEB841),
                          width: 1.5,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  );
                },
                suggestionsCallback: (pattern) async {
                  return await _searchLocation(pattern);
                },
                decorationBuilder: (ctx, child) => Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF042535),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: child,
                ),
                itemBuilder: (context, suggestion) {
                  final name = suggestion['display_name'] ?? '';
                  final type = suggestion['type'] ?? '';
                  return Container(
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.white10)),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDEB841).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: Color(0xFFDEB841),
                          size: 16,
                        ),
                      ),
                      title: Text(
                        name.length > 60 ? name.substring(0, 60) + '...' : name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                      ),
                      subtitle: type.isNotEmpty
                          ? Text(
                              type,
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 11,
                              ),
                            )
                          : null,
                    ),
                  );
                },
                onSelected: (suggestion) {
                  final lat = suggestion['lat']?.toString() ?? '';
                  final lon = suggestion['lon']?.toString() ?? '';
                  final name = suggestion['display_name']?.toString() ?? '';
                  if (lat.isNotEmpty && lon.isNotEmpty) {
                    setState(() {
                      _latitude = double.parse(lat).toStringAsFixed(6);
                      _longitude = double.parse(lon).toStringAsFixed(6);
                    });
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Location set: ${name.length > 35 ? '${name.substring(0, 35)}...' : name}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: const Color(0xFF1B7A4A),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                },
                emptyBuilder: (context) => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.search_off, color: Colors.white38, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'No locations found',
                        style: TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                loadingBuilder: (context) => const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFDEB841),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Searching...',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),
              Text(
                'Powered by OpenStreetMap',
                style: TextStyle(color: Colors.grey[600], fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openVerification() {
    if (_lastCapturedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No photo captured yet!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VerificationScreen(
          image: _lastCapturedImage!,
          hash: _lastHash ?? '--',
          location: _lastLocation ?? '--',
          timestamp: _lastTimestamp ?? '--',
        ),
      ),
    );
  }

  void _openMap() {
    final double? lat = double.tryParse(_latitude);
    final double? lon = double.tryParse(_longitude);
    if (lat == null || lon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Valid GPS coordinates needed to open map!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapScreen(
          latitude: lat,
          longitude: lon,
          timestamp: '$_currentDate  $_currentTime',
          hash: _lastHash ?? 'No photo yet',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF031926),
        elevation: 0,
        title: Image.asset('assets/logo_white.png', height: 25),
        actions: [
          IconButton(
            onPressed: _openMap,
            icon: const Icon(Icons.map, color: Color(0xFFDEB841)),
            tooltip: 'View on Map',
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_isCameraReady && _controller != null)
            Positioned.fill(child: CameraPreview(_controller!))
          else
            const Center(
              child: CircularProgressIndicator(color: Color(0xFFDEB841)),
            ),

          Positioned(
            bottom: 160,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFDEB841)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Color(0xFFDEB841),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Lat: $_latitude  Lon: $_longitude',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        color: Colors.white54,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$_currentDate  $_currentTime',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            bottom: 110,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _toggleFlash,
                  icon: Icon(
                    _flashOn ? Icons.flash_on : Icons.flash_off,
                    color: _flashOn ? const Color(0xFFDEB841) : Colors.white,
                  ),
                ),
                const SizedBox(width: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () async {
                          await _controller!.setZoomLevel(1.0);
                          setState(() => _zoomLevel = 1.0);
                        },
                        child: Text(
                          '1x',
                          style: TextStyle(
                            color: _zoomLevel == 1.0
                                ? const Color(0xFFDEB841)
                                : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () async {
                          await _controller!.setZoomLevel(2.0);
                          setState(() => _zoomLevel = 2.0);
                        },
                        child: Text(
                          '2x',
                          style: TextStyle(
                            color: _zoomLevel == 2.0
                                ? const Color(0xFFDEB841)
                                : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                IconButton(
                  onPressed: _toggleCamera,
                  icon: const Icon(
                    Icons.flip_camera_android,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      bottomNavigationBar: Container(
        height: 100,
        color: const Color(0xFF031926),
        padding: const EdgeInsets.only(bottom: 30),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: _openVerification,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.black,
                  border: Border.all(color: Colors.white24),
                ),
                child: _lastCapturedImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: Image.file(
                          _lastCapturedImage!,
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Icon(Icons.photo, color: Colors.white54, size: 22),
              ),
            ),
            GestureDetector(
              onTap: _openVerification,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.verified_user, color: Colors.white54, size: 22),
                  SizedBox(height: 2),
                  Text(
                    'Verify',
                    style: TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: _capturePhoto,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFDEB841), width: 3),
                ),
                child: Center(
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            GestureDetector(
              onTap: _showManualLocationDialog,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.location_searching,
                    color: Color(0xFFDEB841),
                    size: 22,
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Search',
                    style: TextStyle(color: Color(0xFFDEB841), fontSize: 10),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () async {
                await Gal.open();
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.photo_library, color: Colors.white54, size: 22),
                  SizedBox(height: 2),
                  Text(
                    'Gallery',
                    style: TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── VERIFICATION SCREEN ─────────────────────────────────────
class VerificationScreen extends StatelessWidget {
  final File image;
  final String hash;
  final String location;
  final String timestamp;

  const VerificationScreen({
    super.key,
    required this.image,
    required this.hash,
    required this.location,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF031926),
      appBar: AppBar(
        backgroundColor: const Color(0xFF031926),
        title: const Text(
          'Verification',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                image,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1B7A4A).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1B7A4A)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.check_circle, color: Color(0xFF1B7A4A), size: 28),
                  SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Image Authenticated',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Not tampered',
                        style: TextStyle(
                          color: Color(0xFF1B7A4A),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _infoTile(Icons.location_on, 'Location', location),
            _infoTile(Icons.access_time, 'Timestamp', timestamp),
            _infoTile(Icons.lock, 'SHA-256 Hash', hash, mono: true),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(
    IconData icon,
    String label,
    String value, {
    bool mono = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
