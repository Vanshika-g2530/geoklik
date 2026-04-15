import 'map_screen.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:gal/gal.dart';
import 'package:crypto/crypto.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

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

  String lat = '--';
  String lon = '--';
  String address = '';
  String currentTime = '';
  String currentDate = '';

  File? lastPhoto;
  String? lastHash;
  String? lastLocation;
  String? lastTimestamp;

  @override
  void initState() {
    super.initState();
    lat = widget.initialLatitude;
    lon = widget.initialLongitude;
    setupCamera();
    getLocation();
    startClock();
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
    if (cameras == null) return;
    final curr = controller!.description;
    final next = cameras!.firstWhere(
      (c) => c.lensDirection != curr.lensDirection,
    );
    await controller?.dispose();
    setState(() => cameraReady = false);
    await setupCamera(cam: next);
  }

  Future<void> toggleFlash() async {
    if (controller == null) return;
    setState(() => flashOn = !flashOn);
    await controller!.setFlashMode(flashOn ? FlashMode.torch : FlashMode.off);
  }

  Future<void> getLocation() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      setState(() {
        lat = 'Permission denied';
        lon = '';
      });
      await Geolocator.openAppSettings();
      return;
    }

    bool gpsOn = await Geolocator.isLocationServiceEnabled();
    if (!gpsOn) {
      setState(() {
        lat = 'GPS is OFF';
        lon = 'Turn ON GPS';
      });
      await Geolocator.openLocationSettings();
      return;
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        lat = pos.latitude.toStringAsFixed(6);
        lon = pos.longitude.toStringAsFixed(6);
      });
      // get address from lat lon
      getAddress(pos.latitude, pos.longitude);
    } catch (e) {
      print("location error $e");
    }
  }

  Future<void> getAddress(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String addr = '';
        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          addr += place.subLocality! + ', ';
        }
        if (place.locality != null && place.locality!.isNotEmpty) {
          addr += place.locality! + ', ';
        }
        if (place.administrativeArea != null &&
            place.administrativeArea!.isNotEmpty) {
          addr += place.administrativeArea!;
        }
        setState(() => address = addr.trim());
      }
    } catch (e) {
      print("address error $e");
    }
  }

  void startClock() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      final now = DateTime.now();
      setState(() {
        currentTime =
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
        currentDate = '${now.day}/${now.month}/${now.year}';
      });
      return true;
    });
  }

  String makeHash(Uint8List bytes) => sha256.convert(bytes).toString();

  Future<void> takePhoto() async {
    if (controller == null || !cameraReady) return;

    final XFile file = await controller!.takePicture();
    final Uint8List rawBytes = await file.readAsBytes();
    final String hash = makeHash(rawBytes);

    // show export dialog — with stamp or without
    bool? withStamp = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF031926),
        title: const Text(
          'Save Photo',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: const Text(
          'How do you want to save this photo?',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Without Stamp',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'With Stamp',
              style: TextStyle(color: Color(0xFFDEB841)),
            ),
          ),
        ],
      ),
    );

    if (withStamp == null) return; // user dismissed

    await Gal.requestAccess();

    if (withStamp) {
      // stamp and save
      String stampAddr = address.isNotEmpty ? address : 'Lat: $lat  Lon: $lon';
      final Uint8List stamped = await addStamp(
        rawBytes,
        stampAddr,
        '$currentDate  $currentTime',
        hash.substring(0, 16),
      );
      await Gal.putImageBytes(stamped);

      // save temp file for preview
      final tempPath = file.path.replaceAll('.jpg', '_stamped.jpg');
      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(stamped);
      if (!mounted) return;
      setState(() {
        lastPhoto = tempFile;
      });
    } else {
      // save original without stamp
      await Gal.putImageBytes(rawBytes);
      if (!mounted) return;
      setState(() {
        lastPhoto = File(file.path);
      });
    }

    setState(() {
      lastHash = hash;
      lastLocation = address.isNotEmpty ? address : 'Lat: $lat, Lon: $lon';
      lastTimestamp = '$currentDate  $currentTime';
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              withStamp
                  ? 'Photo saved with stamp!'
                  : 'Photo saved without stamp!',
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1B7A4A),
        duration: const Duration(seconds: 2),
      ),
    );
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

    // dark bg at bottom
    canvas.drawRect(
      Rect.fromLTWH(0, h - 130, w, 130),
      Paint()..color = const Color(0xCC000000),
    );
    // yellow bar on left
    canvas.drawRect(
      Rect.fromLTWH(0, h - 130, 6, 130),
      Paint()..color = const Color(0xFFDEB841),
    );

    void putText(
      String txt,
      double x,
      double y,
      double size, {
      Color col = Colors.white,
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
      tp.layout(maxWidth: w - 40);
      tp.paint(canvas, Offset(x, y));
    }

    putText('GeoKlik', 20, h - 125, 26, col: const Color(0xFFDEB841));
    putText(line1, 20, h - 94, 18); // address or lat lon
    putText(line2, 20, h - 68, 16, col: const Color(0xFFCCCCCC));
    putText('SHA: $hashShort...', 20, h - 44, 14, col: const Color(0xFF999999));

    final pic = recorder.endRecording();
    final finalImg = await pic.toImage(img.width, img.height);
    final data = await finalImg.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  void openVerification() {
    if (lastPhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No photo yet!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VerificationScreen(
          image: lastPhoto!,
          hash: lastHash ?? '--',
          location: lastLocation ?? '--',
          timestamp: lastTimestamp ?? '--',
        ),
      ),
    );
  }

  void openMap() {
    final double? lt = double.tryParse(lat);
    final double? lg = double.tryParse(lon);
    if (lt == null || lg == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('GPS coordinates not ready!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapScreen(
          latitude: lt,
          longitude: lg,
          timestamp: '$currentDate  $currentTime',
          hash: lastHash ?? 'No photo yet',
        ),
      ),
    );
  }

  @override
  void dispose() {
    controller?.dispose();
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
            onPressed: openMap,
            icon: const Icon(Icons.map, color: Color(0xFFDEB841)),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (cameraReady && controller != null)
            Positioned.fill(child: CameraPreview(controller!))
          else
            const Center(
              child: CircularProgressIndicator(color: Color(0xFFDEB841)),
            ),

          // gps + address overlay
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
                      Expanded(
                        child: Text(
                          address.isNotEmpty ? address : 'Lat: $lat  Lon: $lon',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '$lat, $lon',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                      ),
                    ),
                  ],
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
                        '$currentDate  $currentTime',
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

          // flash zoom flip
          Positioned(
            bottom: 110,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: toggleFlash,
                  icon: Icon(
                    flashOn ? Icons.flash_on : Icons.flash_off,
                    color: flashOn ? const Color(0xFFDEB841) : Colors.white,
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
                          await controller!.setZoomLevel(1.0);
                          setState(() => zoomLevel = 1.0);
                        },
                        child: Text(
                          '1x',
                          style: TextStyle(
                            color: zoomLevel == 1.0
                                ? const Color(0xFFDEB841)
                                : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () async {
                          await controller!.setZoomLevel(2.0);
                          setState(() => zoomLevel = 2.0);
                        },
                        child: Text(
                          '2x',
                          style: TextStyle(
                            color: zoomLevel == 2.0
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
                  onPressed: flipCamera,
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
            // last photo thumbnail
            GestureDetector(
              onTap: openVerification,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.black,
                  border: Border.all(color: Colors.white24),
                ),
                child: lastPhoto != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: Image.file(lastPhoto!, fit: BoxFit.cover),
                      )
                    : const Icon(Icons.photo, color: Colors.white54, size: 22),
              ),
            ),

            GestureDetector(
              onTap: openVerification,
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

            // shutter button
            GestureDetector(
              onTap: takePhoto,
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
              onTap: openMap,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.map, color: Colors.white54, size: 22),
                  SizedBox(height: 2),
                  Text(
                    'Map',
                    style: TextStyle(color: Colors.white54, fontSize: 10),
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

            infoTile(Icons.location_on, 'Location', location),
            infoTile(Icons.access_time, 'Timestamp', timestamp),
            infoTile(Icons.lock, 'SHA-256 Hash', hash, mono: true),
          ],
        ),
      ),
    );
  }

  Widget infoTile(
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
