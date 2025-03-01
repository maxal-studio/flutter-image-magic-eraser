# Image Magic Eraser - Flutter

A Flutter package that removes objects from images using an ONNX model. The package provides a seamless way to perform image processing, leveraging the power of machine learning through ONNX Runtime.

---

## 🌟 Features

- Remove objects from images with high accuracy.
- Works entirely offline, ensuring privacy and reliability.  
- Lightweight and optimized for efficient performance.  
- Simple and seamless integration with Flutter projects. 

---



## Getting Started

### 🚀 Prerequisites

Before using this package, ensure that the following dependencies are included in your `pubspec.yaml`:

```yaml
dependencies:
  image_magic_eraser: ^latest_version
  ```

##  Usage
# Initialization
Before using the `removeBg` method, you must initialize the ONNX environment:
    ```dart
    import 'package:image_magic_eraser/image_magic_eraser.dart';

    @override
    void initState() {
        super.initState();
        BackgroundRemover.instance.initializeOrt();
    }


# Remove Background
To remove the background from an image:
```dart
import 'package:image_magic_eraser/image_magic_eraser.dart';
