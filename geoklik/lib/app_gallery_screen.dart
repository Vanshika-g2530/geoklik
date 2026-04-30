import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'dart:io';

class AppGalleryScreen extends StatelessWidget {
  final File? imageFile; // stamped
  final File? originalFile; // without stamp

  const AppGalleryScreen({super.key, this.imageFile, this.originalFile});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(
        backgroundColor: const Color(0xFF031926),
        title: const Text("Gallery", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),

        /// 🔥 EXPORT OPTION
        actions: [
          if (originalFile != null)
            TextButton.icon(
              icon: const Icon(Icons.download, color: Color(0xFFDEB841)),
              label: const Text(
                "Save Original",
                style: TextStyle(color: Color(0xFFDEB841), fontWeight: FontWeight.bold),
              ),
              onPressed: () async {
                await Gal.putImage(originalFile!.path);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Original (unstamped) image saved to gallery! Use this for verification."),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 4),
                    ),
                  );
                }
              },
            ),
        ],
      ),

      /// 🖼 IMAGE VIEW
      body: Center(
        child: imageFile != null
            ? InteractiveViewer(child: Image.file(imageFile!))
            : const Text(
                "No Image Available",
                style: TextStyle(color: Colors.white54),
              ),
      ),
    );
  }
}
