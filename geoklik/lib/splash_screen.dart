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
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const CameraScreen()),
      );
    });
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
