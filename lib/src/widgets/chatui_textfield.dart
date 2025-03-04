/*
 * Copyright (c) 2022 Simform Solutions
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
import 'dart:async';
import 'dart:convert';
import 'dart:io' show File, Platform;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:chatview/src/extensions/extensions.dart';
import 'package:chatview/src/utils/constants/constants.dart';
import 'package:chatview/src/widgets/emoji_picker_widget.dart';
import 'package:dart_emoji/dart_emoji.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../chatview.dart';
import '../utils/debounce.dart';
import '../utils/package_strings.dart';

class ChatUITextField extends StatefulWidget {
  const ChatUITextField({
    Key? key,
    this.sendMessageConfig,
    required this.focusNode,
    required this.textEditingController,
    required this.onPressed,
    required this.onRecordingComplete,
    required this.onImageSelected,
  }) : super(key: key);

  /// Provides configuration of default text field in chat.
  final SendMessageConfiguration? sendMessageConfig;

  /// Provides focusNode for focusing text field.
  final FocusNode focusNode;

  /// Provides functions which handles text field.
  final TextEditingController textEditingController;

  /// Provides callback when user tap on text field.
  final VoidCallBack onPressed;

  /// Provides callback once voice is recorded.
  final Function(String?) onRecordingComplete;

  /// Provides callback when user select images from camera/gallery.
  final StringsCallBack onImageSelected;

  @override
  State<ChatUITextField> createState() => _ChatUITextFieldState();
}

class _ChatUITextFieldState extends State<ChatUITextField> {
  final ValueNotifier<String> _inputText = ValueNotifier('');

  final ImagePicker _imagePicker = ImagePicker();

  RecorderController? controller;

  String recognizedText = "Value";

  ValueNotifier<bool> isRecording = ValueNotifier(false);

  SendMessageConfiguration? get sendMessageConfig => widget.sendMessageConfig;

  VoiceRecordingConfiguration? get voiceRecordingConfig => widget.sendMessageConfig?.voiceRecordingConfiguration;
  ImagePickerIconsConfiguration? get imagePickerIconsConfig =>
      sendMessageConfig?.imagePickerIconsConfig;

  TextFieldConfiguration? get textFieldConfig =>
      sendMessageConfig?.textFieldConfig;

  CancelRecordConfiguration? get cancelRecordConfiguration =>
      sendMessageConfig?.cancelRecordConfiguration;

  OutlineInputBorder get _outLineBorder => OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.transparent),
        borderRadius: widget.sendMessageConfig?.textFieldConfig?.borderRadius ??
            BorderRadius.circular(textFieldBorderRadius),
      );

  ValueNotifier<TypeWriterStatus> composingStatus =
      ValueNotifier(TypeWriterStatus.typed);

  late Debouncer debouncer;

  @override
  void initState() {
    attachListeners();
    debouncer = Debouncer(
        sendMessageConfig?.textFieldConfig?.compositionThresholdTime ??
            const Duration(seconds: 1));
    super.initState();

    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android) {
      controller = RecorderController();
    }
  }

  @override
  void dispose() {
    debouncer.dispose();
    composingStatus.dispose();
    isRecording.dispose();
    _inputText.dispose();
    super.dispose();
  }

  void attachListeners() {
    composingStatus.addListener(() {
      widget.sendMessageConfig?.textFieldConfig?.onMessageTyping
          ?.call(composingStatus.value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final outlineBorder = _outLineBorder;
    return Container(
      padding: textFieldConfig?.padding ?? const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        borderRadius: textFieldConfig?.borderRadius ?? BorderRadius.circular(textFieldBorderRadius),
        color: sendMessageConfig?.textFieldBackgroundColor ?? Colors.white,
      ),
      child: ValueListenableBuilder<bool>(
        valueListenable: isRecording,
        builder: (_, isRecordingValue, child) {
          return Row(
            children: [
              if (isRecordingValue && cancelRecordConfiguration != null)
                IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    cancelRecordConfiguration?.onCancel?.call();
                    _cancelRecording();
                  },
                  icon: cancelRecordConfiguration?.icon ??
                      const Icon(Icons.delete_outline, color: Colors.redAccent),
                  color: cancelRecordConfiguration?.iconColor ??
                      voiceRecordingConfig?.recorderIconColor,
                ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300), // Adjust the duration as needed
                  child: isRecordingValue && controller != null && !kIsWeb
                      ? AudioWaveforms(
                    key: ValueKey('audioWaveform'), // Unique key for the widget
                    size: const Size(double.infinity, 50),
                    recorderController: controller!,
                    margin: voiceRecordingConfig?.margin,
                    padding: voiceRecordingConfig?.padding ??
                        EdgeInsets.symmetric(
                          horizontal: cancelRecordConfiguration == null ? 8 : 5,
                        ),
                    decoration: voiceRecordingConfig?.decoration ??
                        BoxDecoration(
                          color: voiceRecordingConfig?.backgroundColor,
                          borderRadius: BorderRadius.circular(25.0),
                        ),
                    waveStyle: voiceRecordingConfig?.waveStyle ??
                        WaveStyle(
                          extendWaveform: true,
                          showMiddleLine: false,
                          waveColor: voiceRecordingConfig?.waveStyle?.waveColor ??
                              Colors.black,
                        ),
                  )
                      : TextField(
                    key: ValueKey('textField'), // Unique key for the widget
                    focusNode: widget.focusNode,
                    controller: widget.textEditingController,
                    style: textFieldConfig?.textStyle ??
                        const TextStyle(color: Colors.white),
                    maxLines: textFieldConfig?.maxLines ?? 5,
                    minLines: textFieldConfig?.minLines ?? 1,
                    keyboardType: textFieldConfig?.textInputType,
                    inputFormatters: textFieldConfig?.inputFormatters,
                    onChanged: _onChanged,
                    enabled: textFieldConfig?.enabled,
                    textCapitalization: textFieldConfig?.textCapitalization ??
                        TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: textFieldConfig?.hintText ?? PackageStrings.message,
                      prefixIcon: !(widget.sendMessageConfig?.enableEmojiPicker ?? false)
                          ? null
                          : IconButton(
                        icon: widget.sendMessageConfig?.emojiPickerIcon ??
                            const Icon(Icons.emoji_emotions_outlined),
                        onPressed: () => _showBottomSheet(context),
                      ),
                      fillColor: sendMessageConfig?.textFieldBackgroundColor ?? Colors.white,
                      filled: true,
                      hintStyle: textFieldConfig?.hintStyle ??
                          TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: Colors.grey.shade600,
                            letterSpacing: 0.25,
                          ),
                      contentPadding: textFieldConfig?.contentPadding ??
                          const EdgeInsets.symmetric(horizontal: 6),
                      border: outlineBorder,
                      focusedBorder: outlineBorder,
                      enabledBorder: outlineBorder,
                      disabledBorder: outlineBorder,
                    ),
                  ),
                ),
              ),
              ValueListenableBuilder<String>(
                valueListenable: _inputText,
                builder: (_, inputTextValue, child) {
                  final trimmedText = inputTextValue.trim();
                  final isNotEmpty = trimmedText.isNotEmpty;
                  final isOnlyEmoji = EmojiUtil.hasOnlyEmojis(trimmedText);
                  final showSendButton = isNotEmpty || !isOnlyEmoji;

                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300), // Adjust the duration as needed
                    child: showSendButton
                        ? IconButton(
                      key: ValueKey('sendButton'), // Unique key for the widget
                      color: sendMessageConfig?.defaultSendButtonColor ?? Colors.green,
                      onPressed: (textFieldConfig?.enabled ?? true)
                          ? () {
                        widget.onPressed();
                        _inputText.value = '';
                      }
                          : null,
                      icon: sendMessageConfig?.sendButtonIcon ?? const Icon(Icons.send),
                    )
                        : Row(
                      key: ValueKey('iconRow'), // Unique key for the widget
                      children: [
                        if (!isRecordingValue) ...[
                          if (sendMessageConfig?.enableCameraImagePicker ?? true)
                            IconButton(
                              constraints: const BoxConstraints(),
                              onPressed: (textFieldConfig?.enabled ?? true)
                                  ? () => _onIconPressed(
                                ImageSource.camera,
                                config: sendMessageConfig?.imagePickerConfiguration,
                              )
                                  : null,
                              icon: imagePickerIconsConfig?.cameraImagePickerIcon ??
                                  Icon(
                                    Icons.camera_alt_outlined,
                                    color: imagePickerIconsConfig?.cameraIconColor,
                                  ),
                            ),
                          if (sendMessageConfig?.enableGalleryImagePicker ?? true)
                            IconButton(
                              constraints: const BoxConstraints(),
                              onPressed: (textFieldConfig?.enabled ?? true)
                                  ? () => _onIconPressed(
                                ImageSource.gallery,
                                config: sendMessageConfig?.imagePickerConfiguration,
                              )
                                  : null,
                              icon: imagePickerIconsConfig?.galleryImagePickerIcon ??
                                  Icon(
                                    Icons.image,
                                    color: imagePickerIconsConfig?.galleryIconColor,
                                  ),
                            ),
                        ],
                        if ((sendMessageConfig?.allowRecordingVoice ?? false) && !kIsWeb && (Platform.isIOS || Platform.isAndroid))
                          IconButton(
                            key: ValueKey('recordButton'), // Unique key for the widget
                            padding: EdgeInsets.zero,
                            onPressed: (textFieldConfig?.enabled ?? true)
                                ? _recordOrStop
                                : null,
                            icon: (isRecordingValue
                                ? voiceRecordingConfig?.stopIcon
                                : voiceRecordingConfig?.micIcon) ??
                                Container(
                                  decoration: const BoxDecoration(
                                    color: Color(0x197B61FF), // Light purple color
                                    shape: BoxShape.circle, // Circular shape
                                  ),
                                  padding: const EdgeInsets.all(7.0), // Adjust padding as needed
                                  child: Icon(
                                    isRecordingValue ? Icons.stop : Icons.mic,
                                    color: voiceRecordingConfig?.recorderIconColor,
                                  ),
                                ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showBottomSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (newContext) => EmojiPickerWidget(
        emojiPickerSheetConfig: context.chatListConfig.emojiPickerSheetConfig,
        onSelected: (emoji) {
          Navigator.pop(newContext);
          // Get the current text and add the selected emoji
          final updatedText = widget.textEditingController.text + emoji;
          widget.textEditingController.text = updatedText;
          _inputText.value = updatedText; // Notify listeners of the new text
          widget.textEditingController.selection = TextSelection.fromPosition(
            TextPosition(offset: updatedText.length),
          ); // Move cursor to the end
        },
      ),
    );
  }

  FutureOr<void> _cancelRecording() async {
    assert(
      defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android,
      "Voice messages are only supported with android and ios platform",
    );
    if (!isRecording.value) return;
    final path = await controller?.stop();
    if (path == null) {
      isRecording.value = false;
      return;
    }
    final file = File(path);

    if (await file.exists()) {
      await file.delete();
    }

    isRecording.value = false;
  }

  // Future<void> _recordOrStop() async {
  //   assert(
  //     defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android,
  //     "Voice messages are only supported with android and ios platform",
  //   );
  //   if (!isRecording.value) {
  //     await controller?.record(
  //       sampleRate: voiceRecordingConfig?.sampleRate,
  //       bitRate: voiceRecordingConfig?.bitRate,
  //       androidEncoder: voiceRecordingConfig?.androidEncoder,
  //       iosEncoder: voiceRecordingConfig?.iosEncoder,
  //       androidOutputFormat: voiceRecordingConfig?.androidOutputFormat,
  //     );
  //     isRecording.value = true;
  //   } else {
  //     final path = await controller?.stop();
  //     isRecording.value = false;
  //     widget.onRecordingComplete(path);
  //   }
  // }


  Future<void> _recordOrStop() async {
    assert(
    defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android,
    "Voice messages are only supported with android and ios platform",
    );

    final stt.SpeechToText speech = stt.SpeechToText();
    bool isSpeechAvailable = false;

    if (!isRecording.value) {
      // Start recording and speech recognition
      isSpeechAvailable = await speech.initialize();
      if (isSpeechAvailable) {
        speech.listen(
          onResult: (result) {
            recognizedText = result.recognizedWords; // Update recognized text
            debugPrint("Recognized Text: $recognizedText");
          },
          listenFor: const Duration(minutes: 1), // Listen for a longer duration
          pauseFor: const Duration(seconds: 5), // Pause for a short duration
        partialResults: true
        );

        await controller?.record(
          sampleRate: voiceRecordingConfig?.sampleRate,
          bitRate: voiceRecordingConfig?.bitRate,
          androidEncoder: voiceRecordingConfig?.androidEncoder,
          iosEncoder: voiceRecordingConfig?.iosEncoder,
          androidOutputFormat: voiceRecordingConfig?.androidOutputFormat,
        );
        isRecording.value = true;
      } else {
        print("Speech recognition not available");
      }
    } else {
      // Stop recording and speech recognition
      final path = await controller?.stop();
      speech.stop();
      // Ensure recognizedText is updated
      debugPrint("Final Recognized Text: $recognizedText");
      // Convert map to JSON string
      String result = jsonEncode({
        "path": path,
        "text": recognizedText,
      });

      // Send the result
      widget.onRecordingComplete(result);
      isRecording.value = false;
    }
  }


  void _onIconPressed(
    ImageSource imageSource, {
    ImagePickerConfiguration? config,
  }) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: imageSource,
        maxHeight: config?.maxHeight,
        maxWidth: config?.maxWidth,
        imageQuality: config?.imageQuality,
        preferredCameraDevice:
            config?.preferredCameraDevice ?? CameraDevice.rear,
      );
      String? imagePath = image?.path;
      if (config?.onImagePicked != null) {
        String? updatedImagePath = await config?.onImagePicked!(imagePath);
        if (updatedImagePath != null) imagePath = updatedImagePath;
      }
      widget.onImageSelected(imagePath ?? '', '');
    } catch (e) {
      widget.onImageSelected('', e.toString());
    }
  }

  void _onChanged(String inputText) {
    debouncer.run(() {
      composingStatus.value = TypeWriterStatus.typed;
    }, () {
      composingStatus.value = TypeWriterStatus.typing;
    });
    _inputText.value = inputText;
  }
}
