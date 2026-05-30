// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ImageRecordsTableTable extends ImageRecordsTable
    with TableInfo<$ImageRecordsTableTable, ImageRecordsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ImageRecordsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _promptMeta = const VerificationMeta('prompt');
  @override
  late final GeneratedColumn<String> prompt = GeneratedColumn<String>(
    'prompt',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _apiProfileIdMeta = const VerificationMeta(
    'apiProfileId',
  );
  @override
  late final GeneratedColumn<String> apiProfileId = GeneratedColumn<String>(
    'api_profile_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sourceImagePathMeta = const VerificationMeta(
    'sourceImagePath',
  );
  @override
  late final GeneratedColumn<String> sourceImagePath = GeneratedColumn<String>(
    'source_image_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceImagePathsMeta = const VerificationMeta(
    'sourceImagePaths',
  );
  @override
  late final GeneratedColumn<String> sourceImagePaths = GeneratedColumn<String>(
    'source_image_paths',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resultImagePathMeta = const VerificationMeta(
    'resultImagePath',
  );
  @override
  late final GeneratedColumn<String> resultImagePath = GeneratedColumn<String>(
    'result_image_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resultImageUrlMeta = const VerificationMeta(
    'resultImageUrl',
  );
  @override
  late final GeneratedColumn<String> resultImageUrl = GeneratedColumn<String>(
    'result_image_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resultB64Meta = const VerificationMeta(
    'resultB64',
  );
  @override
  late final GeneratedColumn<String> resultB64 = GeneratedColumn<String>(
    'result_b64',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _widthMeta = const VerificationMeta('width');
  @override
  late final GeneratedColumn<int> width = GeneratedColumn<int>(
    'width',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
    'height',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _qualityMeta = const VerificationMeta(
    'quality',
  );
  @override
  late final GeneratedColumn<String> quality = GeneratedColumn<String>(
    'quality',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _outputFormatMeta = const VerificationMeta(
    'outputFormat',
  );
  @override
  late final GeneratedColumn<String> outputFormat = GeneratedColumn<String>(
    'output_format',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('png'),
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _errorMessageMeta = const VerificationMeta(
    'errorMessage',
  );
  @override
  late final GeneratedColumn<String> errorMessage = GeneratedColumn<String>(
    'error_message',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _rawApiResponseValueMeta =
      const VerificationMeta('rawApiResponseValue');
  @override
  late final GeneratedColumn<String> rawApiResponseValue =
      GeneratedColumn<String>(
        'raw_api_response_value',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationMsMeta = const VerificationMeta(
    'durationMs',
  );
  @override
  late final GeneratedColumn<int> durationMs = GeneratedColumn<int>(
    'duration_ms',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _usedSingleImageFallbackMeta =
      const VerificationMeta('usedSingleImageFallback');
  @override
  late final GeneratedColumn<bool> usedSingleImageFallback =
      GeneratedColumn<bool>(
        'used_single_image_fallback',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("used_single_image_fallback" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  static const VerificationMeta _isFavoriteMeta = const VerificationMeta(
    'isFavorite',
  );
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
    'is_favorite',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_favorite" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    prompt,
    apiProfileId,
    sourceImagePath,
    sourceImagePaths,
    resultImagePath,
    resultImageUrl,
    resultB64,
    width,
    height,
    quality,
    outputFormat,
    model,
    status,
    errorMessage,
    rawApiResponseValue,
    createdAt,
    durationMs,
    usedSingleImageFallback,
    isFavorite,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'image_records_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<ImageRecordsTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('prompt')) {
      context.handle(
        _promptMeta,
        prompt.isAcceptableOrUnknown(data['prompt']!, _promptMeta),
      );
    } else if (isInserting) {
      context.missing(_promptMeta);
    }
    if (data.containsKey('api_profile_id')) {
      context.handle(
        _apiProfileIdMeta,
        apiProfileId.isAcceptableOrUnknown(
          data['api_profile_id']!,
          _apiProfileIdMeta,
        ),
      );
    }
    if (data.containsKey('source_image_path')) {
      context.handle(
        _sourceImagePathMeta,
        sourceImagePath.isAcceptableOrUnknown(
          data['source_image_path']!,
          _sourceImagePathMeta,
        ),
      );
    }
    if (data.containsKey('source_image_paths')) {
      context.handle(
        _sourceImagePathsMeta,
        sourceImagePaths.isAcceptableOrUnknown(
          data['source_image_paths']!,
          _sourceImagePathsMeta,
        ),
      );
    }
    if (data.containsKey('result_image_path')) {
      context.handle(
        _resultImagePathMeta,
        resultImagePath.isAcceptableOrUnknown(
          data['result_image_path']!,
          _resultImagePathMeta,
        ),
      );
    }
    if (data.containsKey('result_image_url')) {
      context.handle(
        _resultImageUrlMeta,
        resultImageUrl.isAcceptableOrUnknown(
          data['result_image_url']!,
          _resultImageUrlMeta,
        ),
      );
    }
    if (data.containsKey('result_b64')) {
      context.handle(
        _resultB64Meta,
        resultB64.isAcceptableOrUnknown(data['result_b64']!, _resultB64Meta),
      );
    }
    if (data.containsKey('width')) {
      context.handle(
        _widthMeta,
        width.isAcceptableOrUnknown(data['width']!, _widthMeta),
      );
    } else if (isInserting) {
      context.missing(_widthMeta);
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    } else if (isInserting) {
      context.missing(_heightMeta);
    }
    if (data.containsKey('quality')) {
      context.handle(
        _qualityMeta,
        quality.isAcceptableOrUnknown(data['quality']!, _qualityMeta),
      );
    } else if (isInserting) {
      context.missing(_qualityMeta);
    }
    if (data.containsKey('output_format')) {
      context.handle(
        _outputFormatMeta,
        outputFormat.isAcceptableOrUnknown(
          data['output_format']!,
          _outputFormatMeta,
        ),
      );
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    } else if (isInserting) {
      context.missing(_modelMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('error_message')) {
      context.handle(
        _errorMessageMeta,
        errorMessage.isAcceptableOrUnknown(
          data['error_message']!,
          _errorMessageMeta,
        ),
      );
    }
    if (data.containsKey('raw_api_response_value')) {
      context.handle(
        _rawApiResponseValueMeta,
        rawApiResponseValue.isAcceptableOrUnknown(
          data['raw_api_response_value']!,
          _rawApiResponseValueMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('duration_ms')) {
      context.handle(
        _durationMsMeta,
        durationMs.isAcceptableOrUnknown(data['duration_ms']!, _durationMsMeta),
      );
    }
    if (data.containsKey('used_single_image_fallback')) {
      context.handle(
        _usedSingleImageFallbackMeta,
        usedSingleImageFallback.isAcceptableOrUnknown(
          data['used_single_image_fallback']!,
          _usedSingleImageFallbackMeta,
        ),
      );
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
        _isFavoriteMeta,
        isFavorite.isAcceptableOrUnknown(data['is_favorite']!, _isFavoriteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ImageRecordsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ImageRecordsTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      prompt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}prompt'],
      )!,
      apiProfileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}api_profile_id'],
      )!,
      sourceImagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_image_path'],
      ),
      sourceImagePaths: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_image_paths'],
      ),
      resultImagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result_image_path'],
      ),
      resultImageUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result_image_url'],
      ),
      resultB64: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}result_b64'],
      ),
      width: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}width'],
      )!,
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}height'],
      )!,
      quality: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quality'],
      )!,
      outputFormat: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}output_format'],
      )!,
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      errorMessage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_message'],
      ),
      rawApiResponseValue: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raw_api_response_value'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      durationMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_ms'],
      ),
      usedSingleImageFallback: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}used_single_image_fallback'],
      )!,
      isFavorite: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_favorite'],
      )!,
    );
  }

  @override
  $ImageRecordsTableTable createAlias(String alias) {
    return $ImageRecordsTableTable(attachedDatabase, alias);
  }
}

