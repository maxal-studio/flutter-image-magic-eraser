// Data class to pass to isolate
import 'dart:typed_data';

class ModelInitData {
  final String modelPath;
  final Uint8List modelBytes;

  ModelInitData(this.modelPath, this.modelBytes);
}
