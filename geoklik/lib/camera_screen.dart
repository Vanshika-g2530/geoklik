import 'map_screen.dart';
import 'settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:gal/gal.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'app_gallery_screen.dart';
import 'package:path_provider/path_provider.dart';

class CameraScreen extends StatefulWidget {
  final String initialLatitude;
  final String initialLongitude;

  const CameraScreen({
    super.key,
    this.initialLatitude = '--',
    this.initialLongitude = '--',
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? controller;
  List<CameraDescription>? cameras;
  bool cameraReady = false;
  bool flashOn = false;
  double zoomLevel = 1.0;
  bool showControls = false;

  String lat = '--';
  String lon = '--';
  String address = '';
  String currentTime = '';
  String currentDate = '';

  File? lastPhoto;
  File? lastOriginalPhoto;
  String? lastHash;
  String? lastLocation;
  String? lastTimestamp;

  //  draggable stamp position (FULL WIDTH BAR)
  double stampX = 12;
  double stampY = 400;

  // SETTINGS
  bool stampEnabled = true;
  bool showLocation = true;
  bool showTimestamp = true;
  double fontSize = 14;
  double opacity = 0.6;
  // shutter feedback overlay
  bool showShutterFlash = false;

  @override
  void initState() {
    super.initState();
    lat = widget.initialLatitude;
    lon = widget.initialLongitude;

    setupCamera();
    getLocation();
    startClock();
    loadSettings();
  }

  // LOAD SETTINGS
  void loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      stampEnabled = prefs.getBool('stamp') ?? true;
      showLocation = prefs.getBool('location') ?? true;
      showTimestamp = prefs.getBool('timestamp') ?? true;
      fontSize = prefs.getDouble('font') ?? 14;
      opacity = prefs.getDouble('opacity') ?? 0.6;
    });
  }

  Future<void> setupCamera({CameraDescription? cam}) async {
    await Permission.camera.request();
    cameras = await availableCameras();
    final desc = cam ?? cameras!.first;

    controller = CameraController(
      desc,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await controller!.initialize();
    if (!mounted) return;
    setState(() => cameraReady = true);
  }

  Future<void> flipCamera() async {
    final curr = controller!.description;
    final next = cameras!.firstWhere(
      (c) => c.lensDirection != curr.lensDirection,
    );

    await controller?.dispose();
    setState(() => cameraReady = false);
    await setupCamera(cam: next);
  }

  Future<void> toggleFlash() async {
    setState(() => flashOn = !flashOn);
    // Use auto flash for capture behavior instead of continuous torch
    await controller!.setFlashMode(flashOn ? FlashMode.auto : FlashMode.off);
  }

  Future<void> getLocation() async {
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      lat = pos.latitude.toStringAsFixed(6);
      lon = pos.longitude.toStringAsFixed(6);
    });

    final placemarks = await placemarkFromCoordinates(
      pos.latitude,
      pos.longitude,
    );

    if (placemarks.isNotEmpty) {
      final p = placemarks[0];

      String addr = '';
      if (p.subLocality != null && p.subLocality!.isNotEmpty) {
        addr += '${p.subLocality!}, ';
      }
      if (p.locality != null && p.locality!.isNotEmpty) {
        addr += '${p.locality!}, ';
      }
      if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty) {
        addr += p.administrativeArea!;
      }

      setState(() => address = addr.trim());
    }
  }

  void startClock() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;

      final now = DateTime.now();
      setState(() {
        currentTime = '${now.hour}:${now.minute}:${now.second}';
        currentDate = '${now.day}/${now.month}/${now.year}';
      });

      return true;
    });
  }

  String makeHash(Uint8List bytes) => sha256.convert(bytes).toString();

  Future<void> takePhoto() async {
    // Ensure camera flash mode matches UI before capturing
    await controller!.setFlashMode(flashOn ? FlashMode.auto : FlashMode.off);
    final file = await controller!.takePicture();
    final rawBytes = await file.readAsBytes();
    final hash = makeHash(rawBytes);
    // SAVE ORIGINAL (WITHOUT STAMP) INTERNALLY
    final appDir = await getApplicationDocumentsDirectory();
    final originalPath =
        '${appDir.path}/original_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final originalFile = File(originalPath);
    await originalFile.writeAsBytes(rawBytes);

    await Gal.requestAccess();

    final stamped = await addStamp(
      rawBytes,
      address.isNotEmpty ? address : 'Lat: $lat Lon: $lon',
      '$currentDate  $currentTime',
      hash.substring(0, 16),
    );

    await Gal.putImageBytes(stamped);

    final tempFile = File(file.path.replaceAll('.jpg', '_stamped.jpg'));
    await tempFile.writeAsBytes(stamped);

    if (!mounted) return;
    setState(() {
      lastPhoto = tempFile;
      lastHash = hash;
      lastOriginalPhoto = originalFile;
      lastLocation = address.isNotEmpty ? address : 'Lat: $lat, Lon: $lon';
      lastTimestamp = '$currentDate  $currentTime';
    });
  }

  void _onShutterTap() {
    // show a quick white flash to give capture feedback
    if (!mounted) return;
    setState(() => showShutterFlash = true);

    // hide flash shortly after
    Future.delayed(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      setState(() => showShutterFlash = false);
    });

    // perform capture (don't await here so UI feedback shows immediately)
    takePhoto();
  }

  Future<Uint8List> addStamp(
    Uint8List imgBytes,
    String line1,
    String line2,
    String hashShort,
  ) async {
    final codec = await ui.instantiateImageCodec(imgBytes);
    final frame = await codec.getNextFrame();
    final img = frame.image;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImage(img, Offset.zero, Paint());

    final w = img.width.toDouble();
    final h = img.height.toDouble();

    // Map the draggable UI stamp position (screen coords) to image coords
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;

    final scaleX = w / sw;
    final scaleY = h / sh;

    // UI used a fixed stamp height of ~130 logical pixels and horizontal padding 12
    final uiStampHeight = 130.0;
    final uiStampPadding = 12.0;
    final uiLeftBar = 6.0;
    final uiStampWidth =
        (sw - 24); // same as in build: width = screenWidth - 24

    final imgStampX = (stampX).clamp(0.0, sw) * scaleX;
    final imgStampY = (stampY).clamp(0.0, sh) * scaleY;
    final imgStampW = uiStampWidth * scaleX;
    final imgStampH = uiStampHeight * scaleY;

    canvas.drawRect(
      Rect.fromLTWH(imgStampX, imgStampY, imgStampW, imgStampH),
      Paint()..color = Colors.black.withValues(alpha: opacity),
    );

    canvas.drawRect(
      Rect.fromLTWH(imgStampX, imgStampY, uiLeftBar * scaleX, imgStampH),
      Paint()..color = const Color(0xFFDEB841),
    );

    void putText(
      String txt,
      double x,
      double y,
      double size, {
      Color col = Colors.white,
      double maxW = 0,
    }) {
      final tp = TextPainter(
        text: TextSpan(
          text: txt,
          style: TextStyle(
            color: col,
            fontSize: size,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout(maxWidth: maxW > 0 ? maxW : w - 40);
      tp.paint(canvas, Offset(x, y));
    }

    // Text positions inside the stamp (use small inner padding)
    final innerPadX = imgStampX + (uiStampPadding * scaleX);
    double yCursor = imgStampY + (10 * scaleY);
    final textMaxWidth = imgStampW - (uiStampPadding * 2 * scaleX);

    putText(
      'GeoKlik',
      innerPadX,
      yCursor,
      (fontSize + 6) * scaleX,
      col: const Color(0xFFDEB841),
      maxW: textMaxWidth,
    );
    yCursor += ((fontSize + 6) * scaleX) + (6 * scaleY);

    if (showLocation) {
      putText(
        line1,
        innerPadX,
        yCursor,
        (fontSize + 2) * scaleX,
        maxW: textMaxWidth,
      );
      yCursor += ((fontSize + 2) * scaleX) + (4 * scaleY);
    }

    if (showTimestamp) {
      putText(
        line2,
        innerPadX,
        yCursor,
        (fontSize) * scaleX,
        maxW: textMaxWidth,
      );
      yCursor += ((fontSize) * scaleX) + (6 * scaleY);
    }

    putText(
      'SHA: $hashShort...',
      innerPadX,
      yCursor,
      (fontSize) * scaleX,
      maxW: textMaxWidth,
    );

    final pic = recorder.endRecording();
    final finalImg = await pic.toImage(img.width, img.height);
    final data = await finalImg.toByteData(format: ui.ImageByteFormat.png);

    return data!.buffer.asUint8List();
  }

  void openMap() {
    final lt = double.tryParse(lat);
    final lg = double.tryParse(lon);

    if (lt == null || lg == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapScreen(
          latitude: lt,
          longitude: lg,
          timestamp: '$currentDate  $currentTime',
          hash: lastHash ?? '--',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(
        backgroundColor: const Color(0xFF031926),
        title: Image.asset('assets/logo_white.png', height: 25),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              loadSettings();
            },
          ),
        ],
      ),

      body: Stack(
        children: [
          if (cameraReady && controller != null)
            Positioned.fill(child: CameraPreview(controller!)),

          // shutter flash overlay
          Positioned.fill(
            child: IgnorePointer(
              ignoring: true,
              child: AnimatedOpacity(
                opacity: showShutterFlash ? 0.9 : 0.0,
                duration: const Duration(milliseconds: 120),
                child: Container(color: Colors.white),
              ),
            ),
          ),

          /// DRAGGABLE FULL WIDTH STAMP (SAME UI)
          if (stampEnabled)
            Positioned(
              left: stampX,
              top: stampY,
              child: GestureDetector(
                onPanUpdate: (d) {
                  setState(() {
                    stampX += d.delta.dx;
                    stampY += d.delta.dy;
                  });
                },
                child: Container(
                  width: MediaQuery.of(context).size.width - 24,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: opacity),
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
                          Expanded(
                            child: Text(
                              address.isNotEmpty
                                  ? address
                                  : 'Lat: $lat  Lon: $lon',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: fontSize,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (showLocation)
                        Text(
                          '$lat, $lon',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: fontSize - 2,
                          ),
                        ),
                      const SizedBox(height: 4),
                      if (showTimestamp)
                        Text(
                          '$currentDate  $currentTime',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: fontSize - 2,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

          ///  YEH TU ADD KAREGI (FLOATING CONTROLS)
          Positioned(
            bottom: 120,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (showControls) ...[
                  _controlButton(
                    flashOn ? Icons.flash_on : Icons.flash_off,
                    toggleFlash,
                  ),
                  const SizedBox(height: 10),

                  _controlButton(Icons.flip_camera_android, flipCamera),
                  const SizedBox(height: 10),

                  _controlButton(Icons.zoom_in, () async {
                    double newZoom = zoomLevel == 1.0 ? 2.0 : 1.0;
                    await controller!.setZoomLevel(newZoom);
                    setState(() => zoomLevel = newZoom);
                  }),
                  const SizedBox(height: 10),
                ],

                GestureDetector(
                  onTap: () {
                    setState(() {
                      showControls = !showControls;
                    });
                  },
                  child: Container(
                    width: 55,
                    height: 55,
                    decoration: BoxDecoration(
                      color: Color(0xFF031926),
                      shape: BoxShape.circle,
                      border: Border.all(color: Color(0xFFDEB841), width: 2),
                    ),
                    child: const Icon(Icons.tune, color: Colors.white),
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
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AppGalleryScreen(
                      imageFile: lastPhoto,
                      originalFile: lastOriginalPhoto,
                    ),
                  ),
                );
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.black,
                  border: Border.all(color: Colors.white24),
                ),
                child: lastPhoto != null
                    ? Image.file(lastPhoto!, fit: BoxFit.cover)
                    : const Icon(Icons.photo, color: Colors.white54),
              ),
            ),
            const Icon(Icons.verified, color: Colors.white54),
            GestureDetector(
              onTap: _onShutterTap,
              child: const Icon(Icons.camera, color: Colors.white),
            ),
            GestureDetector(
              onTap: openMap,
              child: const Icon(Icons.map, color: Colors.white54),
            ),
            GestureDetector(
              onTap: () async {
                await Gal.open();
              },
              child: const Icon(Icons.photo_library, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controlButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          shape: BoxShape.circle,
          border: Border.all(color: Color(0xFFDEB841)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
