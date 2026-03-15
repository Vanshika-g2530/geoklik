import 'package:flutter/material.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Capture Photo',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // image preview box
              Container(
                width: double.infinity,
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.teal, width: 2),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt, size: 80, color: Colors.teal),
                      SizedBox(height: 10),
                      Text(
                        'No image captured yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 20),

              // info cards
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // location
                      Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.teal),
                          SizedBox(width: 10),
                          Text(
                            'Location: Not captured yet',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                      Divider(),
                      // date
                      Row(
                        children: [
                          Icon(Icons.calendar_today, color: Colors.teal),
                          SizedBox(width: 10),
                          Text(
                            'Date: Not captured yet',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                      Divider(),
                      // time
                      Row(
                        children: [
                          Icon(Icons.access_time, color: Colors.teal),
                          SizedBox(width: 10),
                          Text(
                            'Time: Not captured yet',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                      Divider(),
                      // hash
                      Row(
                        children: [
                          Icon(Icons.lock, color: Colors.teal),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Hash: Not generated yet',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 20),

              // capture button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {},
                  icon: Icon(Icons.camera_alt),
                  label: Text('Capture Photo', style: TextStyle(fontSize: 16)),
                ),
              ),

              SizedBox(height: 12),

              // save button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {},
                  icon: Icon(Icons.save),
                  label: Text(
                    'Save & Authenticate',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
