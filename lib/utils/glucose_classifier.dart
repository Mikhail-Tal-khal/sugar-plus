/// Mirrors the classification thresholds used by the GlucoScan backend
/// (sugar_plus_backend/app/glucoscan.py: classify()) so manual entries and
/// scan results are graded consistently.
class GlucoseClassification {
  final String label;
  final String recommendation;
  final bool isNormal;

  const GlucoseClassification(this.label, this.recommendation, this.isNormal);
}

GlucoseClassification classifySugarLevel(double sugarLevel) {
  if (sugarLevel < 70) {
    return const GlucoseClassification(
      'Low',
      'Your reading is below the typical range. Consider eating something '
          'and consult a healthcare professional if you feel unwell.',
      false,
    );
  }
  if (sugarLevel < 140) {
    return const GlucoseClassification(
      'Normal',
      'Keep up your healthy diet and exercise.',
      true,
    );
  }
  if (sugarLevel < 200) {
    return const GlucoseClassification(
      'Elevated',
      'Your levels are a bit high. Cut back on sugar and refined carbs, '
          'stay hydrated, and monitor again soon.',
      false,
    );
  }
  return const GlucoseClassification(
    'High',
    'Your levels are significantly elevated. Please consult a healthcare '
        'professional and consider a clinical blood glucose test.',
    false,
  );
}
