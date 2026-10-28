import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shares the draft with the compact editor so every way of leaving keeps edits.
class PromptEditorPage extends StatelessWidget {
  const PromptEditorPage({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('编辑提示词'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('完成'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              key: const Key('fullscreen-prompt-input'),
              controller: controller,
              autofocus: true,
              selectAllOnFocus: false,
              expands: true,
              minLines: null,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                hintText: '描述你想生成的画面',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
