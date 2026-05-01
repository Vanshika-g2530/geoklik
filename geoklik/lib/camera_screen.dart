import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
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
import 'api_constants.dart';

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
  // prevent double-tap race condition
  bool _isCapturing = false;

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
    // Guard against double-tap
    if (_isCapturing) return;
    setState(() => _isCapturing = true);

    try {
      // ── STEP 1: Take the picture ──────────────────────────────────────────
      await controller!.setFlashMode(flashOn ? FlashMode.auto : FlashMode.off);
      final file = await controller!.takePicture();
      final rawBytes = await file.readAsBytes();
      final hash = makeHash(rawBytes);

      // ── STEP 2: Save original (no stamp) to app documents ────────────────
      final appDir = await getApplicationDocumentsDirectory();
      final originalFile = File(
        '${appDir.path}/original_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await originalFile.writeAsBytes(rawBytes);

      // ── STEP 3: Request gallery permission ───────────────────────────────
      final hasAccess = await Gal.requestAccess();
      if (!hasAccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gallery permission denied — image not saved'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // ── STEP 4: Add stamp and save to gallery ─────────────────────────────
      final stamped = await addStamp(
        rawBytes,
        address.isNotEmpty ? address : 'Lat: $lat Lon: $lon',
        '$currentDate  $currentTime',
        hash.substring(0, 16),
      );

      // Save stamped PNG to temp file first, then pass path to Gal
      // (Gal.putImageBytes can throw UNEXPECTED on many Android devices;
      //  path-based Gal.putImage is far more reliable)
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        '${tempDir.path}/geoklik_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await tempFile.writeAsBytes(stamped);

      await Gal.putImage(tempFile.path);

      if (!mounted) return;
      setState(() {
        lastPhoto = tempFile;
        lastHash = hash;
        // Use tempFile (stamped) as the verification source — matches what's in gallery
        lastOriginalPhoto = tempFile;
        lastLocation = address.isNotEmpty ? address : 'Lat: $lat, Lon: $lon';
        lastTimestamp = '$currentDate  $currentTime';
      });

      // Show success immediately — camera is ready for next shot
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('📸 Saved! Uploading to blockchain...'),
            backgroundColor: const Color(0xFF031926),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'View',
              textColor: const Color(0xFFDEB841),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AppGalleryScreen(
                      imageFile: tempFile,
                      originalFile: originalFile,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }

      // ── STEP 5: Upload STAMPED image to blockchain (non-blocking) ─────────
      // Compute hash from in-memory bytes
      final stampedHash = makeHash(stamped);
      _uploadToBlockchain(tempFile, stampedHash);

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Capture error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Always release the lock so camera is usable again
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  /// Uploads stamped image to backend + blockchain. Runs in background.
  Future<void> _uploadToBlockchain(File stampedFile, String stampedHash) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConstants.baseUrl}/upload-proof'),
      );
      request.fields['latitude'] = lat;
      request.fields['longitude'] = lon;
      request.fields['timestamp'] = '$currentDate $currentTime';
      // Send Flutter-computed hash — backend stores this (not its own file hash)
      request.fields['imageHash'] = stampedHash;
      request.files.add(
        await http.MultipartFile.fromPath('image', stampedFile.path),
      );

      // 10-second timeout — backend unreachable won't freeze anything
      final response = await request.send().timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Backend timeout'),
      );

      if (mounted) {
        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Secured on Blockchain!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Saved locally, blockchain upload failed'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      // Blockchain upload failed — photo is still saved locally, just not on chain
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📵 Saved locally. Backend unreachable — check WiFi/firewall'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _onShutterTap() {
    // show a quick white flash to give capture feedback
    if (!mounted) return;
    setState(() => showShutterFlash = true);

    Future.delayed(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      setState(() => showShutterFlash = false);
    });

    // Await so errors in takePhoto() are properly surfaced
    takePhoto().catchError((e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Capture error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }

  // ===== VERIFY FROM FILE (avoids gallery re-encoding) =====
  Future<void> verifyFromGallery() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any, // Use 'any' to allow picking from raw file system rather than media picker
      allowMultiple: false,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;
    await _runVerification(path, fromGallery: true);
  }

  // ===== VERIFY LAST CAPTURED (byte-perfect, no gallery roundtrip) =====
  Future<void> verifyLastCaptured() async {
    if (lastOriginalPhoto == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No captured photo in this session yet'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    await _runVerification(lastOriginalPhoto!.path, fromGallery: false);
  }

  // ===== CORE VERIFICATION LOGIC =====
  Future<void> _runVerification(String filePath, {required bool fromGallery}) async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔍 Verifying on blockchain...'),
          backgroundColor: Color(0xFF031926),
          duration: Duration(seconds: 30),
        ),
      );
    }

    try {
      // Read bytes and compute hash
      final pickedBytes = await File(filePath).readAsBytes();
      final pickedHash = makeHash(pickedBytes);

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConstants.baseUrl}/verify-proof'),
      );
      // Send Flutter-computed hash — backend uses this for lookup
      request.fields['imageHash'] = pickedHash;
      
      // We no longer need to upload the file for verification since we send the hash directly.
      // This also prevents Android from creating temporary copies in the gallery.

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw Exception('Timed out — check backend & network'),
      );
      final body = await streamedResponse.stream.bytesToString();
      final data = jsonDecode(body);

      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();

      final bool verified = data['verified'] == true;
      final blockchainData = data['blockchainData'];
      final String? returnedHash = data['hash'];

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: const Color(0xFF031926),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                verified ? Icons.verified : Icons.cancel,
                color: verified ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Text(
                verified ? 'Verified ✅' : 'Not Found ❌',
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data['message'] ?? 'No response',
                style: const TextStyle(color: Colors.white70),
              ),
              if (!verified && fromGallery) ...[
                const SizedBox(height: 10),
                const Text(
                  '⚠️ Gallery images may be re-encoded by Android. Try "Verify Last Captured" for a reliable check.',
                  style: TextStyle(color: Colors.orange, fontSize: 11),
                ),
              ],
              if (returnedHash != null) ...[
                const SizedBox(height: 10),
                const Divider(color: Color(0xFFDEB841)),
                const SizedBox(height: 4),
                Text(
                  'Hash checked:\n${returnedHash.substring(0, 32)}...',
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
              if (verified && blockchainData != null) ...[
                const SizedBox(height: 14),
                const Divider(color: Color(0xFFDEB841)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on, color: Color(0xFFDEB841), size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${blockchainData['latitude']}, ${blockchainData['longitude']}',
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.access_time, color: Color(0xFFDEB841), size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '${blockchainData['timestamp']}',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK', style: TextStyle(color: Color(0xFFDEB841))),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ===== SHOW VERIFY OPTIONS BOTTOM SHEET =====
  void _showVerifyOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF031926),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Verify Image',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Use original (unstamped) image for accurate verification',
              style: TextStyle(color: Colors.white38, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            // Option 1: Verify last captured (most reliable)
            ListTile(
              leading: Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.green, width: 1.5),
                ),
                child: const Icon(Icons.verified, color: Colors.green, size: 20),
              ),
              title: const Text('Verify Last Captured', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: Text(
                lastOriginalPhoto != null ? '✅ Reliable — uses internal file directly' : 'No photo captured yet this session',
                style: TextStyle(color: lastOriginalPhoto != null ? Colors.green[300] : Colors.white38, fontSize: 11),
              ),
              onTap: lastOriginalPhoto != null ? () {
                Navigator.pop(context);
                verifyLastCaptured();
              } : null,
            ),
            const Divider(color: Colors.white12),
            // Option 2: Pick from gallery
            ListTile(
              leading: Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFDEB841).withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFDEB841), width: 1.5),
                ),
                child: const Icon(Icons.photo_library, color: Color(0xFFDEB841), size: 20),
              ),
              title: const Text('Pick File (Exact Match)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: const Text('Use file manager to select unmodified file (Gallery apps alter image bytes)', style: TextStyle(color: Colors.white38, fontSize: 11)),
              onTap: () {
                Navigator.pop(context);
                verifyFromGallery();
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
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
        height: 110,
        color: const Color(0xFF031926),
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Gallery thumbnail
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
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: Image.file(lastPhoto!, fit: BoxFit.cover),
                      )
                    : const Icon(Icons.photo, color: Colors.white54),
              ),
            ),

            // Verify button — shows options sheet
            GestureDetector(
              onTap: _showVerifyOptions,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF031926),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFDEB841), width: 1.5),
                ),
                child: const Icon(Icons.verified, color: Color(0xFFDEB841), size: 22),
              ),
            ),

            // SHUTTER — large tappable circle, disabled while capturing
            GestureDetector(
              onTap: _isCapturing ? null : _onShutterTap,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: _isCapturing ? Colors.grey[300] : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFDEB841), width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: _isCapturing
                    ? const Padding(
                        padding: EdgeInsets.all(18),
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Color(0xFF031926),
                        ),
                      )
                    : const Icon(Icons.camera_alt, color: Color(0xFF031926), size: 32),
              ),
            ),

            // Map
            GestureDetector(
              onTap: openMap,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF031926),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 1.5),
                ),
                child: const Icon(Icons.map, color: Colors.white54, size: 22),
              ),
            ),

            // Device gallery
            GestureDetector(
              onTap: () async {
                await Gal.open();
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF031926),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24, width: 1.5),
                ),
                child: const Icon(Icons.photo_library, color: Colors.white54, size: 22),
              ),
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
