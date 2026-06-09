import 'dart:io';
import 'package:cloudinary/cloudinary.dart';

class CloudinaryService {
  static final Cloudinary cloudinary = Cloudinary.signedConfig(
    cloudName: 'ddnilmgaz',
    apiKey: '417394117243511',
    apiSecret: 'HXsbCrMKNYdqgHldsiAcuYgLHFo',
  );

  static Future<String?> uploadImage(File file, {String? folder}) async {
    try {
      if (!await file.exists()) {
        print('Cloudinary Error: File does not exist at path ${file.path}');
        return null;
      }

      final response = await cloudinary.upload(
        file: file.path,
        resourceType: CloudinaryResourceType.image,
        folder: folder ?? 'user_profiles',
        fileName: '${DateTime.now().millisecondsSinceEpoch}',
      );

      if (response.isSuccessful) {
        return response.secureUrl;
      }
      return null;
    } catch (e) {
      print('Cloudinary Upload Error: $e');
      return null;
    }
  }
}
