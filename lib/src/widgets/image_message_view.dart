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
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:chatview/src/extensions/extensions.dart';
import 'package:chatview/src/models/models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'reaction_widget.dart';
import 'share_icon.dart';

class ImageMessageView extends StatelessWidget {
  const ImageMessageView({
    Key? key,
    required this.message,
    required this.isMessageBySender,
    this.imageMessageConfig,
    this.messageReactionConfig,
    this.highlightImage = false,
    this.highlightScale = 1.2,
  }) : super(key: key);

  /// Provides message instance of chat.
  final Message message;

  /// Represents current message is sent by current user.
  final bool isMessageBySender;

  /// Provides configuration for image message appearance.
  final ImageMessageConfiguration? imageMessageConfig;

  /// Provides configuration of reaction appearance in chat bubble.
  final MessageReactionConfiguration? messageReactionConfig;

  /// Represents flag of highlighting image when user taps on replied image.
  final bool highlightImage;

  /// Provides scale of highlighted image when user taps on replied image.
  final double highlightScale;


  String get imageUrl => message.message;

  Widget get iconButton => ShareIcon(
    shareIconConfig: imageMessageConfig?.shareIconConfig,
    imageUrl: imageUrl,
  );

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: isMessageBySender ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (isMessageBySender) iconButton,
        Stack(
          children: [
            GestureDetector(
              onTap: () => imageMessageConfig?.onTap != null ? imageMessageConfig?.onTap!(message) : null,
              child: Transform.scale(
                scale: highlightImage ? highlightScale : 1.0,
                alignment: isMessageBySender ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  padding: imageMessageConfig?.padding ?? EdgeInsets.zero,
                  margin: imageMessageConfig?.margin ??
                      EdgeInsets.only(
                        top: 6,
                        right: isMessageBySender ? 6 : 0,
                        left: isMessageBySender ? 0 : 6,
                        bottom: message.reaction.reactions.isNotEmpty ? 15 : 0,
                      ),
                  height: imageMessageConfig?.height ?? 200,
                  width: imageMessageConfig?.width ?? 150,
                  child: ClipRRect(
                    borderRadius: imageMessageConfig?.borderRadius ?? BorderRadius.circular(14),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildImageWidget(),
                        if (imageMessageConfig!.showBlurImage && !isMessageBySender)
                          BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                            child: Container(
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                        if (imageMessageConfig!.showBlurImage && imageMessageConfig?.imageCenterButton != null && !isMessageBySender)
                          Center(
                            child: imageMessageConfig?.imageCenterButton,
                          ),

                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (message.reaction.reactions.isNotEmpty)
              ReactionWidget(
                isMessageBySender: isMessageBySender,
                reaction: message.reaction,
                messageReactionConfig: messageReactionConfig,
              ),
          ],
        ),
       // if (!isMessageBySender) iconButton,
      ],
    );
  }

  Widget _buildImageWidget() {
    if (imageUrl.isUrl) {
      return Stack(
        fit: StackFit.expand,
        children: [
          // Cupertino loading indicator
          Center(
            child: CupertinoActivityIndicator(
              radius: 12,
              color: imageMessageConfig?.loaderColor,
            ),
          ),

          // Actual image with blur effect when needed
          Image.network(
            imageUrl,
            fit: BoxFit.fitHeight,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (frame == null) {
                return const SizedBox.shrink();
              }
              return Stack(
                fit: StackFit.expand,
                children: [
                  child,
                  if (imageMessageConfig!.showBlurImage && !isMessageBySender)
                    BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                      child: Container(
                        color: Colors.black.withOpacity(0.3),
                      ),
                    ),
                  if (imageMessageConfig!.showBlurImage && imageMessageConfig?.imageCenterButton != null && !isMessageBySender)
                    Center(
                      child: imageMessageConfig?.imageCenterButton,
                    ),
                ],
              );
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return child; // Return the frameBuilder's result, which will be empty until loaded
            },
          ),
        ],
      );
    } else if (imageUrl.fromMemory) {
      return Image.memory(
        base64Decode(imageUrl.substring(imageUrl.indexOf('base64') + 7)),
        fit: BoxFit.fill,
      );
    } else {
      return Image.file(
        File(imageUrl),
        fit: BoxFit.fill,
      );
    }
  }
}