class ImageRecordsTableData extends DataClass
    implements Insertable<ImageRecordsTableData> {
  final String id;
  final String prompt;
  final String apiProfileId;
  final String? sourceImagePath;
  final String? sourceImagePaths;
  final String? resultImagePath;
  final String? resultImageUrl;
  final String? resultB64;
  final int width;
  final int height;
  final String quality;
  final String outputFormat;
  final String model;
  final String status;
  final String? errorMessage;
  final String? rawApiResponseValue;
  final DateTime createdAt;
  final int? durationMs;
  final bool usedSingleImageFallback;
  final bool isFavorite;
  const ImageRecordsTableData({
    required this.id,
    required this.prompt,
    required this.apiProfileId,
    this.sourceImagePath,
    this.sourceImagePaths,
    this.resultImagePath,
    this.resultImageUrl,
    this.resultB64,
    required this.width,
    required this.height,
    required this.quality,
    required this.outputFormat,
    required this.model,
    required this.status,
    this.errorMessage,
    this.rawApiResponseValue,
    required this.createdAt,
    this.durationMs,
    required this.usedSingleImageFallback,
    required this.isFavorite,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['prompt'] = Variable<String>(prompt);
    map['api_profile_id'] = Variable<String>(apiProfileId);
    if (!nullToAbsent || sourceImagePath != null) {
      map['source_image_path'] = Variable<String>(sourceImagePath);
    }
    if (!nullToAbsent || sourceImagePaths != null) {
      map['source_image_paths'] = Variable<String>(sourceImagePaths);
    }
    if (!nullToAbsent || resultImagePath != null) {
      map['result_image_path'] = Variable<String>(resultImagePath);
    }
    if (!nullToAbsent || resultImageUrl != null) {
      map['result_image_url'] = Variable<String>(resultImageUrl);
    }
    if (!nullToAbsent || resultB64 != null) {
      map['result_b64'] = Variable<String>(resultB64);
    }
    map['width'] = Variable<int>(width);
    map['height'] = Variable<int>(height);
    map['quality'] = Variable<String>(quality);
    map['output_format'] = Variable<String>(outputFormat);
    map['model'] = Variable<String>(model);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || errorMessage != null) {
      map['error_message'] = Variable<String>(errorMessage);
    }
    if (!nullToAbsent || rawApiResponseValue != null) {
      map['raw_api_response_value'] = Variable<String>(rawApiResponseValue);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || durationMs != null) {
      map['duration_ms'] = Variable<int>(durationMs);
    }
    map['used_single_image_fallback'] = Variable<bool>(usedSingleImageFallback);
    map['is_favorite'] = Variable<bool>(isFavorite);
    return map;
  }

  ImageRecordsTableCompanion toCompanion(bool nullToAbsent) {
    return ImageRecordsTableCompanion(
      id: Value(id),
      prompt: Value(prompt),
      apiProfileId: Value(apiProfileId),
      sourceImagePath: sourceImagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceImagePath),
      sourceImagePaths: sourceImagePaths == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceImagePaths),
      resultImagePath: resultImagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(resultImagePath),
      resultImageUrl: resultImageUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(resultImageUrl),
      resultB64: resultB64 == null && nullToAbsent
          ? const Value.absent()
          : Value(resultB64),
      width: Value(width),
      height: Value(height),
      quality: Value(quality),
      outputFormat: Value(outputFormat),
      model: Value(model),
      status: Value(status),
      errorMessage: errorMessage == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMessage),
      rawApiResponseValue: rawApiResponseValue == null && nullToAbsent
          ? const Value.absent()
          : Value(rawApiResponseValue),
      createdAt: Value(createdAt),
      durationMs: durationMs == null && nullToAbsent
          ? const Value.absent()
          : Value(durationMs),
      usedSingleImageFallback: Value(usedSingleImageFallback),
      isFavorite: Value(isFavorite),
    );
  }

  factory ImageRecordsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ImageRecordsTableData(
      id: serializer.fromJson<String>(json['id']),
      prompt: serializer.fromJson<String>(json['prompt']),
      apiProfileId: serializer.fromJson<String>(json['apiProfileId']),
      sourceImagePath: serializer.fromJson<String?>(json['sourceImagePath']),
      sourceImagePaths: serializer.fromJson<String?>(json['sourceImagePaths']),
      resultImagePath: serializer.fromJson<String?>(json['resultImagePath']),
      resultImageUrl: serializer.fromJson<String?>(json['resultImageUrl']),
      resultB64: serializer.fromJson<String?>(json['resultB64']),
      width: serializer.fromJson<int>(json['width']),
      height: serializer.fromJson<int>(json['height']),
      quality: serializer.fromJson<String>(json['quality']),
      outputFormat: serializer.fromJson<String>(json['outputFormat']),
      model: serializer.fromJson<String>(json['model']),
      status: serializer.fromJson<String>(json['status']),
      errorMessage: serializer.fromJson<String?>(json['errorMessage']),
      rawApiResponseValue: serializer.fromJson<String?>(
        json['rawApiResponseValue'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      durationMs: serializer.fromJson<int?>(json['durationMs']),
      usedSingleImageFallback: serializer.fromJson<bool>(
        json['usedSingleImageFallback'],
      ),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'prompt': serializer.toJson<String>(prompt),
      'apiProfileId': serializer.toJson<String>(apiProfileId),
      'sourceImagePath': serializer.toJson<String?>(sourceImagePath),
      'sourceImagePaths': serializer.toJson<String?>(sourceImagePaths),
      'resultImagePath': serializer.toJson<String?>(resultImagePath),
      'resultImageUrl': serializer.toJson<String?>(resultImageUrl),
      'resultB64': serializer.toJson<String?>(resultB64),
      'width': serializer.toJson<int>(width),
      'height': serializer.toJson<int>(height),
      'quality': serializer.toJson<String>(quality),
      'outputFormat': serializer.toJson<String>(outputFormat),
      'model': serializer.toJson<String>(model),
      'status': serializer.toJson<String>(status),
      'errorMessage': serializer.toJson<String?>(errorMessage),
      'rawApiResponseValue': serializer.toJson<String?>(rawApiResponseValue),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'durationMs': serializer.toJson<int?>(durationMs),
      'usedSingleImageFallback': serializer.toJson<bool>(
        usedSingleImageFallback,
      ),
      'isFavorite': serializer.toJson<bool>(isFavorite),
    };
  }

  ImageRecordsTableData copyWith({
    String? id,
    String? prompt,
    String? apiProfileId,
    Value<String?> sourceImagePath = const Value.absent(),
    Value<String?> sourceImagePaths = const Value.absent(),
    Value<String?> resultImagePath = const Value.absent(),
    Value<String?> resultImageUrl = const Value.absent(),
    Value<String?> resultB64 = const Value.absent(),
    int? width,
    int? height,
    String? quality,
    String? outputFormat,
    String? model,
    String? status,
    Value<String?> errorMessage = const Value.absent(),
    Value<String?> rawApiResponseValue = const Value.absent(),
    DateTime? createdAt,
    Value<int?> durationMs = const Value.absent(),
    bool? usedSingleImageFallback,
    bool? isFavorite,
  }) => ImageRecordsTableData(
    id: id ?? this.id,
    prompt: prompt ?? this.prompt,
    apiProfileId: apiProfileId ?? this.apiProfileId,
    sourceImagePath: sourceImagePath.present
        ? sourceImagePath.value
        : this.sourceImagePath,
    sourceImagePaths: sourceImagePaths.present
        ? sourceImagePaths.value
        : this.sourceImagePaths,
    resultImagePath: resultImagePath.present
        ? resultImagePath.value
        : this.resultImagePath,
    resultImageUrl: resultImageUrl.present
        ? resultImageUrl.value
        : this.resultImageUrl,
    resultB64: resultB64.present ? resultB64.value : this.resultB64,
    width: width ?? this.width,
    height: height ?? this.height,
    quality: quality ?? this.quality,
    outputFormat: outputFormat ?? this.outputFormat,
    model: model ?? this.model,
    status: status ?? this.status,
    errorMessage: errorMessage.present ? errorMessage.value : this.errorMessage,
    rawApiResponseValue: rawApiResponseValue.present
        ? rawApiResponseValue.value
        : this.rawApiResponseValue,
    createdAt: createdAt ?? this.createdAt,
    durationMs: durationMs.present ? durationMs.value : this.durationMs,
    usedSingleImageFallback:
        usedSingleImageFallback ?? this.usedSingleImageFallback,
    isFavorite: isFavorite ?? this.isFavorite,
  );
  ImageRecordsTableData copyWithCompanion(ImageRecordsTableCompanion data) {
    return ImageRecordsTableData(
      id: data.id.present ? data.id.value : this.id,
      prompt: data.prompt.present ? data.prompt.value : this.prompt,
      apiProfileId: data.apiProfileId.present
          ? data.apiProfileId.value
          : this.apiProfileId,
      sourceImagePath: data.sourceImagePath.present
          ? data.sourceImagePath.value
          : this.sourceImagePath,
      sourceImagePaths: data.sourceImagePaths.present
          ? data.sourceImagePaths.value
          : this.sourceImagePaths,
      resultImagePath: data.resultImagePath.present
          ? data.resultImagePath.value
          : this.resultImagePath,
      resultImageUrl: data.resultImageUrl.present
          ? data.resultImageUrl.value
          : this.resultImageUrl,
      resultB64: data.resultB64.present ? data.resultB64.value : this.resultB64,
      width: data.width.present ? data.width.value : this.width,
      height: data.height.present ? data.height.value : this.height,
      quality: data.quality.present ? data.quality.value : this.quality,
      outputFormat: data.outputFormat.present
          ? data.outputFormat.value
          : this.outputFormat,
      model: data.model.present ? data.model.value : this.model,
      status: data.status.present ? data.status.value : this.status,
      errorMessage: data.errorMessage.present
          ? data.errorMessage.value
          : this.errorMessage,
      rawApiResponseValue: data.rawApiResponseValue.present
          ? data.rawApiResponseValue.value
          : this.rawApiResponseValue,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      durationMs: data.durationMs.present
          ? data.durationMs.value
          : this.durationMs,
      usedSingleImageFallback: data.usedSingleImageFallback.present
          ? data.usedSingleImageFallback.value
          : this.usedSingleImageFallback,
      isFavorite: data.isFavorite.present
          ? data.isFavorite.value
          : this.isFavorite,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ImageRecordsTableData(')
          ..write('id: $id, ')
          ..write('prompt: $prompt, ')
          ..write('apiProfileId: $apiProfileId, ')
          ..write('sourceImagePath: $sourceImagePath, ')
          ..write('sourceImagePaths: $sourceImagePaths, ')
          ..write('resultImagePath: $resultImagePath, ')
          ..write('resultImageUrl: $resultImageUrl, ')
          ..write('resultB64: $resultB64, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('quality: $quality, ')
          ..write('outputFormat: $outputFormat, ')
          ..write('model: $model, ')
          ..write('status: $status, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('rawApiResponseValue: $rawApiResponseValue, ')
          ..write('createdAt: $createdAt, ')
          ..write('durationMs: $durationMs, ')
          ..write('usedSingleImageFallback: $usedSingleImageFallback, ')
          ..write('isFavorite: $isFavorite')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    prompt,
    apiProfileId,
    sourceImagePath,
    sourceImagePaths,
    resultImagePath,
    resultImageUrl,
    resultB64,
    width,
    height,
    quality,
    outputFormat,
    model,
    status,
    errorMessage,
    rawApiResponseValue,
    createdAt,
    durationMs,
    usedSingleImageFallback,
    isFavorite,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImageRecordsTableData &&
          other.id == this.id &&
          other.prompt == this.prompt &&
          other.apiProfileId == this.apiProfileId &&
          other.sourceImagePath == this.sourceImagePath &&
          other.sourceImagePaths == this.sourceImagePaths &&
          other.resultImagePath == this.resultImagePath &&
          other.resultImageUrl == this.resultImageUrl &&
          other.resultB64 == this.resultB64 &&
          other.width == this.width &&
          other.height == this.height &&
          other.quality == this.quality &&
          other.outputFormat == this.outputFormat &&
          other.model == this.model &&
          other.status == this.status &&
          other.errorMessage == this.errorMessage &&
          other.rawApiResponseValue == this.rawApiResponseValue &&
          other.createdAt == this.createdAt &&
          other.durationMs == this.durationMs &&
          other.usedSingleImageFallback == this.usedSingleImageFallback &&
          other.isFavorite == this.isFavorite);
}

class ImageRecordsTableCompanion
    extends UpdateCompanion<ImageRecordsTableData> {
  final Value<String> id;
  final Value<String> prompt;
  final Value<String> apiProfileId;
  final Value<String?> sourceImagePath;
  final Value<String?> sourceImagePaths;
  final Value<String?> resultImagePath;
  final Value<String?> resultImageUrl;
  final Value<String?> resultB64;
  final Value<int> width;
  final Value<int> height;
  final Value<String> quality;
  final Value<String> outputFormat;
  final Value<String> model;
  final Value<String> status;
  final Value<String?> errorMessage;
  final Value<String?> rawApiResponseValue;
  final Value<DateTime> createdAt;
  final Value<int?> durationMs;
  final Value<bool> usedSingleImageFallback;
  final Value<bool> isFavorite;
  final Value<int> rowid;
  const ImageRecordsTableCompanion({
    this.id = const Value.absent(),
    this.prompt = const Value.absent(),
    this.apiProfileId = const Value.absent(),
    this.sourceImagePath = const Value.absent(),
    this.sourceImagePaths = const Value.absent(),
    this.resultImagePath = const Value.absent(),
    this.resultImageUrl = const Value.absent(),
    this.resultB64 = const Value.absent(),
    this.width = const Value.absent(),
    this.height = const Value.absent(),
    this.quality = const Value.absent(),
    this.outputFormat = const Value.absent(),
    this.model = const Value.absent(),
    this.status = const Value.absent(),
    this.errorMessage = const Value.absent(),
    this.rawApiResponseValue = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.durationMs = const Value.absent(),
    this.usedSingleImageFallback = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ImageRecordsTableCompanion.insert({
    required String id,
    required String prompt,
    this.apiProfileId = const Value.absent(),
    this.sourceImagePath = const Value.absent(),
    this.sourceImagePaths = const Value.absent(),
    this.resultImagePath = const Value.absent(),
    this.resultImageUrl = const Value.absent(),
    this.resultB64 = const Value.absent(),
    required int width,
    required int height,
    required String quality,
    this.outputFormat = const Value.absent(),
    required String model,
    required String status,
    this.errorMessage = const Value.absent(),
    this.rawApiResponseValue = const Value.absent(),
    required DateTime createdAt,
    this.durationMs = const Value.absent(),
    this.usedSingleImageFallback = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       prompt = Value(prompt),
       width = Value(width),
       height = Value(height),
       quality = Value(quality),
       model = Value(model),
       status = Value(status),
       createdAt = Value(createdAt);
  static Insertable<ImageRecordsTableData> custom({
    Expression<String>? id,
    Expression<String>? prompt,
    Expression<String>? apiProfileId,
    Expression<String>? sourceImagePath,
    Expression<String>? sourceImagePaths,
    Expression<String>? resultImagePath,
    Expression<String>? resultImageUrl,
    Expression<String>? resultB64,
    Expression<int>? width,
    Expression<int>? height,
    Expression<String>? quality,
    Expression<String>? outputFormat,
    Expression<String>? model,
    Expression<String>? status,
    Expression<String>? errorMessage,
    Expression<String>? rawApiResponseValue,
    Expression<DateTime>? createdAt,
    Expression<int>? durationMs,
    Expression<bool>? usedSingleImageFallback,
    Expression<bool>? isFavorite,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (prompt != null) 'prompt': prompt,
      if (apiProfileId != null) 'api_profile_id': apiProfileId,
      if (sourceImagePath != null) 'source_image_path': sourceImagePath,
      if (sourceImagePaths != null) 'source_image_paths': sourceImagePaths,
      if (resultImagePath != null) 'result_image_path': resultImagePath,
      if (resultImageUrl != null) 'result_image_url': resultImageUrl,
      if (resultB64 != null) 'result_b64': resultB64,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (quality != null) 'quality': quality,
      if (outputFormat != null) 'output_format': outputFormat,
      if (model != null) 'model': model,
      if (status != null) 'status': status,
      if (errorMessage != null) 'error_message': errorMessage,
      if (rawApiResponseValue != null)
        'raw_api_response_value': rawApiResponseValue,
      if (createdAt != null) 'created_at': createdAt,
      if (durationMs != null) 'duration_ms': durationMs,
      if (usedSingleImageFallback != null)
        'used_single_image_fallback': usedSingleImageFallback,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ImageRecordsTableCompanion copyWith({
    Value<String>? id,
    Value<String>? prompt,
    Value<String>? apiProfileId,
    Value<String?>? sourceImagePath,
    Value<String?>? sourceImagePaths,
    Value<String?>? resultImagePath,
    Value<String?>? resultImageUrl,
    Value<String?>? resultB64,
    Value<int>? width,
    Value<int>? height,
    Value<String>? quality,
    Value<String>? outputFormat,
    Value<String>? model,
    Value<String>? status,
    Value<String?>? errorMessage,
    Value<String?>? rawApiResponseValue,
    Value<DateTime>? createdAt,
    Value<int?>? durationMs,
    Value<bool>? usedSingleImageFallback,
    Value<bool>? isFavorite,
    Value<int>? rowid,
  }) {
    return ImageRecordsTableCompanion(
      id: id ?? this.id,
      prompt: prompt ?? this.prompt,
      apiProfileId: apiProfileId ?? this.apiProfileId,
      sourceImagePath: sourceImagePath ?? this.sourceImagePath,
      sourceImagePaths: sourceImagePaths ?? this.sourceImagePaths,
      resultImagePath: resultImagePath ?? this.resultImagePath,
      resultImageUrl: resultImageUrl ?? this.resultImageUrl,
      resultB64: resultB64 ?? this.resultB64,
      width: width ?? this.width,
      height: height ?? this.height,
      quality: quality ?? this.quality,
      outputFormat: outputFormat ?? this.outputFormat,
      model: model ?? this.model,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      rawApiResponseValue: rawApiResponseValue ?? this.rawApiResponseValue,
      createdAt: createdAt ?? this.createdAt,
      durationMs: durationMs ?? this.durationMs,
      usedSingleImageFallback:
          usedSingleImageFallback ?? this.usedSingleImageFallback,
      isFavorite: isFavorite ?? this.isFavorite,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (prompt.present) {
      map['prompt'] = Variable<String>(prompt.value);
    }
    if (apiProfileId.present) {
      map['api_profile_id'] = Variable<String>(apiProfileId.value);
    }
    if (sourceImagePath.present) {
      map['source_image_path'] = Variable<String>(sourceImagePath.value);
    }
    if (sourceImagePaths.present) {
      map['source_image_paths'] = Variable<String>(sourceImagePaths.value);
    }
    if (resultImagePath.present) {
      map['result_image_path'] = Variable<String>(resultImagePath.value);
    }
    if (resultImageUrl.present) {
      map['result_image_url'] = Variable<String>(resultImageUrl.value);
    }
    if (resultB64.present) {
      map['result_b64'] = Variable<String>(resultB64.value);
    }
    if (width.present) {
      map['width'] = Variable<int>(width.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (quality.present) {
      map['quality'] = Variable<String>(quality.value);
    }
    if (outputFormat.present) {
      map['output_format'] = Variable<String>(outputFormat.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (errorMessage.present) {
      map['error_message'] = Variable<String>(errorMessage.value);
    }
    if (rawApiResponseValue.present) {
      map['raw_api_response_value'] = Variable<String>(
        rawApiResponseValue.value,
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (durationMs.present) {
      map['duration_ms'] = Variable<int>(durationMs.value);
    }
    if (usedSingleImageFallback.present) {
      map['used_single_image_fallback'] = Variable<bool>(
        usedSingleImageFallback.value,
      );
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ImageRecordsTableCompanion(')
          ..write('id: $id, ')
          ..write('prompt: $prompt, ')
          ..write('apiProfileId: $apiProfileId, ')
          ..write('sourceImagePath: $sourceImagePath, ')
          ..write('sourceImagePaths: $sourceImagePaths, ')
          ..write('resultImagePath: $resultImagePath, ')
          ..write('resultImageUrl: $resultImageUrl, ')
          ..write('resultB64: $resultB64, ')
          ..write('width: $width, ')
          ..write('height: $height, ')
          ..write('quality: $quality, ')
          ..write('outputFormat: $outputFormat, ')
          ..write('model: $model, ')
          ..write('status: $status, ')
          ..write('errorMessage: $errorMessage, ')
          ..write('rawApiResponseValue: $rawApiResponseValue, ')
          ..write('createdAt: $createdAt, ')
          ..write('durationMs: $durationMs, ')
          ..write('usedSingleImageFallback: $usedSingleImageFallback, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FavoriteFoldersTableTable extends FavoriteFoldersTable
    with TableInfo<$FavoriteFoldersTableTable, FavoriteFoldersTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FavoriteFoldersTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isDefaultMeta = const VerificationMeta(
    'isDefault',
  );
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
    'is_default',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_default" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, title, isDefault, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'favorite_folders_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<FavoriteFoldersTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('is_default')) {
      context.handle(
        _isDefaultMeta,
        isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FavoriteFoldersTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FavoriteFoldersTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      isDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_default'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $FavoriteFoldersTableTable createAlias(String alias) {
    return $FavoriteFoldersTableTable(attachedDatabase, alias);
  }
}

class FavoriteFoldersTableData extends DataClass
    implements Insertable<FavoriteFoldersTableData> {
  final String id;
  final String title;
  final bool isDefault;
  final DateTime createdAt;
  const FavoriteFoldersTableData({
    required this.id,
    required this.title,
    required this.isDefault,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['is_default'] = Variable<bool>(isDefault);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  FavoriteFoldersTableCompanion toCompanion(bool nullToAbsent) {
    return FavoriteFoldersTableCompanion(
      id: Value(id),
      title: Value(title),
      isDefault: Value(isDefault),
      createdAt: Value(createdAt),
    );
  }

  factory FavoriteFoldersTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FavoriteFoldersTableData(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'isDefault': serializer.toJson<bool>(isDefault),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  FavoriteFoldersTableData copyWith({
    String? id,
    String? title,
    bool? isDefault,
    DateTime? createdAt,
  }) => FavoriteFoldersTableData(
    id: id ?? this.id,
    title: title ?? this.title,
    isDefault: isDefault ?? this.isDefault,
    createdAt: createdAt ?? this.createdAt,
  );
  FavoriteFoldersTableData copyWithCompanion(
    FavoriteFoldersTableCompanion data,
  ) {
    return FavoriteFoldersTableData(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FavoriteFoldersTableData(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('isDefault: $isDefault, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, isDefault, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FavoriteFoldersTableData &&
          other.id == this.id &&
          other.title == this.title &&
          other.isDefault == this.isDefault &&
          other.createdAt == this.createdAt);
}

class FavoriteFoldersTableCompanion
    extends UpdateCompanion<FavoriteFoldersTableData> {
  final Value<String> id;
  final Value<String> title;
  final Value<bool> isDefault;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const FavoriteFoldersTableCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FavoriteFoldersTableCompanion.insert({
    required String id,
    required String title,
    this.isDefault = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       createdAt = Value(createdAt);
  static Insertable<FavoriteFoldersTableData> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<bool>? isDefault,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (isDefault != null) 'is_default': isDefault,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FavoriteFoldersTableCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<bool>? isDefault,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return FavoriteFoldersTableCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FavoriteFoldersTableCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('isDefault: $isDefault, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FavoriteFolderItemsTableTable extends FavoriteFolderItemsTable
    with
        TableInfo<
          $FavoriteFolderItemsTableTable,
          FavoriteFolderItemsTableData
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FavoriteFolderItemsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _folderIdMeta = const VerificationMeta(
    'folderId',
  );
  @override
  late final GeneratedColumn<String> folderId = GeneratedColumn<String>(
    'folder_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES favorite_folders_table (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _recordIdMeta = const VerificationMeta(
    'recordId',
  );
  @override
  late final GeneratedColumn<String> recordId = GeneratedColumn<String>(
    'record_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES image_records_table (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [folderId, recordId, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'favorite_folder_items_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<FavoriteFolderItemsTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('folder_id')) {
      context.handle(
        _folderIdMeta,
        folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_folderIdMeta);
    }
    if (data.containsKey('record_id')) {
      context.handle(
        _recordIdMeta,
        recordId.isAcceptableOrUnknown(data['record_id']!, _recordIdMeta),
      );
    } else if (isInserting) {
      context.missing(_recordIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {folderId, recordId};
  @override
  FavoriteFolderItemsTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FavoriteFolderItemsTableData(
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_id'],
      )!,
      recordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $FavoriteFolderItemsTableTable createAlias(String alias) {
    return $FavoriteFolderItemsTableTable(attachedDatabase, alias);
  }
}

class FavoriteFolderItemsTableData extends DataClass
    implements Insertable<FavoriteFolderItemsTableData> {
  final String folderId;
  final String recordId;
  final DateTime createdAt;
  const FavoriteFolderItemsTableData({
    required this.folderId,
    required this.recordId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['folder_id'] = Variable<String>(folderId);
    map['record_id'] = Variable<String>(recordId);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  FavoriteFolderItemsTableCompanion toCompanion(bool nullToAbsent) {
    return FavoriteFolderItemsTableCompanion(
      folderId: Value(folderId),
      recordId: Value(recordId),
      createdAt: Value(createdAt),
    );
  }

  factory FavoriteFolderItemsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FavoriteFolderItemsTableData(
      folderId: serializer.fromJson<String>(json['folderId']),
      recordId: serializer.fromJson<String>(json['recordId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'folderId': serializer.toJson<String>(folderId),
      'recordId': serializer.toJson<String>(recordId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  FavoriteFolderItemsTableData copyWith({
    String? folderId,
    String? recordId,
    DateTime? createdAt,
  }) => FavoriteFolderItemsTableData(
    folderId: folderId ?? this.folderId,
    recordId: recordId ?? this.recordId,
    createdAt: createdAt ?? this.createdAt,
  );
  FavoriteFolderItemsTableData copyWithCompanion(
    FavoriteFolderItemsTableCompanion data,
  ) {
    return FavoriteFolderItemsTableData(
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      recordId: data.recordId.present ? data.recordId.value : this.recordId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FavoriteFolderItemsTableData(')
          ..write('folderId: $folderId, ')
          ..write('recordId: $recordId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(folderId, recordId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FavoriteFolderItemsTableData &&
          other.folderId == this.folderId &&
          other.recordId == this.recordId &&
          other.createdAt == this.createdAt);
}

class FavoriteFolderItemsTableCompanion
    extends UpdateCompanion<FavoriteFolderItemsTableData> {
  final Value<String> folderId;
  final Value<String> recordId;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const FavoriteFolderItemsTableCompanion({
    this.folderId = const Value.absent(),
    this.recordId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FavoriteFolderItemsTableCompanion.insert({
    required String folderId,
    required String recordId,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : folderId = Value(folderId),
       recordId = Value(recordId),
       createdAt = Value(createdAt);
  static Insertable<FavoriteFolderItemsTableData> custom({
    Expression<String>? folderId,
    Expression<String>? recordId,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (folderId != null) 'folder_id': folderId,
      if (recordId != null) 'record_id': recordId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FavoriteFolderItemsTableCompanion copyWith({
    Value<String>? folderId,
    Value<String>? recordId,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return FavoriteFolderItemsTableCompanion(
      folderId: folderId ?? this.folderId,
      recordId: recordId ?? this.recordId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (folderId.present) {
      map['folder_id'] = Variable<String>(folderId.value);
    }
    if (recordId.present) {
      map['record_id'] = Variable<String>(recordId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FavoriteFolderItemsTableCompanion(')
          ..write('folderId: $folderId, ')
          ..write('recordId: $recordId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ImageRecordsTableTable imageRecordsTable =
      $ImageRecordsTableTable(this);
  late final $FavoriteFoldersTableTable favoriteFoldersTable =
      $FavoriteFoldersTableTable(this);
  late final $FavoriteFolderItemsTableTable favoriteFolderItemsTable =
      $FavoriteFolderItemsTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    imageRecordsTable,
    favoriteFoldersTable,
    favoriteFolderItemsTable,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'favorite_folders_table',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [
        TableUpdate('favorite_folder_items_table', kind: UpdateKind.delete),
      ],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'image_records_table',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [
        TableUpdate('favorite_folder_items_table', kind: UpdateKind.delete),
      ],
    ),
  ]);
}

typedef $$ImageRecordsTableTableCreateCompanionBuilder =
    ImageRecordsTableCompanion Function({
      required String id,
      required String prompt,
      Value<String> apiProfileId,
      Value<String?> sourceImagePath,
      Value<String?> sourceImagePaths,
      Value<String?> resultImagePath,
      Value<String?> resultImageUrl,
      Value<String?> resultB64,
      required int width,
      required int height,
      required String quality,
      Value<String> outputFormat,
      required String model,
      required String status,
      Value<String?> errorMessage,
      Value<String?> rawApiResponseValue,
      required DateTime createdAt,
      Value<int?> durationMs,
      Value<bool> usedSingleImageFallback,
      Value<bool> isFavorite,
      Value<int> rowid,
    });
typedef $$ImageRecordsTableTableUpdateCompanionBuilder =
    ImageRecordsTableCompanion Function({
      Value<String> id,
      Value<String> prompt,
      Value<String> apiProfileId,
      Value<String?> sourceImagePath,
      Value<String?> sourceImagePaths,
      Value<String?> resultImagePath,
      Value<String?> resultImageUrl,
      Value<String?> resultB64,
      Value<int> width,
      Value<int> height,
      Value<String> quality,
      Value<String> outputFormat,
      Value<String> model,
      Value<String> status,
      Value<String?> errorMessage,
      Value<String?> rawApiResponseValue,
      Value<DateTime> createdAt,
      Value<int?> durationMs,
      Value<bool> usedSingleImageFallback,
      Value<bool> isFavorite,
      Value<int> rowid,
    });

final class $$ImageRecordsTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ImageRecordsTableTable,
          ImageRecordsTableData
        > {
  $$ImageRecordsTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<
    $FavoriteFolderItemsTableTable,
    List<FavoriteFolderItemsTableData>
  >
  _favoriteFolderItemsTableRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.favoriteFolderItemsTable,
        aliasName: $_aliasNameGenerator(
          db.imageRecordsTable.id,
          db.favoriteFolderItemsTable.recordId,
        ),
      );

  $$FavoriteFolderItemsTableTableProcessedTableManager
  get favoriteFolderItemsTableRefs {
    final manager = $$FavoriteFolderItemsTableTableTableManager(
      $_db,
      $_db.favoriteFolderItemsTable,
    ).filter((f) => f.recordId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _favoriteFolderItemsTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ImageRecordsTableTableFilterComposer
    extends Composer<_$AppDatabase, $ImageRecordsTableTable> {
  $$ImageRecordsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get prompt => $composableBuilder(
    column: $table.prompt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get apiProfileId => $composableBuilder(
    column: $table.apiProfileId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceImagePath => $composableBuilder(
    column: $table.sourceImagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceImagePaths => $composableBuilder(
    column: $table.sourceImagePaths,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resultImagePath => $composableBuilder(
    column: $table.resultImagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resultImageUrl => $composableBuilder(
    column: $table.resultImageUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resultB64 => $composableBuilder(
    column: $table.resultB64,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get quality => $composableBuilder(
    column: $table.quality,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outputFormat => $composableBuilder(
    column: $table.outputFormat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rawApiResponseValue => $composableBuilder(
    column: $table.rawApiResponseValue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get usedSingleImageFallback => $composableBuilder(
    column: $table.usedSingleImageFallback,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> favoriteFolderItemsTableRefs(
    Expression<bool> Function($$FavoriteFolderItemsTableTableFilterComposer f)
    f,
  ) {
    final $$FavoriteFolderItemsTableTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.favoriteFolderItemsTable,
          getReferencedColumn: (t) => t.recordId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FavoriteFolderItemsTableTableFilterComposer(
                $db: $db,
                $table: $db.favoriteFolderItemsTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ImageRecordsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ImageRecordsTableTable> {
  $$ImageRecordsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get prompt => $composableBuilder(
    column: $table.prompt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get apiProfileId => $composableBuilder(
    column: $table.apiProfileId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceImagePath => $composableBuilder(
    column: $table.sourceImagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceImagePaths => $composableBuilder(
    column: $table.sourceImagePaths,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resultImagePath => $composableBuilder(
    column: $table.resultImagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resultImageUrl => $composableBuilder(
    column: $table.resultImageUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resultB64 => $composableBuilder(
    column: $table.resultB64,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get width => $composableBuilder(
    column: $table.width,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get quality => $composableBuilder(
    column: $table.quality,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outputFormat => $composableBuilder(
    column: $table.outputFormat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rawApiResponseValue => $composableBuilder(
    column: $table.rawApiResponseValue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get usedSingleImageFallback => $composableBuilder(
    column: $table.usedSingleImageFallback,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ImageRecordsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ImageRecordsTableTable> {
  $$ImageRecordsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get prompt =>
      $composableBuilder(column: $table.prompt, builder: (column) => column);

  GeneratedColumn<String> get apiProfileId => $composableBuilder(
    column: $table.apiProfileId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceImagePath => $composableBuilder(
    column: $table.sourceImagePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceImagePaths => $composableBuilder(
    column: $table.sourceImagePaths,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resultImagePath => $composableBuilder(
    column: $table.resultImagePath,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resultImageUrl => $composableBuilder(
    column: $table.resultImageUrl,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resultB64 =>
      $composableBuilder(column: $table.resultB64, builder: (column) => column);

  GeneratedColumn<int> get width =>
      $composableBuilder(column: $table.width, builder: (column) => column);

  GeneratedColumn<int> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<String> get quality =>
      $composableBuilder(column: $table.quality, builder: (column) => column);

  GeneratedColumn<String> get outputFormat => $composableBuilder(
    column: $table.outputFormat,
    builder: (column) => column,
  );

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get errorMessage => $composableBuilder(
    column: $table.errorMessage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get rawApiResponseValue => $composableBuilder(
    column: $table.rawApiResponseValue,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get durationMs => $composableBuilder(
    column: $table.durationMs,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get usedSingleImageFallback => $composableBuilder(
    column: $table.usedSingleImageFallback,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
    column: $table.isFavorite,
    builder: (column) => column,
  );

  Expression<T> favoriteFolderItemsTableRefs<T extends Object>(
    Expression<T> Function($$FavoriteFolderItemsTableTableAnnotationComposer a)
    f,
  ) {
    final $$FavoriteFolderItemsTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.favoriteFolderItemsTable,
          getReferencedColumn: (t) => t.recordId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FavoriteFolderItemsTableTableAnnotationComposer(
                $db: $db,
                $table: $db.favoriteFolderItemsTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$ImageRecordsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ImageRecordsTableTable,
          ImageRecordsTableData,
          $$ImageRecordsTableTableFilterComposer,
          $$ImageRecordsTableTableOrderingComposer,
          $$ImageRecordsTableTableAnnotationComposer,
          $$ImageRecordsTableTableCreateCompanionBuilder,
          $$ImageRecordsTableTableUpdateCompanionBuilder,
          (ImageRecordsTableData, $$ImageRecordsTableTableReferences),
          ImageRecordsTableData,
          PrefetchHooks Function({bool favoriteFolderItemsTableRefs})
        > {
  $$ImageRecordsTableTableTableManager(
    _$AppDatabase db,
    $ImageRecordsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ImageRecordsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ImageRecordsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ImageRecordsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> prompt = const Value.absent(),
                Value<String> apiProfileId = const Value.absent(),
                Value<String?> sourceImagePath = const Value.absent(),
                Value<String?> sourceImagePaths = const Value.absent(),
                Value<String?> resultImagePath = const Value.absent(),
                Value<String?> resultImageUrl = const Value.absent(),
                Value<String?> resultB64 = const Value.absent(),
                Value<int> width = const Value.absent(),
                Value<int> height = const Value.absent(),
                Value<String> quality = const Value.absent(),
                Value<String> outputFormat = const Value.absent(),
                Value<String> model = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> errorMessage = const Value.absent(),
                Value<String?> rawApiResponseValue = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int?> durationMs = const Value.absent(),
                Value<bool> usedSingleImageFallback = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ImageRecordsTableCompanion(
                id: id,
                prompt: prompt,
                apiProfileId: apiProfileId,
                sourceImagePath: sourceImagePath,
                sourceImagePaths: sourceImagePaths,
                resultImagePath: resultImagePath,
                resultImageUrl: resultImageUrl,
                resultB64: resultB64,
                width: width,
                height: height,
                quality: quality,
                outputFormat: outputFormat,
                model: model,
                status: status,
                errorMessage: errorMessage,
                rawApiResponseValue: rawApiResponseValue,
                createdAt: createdAt,
                durationMs: durationMs,
                usedSingleImageFallback: usedSingleImageFallback,
                isFavorite: isFavorite,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String prompt,
                Value<String> apiProfileId = const Value.absent(),
                Value<String?> sourceImagePath = const Value.absent(),
                Value<String?> sourceImagePaths = const Value.absent(),
                Value<String?> resultImagePath = const Value.absent(),
                Value<String?> resultImageUrl = const Value.absent(),
                Value<String?> resultB64 = const Value.absent(),
                required int width,
                required int height,
                required String quality,
                Value<String> outputFormat = const Value.absent(),
                required String model,
                required String status,
                Value<String?> errorMessage = const Value.absent(),
                Value<String?> rawApiResponseValue = const Value.absent(),
                required DateTime createdAt,
                Value<int?> durationMs = const Value.absent(),
                Value<bool> usedSingleImageFallback = const Value.absent(),
                Value<bool> isFavorite = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ImageRecordsTableCompanion.insert(
                id: id,
                prompt: prompt,
                apiProfileId: apiProfileId,
                sourceImagePath: sourceImagePath,
                sourceImagePaths: sourceImagePaths,
                resultImagePath: resultImagePath,
                resultImageUrl: resultImageUrl,
                resultB64: resultB64,
                width: width,
                height: height,
                quality: quality,
                outputFormat: outputFormat,
                model: model,
                status: status,
                errorMessage: errorMessage,
                rawApiResponseValue: rawApiResponseValue,
                createdAt: createdAt,
                durationMs: durationMs,
                usedSingleImageFallback: usedSingleImageFallback,
                isFavorite: isFavorite,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ImageRecordsTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({favoriteFolderItemsTableRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (favoriteFolderItemsTableRefs) db.favoriteFolderItemsTable,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (favoriteFolderItemsTableRefs)
                    await $_getPrefetchedData<
                      ImageRecordsTableData,
                      $ImageRecordsTableTable,
                      FavoriteFolderItemsTableData
                    >(
                      currentTable: table,
                      referencedTable: $$ImageRecordsTableTableReferences
                          ._favoriteFolderItemsTableRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$ImageRecordsTableTableReferences(
                            db,
                            table,
                            p0,
                          ).favoriteFolderItemsTableRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.recordId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$ImageRecordsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ImageRecordsTableTable,
      ImageRecordsTableData,
      $$ImageRecordsTableTableFilterComposer,
      $$ImageRecordsTableTableOrderingComposer,
      $$ImageRecordsTableTableAnnotationComposer,
      $$ImageRecordsTableTableCreateCompanionBuilder,
      $$ImageRecordsTableTableUpdateCompanionBuilder,
      (ImageRecordsTableData, $$ImageRecordsTableTableReferences),
      ImageRecordsTableData,
      PrefetchHooks Function({bool favoriteFolderItemsTableRefs})
    >;
typedef $$FavoriteFoldersTableTableCreateCompanionBuilder =
    FavoriteFoldersTableCompanion Function({
      required String id,
      required String title,
      Value<bool> isDefault,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$FavoriteFoldersTableTableUpdateCompanionBuilder =
    FavoriteFoldersTableCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<bool> isDefault,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$FavoriteFoldersTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $FavoriteFoldersTableTable,
          FavoriteFoldersTableData
        > {
  $$FavoriteFoldersTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<
    $FavoriteFolderItemsTableTable,
    List<FavoriteFolderItemsTableData>
  >
  _favoriteFolderItemsTableRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.favoriteFolderItemsTable,
        aliasName: $_aliasNameGenerator(
          db.favoriteFoldersTable.id,
          db.favoriteFolderItemsTable.folderId,
        ),
      );

  $$FavoriteFolderItemsTableTableProcessedTableManager
  get favoriteFolderItemsTableRefs {
    final manager = $$FavoriteFolderItemsTableTableTableManager(
      $_db,
      $_db.favoriteFolderItemsTable,
    ).filter((f) => f.folderId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _favoriteFolderItemsTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$FavoriteFoldersTableTableFilterComposer
    extends Composer<_$AppDatabase, $FavoriteFoldersTableTable> {
  $$FavoriteFoldersTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> favoriteFolderItemsTableRefs(
    Expression<bool> Function($$FavoriteFolderItemsTableTableFilterComposer f)
    f,
  ) {
    final $$FavoriteFolderItemsTableTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.favoriteFolderItemsTable,
          getReferencedColumn: (t) => t.folderId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FavoriteFolderItemsTableTableFilterComposer(
                $db: $db,
                $table: $db.favoriteFolderItemsTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$FavoriteFoldersTableTableOrderingComposer
    extends Composer<_$AppDatabase, $FavoriteFoldersTableTable> {
  $$FavoriteFoldersTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FavoriteFoldersTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $FavoriteFoldersTableTable> {
  $$FavoriteFoldersTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> favoriteFolderItemsTableRefs<T extends Object>(
    Expression<T> Function($$FavoriteFolderItemsTableTableAnnotationComposer a)
    f,
  ) {
    final $$FavoriteFolderItemsTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.favoriteFolderItemsTable,
          getReferencedColumn: (t) => t.folderId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FavoriteFolderItemsTableTableAnnotationComposer(
                $db: $db,
                $table: $db.favoriteFolderItemsTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$FavoriteFoldersTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FavoriteFoldersTableTable,
          FavoriteFoldersTableData,
          $$FavoriteFoldersTableTableFilterComposer,
          $$FavoriteFoldersTableTableOrderingComposer,
          $$FavoriteFoldersTableTableAnnotationComposer,
          $$FavoriteFoldersTableTableCreateCompanionBuilder,
          $$FavoriteFoldersTableTableUpdateCompanionBuilder,
          (FavoriteFoldersTableData, $$FavoriteFoldersTableTableReferences),
          FavoriteFoldersTableData,
          PrefetchHooks Function({bool favoriteFolderItemsTableRefs})
        > {
  $$FavoriteFoldersTableTableTableManager(
    _$AppDatabase db,
    $FavoriteFoldersTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FavoriteFoldersTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FavoriteFoldersTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$FavoriteFoldersTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FavoriteFoldersTableCompanion(
                id: id,
                title: title,
                isDefault: isDefault,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                Value<bool> isDefault = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => FavoriteFoldersTableCompanion.insert(
                id: id,
                title: title,
                isDefault: isDefault,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FavoriteFoldersTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({favoriteFolderItemsTableRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (favoriteFolderItemsTableRefs) db.favoriteFolderItemsTable,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (favoriteFolderItemsTableRefs)
                    await $_getPrefetchedData<
                      FavoriteFoldersTableData,
                      $FavoriteFoldersTableTable,
                      FavoriteFolderItemsTableData
                    >(
                      currentTable: table,
                      referencedTable: $$FavoriteFoldersTableTableReferences
                          ._favoriteFolderItemsTableRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$FavoriteFoldersTableTableReferences(
                            db,
                            table,
                            p0,
                          ).favoriteFolderItemsTableRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.folderId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$FavoriteFoldersTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FavoriteFoldersTableTable,
      FavoriteFoldersTableData,
      $$FavoriteFoldersTableTableFilterComposer,
      $$FavoriteFoldersTableTableOrderingComposer,
      $$FavoriteFoldersTableTableAnnotationComposer,
      $$FavoriteFoldersTableTableCreateCompanionBuilder,
      $$FavoriteFoldersTableTableUpdateCompanionBuilder,
      (FavoriteFoldersTableData, $$FavoriteFoldersTableTableReferences),
      FavoriteFoldersTableData,
      PrefetchHooks Function({bool favoriteFolderItemsTableRefs})
    >;
typedef $$FavoriteFolderItemsTableTableCreateCompanionBuilder =
    FavoriteFolderItemsTableCompanion Function({
      required String folderId,
      required String recordId,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$FavoriteFolderItemsTableTableUpdateCompanionBuilder =
    FavoriteFolderItemsTableCompanion Function({
      Value<String> folderId,
      Value<String> recordId,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

final class $$FavoriteFolderItemsTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $FavoriteFolderItemsTableTable,
          FavoriteFolderItemsTableData
        > {
  $$FavoriteFolderItemsTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $FavoriteFoldersTableTable _folderIdTable(_$AppDatabase db) =>
      db.favoriteFoldersTable.createAlias(
        $_aliasNameGenerator(
          db.favoriteFolderItemsTable.folderId,
          db.favoriteFoldersTable.id,
        ),
      );

  $$FavoriteFoldersTableTableProcessedTableManager get folderId {
    final $_column = $_itemColumn<String>('folder_id')!;

    final manager = $$FavoriteFoldersTableTableTableManager(
      $_db,
      $_db.favoriteFoldersTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_folderIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ImageRecordsTableTable _recordIdTable(_$AppDatabase db) =>
      db.imageRecordsTable.createAlias(
        $_aliasNameGenerator(
          db.favoriteFolderItemsTable.recordId,
          db.imageRecordsTable.id,
        ),
      );

  $$ImageRecordsTableTableProcessedTableManager get recordId {
    final $_column = $_itemColumn<String>('record_id')!;

    final manager = $$ImageRecordsTableTableTableManager(
      $_db,
      $_db.imageRecordsTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_recordIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FavoriteFolderItemsTableTableFilterComposer
    extends Composer<_$AppDatabase, $FavoriteFolderItemsTableTable> {
  $$FavoriteFolderItemsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$FavoriteFoldersTableTableFilterComposer get folderId {
    final $$FavoriteFoldersTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.favoriteFoldersTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FavoriteFoldersTableTableFilterComposer(
            $db: $db,
            $table: $db.favoriteFoldersTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ImageRecordsTableTableFilterComposer get recordId {
    final $$ImageRecordsTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recordId,
      referencedTable: $db.imageRecordsTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImageRecordsTableTableFilterComposer(
            $db: $db,
            $table: $db.imageRecordsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FavoriteFolderItemsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $FavoriteFolderItemsTableTable> {
  $$FavoriteFolderItemsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$FavoriteFoldersTableTableOrderingComposer get folderId {
    final $$FavoriteFoldersTableTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.folderId,
          referencedTable: $db.favoriteFoldersTable,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FavoriteFoldersTableTableOrderingComposer(
                $db: $db,
                $table: $db.favoriteFoldersTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  $$ImageRecordsTableTableOrderingComposer get recordId {
    final $$ImageRecordsTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recordId,
      referencedTable: $db.imageRecordsTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImageRecordsTableTableOrderingComposer(
            $db: $db,
            $table: $db.imageRecordsTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FavoriteFolderItemsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $FavoriteFolderItemsTableTable> {
  $$FavoriteFolderItemsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$FavoriteFoldersTableTableAnnotationComposer get folderId {
    final $$FavoriteFoldersTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.folderId,
          referencedTable: $db.favoriteFoldersTable,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FavoriteFoldersTableTableAnnotationComposer(
                $db: $db,
                $table: $db.favoriteFoldersTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  $$ImageRecordsTableTableAnnotationComposer get recordId {
    final $$ImageRecordsTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.recordId,
          referencedTable: $db.imageRecordsTable,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ImageRecordsTableTableAnnotationComposer(
                $db: $db,
                $table: $db.imageRecordsTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$FavoriteFolderItemsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FavoriteFolderItemsTableTable,
          FavoriteFolderItemsTableData,
          $$FavoriteFolderItemsTableTableFilterComposer,
          $$FavoriteFolderItemsTableTableOrderingComposer,
          $$FavoriteFolderItemsTableTableAnnotationComposer,
          $$FavoriteFolderItemsTableTableCreateCompanionBuilder,
          $$FavoriteFolderItemsTableTableUpdateCompanionBuilder,
          (
            FavoriteFolderItemsTableData,
            $$FavoriteFolderItemsTableTableReferences,
          ),
          FavoriteFolderItemsTableData,
          PrefetchHooks Function({bool folderId, bool recordId})
        > {
  $$FavoriteFolderItemsTableTableTableManager(
    _$AppDatabase db,
    $FavoriteFolderItemsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FavoriteFolderItemsTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$FavoriteFolderItemsTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$FavoriteFolderItemsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> folderId = const Value.absent(),
                Value<String> recordId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FavoriteFolderItemsTableCompanion(
                folderId: folderId,
                recordId: recordId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String folderId,
                required String recordId,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => FavoriteFolderItemsTableCompanion.insert(
                folderId: folderId,
                recordId: recordId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FavoriteFolderItemsTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({folderId = false, recordId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (folderId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.folderId,
                                referencedTable:
                                    $$FavoriteFolderItemsTableTableReferences
                                        ._folderIdTable(db),
                                referencedColumn:
                                    $$FavoriteFolderItemsTableTableReferences
                                        ._folderIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (recordId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.recordId,
                                referencedTable:
                                    $$FavoriteFolderItemsTableTableReferences
                                        ._recordIdTable(db),
                                referencedColumn:
                                    $$FavoriteFolderItemsTableTableReferences
                                        ._recordIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$FavoriteFolderItemsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FavoriteFolderItemsTableTable,
      FavoriteFolderItemsTableData,
      $$FavoriteFolderItemsTableTableFilterComposer,
      $$FavoriteFolderItemsTableTableOrderingComposer,
      $$FavoriteFolderItemsTableTableAnnotationComposer,
      $$FavoriteFolderItemsTableTableCreateCompanionBuilder,
      $$FavoriteFolderItemsTableTableUpdateCompanionBuilder,
      (FavoriteFolderItemsTableData, $$FavoriteFolderItemsTableTableReferences),
      FavoriteFolderItemsTableData,
      PrefetchHooks Function({bool folderId, bool recordId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ImageRecordsTableTableTableManager get imageRecordsTable =>
      $$ImageRecordsTableTableTableManager(_db, _db.imageRecordsTable);
  $$FavoriteFoldersTableTableTableManager get favoriteFoldersTable =>
      $$FavoriteFoldersTableTableTableManager(_db, _db.favoriteFoldersTable);
  $$FavoriteFolderItemsTableTableTableManager get favoriteFolderItemsTable =>
      $$FavoriteFolderItemsTableTableTableManager(
        _db,
        _db.favoriteFolderItemsTable,
      );
}
