class GlucoScanResult {
  final bool success;
  final double? sugarLevel;
  final double? refractiveIndex;
  final double? brix;
  final String? classification;
  final String? recommendation;
  final int readingsCount;
  final String? message;

  const GlucoScanResult({
    required this.success,
    this.sugarLevel,
    this.refractiveIndex,
    this.brix,
    this.classification,
    this.recommendation,
    this.readingsCount = 0,
    this.message,
  });

  factory GlucoScanResult.fromJson(Map<String, dynamic> json) {
    return GlucoScanResult(
      success: json['success'] as bool? ?? false,
      sugarLevel: (json['sugar_level'] as num?)?.toDouble(),
      refractiveIndex: (json['refractive_index'] as num?)?.toDouble(),
      brix: (json['brix'] as num?)?.toDouble(),
      classification: json['classification'] as String?,
      recommendation: json['recommendation'] as String?,
      readingsCount: (json['readings_count'] as num?)?.toInt() ?? 0,
      message: json['message'] as String?,
    );
  }

  bool get isNormal => classification == 'Normal';
}
