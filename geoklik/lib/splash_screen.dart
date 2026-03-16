import 'package:flutter/material.dart';
import 'main.dart';
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
    // wait 3 seconds then go to home screen
    Future.delayed(Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => CameraScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.teal,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // logo placeholder for now
            Icon(Icons.shield, size: 150, color: Colors.white),

            Text(
              'GeoKlik',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Authenticate Your World',
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),
            SizedBox(height: 50),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
