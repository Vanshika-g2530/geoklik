import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'camera_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _loadApp();
  }

  Future<void> _loadApp() async {
    String latitude = '--';
    String longitude = '--';

    try {
      // Permission
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      // Get location
      if (permission != LocationPermission.denied &&
          permission != LocationPermission.deniedForever) {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

        if (serviceEnabled) {
          final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );

          latitude = pos.latitude.toStringAsFixed(6);
          longitude = pos.longitude.toStringAsFixed(6);
        }
      }
    } catch (e) {
      print("Splash location error: $e");
    }

    // ⏳ Delay (increase slightly if you want)
    await Future.delayed(const Duration(seconds: 4));

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => CameraScreen(
          initialLatitude: latitude,
          initialLongitude: longitude,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // MAP BACKGROUND
          Positioned.fill(
            child: Image.asset("assets/map_bg.png", fit: BoxFit.cover),
          ),

          // DARK OVERLAY (image ko readable banane ke liye)
          Container(color: Colors.black.withOpacity(0.25)),

          // CENTER LOGO
          Center(child: Image.asset("assets/logo_wbg.png", width: 220)),

          // LOADER
          const Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: CircularProgressIndicator(color: Color(0xFFDEB841)),
            ),
          ),
        ],
      ),
    );
  }
}
