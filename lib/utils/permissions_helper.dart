// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionsHelper {
  static Future<bool> requestCameraPermission(BuildContext context) async {
    try {
      // Check current status
      PermissionStatus status = await Permission.camera.status;
      
      if (status.isGranted) {
        return true;
      }
      
      if (status.isDenied) {
        // Request permission
        status = await Permission.camera.request();
        
        if (status.isGranted) {
          return true;
        } else if (status.isDenied) {
          _showPermissionDeniedDialog(context);
          return false;
        }
      }
      
      if (status.isPermanentlyDenied) {
        _showPermanentlyDeniedDialog(context);
        return false;
      }
      
      return false;
    } catch (e) {
      debugPrint('Error requesting camera permission: $e');
      _showErrorDialog(context, e.toString());
      return false;
    }
  }
  
  static void _showPermissionDeniedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.camera_alt, color: Colors.orange),
            SizedBox(width: 12),
            Text('Camera Permission Required'),
          ],
        ),
        content: const Text(
          'Sugar Plus needs camera access to scan your eyes and detect blood sugar levels. '
          'Please grant camera permission to use this feature.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await Permission.camera.request();
            },
            child: const Text('Grant Permission'),
          ),
        ],
      ),
    );
  }
  
  static void _showPermanentlyDeniedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 12),
            Text('Permission Denied'),
          ],
        ),
        content: const Text(
          'Camera permission has been permanently denied. '
          'Please enable it in your device settings to use this feature.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
  
  static void _showErrorDialog(BuildContext context, String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text('An error occurred while requesting permissions:\n\n$error'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  static Future<Map<String, bool>> checkAllPermissions() async {
    return {
      'camera': await Permission.camera.isGranted,
      'storage': await Permission.storage.isGranted,
      'photos': await Permission.photos.isGranted,
    };
  }
  
  static Future<void> requestAllPermissions(BuildContext context) async {
    final permissions = [
      Permission.camera,
    ];
    
    final statuses = await permissions.request();
    
    final deniedPermissions = statuses.entries
        .where((entry) => !entry.value.isGranted)
        .map((entry) => entry.key.toString().split('.').last)
        .toList();
    
    if (deniedPermissions.isNotEmpty && context.mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Permissions Required'),
          content: Text(
            'The following permissions are required for the app to function properly:\n\n'
            '${deniedPermissions.join(', ')}\n\n'
            'Please grant these permissions in your device settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    }
  }
}