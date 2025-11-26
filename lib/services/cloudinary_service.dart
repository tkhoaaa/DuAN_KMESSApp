import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../config/cloudinary_config.dart';

/// Service để upload ảnh/video lên Cloudinary
class CloudinaryService {
  /// Upload ảnh lên Cloudinary
  /// 
  /// [file]: File ảnh từ image_picker
  /// [folder]: Thư mục lưu trữ (ví dụ: 'user_profiles/user123' hoặc 'posts/user123')
  /// [publicId]: Tên file (nếu null, Cloudinary tự tạo)
  /// 
  /// Returns: Map chứa url và publicId
  static Future<Map<String, String>> uploadImage({
    required XFile file,
    String? folder,
    String? publicId,
  }) async {
    try {
      // Đọc file
      final bytes = await file.readAsBytes();
      
      // Tạo form data
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final params = <String, String>{
        'timestamp': timestamp.toString(),
        'api_key': CloudinaryConfig.apiKey,
      };
      
      // Thêm folder và public_id trước khi tạo signature
      if (folder != null && folder.isNotEmpty) {
        params['folder'] = folder.trim();
      }
      
      if (publicId != null && publicId.isNotEmpty) {
        // Loại bỏ khoảng trắng và ký tự đặc biệt trong publicId
        params['public_id'] = publicId.trim().replaceAll(RegExp(r'\s+'), '_');
      }
      
      // Tạo signature (phải tạo sau khi có đầy đủ params)
      final signature = _generateSignature(params);
      params['signature'] = signature;
      
      // Debug: In ra để kiểm tra
      print('Cloudinary upload - cloudName: "${CloudinaryConfig.cleanCloudName}" (length: ${CloudinaryConfig.cleanCloudName.length})');
      print('Cloudinary upload - apiKey: ${CloudinaryConfig.apiKey}');
      print('Cloudinary upload - URL: ${CloudinaryConfig.imageUploadUrl}');
      
      // Tạo multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(CloudinaryConfig.imageUploadUrl),
      );
      
      // Thêm fields
      params.forEach((key, value) {
        request.fields[key] = value;
      });
      
      // Thêm file
      if (kIsWeb) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: file.name.isNotEmpty ? file.name : 'image.jpg',
          ),
        );
      } else {
        final fileObj = File(file.path);
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            fileObj.path,
            filename: file.name.isNotEmpty ? file.name : 'image.jpg',
          ),
        );
      }
      
      // Gửi request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode != 200) {
        // Parse error response để hiển thị thông báo rõ ràng hơn
        try {
          final errorJson = json.decode(response.body) as Map<String, dynamic>;
          if (errorJson['error'] != null) {
            final error = errorJson['error'];
            final message = error['message'] ?? 'Unknown error';
            throw Exception('Cloudinary upload failed: $message');
          }
        } catch (_) {
          // Nếu không parse được JSON, dùng response body
        }
        throw Exception(
          'Upload failed: ${response.statusCode} - ${response.body}',
        );
      }
      
      final jsonResponse = json.decode(response.body) as Map<String, dynamic>;
      
      if (jsonResponse['error'] != null) {
        final error = jsonResponse['error'];
        final message = error['message'] ?? 'Unknown error';
        throw Exception('Cloudinary error: $message');
      }
      
      // Lấy secure_url hoặc url
      final url = jsonResponse['secure_url'] as String? ?? 
                  jsonResponse['url'] as String?;
      final publicIdResult = jsonResponse['public_id'] as String? ?? publicId;
      
      if (url == null || publicIdResult == null) {
        throw Exception('No URL or public_id returned from Cloudinary');
      }
      
      return {
        'url': url,
        'publicId': publicIdResult,
      };
    } catch (e) {
      throw Exception('Failed to upload image to Cloudinary: $e');
    }
  }
  
  /// Upload video lên Cloudinary
  /// 
  /// [file]: File video từ image_picker
  /// [folder]: Thư mục lưu trữ
  /// [publicId]: Tên file
  /// 
  /// Returns: Map chứa video URL, thumbnail URL, và duration (ms)
  static Future<Map<String, dynamic>> uploadVideo({
    required XFile file,
    String? folder,
    String? publicId,
  }) async {
    try {
      // Đọc file
      final bytes = await file.readAsBytes();
      
      // Tạo form data
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final params = <String, String>{
        'timestamp': timestamp.toString(),
        'api_key': CloudinaryConfig.apiKey,
        'resource_type': 'video',
      };
      
      // Thêm folder và public_id trước khi tạo signature
      if (folder != null && folder.isNotEmpty) {
        params['folder'] = folder;
      }
      
      if (publicId != null && publicId.isNotEmpty) {
        // Loại bỏ khoảng trắng và ký tự đặc biệt trong publicId
        params['public_id'] = publicId.trim().replaceAll(RegExp(r'\s+'), '_');
      }
      
      // Tạo signature (phải tạo sau khi có đầy đủ params)
      final signature = _generateSignature(params);
      params['signature'] = signature;
      
      // Debug: In ra để kiểm tra
      print('Cloudinary video upload - cloudName: "${CloudinaryConfig.cleanCloudName}" (length: ${CloudinaryConfig.cleanCloudName.length})');
      print('Cloudinary video upload - URL: ${CloudinaryConfig.videoUploadUrl}');
      
      // Tạo multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(CloudinaryConfig.videoUploadUrl),
      );
      
      // Thêm fields
      params.forEach((key, value) {
        request.fields[key] = value;
      });
      
      // Thêm file
      if (kIsWeb) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: file.name.isNotEmpty ? file.name : 'video.mp4',
          ),
        );
      } else {
        final fileObj = File(file.path);
        request.files.add(
          await http.MultipartFile.fromPath(
            'file',
            fileObj.path,
            filename: file.name.isNotEmpty ? file.name : 'video.mp4',
          ),
        );
      }
      
      // Gửi request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode != 200) {
        // Parse error response để hiển thị thông báo rõ ràng hơn
        try {
          final errorJson = json.decode(response.body) as Map<String, dynamic>;
          if (errorJson['error'] != null) {
            final error = errorJson['error'];
            final message = error['message'] ?? 'Unknown error';
            throw Exception('Cloudinary upload failed: $message');
          }
        } catch (_) {
          // Nếu không parse được JSON, dùng response body
        }
        throw Exception(
          'Upload failed: ${response.statusCode} - ${response.body}',
        );
      }
      
      final jsonResponse = json.decode(response.body) as Map<String, dynamic>;
      
      if (jsonResponse['error'] != null) {
        final error = jsonResponse['error'];
        final message = error['message'] ?? 'Unknown error';
        throw Exception('Cloudinary error: $message');
      }
      
      // Lấy URLs
      final videoUrl = jsonResponse['secure_url'] as String? ?? 
                      jsonResponse['url'] as String?;
      final publicIdResult = jsonResponse['public_id'] as String? ?? publicId;
      
      if (videoUrl == null || publicIdResult == null) {
        throw Exception('No URL or public_id returned from Cloudinary');
      }
      
      // Lấy duration (nếu có)
      final duration = jsonResponse['duration'] as num?;
      final durationMs = duration != null ? (duration * 1000).round() : null;
      
      // Tạo thumbnail URL (Cloudinary tự động tạo)
      final thumbnailUrl = CloudinaryConfig.getVideoThumbnailUrl(publicIdResult);
      
      return {
        'url': videoUrl,
        'thumbnailUrl': thumbnailUrl,
        'durationMs': durationMs,
        'publicId': publicIdResult,
      };
    } catch (e) {
      throw Exception('Failed to upload video to Cloudinary: $e');
    }
  }
  
  /// Tạo signature cho Cloudinary API
  /// 
  /// Theo Cloudinary docs: https://cloudinary.com/documentation/signatures
  /// Signature = SHA1(timestamp + api_secret + sorted_params)
  static String _generateSignature(Map<String, String> params) {
    // Loại bỏ các params không cần sign
    final paramsToSign = <String, String>{};
    params.forEach((key, value) {
      if (key != 'file' &&
          key != 'signature' &&
          key != 'api_key' &&
          key != 'resource_type') {
        paramsToSign[key] = value;
      }
    });
    
    // Sắp xếp params theo key (alphabetical order)
    final sortedKeys = paramsToSign.keys.toList()..sort();
    
    // Tạo string để sign: key1=value1&key2=value2...
    final signString = sortedKeys
        .map((key) => '$key=${paramsToSign[key]}')
        .join('&');
    
    // Thêm API secret vào cuối
    final stringToSign = '$signString${CloudinaryConfig.apiSecret}';
    
    // Hash SHA1
    final bytes = utf8.encode(stringToSign);
    final hash = sha1.convert(bytes);
    
    return hash.toString();
  }
  
  /// Xóa file từ Cloudinary (cần quyền admin hoặc dùng signed URL)
  /// 
  /// ⚠️ Lưu ý: Cần setup upload preset với unsigned upload để xóa được
  static Future<void> deleteFile(String publicId, {String resourceType = 'image'}) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final params = <String, String>{
        'public_id': publicId,
        'timestamp': timestamp.toString(),
        'api_key': CloudinaryConfig.apiKey,
      };
      
      final signature = _generateSignature(params);
      params['signature'] = signature;
      
      final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/${CloudinaryConfig.cloudName}/$resourceType/destroy',
      );
      
      final response = await http.post(
        url,
        body: params,
      );
      
      if (response.statusCode != 200) {
        throw Exception('Delete failed: ${response.statusCode} - ${response.body}');
      }
      
      final jsonResponse = json.decode(response.body) as Map<String, dynamic>;
      
      if (jsonResponse['result'] != 'ok') {
        throw Exception('Delete failed: ${jsonResponse['result']}');
      }
    } catch (e) {
      throw Exception('Failed to delete file from Cloudinary: $e');
    }
  }
}

