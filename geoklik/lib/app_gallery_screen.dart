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
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: const Color(0xFF031926),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (_) {
                  return SafeArea(
                    child: ListTile(
                      leading: const Icon(Icons.download, color: Colors.white),
                      title: const Text(
                        "Export Without Stamp",
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () async {
                        if (originalFile != null) {
                          await Gal.putImage(originalFile!.path);

                          Navigator.pop(context);

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Exported to phone gallery"),
                            ),
                          );
                        }
                      },
                    ),
                  );
                },
              );
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
