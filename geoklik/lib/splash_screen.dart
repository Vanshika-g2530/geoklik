import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'camera_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  String statusText = "Getting location...";
  double opacity = 0.0;
  double scale = 0.8;

  @override
  void initState() {
    super.initState();

    // animation start
    Future.delayed(const Duration(milliseconds: 200), () {
      setState(() {
        opacity = 1.0;
        scale = 1.0;
      });
    });

    _loadApp();
  }

  Future<void> _loadApp() async {
    String latitude = '--';
    String longitude = '--';

    try {
      setState(() => statusText = "Checking permissions...");

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      setState(() => statusText = "Getting location...");

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

      setState(() => statusText = "Preparing camera...");
    } catch (e) {
      print("Splash location error: $e");
    }

    // small delay for smooth transition
    await Future.delayed(const Duration(seconds: 2));

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
          // BACKGROUND IMAGE
          Positioned.fill(
            child: Image.asset("assets/map_darkbg.png", fit: BoxFit.cover),
          ),

          // DARK OVERLAY (important)
          Container(color: Colors.black.withOpacity(0.2)),

          // CENTER CONTENT
          Center(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 800),
              opacity: opacity,
              child: AnimatedScale(
                duration: const Duration(milliseconds: 800),
                scale: scale,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // LOGO
                    Image.asset("assets/logo_white.png", width: 200),

                    const SizedBox(height: 16),

                    // TAGLINE
                    const SizedBox(height: 6),
                    const Text(
                      "Geo-Authenticated Photos",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // STATUS TEXT
                    Text(
                      statusText,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // LOADER
                    const CircularProgressIndicator(
                      color: Color(0xFFDEB841),
                      strokeWidth: 2,
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
