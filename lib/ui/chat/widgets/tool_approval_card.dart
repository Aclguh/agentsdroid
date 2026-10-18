import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/agent_event.dart';

class ToolApprovalCard extends StatefulWidget {
  final ToolCallEvent toolCall;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onViewDiff;
  final bool defaultExpanded;

  const ToolApprovalCard({
    super.key,
    required this.toolCall,
    this.onApprove,
    this.onReject,
    this.onViewDiff,
    this.defaultExpanded = false,
  });

  @override
  State<ToolApprovalCard> createState() => _ToolApprovalCardState();
}

class _ToolApprovalCardState extends State<ToolApprovalCard> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.defaultExpanded;
  }

  String _getCompactSummary() {
    final args = widget.toolCall.arguments;
    if (widget.toolCall.toolName == 'run_command') {
      final cmd = args['command']?.toString() ?? '';
      return cmd.isNotEmpty ? '\$ $cmd' : '';
    }
    if (args.containsKey('path')) {
      return args['path'].toString();
    }
    if (args.containsKey('query')) {
      return '"${args['query']}"';
    }
    if (args.isNotEmpty) {
      final firstVal = args.values.first;
      return firstVal.toString();
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isPending = widget.toolCall.status == ToolCallStatus.pending;
    final compactSummary = _getCompactSummary();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
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
          // Header: Icon + Name / Summary + Status Badge + Expand/Collapse Chevron
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Row(
                children: [
                  Icon(
                    _getToolIcon(widget.toolCall.toolName),
                    size: 18,
                    color: _getStatusColor(theme),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.toolCall.toolName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                            fontSize: 13,
                          ),
                        ),
                        if (compactSummary.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: Text(
                              compactSummary,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  _buildStatusChip(theme, l10n),
                  const SizedBox(width: 4),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),

          // Collapsible Content
          if (_isExpanded) ...[
            const Divider(height: 1, thickness: 0.5),
            const SizedBox(height: 8),

            // Arguments Summary / Detail
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: _buildArgumentsPreview(theme),
            ),

            // Result / Error Preview if completed/failed
            if (widget.toolCall.status == ToolCallStatus.completed && widget.toolCall.result != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 240),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      widget.toolCall.result is String
                          ? widget.toolCall.result
                          : const JsonEncoder.withIndent('  ').convert(widget.toolCall.result),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              ),

            if (widget.toolCall.status == ToolCallStatus.failed && widget.toolCall.errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: SelectableText(
                    'Error: ${widget.toolCall.errorMessage}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),

            // Actions Bar for Pending Approval
            if (isPending) ...[
              const Divider(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 12.0, right: 12.0, bottom: 10.0),
                child: Row(
                  children: [
                    if (widget.onViewDiff != null &&
                        (widget.toolCall.toolName == 'write_file' ||
                            widget.toolCall.toolName == 'patch_file'))
                      OutlinedButton.icon(
                        onPressed: widget.onViewDiff,
                        icon: const Icon(Icons.difference_outlined, size: 16),
                        label: Text(l10n?.reviewDiff ?? 'Review Diff'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    const Spacer(),
                    TextButton(
                      onPressed: widget.onReject,
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(l10n?.reject ?? 'Reject'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: widget.onApprove,
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
        ],
      ),
    );
  }

  Widget _buildArgumentsPreview(ThemeData theme) {
    final args = widget.toolCall.arguments;
    if (widget.toolCall.toolName == 'run_command') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.circular(6),
        ),
        child: SelectableText(
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
            child: SelectableText(
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

    return SelectableText(
      const JsonEncoder.withIndent('  ').convert(args),
      style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
    );
  }

  Widget _buildStatusChip(ThemeData theme, AppLocalizations? l10n) {
    String label;
    Color color;

    switch (widget.toolCall.status) {
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
        label = widget.toolCall.autoApproved
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
    if (widget.toolCall.status == ToolCallStatus.pending) {
      return Colors.amber.withValues(alpha: 0.08);
    }
    return theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25);
  }

  Color _getCardBorderColor(ThemeData theme) {
    if (widget.toolCall.status == ToolCallStatus.pending) {
      return Colors.amber.withValues(alpha: 0.6);
    }
    return theme.colorScheme.outlineVariant.withValues(alpha: 0.3);
  }

  Color _getStatusColor(ThemeData theme) {
    switch (widget.toolCall.status) {
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
