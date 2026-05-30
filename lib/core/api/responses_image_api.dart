import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/generation_request.dart';
import '../models/generation_result.dart';
import '../models/settings_model.dart';
import 'openai_client.dart';

Map<String, dynamic> buildResponsesImageBody({
  required GenerationRequest request,
  required ApiProfile profile,
  required Object input,
  required String action,
}) {
  return <String, dynamic>{
    'model': profile.model,
    'input': input,
    'tools': [buildResponsesImageTool(request: request, action: action)],
    'tool_choice': 'required',
  };
}

Map<String, dynamic> buildResponsesImageTool({
  required GenerationRequest request,
  required String action,
}) {
  final tool = <String, dynamic>{
    'type': 'image_generation',
    'action': action,
    'quality': request.quality.apiValue,
    'output_format': request.outputFormat.apiValue,
  };

  final size = request.apiSize;
  if (size != null) {
    tool['size'] = size;
  }

  return tool;
}

List<GenerationResult> parseResponsesImageResults(
  Map<String, dynamic> response,
) {
  final output = response['output'];
  if (output is! List || output.isEmpty) {
    throw const ApiException('Responses API 没有返回 output 图片结果。');
  }

  final results = <GenerationResult>[];
  for (final item in output) {
    if (item is! Map) {
      continue;
    }
    final map = Map<String, dynamic>.from(item);
    if (map['type'] != 'image_generation_call') {
      continue;
    }

    final b64Json = _extractResultBase64(map['result']);
    if (b64Json == null) {
      continue;
    }

    results.add(GenerationResult(b64Json: b64Json, rawResponseValue: b64Json));
  }

  if (results.isEmpty) {
    throw const ApiException(
      'Responses API 返回成功，但没有找到 image_generation_call 图片结果。',
    );
  }

  return results;
}

Future<String> imagePathToDataUrl(String path) async {
  final bytes = await File(path).readAsBytes();
  return 'data:${_mimeTypeForPath(path)};base64,${base64Encode(bytes)}';
}

String? _extractResultBase64(Object? result) {
  final b64 = switch (result) {
    String value => value,
    Map value => _extractBase64FromMap(Map<String, dynamic>.from(value)),
    _ => '',
  };

  final trimmed = b64.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _extractBase64FromMap(Map<String, dynamic> result) {
  return switch (result) {
    {'b64_json': final String value} => value,
    {'base64': final String value} => value,
    {'image': final String value} => value,
    {'data': final String value} => value,
    _ => '',
  };
}

String _mimeTypeForPath(String path) {
  return switch (p.extension(path).toLowerCase()) {
    '.jpg' || '.jpeg' => 'image/jpeg',
    '.webp' => 'image/webp',
    '.gif' => 'image/gif',
    _ => 'image/png',
  };
}
