import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isCameraReady = false;
  bool _isFrontCamera = false;
  double _zoomLevel = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 8.0;
  bool _flashOn = false;

  // GPS data
  String _latitude = '--';
  String _longitude = '--';
  String _altitude = '--';

  // Time & Date
  String _currentTime = '';
  String _currentDate = '';
  String _currentDay = '';

  File? _lastCapturedImage;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _startLocationUpdates();
    _startTimeUpdates();
  }

  // ─── TIME ───────────────────────────────────────────────
  void _startTimeUpdates() {
    _updateTime();
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      _updateTime();
      return true;
    });
  }

  void _updateTime() {
    final now = DateTime.now();
    final days = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    setState(() {
      _currentTime =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      _currentDate = '${now.day} ${months[now.month - 1]} ${now.year}';
      _currentDay = days[now.weekday % 7];
    });
  }

  // ─── GPS ────────────────────────────────────────────────
  Future<void> _startLocationUpdates() async {
    final status = await Permission.location.request();
    if (!status.isGranted) return;

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

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
        _altitude = pos.altitude.toStringAsFixed(1);
      });
    });
  }

  // ─── CAMERA ─────────────────────────────────────────────
  Future<void> _initCamera({bool useFront = false}) async {
    await Permission.camera.request();
    _cameras = await availableCameras();
    if (_cameras == null || _cameras!.isEmpty) return;

    final desc = useFront
        ? _cameras!.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
            orElse: () => _cameras!.first,
          )
        : _cameras!.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.back,
            orElse: () => _cameras!.first,
          );

    _controller = CameraController(
      desc,
      ResolutionPreset.high,
      enableAudio: false,
    );
    await _controller!.initialize();

    _minZoom = await _controller!.getMinZoomLevel();
    _maxZoom = await _controller!.getMaxZoomLevel();
    _zoomLevel = _minZoom;

    if (!mounted) return;
    setState(() => _isCameraReady = true);
  }

  Future<void> _toggleCamera() async {
    setState(() {
      _isCameraReady = false;
      _isFrontCamera = !_isFrontCamera;
    });
    await _controller?.dispose();
    await _initCamera(useFront: _isFrontCamera);
  }

  Future<void> _toggleFlash() async {
    if (_controller == null) return;
    setState(() => _flashOn = !_flashOn);
    await _controller!.setFlashMode(_flashOn ? FlashMode.torch : FlashMode.off);
  }

  Future<void> _capturePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      final XFile file = await _controller!.takePicture();
      setState(() => _lastCapturedImage = File(file.path));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Photo saved! $_currentDate $_currentTime'),
          backgroundColor: Colors.teal,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint('Capture error: $e');
    }
  }

  Future<void> _setZoom(double value) async {
    if (_controller == null) return;
    setState(() => _zoomLevel = value);
    await _controller!.setZoomLevel(value);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  // ─── BUILD ───────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // ── CAMERA PREVIEW ──────────────────────────
            if (_isCameraReady && _controller != null)
              Positioned.fill(child: CameraPreview(_controller!))
            else
              const Positioned.fill(
                child: Center(
                  child: CircularProgressIndicator(color: Colors.teal),
                ),
              ),

            // ── TOP BAR ─────────────────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // App name
                    const Text(
                      'GeoKlik',
                      style: TextStyle(
                        color: Colors.tealAccent,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    // Flash toggle
                    IconButton(
                      onPressed: _toggleFlash,
                      icon: Icon(
                        _flashOn ? Icons.flash_on : Icons.flash_off,
                        color: _flashOn ? Colors.yellow : Colors.white,
                        size: 26,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── GPS BANNER ──────────────────────────────
            Positioned(
              top: 65,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.62),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.tealAccent.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Colors.tealAccent,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 2,
                        children: [
                          _gpsChip('LAT', _latitude),
                          _gpsChip('LON', _longitude),
                          _gpsChip('ALT', '${_altitude}m'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _currentTime,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                        Text(
                          '$_currentDay, $_currentDate',
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── ZOOM SLIDER ─────────────────────────────
            Positioned(
              right: 12,
              top: MediaQuery.of(context).size.height * 0.25,
              bottom: MediaQuery.of(context).size.height * 0.22,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_zoomLevel.toStringAsFixed(1)}x',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: Slider(
                        value: _zoomLevel,
                        min: _minZoom,
                        max: _maxZoom,
                        activeColor: Colors.tealAccent,
                        inactiveColor: Colors.white30,
                        onChanged: _setZoom,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── BOTTOM CONTROLS ─────────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 30,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.85),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Last captured thumbnail
                    GestureDetector(
                      onTap: () {
                        if (_lastCapturedImage != null) {
                          showDialog(
                            context: context,
                            builder: (_) =>
                                Dialog(child: Image.file(_lastCapturedImage!)),
                          );
                        }
                      },
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white54, width: 1.5),
                          color: Colors.white12,
                        ),
                        child: _lastCapturedImage != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.file(
                                  _lastCapturedImage!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : const Icon(
                                Icons.photo,
                                color: Colors.white38,
                                size: 28,
                              ),
                      ),
                    ),

                    // Shutter button
                    GestureDetector(
                      onTap: _capturePhoto,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          color: Colors.white24,
                        ),
                        child: Center(
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Flip camera
                    IconButton(
                      onPressed: _toggleCamera,
                      icon: const Icon(
                        Icons.flip_camera_android,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── HELPER WIDGET ──────────────────────────────────────
  Widget _gpsChip(String label, String value) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: TextStyle(
              color: Colors.tealAccent.withOpacity(0.8),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
