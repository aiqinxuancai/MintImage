import 'generation_request.dart';

enum ImageRecordStatus {
  pending('pending', '排队中'),
  loading('loading', '生成中'),
  done('done', '已完成'),
  error('error', '失败'),
  cancelled('cancelled', '已取消');

  const ImageRecordStatus(this.storageValue, this.label);

  final String storageValue;
  final String label;

  static ImageRecordStatus fromStorageValue(String value) {
    return ImageRecordStatus.values.firstWhere(
      (status) => status.storageValue == value,
      orElse: () => ImageRecordStatus.pending,
    );
  }
}

class ImageRecord {
  const ImageRecord({
    required this.id,
    required this.prompt,
    required this.apiProfileId,
    required this.sourceImagePath,
    required this.sourceImagePaths,
    required this.resultImagePath,
    required this.resultImageUrl,
    required this.resultB64,
    required this.width,
    required this.height,
    required this.quality,
    required this.model,
    required this.status,
    required this.errorMessage,
    required this.rawApiResponseValue,
    required this.createdAt,
    required this.durationMs,
    required this.usedSingleImageFallback,
  });

  factory ImageRecord.pending({
    required String id,
    required GenerationRequest request,
    required String model,
    required DateTime createdAt,
  }) {
    return ImageRecord(
      id: id,
      prompt: request.prompt,
      apiProfileId: request.apiProfileId,
      sourceImagePath: request.imagePaths.isEmpty
          ? null
          : request.imagePaths[0],
      sourceImagePaths: request.imagePaths,
      resultImagePath: null,
      resultImageUrl: null,
      resultB64: null,
      width: request.resolvedWidth,
      height: request.resolvedHeight,
      quality: request.quality.apiValue,
      model: model,
      status: ImageRecordStatus.pending,
      errorMessage: null,
      rawApiResponseValue: null,
      createdAt: createdAt,
      durationMs: null,
      usedSingleImageFallback: false,
    );
  }

  final String id;
  final String prompt;
  final String apiProfileId;
  final String? sourceImagePath;
  final List<String> sourceImagePaths;
  final String? resultImagePath;
  final String? resultImageUrl;
  final String? resultB64;
  final int width;
  final int height;
  final String quality;
  final String model;
  final ImageRecordStatus status;
  final String? errorMessage;
  final String? rawApiResponseValue;
  final DateTime createdAt;
  final int? durationMs;
  final bool usedSingleImageFallback;

  bool get isInProgress =>
      status == ImageRecordStatus.pending ||
      status == ImageRecordStatus.loading;

  String get sizeLabel => '$width×$height';

  String get qualityLabel => ImageQuality.fromApiValue(quality).label;

  List<String> get sourceAttachmentPaths {
    if (sourceImagePaths.isNotEmpty) {
      return sourceImagePaths;
    }

    final path = sourceImagePath;
    return path == null || path.isEmpty ? const [] : [path];
  }

  ImageRecord markCancelled() {
    return copyWith(
      status: ImageRecordStatus.cancelled,
      clearErrorMessage: true,
      clearResultImagePath: true,
      clearResultImageUrl: true,
      clearResultB64: true,
      clearRawApiResponseValue: true,
      usedSingleImageFallback: false,
    );
  }

  ImageRecord recoverInterruptedGeneration() {
    if (!isInProgress) {
      return this;
    }

    return markCancelled();
  }

  ImageRecord copyWith({
    String? id,
    String? prompt,
    String? apiProfileId,
    String? sourceImagePath,
    List<String>? sourceImagePaths,
    String? resultImagePath,
    String? resultImageUrl,
    String? resultB64,
    int? width,
    int? height,
    String? quality,
    String? model,
    ImageRecordStatus? status,
    String? errorMessage,
    String? rawApiResponseValue,
    DateTime? createdAt,
    int? durationMs,
    bool clearErrorMessage = false,
    bool clearResultImagePath = false,
    bool clearResultImageUrl = false,
    bool clearResultB64 = false,
    bool clearRawApiResponseValue = false,
    bool? usedSingleImageFallback,
  }) {
    return ImageRecord(
      id: id ?? this.id,
      prompt: prompt ?? this.prompt,
      apiProfileId: apiProfileId ?? this.apiProfileId,
      sourceImagePath: sourceImagePath ?? this.sourceImagePath,
      sourceImagePaths: sourceImagePaths ?? this.sourceImagePaths,
      resultImagePath: clearResultImagePath
          ? null
          : resultImagePath ?? this.resultImagePath,
      resultImageUrl: clearResultImageUrl
          ? null
          : resultImageUrl ?? this.resultImageUrl,
      resultB64: clearResultB64 ? null : resultB64 ?? this.resultB64,
      width: width ?? this.width,
      height: height ?? this.height,
      quality: quality ?? this.quality,
      model: model ?? this.model,
      status: status ?? this.status,
      errorMessage: clearErrorMessage
          ? null
          : errorMessage ?? this.errorMessage,
      rawApiResponseValue: clearRawApiResponseValue
          ? null
          : rawApiResponseValue ?? this.rawApiResponseValue,
      createdAt: createdAt ?? this.createdAt,
      durationMs: durationMs ?? this.durationMs,
      usedSingleImageFallback:
          usedSingleImageFallback ?? this.usedSingleImageFallback,
    );
  }
}
