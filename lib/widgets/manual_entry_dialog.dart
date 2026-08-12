import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:sugar_plus/utils/colors.dart';
import 'package:sugar_plus/utils/glucose_classifier.dart';

/// Shows a dialog for manually logging a blood-sugar reading (e.g. from a
/// glucometer). Saves it to the same `diabetes_tests` history collection as
/// GlucoScan results, tagged `source: 'manual'`. Returns true if a reading
/// was saved.
Future<bool> showManualEntryDialog(BuildContext context) async {
  final controller = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool isSaving = false;

  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setState) {
          Future<void> save() async {
            if (!formKey.currentState!.validate()) return;

            final user = FirebaseAuth.instance.currentUser;
            if (user == null) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(content: Text('Please login to save results')),
              );
              return;
            }

            final sugarLevel = double.parse(controller.text.trim());
            final classification = classifySugarLevel(sugarLevel);

            setState(() => isSaving = true);
            try {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('diabetes_tests')
                  .add({
                'sugarLevel': sugarLevel,
                'diagnosis': classification.label,
                'isNormal': classification.isNormal,
                'recommendation': classification.recommendation,
                'source': 'manual',
                'method': 'manual_entry',
                'timestamp': FieldValue.serverTimestamp(),
              });
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop(true);
              }
            } catch (e) {
              setState(() => isSaving = false);
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text('Error saving: $e')),
                );
              }
            }
          }

          return AlertDialog(
            title: const Text('Log Reading Manually'),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Blood sugar (mg/dL)',
                  suffixText: 'mg/dL',
                ),
                validator: (value) {
                  final parsed = double.tryParse((value ?? '').trim());
                  if (parsed == null) return 'Enter a valid number';
                  if (parsed < 20 || parsed > 600) return 'Enter a value between 20 and 600';
                  return null;
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving ? null : save,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );

  return saved ?? false;
}
