import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/agent_event.dart';

class ToolApprovalCard extends StatelessWidget {
  final ToolCallEvent toolCall;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onViewDiff;

  const ToolApprovalCard({
    super.key,
    required this.toolCall,
    this.onApprove,
    this.onReject,
    this.onViewDiff,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isPending = toolCall.status == ToolCallStatus.pending;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      decoration: BoxDecoration(
        color: _getCardBackground(theme),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getCardBorderColor(theme),
          width: isPending ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Icon + Name + Status Badge
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
            child: Row(
              children: [
                Icon(_getToolIcon(toolCall.toolName), size: 18, color: _getStatusColor(theme)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    toolCall.toolName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                _buildStatusChip(theme, l10n),
              ],
            ),
          ),

          // Arguments Summary
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: _buildArgumentsPreview(theme),
          ),

          // Result / Error Preview if completed/failed
          if (toolCall.status == ToolCallStatus.completed && toolCall.result != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  toolCall.result is String
                      ? toolCall.result
                      : const JsonEncoder.withIndent('  ').convert(toolCall.result),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
            ),

          if (toolCall.status == ToolCallStatus.failed && toolCall.errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
              child: Text(
                'Error: ${toolCall.errorMessage}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
              ),
            ),

          // Actions Bar for Pending Approval
          if (isPending) ...[
            const Divider(height: 12),
            Padding(
              padding: const EdgeInsets.only(left: 12.0, right: 12.0, bottom: 10.0),
              child: Row(
                children: [
                  if (onViewDiff != null &&
                      (toolCall.toolName == 'write_file' || toolCall.toolName == 'patch_file'))
                    OutlinedButton.icon(
                      onPressed: onViewDiff,
                      icon: const Icon(Icons.difference_outlined, size: 16),
                      label: Text(l10n?.reviewDiff ?? 'Review Diff'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: onReject,
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(l10n?.reject ?? 'Reject'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check, size: 16),
                    label: Text(l10n?.approve ?? 'Approve'),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
          ] else
            const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildArgumentsPreview(ThemeData theme) {
    final args = toolCall.arguments;
    if (toolCall.toolName == 'run_command') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '\$ ${args['command'] ?? ''}',
          style: theme.textTheme.bodySmall?.copyWith(
            fontFamily: 'monospace',
            color: Colors.greenAccent,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (args.containsKey('path')) {
      return Row(
        children: [
          Icon(Icons.insert_drive_file_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              args['path'].toString(),
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      );
    }

    return Text(
      args.toString(),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
    );
  }

  Widget _buildStatusChip(ThemeData theme, AppLocalizations? l10n) {
    String label;
    Color color;

    switch (toolCall.status) {
      case ToolCallStatus.pending:
        label = l10n?.needsApproval ?? 'Needs Approval';
        color = Colors.amber;
        break;
      case ToolCallStatus.approved:
        label = l10n?.approved ?? 'Approved';
        color = Colors.lightBlue;
        break;
      case ToolCallStatus.executing:
        label = l10n?.executing ?? 'Running...';
        color = Colors.lightBlueAccent;
        break;
      case ToolCallStatus.completed:
        label = toolCall.autoApproved
            ? (l10n?.autoExecuted ?? 'Auto Executed')
            : (l10n?.completed ?? 'Completed');
        color = Colors.green;
        break;
      case ToolCallStatus.rejected:
        label = l10n?.rejected ?? 'Rejected';
        color = Colors.redAccent;
        break;
      case ToolCallStatus.failed:
        label = l10n?.failed ?? 'Failed';
        color = Colors.red;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getCardBackground(ThemeData theme) {
    if (toolCall.status == ToolCallStatus.pending) {
      return Colors.amber.withValues(alpha: 0.08);
    }
    return theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25);
  }

  Color _getCardBorderColor(ThemeData theme) {
    if (toolCall.status == ToolCallStatus.pending) {
      return Colors.amber.withValues(alpha: 0.6);
    }
    return theme.colorScheme.outlineVariant.withValues(alpha: 0.3);
  }

  Color _getStatusColor(ThemeData theme) {
    switch (toolCall.status) {
      case ToolCallStatus.pending:
        return Colors.amber;
      case ToolCallStatus.completed:
        return Colors.green;
      case ToolCallStatus.failed:
      case ToolCallStatus.rejected:
        return Colors.redAccent;
      default:
        return theme.colorScheme.primary;
    }
  }

  IconData _getToolIcon(String name) {
    switch (name) {
      case 'read_file':
        return Icons.menu_book_outlined;
      case 'write_file':
      case 'patch_file':
        return Icons.edit_note_outlined;
      case 'list_directory':
        return Icons.folder_open_outlined;
      case 'search_files':
        return Icons.search_outlined;
      case 'run_command':
        return Icons.terminal_outlined;
      default:
        return Icons.build_outlined;
    }
  }
}
