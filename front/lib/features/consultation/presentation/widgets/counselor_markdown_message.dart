// Counselor Markdown response renderer with safe link filtering and copy action.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/platform/external_url_launcher.dart';
import '../../../../shared/markdown/clean_markdown_body.dart';
import '../../../../theme/app_theme.dart';

typedef CounselorLinkLauncher = Future<void> Function(Uri uri);

class CounselorMarkdownMessage extends StatefulWidget {
  const CounselorMarkdownMessage({
    required this.data,
    this.showCopyButton = true,
    this.onLinkTap,
    this.onCopied,
    this.copyButtonKey,
    super.key,
  });

  final String data;
  final bool showCopyButton;
  final CounselorLinkLauncher? onLinkTap;
  final VoidCallback? onCopied;
  final Key? copyButtonKey;

  @override
  State<CounselorMarkdownMessage> createState() =>
      _CounselorMarkdownMessageState();
}

class _CounselorMarkdownMessageState extends State<CounselorMarkdownMessage> {
  bool _copied = false;
  Timer? _copiedResetTimer;

  @override
  void dispose() {
    _copiedResetTimer?.cancel();
    super.dispose();
  }

  Future<void> _copyMessage() async {
    await Clipboard.setData(ClipboardData(text: widget.data));
    widget.onCopied?.call();
    if (!mounted) {
      return;
    }
    _copiedResetTimer?.cancel();
    setState(() {
      _copied = true;
    });
    _copiedResetTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _copied = false;
      });
    });
  }

  Future<void> _handleTapLink(String text, String? href, String title) async {
    if (href == null || href.trim().isEmpty) {
      return;
    }
    final uri = Uri.tryParse(href.trim());
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        !uri.hasAuthority ||
        uri.host.isEmpty) {
      return;
    }
    if (widget.onLinkTap != null) {
      await widget.onLinkTap!(uri);
      return;
    }
    try {
      await launchExternalUri(uri);
    } on Object {
      // Headless tests and environments without a browser handler keep UI responsive.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.maumTokens;
    final foreground = tokens.foreground;
    final secondary = tokens.mutedForeground;
    final accent = tokens.primary;
    final quoteBg = tokens.elevatedSurface;
    final codeBg = tokens.codeBlockBackground;
    final borderColor = tokens.codeBlockBorder;

    final baseBody = (theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 15))
        .copyWith(
      color: foreground,
      height: 1.5,
    );

    final styleSheet = CleanMarkdownStyle(
      p: baseBody,
      strong: baseBody.copyWith(fontWeight: FontWeight.w700),
      em: baseBody.copyWith(fontStyle: FontStyle.italic),
      del: baseBody.copyWith(decoration: TextDecoration.lineThrough),
      a: baseBody.copyWith(
        color: accent,
        decoration: TextDecoration.underline,
        decorationColor: accent,
      ),
      h1: baseBody.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
      h2: baseBody.copyWith(fontSize: 17, fontWeight: FontWeight.w700),
      h3: baseBody.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      listBullet: baseBody.copyWith(color: accent, fontWeight: FontWeight.w600),
      blockSpacing: 8,
      listIndent: 18,
      blockquote: baseBody.copyWith(color: secondary),
      blockquotePadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      blockquoteDecoration: BoxDecoration(
        color: quoteBg,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(color: accent, width: 3),
        ),
      ),
      code: baseBody.copyWith(
        fontFamily: 'monospace',
        fontSize: (baseBody.fontSize ?? 15) * 0.9,
        backgroundColor: codeBg,
      ),
      codeblockPadding: const EdgeInsets.all(10),
      codeblockDecoration: BoxDecoration(
        color: codeBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: borderColor)),
      ),
      tableHead: baseBody.copyWith(fontWeight: FontWeight.w700),
      tableBody: baseBody,
      tableBorder: TableBorder.all(color: borderColor),
      tableCellPadding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      tableHeaderColor: quoteBg,
    );

    final markdown = CleanMarkdownBody(
      data: widget.data,
      style: styleSheet,
      softLineBreak: true,
      onTapLink: _handleTapLink,
    );

    if (!widget.showCopyButton || widget.data.trim().isEmpty) {
      return markdown;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        markdown,
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Semantics(
            button: true,
            label: _copied ? '답변을 복사했어요' : '답변 복사',
            child: InkWell(
              key: widget.copyButtonKey,
              onTap: _copyMessage,
              borderRadius: BorderRadius.circular(10),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _copied ? Icons.check_rounded : Icons.copy_rounded,
                        size: 16,
                        color: _copied ? accent : secondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _copied ? '복사됨' : '복사',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: _copied ? accent : secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
