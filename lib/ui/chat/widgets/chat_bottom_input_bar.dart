import 'package:flutter/material.dart';
import '../../../core/storage/key_vault.dart';
import '../../../l10n/app_localizations.dart';

class ChatBottomInputBar extends StatelessWidget {
  final TextEditingController textController;
  final FocusNode inputFocusNode;
  final bool isWorking;
  final ApprovalMode approvalMode;
  final ThinkingIntensity thinkingIntensity;
  final String activeModel;
  final String displayModelName;
  final String approvalModeLabel;
  final IconData approvalModeIcon;
  final String thinkingShortLabel;
  final VoidCallback onAttachmentTap;
  final VoidCallback onApprovalModeTap;
  final VoidCallback onThinkingTap;
  final VoidCallback onSend;
  final VoidCallback onStop;

  const ChatBottomInputBar({
    super.key,
    required this.textController,
    required this.inputFocusNode,
    required this.isWorking,
    required this.approvalMode,
    required this.thinkingIntensity,
    required this.activeModel,
    required this.displayModelName,
    required this.approvalModeLabel,
    required this.approvalModeIcon,
    required this.thinkingShortLabel,
    required this.onAttachmentTap,
    required this.onApprovalModeTap,
    required this.onThinkingTap,
    required this.onSend,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 4,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF212121) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark ? const Color(0xFF333333) : const Color(0xFFE5E7EB),
            width: 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Multiline Input Field
            TextField(
              controller: textController,
              focusNode: inputFocusNode,
              autofocus: false,
              minLines: 2,
              maxLines: 6,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              onTapOutside: (_) {
                inputFocusNode.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
                FocusManager.instance.primaryFocus?.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
              },
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white : Colors.black87,
                height: 1.35,
              ),
              decoration: InputDecoration.collapsed(
                hintText: isWorking ? l10n.inputHintWorking : l10n.inputBoxHint,
                hintStyle: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Bottom Action Bar
            Row(
              children: [
                // + Attachment Button
                Material(
                  color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFE5E7EB),
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onAttachmentTap,
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: Icon(
                        Icons.add,
                        size: 18,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Approval Mode Pill
                Material(
                  color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onApprovalModeTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFD1D5DB),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            approvalModeIcon,
                            size: 14,
                            color: approvalMode == ApprovalMode.yolo
                                ? Colors.amber
                                : (isDark ? Colors.white70 : Colors.black87),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            approvalModeLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.keyboard_arrow_down,
                            size: 14,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Model & Thinking Intensity Pill
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Material(
                      color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: onThinkingTap,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFD1D5DB),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  activeModel.isEmpty
                                      ? l10n.noModelsConfigured
                                      : '$displayModelName $thinkingShortLabel',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.white70 : Colors.black87,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                Icons.keyboard_arrow_down,
                                size: 14,
                                color: isDark ? Colors.white54 : Colors.black54,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Send / Stop Circular Button (Fine-grained reactive via ValueListenableBuilder)
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: textController,
                  builder: (context, textValue, _) {
                    final hasText = textValue.text.trim().isNotEmpty;
                    return Material(
                      color: isWorking
                          ? Colors.redAccent
                          : (hasText
                              ? theme.colorScheme.primary
                              : (isDark ? const Color(0xFF2C2C2C) : const Color(0xFFE0E0E0))),
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: isWorking ? onStop : (hasText ? onSend : null),
                        child: SizedBox(
                          width: 32,
                          height: 32,
                          child: Icon(
                            isWorking ? Icons.stop_rounded : Icons.arrow_upward_rounded,
                            size: 18,
                            color: isWorking || hasText
                                ? Colors.white
                                : (isDark ? Colors.white30 : Colors.black26),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
