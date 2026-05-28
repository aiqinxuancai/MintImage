enum SizePreset {
  auto('auto', '自动', 0, 0),
  square1k('square-1k', '方形成图 1K', 1024, 1024),
  posterPortrait('poster-portrait', '竖版海报', 1024, 1536),
  posterLandscape('poster-landscape', '横版海报', 1536, 1024),
  story916('story-9-16', '竖屏故事 9:16', 1088, 1920),
  video169('video-16-9', '视频封面 16:9', 1920, 1088),
  wide2k('wide-2k', '宽屏展示 2K', 2560, 1440),
  portrait2k('portrait-2k', '高清竖图 2K', 1440, 2560),
  square2k('square-2k', '高清方图 2K', 2048, 2048),
  portrait4k('portrait-4k', '高清竖图 4K', 2160, 3840),
  wide4k('wide-4k', '宽屏展示 4K', 3840, 2160),
  custom('custom', '自定义', 1024, 1024);

  const SizePreset(this.storageKey, this.label, this.width, this.height);

  final String storageKey;
  final String label;
  final int width;
  final int height;

  static SizePreset fromStorageKey(String key) {
    return SizePreset.values.firstWhere(
      (preset) => preset.storageKey == key,
      orElse: () => SizePreset.square1k,
    );
  }
}

enum ImageQuality {
  auto('auto', '自动'),
  low('low', '低'),
  medium('medium', '中'),
  high('high', '高');

  const ImageQuality(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static ImageQuality fromApiValue(String value) {
    return ImageQuality.values.firstWhere(
      (quality) => quality.apiValue == value,
      orElse: () => ImageQuality.auto,
    );
  }
}

class GenerationRequest {
  const GenerationRequest({
    required this.prompt,
    required this.imagePaths,
    required this.sizePreset,
    required this.customWidth,
    required this.customHeight,
    required this.quality,
    required this.count,
    required this.apiProfileId,
  });

  final String prompt;
  final List<String> imagePaths;
  final SizePreset sizePreset;
  final int customWidth;
  final int customHeight;
  final ImageQuality quality;
  final int count;
  final String apiProfileId;

  bool get hasAttachments => imagePaths.isNotEmpty;

  bool get isAutoSize => sizePreset == SizePreset.auto;

  int get resolvedWidth =>
      sizePreset == SizePreset.custom ? customWidth : sizePreset.width;

  int get resolvedHeight =>
      sizePreset == SizePreset.custom ? customHeight : sizePreset.height;

  String? get apiSize => isAutoSize ? null : '${resolvedWidth}x$resolvedHeight';

  GenerationRequest copyWith({
    String? prompt,
    List<String>? imagePaths,
    SizePreset? sizePreset,
    int? customWidth,
    int? customHeight,
    ImageQuality? quality,
    int? count,
    String? apiProfileId,
  }) {
    return GenerationRequest(
      prompt: prompt ?? this.prompt,
      imagePaths: imagePaths ?? this.imagePaths,
      sizePreset: sizePreset ?? this.sizePreset,
      customWidth: customWidth ?? this.customWidth,
      customHeight: customHeight ?? this.customHeight,
      quality: quality ?? this.quality,
      count: count ?? this.count,
      apiProfileId: apiProfileId ?? this.apiProfileId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'prompt': prompt,
      'imagePaths': imagePaths,
      'sizePreset': sizePreset.storageKey,
      'customWidth': customWidth,
      'customHeight': customHeight,
      'quality': quality.apiValue,
      'count': count,
      'apiProfileId': apiProfileId,
    };
  }

  factory GenerationRequest.fromJson(Map<String, dynamic> json) {
    return GenerationRequest(
      prompt: json['prompt'] as String? ?? '',
      imagePaths: (json['imagePaths'] as List<dynamic>? ?? <dynamic>[])
          .map((item) => item as String)
          .toList(),
      sizePreset: SizePreset.fromStorageKey(
        json['sizePreset'] as String? ?? SizePreset.square1k.storageKey,
      ),
      customWidth: json['customWidth'] as int? ?? 1024,
      customHeight: json['customHeight'] as int? ?? 1024,
      quality: ImageQuality.fromApiValue(
        json['quality'] as String? ?? ImageQuality.auto.apiValue,
      ),
      count: json['count'] as int? ?? 1,
      apiProfileId: json['apiProfileId'] as String? ?? '',
    );
  }
}
