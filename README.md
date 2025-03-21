# Flutter - Image Magic Eraser

A Flutter package that removes objects from images using machine learning (LaMa Model).

---

## 🌟 Features

- Remove objects from images using polygon selections
- Works entirely offline, ensuring privacy and reliability
- Lightweight and optimized for efficient performance
- Simple and seamless integration with Flutter projects
- Interactive polygon drawing widget for easy object selection

---

## 🔭 Demo
![Demo](./doc/demo.gif)

## Getting Started

### 🚀 Installation

Add this package to your Flutter project by including it in your `pubspec.yaml`:

```yaml
dependencies:
  image_magic_eraser: ^latest_version
```

Then run:

```bash
flutter pub get
```


## 📚 Usage

## (Method 1) Initialize from Assets

Before using the inpainting functionality, you need to initialize the ONNX runtime with the LaMa model:

```dart
import 'package:image_magic_eraser/image_magic_eraser.dart';

// Initialize the service with the model path
await InpaintingService.instance.initializeOrt('assets/models/lama_fp32.onnx');
```

### 📁 Model Setup

1. Download the LaMa model file (`lama_fp32.onnx`) from this url [Carve/LaMa-ONNX](https://huggingface.co/Carve/LaMa-ONNX/tree/main) and place it in your assets folder.

> **Note:** The LaMa model file is quite large (~200MB) and will significantly increase your app size. If you have experience with model optimization and can provide a smaller ONNX model suitable for mobile image inpainting, we'd love to hear from you! Please reach out to us at info@max.al or dajanvulaj@gmail.com. We're actively looking for optimized alternatives to improve the package's footprint.


2. Update your `pubspec.yaml` to include the model:

```yaml
flutter:
  assets:
    - assets/models/lama_fp32.onnx
```

## (Method 2) Initialize from URL

You can also download and initialize the model directly from a URL:

```dart
import 'package:image_magic_eraser/image_magic_eraser.dart';
// Model URL: 
String modelUrl = 'https://huggingface.co/Carve/LaMa-ONNX/resolve/main/lama_fp32.onnx';
// SHA-256 checksum for model integrity verification
String modelChecksum = '1faef5301d78db7dda502fe59966957ec4b79dd64e16f03ed96913c7a4eb68d6';

// Initialize from URL with checksum verification
await InpaintingService.instance.initializeOrtFromUrl(
  modelUrl,
  modelChecksum,
);
```

> **Note:** Downloaded models are stored permanently in the app's document directory. Once downloaded, the model won't need to be downloaded again.

### Track Download Progress

When initializing from URL, you can monitor the download progress:

```dart
// Listen to download progress updates
InpaintingService.instance.downloadProgressStream.listen((progress) {
  double percentage = progress.progress * 100;
  int downloadedMB = progress.downloaded ~/ (1024 * 1024);
  int totalMB = progress.total ~/ (1024 * 1024);
  
  print('Downloaded: $downloadedMB MB / $totalMB MB ($percentage%)');
});
```

> **Attention:** When model is loaded from assets update these `Xcode` Settings under `Runner` / `Build Settings` / `Deployment`

`Strip Linked Product` : `No`  
`Strip Style` : `Non-Global Symbols`  


---
---
## Model Loading State Management

The package provides a way to track the model loading state, which is particularly useful since model loading can take some time depending on the device. You can listen to state changes and update your UI accordingly:

```dart
// Get current loading state
ModelLoadingState currentState = InpaintingService.instance.modelLoadingState;

// Listen to state changes
InpaintingService.instance.modelLoadingStateStream.listen((state) {
  switch (state) {
    case ModelLoadingState.notLoaded:
      // Model needs to be loaded
      break;
    case ModelLoadingState.downloading:
      // Model is being downloaded (when using initializeOrtFromUrl)
      break;
    case ModelLoadingState.loading:
      // Show loading indicator
      break;
    case ModelLoadingState.loaded:
      // Model is ready to use
      break;
    case ModelLoadingState.error:
      // Generic error occurred
      break;
    case ModelLoadingState.downloadError:
      // Error downloading the model (network/url issues)
      break;
    case ModelLoadingState.checksumError:
      // Model integrity verification failed
      break;
    case ModelLoadingState.loadingError:
      // Error loading the model (incompatible format)
      break;
  }
});
```


### (Method 1) : Using the ImageMaskSelector

The package includes an interactive image selector widget that makes it easy for users to select areas to inpaint:

```dart
// Create a controller for the image selector widget
final imageSelectorController = ImageSelectorController();

// Set up the widget in your UI
ImageMaskSelector(
  controller: imageSelectorController,
  child: Image.memory(imageBytes),
),

// When ready to inpaint, get the polygons from the controller
final polygonsData = imageSelectorController.polygons
    .map((polygon) => polygon.toInpaintingFormat())
    .toList();

// Perform inpainting with the drawn polygons
final result = await InpaintingService.instance.inpaint(
  imageBytes,
  polygonsData,
);
```

### (Method 2) : Inpainting with Polygons 

Define areas to inpaint using polygons (each polygon is a list of points):

```dart
// Load your image as Uint8List
final Uint8List imageBytes = await File('path_to_image.jpg').readAsBytes();

// Define polygons to inpaint (areas to remove)
final List<List<Map<String, double>>> polygons = [
  // Rectangle to remove an object
  [
    {'x': 230.0, 'y': 300.0},
    {'x': 430.0, 'y': 300.0},
    {'x': 430.0, 'y': 770.0},
    {'x': 230.0, 'y': 770.0},
  ],
  // Triangle to remove another object
  [
    {'x': 700.0, 'y': 100.0},
    {'x': 900.0, 'y': 100.0},
    {'x': 800.0, 'y': 300.0},
  ],
];

// Perform inpainting with polygons
final ui.Image result = await InpaintingService.instance.inpaint(
  imageBytes,
  polygons,
);

// Convert ui.Image to Uint8List if needed
final ByteData? byteData = await result.toByteData(format: ui.ImageByteFormat.png);
final Uint8List outputBytes = byteData!.buffer.asUint8List();

// Use the result in your UI
Image.memory(outputBytes)
```

### Visualizing the Inpainting Process (Debug)

You can visualize the steps of the inpainting process for debugging:

```dart
// Generate debug images for the inpainting process
final debugImages = await InpaintingService.instance.generateDebugImages(
  imageBytes,
  polygonsData,
);

// Display the debug images
// Each key in the map represents a step in the process:
// 'original', 'cropped', 'mask', 'resized_image', 'resized_mask',
// 'inpainted_patch_raw', 'inpainted_patch_resized', 'inpainted_patch', 'final_result'
RawImage(
  image: debugImages['mask'],
  fit: BoxFit.contain,
)
```

## 📱 Complete Example

Check out the Example app in the repository for a full implementation.

## 📝 Notes

- For optimal results, ensure that your polygons completely cover the object you want to remove.
- Processing large images may take time, especially on older devices.
- The quality of inpainting depends on the complexity of the image and the area being inpainted.
- The polygon drawing widget automatically handles coordinate conversion between screen and image space.