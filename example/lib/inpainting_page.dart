import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_magic_eraser/image_magic_eraser.dart';
import 'dart:ui' as ui;

class InpaintingPage extends StatefulWidget {
  const InpaintingPage({super.key});

  @override
  State<InpaintingPage> createState() {
    return _InpaintingPageState();
  }
}

class _InpaintingPageState extends State<InpaintingPage> {
  File? _selectedImage;
  File? _selectedMask;
  ui.Image? _outputImage;
  bool _isModelLoaded = false;
  bool _isInpainting = false;

  @override
  void initState() {
    _selectedImage = File("assets/image.jpg");
    _selectedMask = File("assets/mask.jpg");
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Image Inpainting")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _selectedImage != null
                      ? Image.asset(_selectedImage!.path, width: 400)
                      : Container(),
                  _selectedMask != null
                      ? Image.asset(_selectedMask!.path, width: 400)
                      : Container(),
                  if (_isInpainting)
                    const CircularProgressIndicator()
                  else if (_outputImage != null)
                    RawImage(
                      image: _outputImage,
                      width: 400,
                    )
                  else
                    Container(),
                ],
              ),
              if (!_isModelLoaded)
                ElevatedButton(
                    onPressed: () async {
                      try {
                        await InpaintingService.instance.initializeOrt();
                        setState(() {
                          _isModelLoaded = true;
                        });
                      } catch (e) {
                        setState(() {
                          _isModelLoaded = false;
                        });
                        debugPrint('Error loading model: $e');
                      }
                    },
                    child: const Text("Load model")),
              if (_isModelLoaded)
                ElevatedButton(
                    onPressed: () async {
                      if (_isInpainting) return;
                      setState(() {
                        _isInpainting = true;
                      });

                      final ByteData bytes =
                          await rootBundle.load(_selectedImage!.path);
                      final Uint8List selectedImageBytes =
                          bytes.buffer.asUint8List();

                      final ByteData maskBytes =
                          await rootBundle.load(_selectedMask!.path);
                      final Uint8List selectedMaskBytes =
                          maskBytes.buffer.asUint8List();

                      try {
                        final outputImage = await InpaintingService.instance
                            .inpaint(selectedImageBytes, selectedMaskBytes);
                        setState(() {
                          _outputImage = outputImage;
                          _isInpainting = false;
                        });
                      } catch (e) {
                        setState(() {
                          _isInpainting = false;
                        });
                        debugPrint('Error inpainting: $e');
                      }
                    },
                    child: const Text("Inpaint")),
            ],
          ),
        ),
      ),
    );
  }
}
