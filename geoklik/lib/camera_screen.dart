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
  bool _flashOn = false;

  double _zoomLevel = 1.0;

  String _latitude = '--';
  String _longitude = '--';

  String _currentTime = '';
  String _currentDate = '';

  File? _lastCapturedImage;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _startLocationUpdates();
    _startTimeUpdates();
  }

  // CAMERA INIT
  Future<void> _initCamera() async {
    await Permission.camera.request();

    _cameras = await availableCameras();

    _controller = CameraController(
      _cameras!.first,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await _controller!.initialize();

    setState(() {
      _isCameraReady = true;
    });
  }

  // LOCATION
  Future<void> _startLocationUpdates() async {
    final status = await Permission.location.request();

    if (!status.isGranted) return;

    Geolocator.getPositionStream().listen((Position pos) {
      setState(() {
        _latitude = pos.latitude.toStringAsFixed(6);
        _longitude = pos.longitude.toStringAsFixed(6);
      });
    });
  }

  // TIME
  void _startTimeUpdates() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));

      final now = DateTime.now();

      setState(() {
        _currentTime = "${now.hour}:${now.minute}:${now.second}";

        _currentDate = "${now.day}/${now.month}/${now.year}";
      });

      return true;
    });
  }

  // FLASH
  Future<void> _toggleFlash() async {
    if (_controller == null) return;

    if (_flashOn) {
      await _controller!.setFlashMode(FlashMode.off);
    } else {
      await _controller!.setFlashMode(FlashMode.torch);
    }

    setState(() {
      _flashOn = !_flashOn;
    });
  }

  // SWITCH CAMERA
  Future<void> _toggleCamera() async {
    if (_cameras == null) return;

    final current = _controller!.description;

    final newCamera = _cameras!.firstWhere(
      (camera) => camera.lensDirection != current.lensDirection,
    );

    await _controller?.dispose();

    _controller = CameraController(
      newCamera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await _controller!.initialize();

    setState(() {});
  }

  // CAPTURE PHOTO
  Future<void> _capturePhoto() async {
    if (_controller == null) return;

    final XFile file = await _controller!.takePicture();

    setState(() {
      _lastCapturedImage = File(file.path);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Photo captured"),
        backgroundColor: Color(0xFFDEB841),
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
        title: Image.asset("assets/logo_white.png", height: 25),
      ),

      body: Stack(
        children: [
          if (_isCameraReady)
            Positioned.fill(child: CameraPreview(_controller!))
          else
            const Center(
              child: CircularProgressIndicator(color: Color(0xFFDEB841)),
            ),

          // LOCATION OVERLAY
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
                  Text(
                    "Lat: $_latitude  Lon: $_longitude",
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    "$_currentDate  $_currentTime",
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),

          // FLASH + ZOOM + FLIP
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
                    color: Colors.white,
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
                          setState(() {
                            _zoomLevel = 1.0;
                          });
                        },
                        child: Text(
                          "1x",
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
                          setState(() {
                            _zoomLevel = 2.0;
                          });
                        },
                        child: Text(
                          "2x",
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

      // BOTTOM BAR
      bottomNavigationBar: Container(
        height: 65,
        color: const Color(0xFF031926),

        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.center,

          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.black,
              ),
              child: _lastCapturedImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(_lastCapturedImage!, fit: BoxFit.cover),
                    )
                  : const Icon(Icons.photo, color: Colors.white),
            ),

            const Icon(Icons.map, color: Colors.white),

            GestureDetector(
              onTap: _capturePhoto,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                ),
              ),
            ),

            const Icon(Icons.edit, color: Colors.white),

            const Icon(Icons.location_on, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
