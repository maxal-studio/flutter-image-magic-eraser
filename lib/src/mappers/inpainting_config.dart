import 'package:flutter/foundation.dart';

/// Configuration for the inpainting algorithm
///
/// This class contains parameters for the inpainting algorithm, such as
/// input size, expansion percentage, and feather size.
@immutable
class InpaintingConfig {
  /// The input size for the inpainting model (default: 512)
  final int inputSize;

  /// The percentage by which to expand the bounding box (default: 0.3)
  final double expandPercentage;

  /// The maximum expansion size in pixels (default: 200)
  final int maxExpansionSize;

  /// The feather size for blending in pixels (default: 20)
  final int featherSize;

  /// Whether to enable debug logging (default: false)
  final bool debug;

  /// Creates a new configuration for the inpainting algorithm
  const InpaintingConfig({
    this.inputSize = 512,
    this.expandPercentage = 0.3,
    this.maxExpansionSize = 200,
    this.featherSize = 20,
    this.debug = false,
  });

  /// Creates a copy of this configuration with the given fields replaced
  InpaintingConfig copyWith({
    int? inputSize,
    double? expandPercentage,
    int? maxExpansionSize,
    int? featherSize,
    bool? debug,
  }) {
    return InpaintingConfig(
      inputSize: inputSize ?? this.inputSize,
      expandPercentage: expandPercentage ?? this.expandPercentage,
      maxExpansionSize: maxExpansionSize ?? this.maxExpansionSize,
      featherSize: featherSize ?? this.featherSize,
      debug: debug ?? this.debug,
    );
  }

  /// Returns a string representation of the configuration
  @override
  String toString() {
    return 'InpaintingConfig(inputSize: $inputSize, expandPercentage: $expandPercentage, maxExpansionSize: $maxExpansionSize, featherSize: $featherSize, debug: $debug)';
  }
}
