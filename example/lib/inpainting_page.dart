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
  bool _isLoadingModel = false;

  @override
  void initState() {
    _selectedImage = File("assets/image.jpg");
    _selectedMask = File("assets/mask.jpg");
    super.initState();

    // Check if model is already loaded
    _isModelLoaded = InpaintingService.instance.isModelLoaded();
  }

  @override
  void dispose() {
    // No need to dispose of the service here as it's a singleton
    // and might be used elsewhere in the app
    super.dispose();
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
                    onPressed: _isLoadingModel
                        ? null
                        : () async {
                            setState(() {
                              _isLoadingModel = true;
                            });

                            try {
                              await InpaintingService.instance.initializeOrt(
                                  'assets/models/lama_fp32.onnx');
                              InpaintingService.instance.setModelInputSize(
                                  InputSize(width: 512, height: 512));

                              setState(() {
                                _isModelLoaded = true;
                                _isLoadingModel = false;
                              });
                            } catch (e) {
                              setState(() {
                                _isModelLoaded = false;
                                _isLoadingModel = false;
                              });
                              debugPrint('Error loading model: $e');
                            }
                          },
                    child: _isLoadingModel
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: 8),
                              Text("Loading model..."),
                            ],
                          )
                        : const Text("Load model")),
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
