import 'map_screen.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:gal/gal.dart';
import 'package:crypto/crypto.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

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
    final status = await Permission.location.request();
    if (!status.isGranted) {
      setState(() {
        _latitude = 'Permission denied';
        _longitude = '';
      });
      return;
    }
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        _latitude = 'GPS is OFF';
        _longitude = 'Enable in settings';
      });
      await Geolocator.openLocationSettings();
      return;
    }
    try {
      final Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() {
        _latitude = pos.latitude.toStringAsFixed(6);
        _longitude = pos.longitude.toStringAsFixed(6);
      });
    } catch (e) {
      debugPrint('Location error: $e');
    }
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 1,
      ),
    ).listen((Position pos) {
      if (!mounted) return;
      setState(() {
        _latitude = pos.latitude.toStringAsFixed(6);
        _longitude = pos.longitude.toStringAsFixed(6);
      });
    });
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

  void _showManualLocationDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF031926),
        title: const Text(
          'Manual Location',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'e.g. New Delhi, India',
            hintStyle: TextStyle(color: Colors.grey[500]),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFDEB841)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFDEB841)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  _latitude = controller.text;
                  _longitude = 'Manual';
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text(
              'Set',
              style: TextStyle(color: Color(0xFFDEB841)),
            ),
          ),
        ],
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
    if (_latitude == '--' ||
        _latitude == 'GPS is OFF' ||
        _latitude == 'Permission denied') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('GPS not ready yet!')));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapScreen(
          latitude: double.parse(_latitude),
          longitude: double.parse(_longitude),
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
            // thumbnail
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
            // verify
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
            // shutter
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
            // manual
            GestureDetector(
              onTap: _showManualLocationDialog,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.edit_location, color: Colors.white54, size: 22),
                  SizedBox(height: 2),
                  Text(
                    'Manual',
                    style: TextStyle(color: Colors.white54, fontSize: 10),
                  ),
                ],
              ),
            ),
            // gallery
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
