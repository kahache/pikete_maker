import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'picker_cache.dart';

/// Source of the photo (sheet of step 3 of D12).
enum PhotoSource { camera, gallery }

/// The user denied the camera permission → the UI routes to E1 (user-flows
/// §2), with the gallery ALWAYS as alternative: the permission is not a wall.
class CameraPermissionDeniedException implements Exception {}

/// Abstraction of the photo picker.
///
/// It exists for two reasons: (a) widget tests inject a fake without touching
/// native plumbing, and (b) if we ever swap image_picker for an embedded
/// camera (capture with guides, user-flows §4.3), the UI never notices.
abstract interface class PhotoPicker {
  /// Returns the encoded bytes (JPEG) of the chosen photo, or `null` if the
  /// user cancelled. Throws [CameraPermissionDeniedException] if the camera
  /// was denied.
  Future<Uint8List?> pick(PhotoSource source);
}

/// Picks one file for [source] (the plugin call; a seam for tests).
typedef XFilePicker = Future<XFile?> Function(PhotoSource source);

/// Real implementation with `image_picker` (official plugin).
///
/// On Android the camera delegates to the system app (no CAMERA permission of
/// our own) and the gallery uses the system photo picker (no storage
/// permission on Android 13+): the E1 route is defensive (iOS/odd OEMs).
///
/// PRIVACY (security audit Q2 F1): the plugin leaves its copies of the photo
/// (the gallery's full-resolution original, the scaled copy with the EXIF
/// GPS) in the app cache. Right after the bytes are read into memory those
/// files are deleted ([deletePickedFile]); the app start sweeps any leftover
/// ([purgePickerCache]). "No la guardamos" stays literally true.
class ImagePickerPhotoPicker implements PhotoPicker {
  ImagePickerPhotoPicker({@visibleForTesting XFilePicker? pickFile})
      : _pickFile = pickFile;

  final ImagePicker _picker = ImagePicker();
  final XFilePicker? _pickFile;

  /// Longest side we request from the picker: plenty for the preview and for
  /// the analysis (which also rescales to 512, see prepare_image.dart), and
  /// avoids loading full 12 MP photos in memory (gate G1 on mid-range).
  static const double _maxSidePx = 1600;

  /// JPEG recompression by the picker: invisible to the eye, reduces memory
  /// and disk.
  static const int _jpegQuality = 90;

  @override
  Future<Uint8List?> pick(PhotoSource source) async {
    try {
      final XFile? photo = await (_pickFile ?? _pickWithPlugin)(source);
      if (photo == null) return null; // cancelled: not an error
      try {
        return await photo.readAsBytes();
      } finally {
        // The bytes are in memory now (or the read failed): the plugin's
        // copies on disk have no further use.
        deletePickedFile(photo.path);
      }
    } on PlatformException catch (e) {
      if (e.code == 'camera_access_denied') {
        throw CameraPermissionDeniedException();
      }
      // 'photo_access_denied' (legacy iOS) or others: treated as
      // cancellation; the user stays where they were, no blaming error screen.
      return null;
    }
  }

  Future<XFile?> _pickWithPlugin(PhotoSource source) => _picker.pickImage(
        source: source == PhotoSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: _maxSidePx,
        maxHeight: _maxSidePx,
        imageQuality: _jpegQuality,
      );
}
