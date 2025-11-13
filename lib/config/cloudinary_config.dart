/// Cấu hình Cloudinary
/// 
/// Lấy thông tin từ: https://console.cloudinary.com/settings/product-environment-credentials
/// 
/// ⚠️ LƯU Ý: Không commit API Secret vào Git!
/// Nên dùng environment variables hoặc Firebase Remote Config
class CloudinaryConfig {
  // Cloudinary credentials - đã cấu hình
  // ⚠️ Đảm bảo cloud_name không có khoảng trắng hoặc ký tự đặc biệt
  // Từ CLOUDINARY_URL: cloudinary://993289453561116:w0ciVAw-XPZjputlBizd_XFx_1M@drhppamlz993289453561116
  // Format: cloudinary://api_key:api_secret@cloud_name
  // Cloud name từ URL: drhppamlz993289453561116
  // Nếu lỗi, thử với 'drhppamlz' (không có số)
  static const String cloudName = 'drhppamlz';
  static const String apiKey = '993289453561116';
  static const String apiSecret = 'w0ciVAw-XPZjputlBizd_XFx_1M';
  
  // Getter để đảm bảo cloud_name sạch (loại bỏ khoảng trắng)
  static String get cleanCloudName => cloudName.trim();
  
  // Upload URL
  static String get imageUploadUrl => 
    'https://api.cloudinary.com/v1_1/$cleanCloudName/image/upload';
  
  static String get videoUploadUrl => 
    'https://api.cloudinary.com/v1_1/$cleanCloudName/video/upload';
  
  /// Tạo URL ảnh với transform (resize, crop, etc.)
  /// 
  /// Ví dụ:
  /// - getImageUrl('posts/user123/photo', width: 800, height: 600)
  /// - getImageUrl('posts/user123/photo', width: 300) // auto height
  static String getImageUrl(
    String publicId, {
    int? width,
    int? height,
    String? format,
    String? quality,
  }) {
    final baseUrl = 'https://res.cloudinary.com/$cleanCloudName/image/upload';
    final transformations = <String>[];
    
    if (width != null || height != null) {
      final w = width ?? 'auto';
      final h = height ?? 'auto';
      transformations.add('w_$w,h_$h,c_limit'); // c_limit: giữ tỷ lệ
    }
    
    if (format != null) {
      transformations.add('f_$format');
    }
    
    if (quality != null) {
      transformations.add('q_$quality');
    }
    
    final transformStr = transformations.isEmpty 
        ? '' 
        : '/${transformations.join(',')}';
    
    return '$baseUrl$transformStr/$publicId';
  }
  
  /// Tạo URL video với transform
  static String getVideoUrl(
    String publicId, {
    int? width,
    int? height,
    String? format,
  }) {
    final baseUrl = 'https://res.cloudinary.com/$cleanCloudName/video/upload';
    final transformations = <String>[];
    
    if (width != null || height != null) {
      final w = width ?? 'auto';
      final h = height ?? 'auto';
      transformations.add('w_$w,h_$h,c_limit');
    }
    
    if (format != null) {
      transformations.add('f_$format');
    }
    
    final transformStr = transformations.isEmpty 
        ? '' 
        : '/${transformations.join(',')}';
    
    return '$baseUrl$transformStr/$publicId';
  }
  
  /// Tạo thumbnail cho video (Cloudinary tự động tạo từ video)
  static String getVideoThumbnailUrl(
    String publicId, {
    int width = 640,
    int height = 360,
  }) {
    return getImageUrl(
      publicId,
      width: width,
      height: height,
      format: 'jpg',
    );
  }
}

