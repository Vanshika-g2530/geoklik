import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool stampEnabled = true;
  bool saveLocation = true;
  bool saveTimestamp = true;

  double opacity = 0.7;
  double fontSize = 14;

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  // 🔥 LOAD SETTINGS
  void loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      stampEnabled = prefs.getBool('stamp') ?? true;
      saveLocation = prefs.getBool('location') ?? true;
      saveTimestamp = prefs.getBool('timestamp') ?? true;
      opacity = prefs.getDouble('opacity') ?? 0.7;
      fontSize = prefs.getDouble('font') ?? 14;
    });
  }

  // 🔥 UPDATE FUNCTIONS
  void updateStamp(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => stampEnabled = value);
    await prefs.setBool('stamp', value);
  }

  void updateLocation(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => saveLocation = value);
    await prefs.setBool('location', value);
  }

  void updateTimestamp(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => saveTimestamp = value);
    await prefs.setBool('timestamp', value);
  }

  void updateOpacity(double value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => opacity = value);
    await prefs.setDouble('opacity', value);
  }

  void updateFont(double value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => fontSize = value);
    await prefs.setDouble('font', value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF031926),
      appBar: AppBar(
        backgroundColor: const Color(0xFF031926),
        title: const Text("Settings", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 🔥 STAMP SETTINGS
          const Text(
            "Stamp Settings",
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 10),

          SwitchListTile(
            value: stampEnabled,
            onChanged: updateStamp,
            title: const Text(
              "Enable Stamp",
              style: TextStyle(color: Colors.white),
            ),
            activeThumbColor: const Color(0xFFDEB841),
          ),

          ListTile(
            title: const Text(
              "Stamp Opacity",
              style: TextStyle(color: Colors.white),
            ),
            subtitle: Slider(
              value: opacity,
              min: 0.3,
              max: 1.0,
              activeColor: const Color(0xFFDEB841),
              onChanged: updateOpacity,
            ),
          ),

          ListTile(
            title: const Text(
              "Font Size",
              style: TextStyle(color: Colors.white),
            ),
            subtitle: Slider(
              value: fontSize,
              min: 10,
              max: 24,
              activeColor: const Color(0xFFDEB841),
              onChanged: updateFont,
            ),
          ),

          const SizedBox(height: 20),

          // 📍 LOCATION SETTINGS
          const Text(
            "Capture Settings",
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 10),

          SwitchListTile(
            value: saveLocation,
            onChanged: updateLocation,
            title: const Text(
              "Save Location",
              style: TextStyle(color: Colors.white),
            ),
            activeThumbColor: const Color(0xFFDEB841),
          ),

          SwitchListTile(
            value: saveTimestamp,
            onChanged: updateTimestamp,
            title: const Text(
              "Save Timestamp",
              style: TextStyle(color: Colors.white),
            ),
            activeThumbColor: const Color(0xFFDEB841),
          ),

          const SizedBox(height: 20),

          // ⚙️ APP INFO
          const Text(
            "About",
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 10),

          const ListTile(
            title: Text("GeoKlik v1.0", style: TextStyle(color: Colors.white)),
            subtitle: Text(
              "Geo-authenticated photos",
              style: TextStyle(color: Colors.white54),
            ),
          ),
        ],
      ),
    );
  }
}
