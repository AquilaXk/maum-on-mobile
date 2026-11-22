// Clean-room bounded single-pass Markdown parser and Flutter renderer.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

typedef CleanMarkdownLinkTapCallback = void Function(
  String text,
  String? href,
  String title,
);

@immutable
class CleanMarkdownStyle {
  const CleanMarkdownStyle({
    required this.p,
    required this.strong,
    required this.em,
    required this.del,
    required this.a,
    required this.h1,
    required this.h2,
    required this.h3,
    required this.listBullet,
    required this.blockquote,
    required this.blockquotePadding,
    required this.blockquoteDecoration,
    required this.code,
    required this.codeblockPadding,
    required this.codeblockDecoration,
    required this.horizontalRuleDecoration,
    required this.tableHead,
    required this.tableBody,
    required this.tableBorder,
    required this.tableCellPadding,
    this.tableHeaderColor,
    this.blockSpacing = 8,
    this.listIndent = 18,
  });

  factory CleanMarkdownStyle.fromTheme(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final baseBody =
        (theme.textTheme.bodyMedium ?? const TextStyle(fontSize: 15)).copyWith(
      color: colorScheme.onSurface,
      height: 1.5,
    );
    final codeBg = colorScheme.surfaceContainerHighest;

    return CleanMarkdownStyle(
      p: baseBody,
      strong: baseBody.copyWith(fontWeight: FontWeight.w700),
      em: baseBody.copyWith(fontStyle: FontStyle.italic),
      del: baseBody.copyWith(decoration: TextDecoration.lineThrough),
      a: baseBody.copyWith(
        color: colorScheme.primary,
        decoration: TextDecoration.underline,
        decorationColor: colorScheme.primary,
      ),
      h1: baseBody.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
      h2: baseBody.copyWith(fontSize: 17, fontWeight: FontWeight.w700),
      h3: baseBody.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      listBullet: baseBody.copyWith(
        color: colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
      blockquote: baseBody.copyWith(color: colorScheme.onSurfaceVariant),
      blockquotePadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      blockquoteDecoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(color: colorScheme.primary, width: 3),
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
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      tableHead: baseBody.copyWith(fontWeight: FontWeight.w700),
      tableBody: baseBody,
      tableBorder: TableBorder.all(color: colorScheme.outlineVariant),
      tableCellPadding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      tableHeaderColor: codeBg,
    );
  }

  final TextStyle p;
  final TextStyle strong;
  final TextStyle em;
  final TextStyle del;
  final TextStyle a;
  final TextStyle h1;
  final TextStyle h2;
  final TextStyle h3;
  final TextStyle listBullet;
  final TextStyle blockquote;
  final EdgeInsetsGeometry blockquotePadding;
  final Decoration blockquoteDecoration;
  final TextStyle code;
  final EdgeInsetsGeometry codeblockPadding;
  final Decoration codeblockDecoration;
  final Decoration horizontalRuleDecoration;
  final TextStyle tableHead;
  final TextStyle tableBody;
  final TableBorder tableBorder;
  final EdgeInsetsGeometry tableCellPadding;
  final Color? tableHeaderColor;
  final double blockSpacing;
  final double listIndent;
}

class CleanMarkdownBody extends StatelessWidget {
  const CleanMarkdownBody({
    required this.data,
    this.style,
    this.softLineBreak = true,
    this.onTapLink,
    super.key,
  });

  static const int maxCharacters = 24000;
  static const int maxBlocks = 256;
  static const int maxInlineSpans = 256;
  static const int maxNesting = 8;

  final String data;
  final CleanMarkdownStyle? style;
  final bool softLineBreak;
  final CleanMarkdownLinkTapCallback? onTapLink;

  @override
  Widget build(BuildContext context) {
    final resolvedStyle = style ?? CleanMarkdownStyle.fromTheme(Theme.of(context));
    final document = CleanMarkdownParser.parse(
      data,
      softLineBreak: softLineBreak,
    );

    if (document.blocks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < document.blocks.length; i += 1) ...[
          if (i > 0) SizedBox(height: resolvedStyle.blockSpacing),
          _MarkdownBlockView(
            block: document.blocks[i],
            style: resolvedStyle,
            onTapLink: onTapLink,
          ),
        ],
      ],
    );
  }
}

class _MarkdownBlockView extends StatelessWidget {
  const _MarkdownBlockView({
    required this.block,
    required this.style,
    required this.onTapLink,
  });

  final CleanMarkdownBlock block;
  final CleanMarkdownStyle style;
  final CleanMarkdownLinkTapCallback? onTapLink;

  @override
  Widget build(BuildContext context) {
    return switch (block) {
      CleanMarkdownHeadingBlock(:final level, :final spans) =>
        _InlineMarkdownText(
          spans: spans,
          baseStyle: switch (level) {
            1 => style.h1,
            2 => style.h2,
            _ => style.h3,
          },
          style: style,
          onTapLink: onTapLink,
        ),
      CleanMarkdownParagraphBlock(:final spans) => _InlineMarkdownText(
          spans: spans,
          baseStyle: style.p,
          style: style,
          onTapLink: onTapLink,
        ),
      CleanMarkdownListBlock(:final items) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < items.length; i += 1) ...[
              if (i > 0) const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(
                      left: items[i].indentLevel * style.listIndent,
                      right: 6,
                    ),
                    child: Text(
                      items[i].ordered ? '${items[i].ordinal}.' : '•',
                      style: style.listBullet,
                    ),
                  ),
                  Expanded(
                    child: _InlineMarkdownText(
                      spans: items[i].spans,
                      baseStyle: style.p,
                      style: style,
                      onTapLink: onTapLink,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      CleanMarkdownBlockquoteBlock(:final blocks) => DecoratedBox(
          decoration: style.blockquoteDecoration,
          child: Padding(
            padding: style.blockquotePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < blocks.length; i += 1) ...[
                  if (i > 0) SizedBox(height: style.blockSpacing),
                  _BlockquoteChildView(
                    block: blocks[i],
                    style: style,
                    onTapLink: onTapLink,
                  ),
                ],
              ],
            ),
          ),
        ),
      CleanMarkdownCodeBlock(:final code) => DecoratedBox(
          decoration: style.codeblockDecoration,
          child: Padding(
            padding: style.codeblockPadding,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Text(
                code,
                style: style.code.copyWith(backgroundColor: Colors.transparent),
              ),
            ),
          ),
        ),
      CleanMarkdownHorizontalRuleBlock() => DecoratedBox(
          decoration: style.horizontalRuleDecoration,
          child: const SizedBox(height: 1, width: double.infinity),
        ),
      CleanMarkdownTableBlock(
        :final headers,
        :final alignments,
        :final rows,
      ) =>
        Table(
          border: style.tableBorder,
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              decoration: style.tableHeaderColor == null
                  ? null
                  : BoxDecoration(color: style.tableHeaderColor),
              children: [
                for (var col = 0; col < headers.length; col += 1)
                  Padding(
                    padding: style.tableCellPadding,
                    child: _InlineMarkdownText(
                      spans: headers[col],
                      baseStyle: style.tableHead,
                      style: style,
                      textAlign: alignments[col],
                      onTapLink: onTapLink,
                    ),
                  ),
              ],
            ),
            for (final row in rows)
              TableRow(
                children: [
                  for (var col = 0; col < headers.length; col += 1)
                    Padding(
                      padding: style.tableCellPadding,
                      child: _InlineMarkdownText(
                        spans: col < row.length ? row[col] : const [],
                        baseStyle: style.tableBody,
                        style: style,
                        textAlign: alignments[col],
                        onTapLink: onTapLink,
                      ),
                    ),
                ],
              ),
          ],
        ),
      CleanMarkdownImageBlock() => const SizedBox.shrink(),
    };
  }
}

class _BlockquoteChildView extends StatelessWidget {
  const _BlockquoteChildView({
    required this.block,
    required this.style,
    required this.onTapLink,
  });

  final CleanMarkdownBlock block;
  final CleanMarkdownStyle style;
  final CleanMarkdownLinkTapCallback? onTapLink;

  @override
  Widget build(BuildContext context) {
    final child = block;
    if (child is CleanMarkdownParagraphBlock) {
      return _InlineMarkdownText(
        spans: child.spans,
        baseStyle: style.blockquote,
        style: style,
        onTapLink: onTapLink,
      );
    }
    return _MarkdownBlockView(
      block: child,
      style: style,
      onTapLink: onTapLink,
    );
  }
}

class _InlineMarkdownText extends StatefulWidget {
  const _InlineMarkdownText({
    required this.spans,
    required this.baseStyle,
    required this.style,
    this.textAlign,
    this.onTapLink,
  });

  final List<CleanMarkdownInlineSpan> spans;
  final TextStyle baseStyle;
  final CleanMarkdownStyle style;
  final TextAlign? textAlign;
  final CleanMarkdownLinkTapCallback? onTapLink;

  @override
  State<_InlineMarkdownText> createState() => _InlineMarkdownTextState();
}

class _InlineMarkdownTextState extends State<_InlineMarkdownText> {
  final List<TapGestureRecognizer> _recognizers = <TapGestureRecognizer>[];
  InlineSpan? _cachedSpan;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rebuildSpan();
  }

  @override
  void didUpdateWidget(covariant _InlineMarkdownText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.spans, widget.spans) ||
        oldWidget.baseStyle != widget.baseStyle ||
        oldWidget.style != widget.style ||
        oldWidget.onTapLink != widget.onTapLink) {
      _rebuildSpan();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  void _rebuildSpan() {
    _disposeRecognizers();
    if (widget.spans.isEmpty) {
      _cachedSpan = null;
      return;
    }
    final built = _buildTextSpans(
      widget.spans,
      currentStyle: widget.baseStyle,
      activeRecognizer: null,
    );
    if (built.isEmpty) {
      _cachedSpan = null;
    } else if (built.length == 1) {
      _cachedSpan = built.first;
    } else {
      _cachedSpan = TextSpan(style: widget.baseStyle, children: built);
    }
  }

  List<TextSpan> _buildTextSpans(
    List<CleanMarkdownInlineSpan> nodes, {
    required TextStyle currentStyle,
    required TapGestureRecognizer? activeRecognizer,
  }) {
    final result = <TextSpan>[];
    for (final node in nodes) {
      switch (node) {
        case CleanMarkdownTextSpan(:final text):
          if (text.isNotEmpty) {
            result.add(
              TextSpan(
                text: text,
                style: currentStyle,
                recognizer: activeRecognizer,
              ),
            );
          }
        case CleanMarkdownCodeSpan(:final code):
          if (code.isNotEmpty) {
            result.add(
              TextSpan(
                text: code,
                style: currentStyle.merge(widget.style.code),
                recognizer: activeRecognizer,
              ),
            );
          }
        case CleanMarkdownStyledSpan(:final kind, :final children):
          final mergedStyle = switch (kind) {
            CleanMarkdownInlineStyle.strong =>
              currentStyle.merge(widget.style.strong),
            CleanMarkdownInlineStyle.emphasis =>
              currentStyle.merge(widget.style.em),
            CleanMarkdownInlineStyle.strikethrough =>
              currentStyle.merge(widget.style.del),
          };
          result.addAll(
            _buildTextSpans(
              children,
              currentStyle: mergedStyle,
              activeRecognizer: activeRecognizer,
            ),
          );
        case CleanMarkdownLinkSpan(
            :final href,
            :final title,
            :final children,
          ):
          final plainLabel = _collectInlinePlainText(children);
          final linkStyle = currentStyle.merge(widget.style.a);
          TapGestureRecognizer? recognizer;
          if (widget.onTapLink != null &&
              CleanMarkdownParser.isSafeExternalUri(href)) {
            recognizer = TapGestureRecognizer()
              ..onTap = () => widget.onTapLink!(plainLabel, href, title);
            _recognizers.add(recognizer);
          }
          final linkChildren = _buildTextSpans(
            children,
            currentStyle: linkStyle,
            activeRecognizer: recognizer,
          );
          if (linkChildren.length == 1) {
            result.add(linkChildren.first);
          } else if (linkChildren.isNotEmpty) {
            result.add(
              TextSpan(
                style: linkStyle,
                children: linkChildren,
              ),
            );
          }
        case CleanMarkdownImageSpan():
          // Markdown images are suppressed intentionally to prevent external loads.
          break;
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final span = _cachedSpan;
    if (span == null) {
      return const SizedBox.shrink();
    }
    final alignment = switch (widget.textAlign) {
      TextAlign.center => Alignment.center,
      TextAlign.right => Alignment.centerRight,
      TextAlign.end => AlignmentDirectional.centerEnd,
      _ => AlignmentDirectional.centerStart,
    };
    return Align(
      alignment: alignment,
      widthFactor: 1,
      heightFactor: 1,
      child: Text.rich(
        span,
        textAlign: widget.textAlign,
      ),
    );
  }
}

sealed class CleanMarkdownBlock {
  const CleanMarkdownBlock();
}

final class CleanMarkdownHeadingBlock extends CleanMarkdownBlock {
  const CleanMarkdownHeadingBlock({
    required this.level,
    required this.spans,
  });

  final int level;
  final List<CleanMarkdownInlineSpan> spans;
}

final class CleanMarkdownParagraphBlock extends CleanMarkdownBlock {
  const CleanMarkdownParagraphBlock({required this.spans});

  final List<CleanMarkdownInlineSpan> spans;
}

final class CleanMarkdownListItem {
  const CleanMarkdownListItem({
    required this.ordered,
    required this.ordinal,
    required this.indentLevel,
    required this.spans,
  });

  final bool ordered;
  final int ordinal;
  final int indentLevel;
  final List<CleanMarkdownInlineSpan> spans;
}

final class CleanMarkdownListBlock extends CleanMarkdownBlock {
  const CleanMarkdownListBlock({required this.items});

  final List<CleanMarkdownListItem> items;
}

final class CleanMarkdownBlockquoteBlock extends CleanMarkdownBlock {
  const CleanMarkdownBlockquoteBlock({
    required this.blocks,
    required this.depth,
  });

  final List<CleanMarkdownBlock> blocks;
  final int depth;
}

final class CleanMarkdownCodeBlock extends CleanMarkdownBlock {
  const CleanMarkdownCodeBlock({
    required this.code,
    this.language = '',
  });

  final String code;
  final String language;
}

final class CleanMarkdownHorizontalRuleBlock extends CleanMarkdownBlock {
  const CleanMarkdownHorizontalRuleBlock();
}

final class CleanMarkdownTableBlock extends CleanMarkdownBlock {
  const CleanMarkdownTableBlock({
    required this.headers,
    required this.alignments,
    required this.rows,
  });

  final List<List<CleanMarkdownInlineSpan>> headers;
  final List<TextAlign> alignments;
  final List<List<List<CleanMarkdownInlineSpan>>> rows;
}

final class CleanMarkdownImageBlock extends CleanMarkdownBlock {
  const CleanMarkdownImageBlock();
}

enum CleanMarkdownInlineStyle { strong, emphasis, strikethrough }

sealed class CleanMarkdownInlineSpan {
  const CleanMarkdownInlineSpan();
}

final class CleanMarkdownTextSpan extends CleanMarkdownInlineSpan {
  const CleanMarkdownTextSpan(this.text);

  final String text;
}

final class CleanMarkdownCodeSpan extends CleanMarkdownInlineSpan {
  const CleanMarkdownCodeSpan(this.code);

  final String code;
}

final class CleanMarkdownStyledSpan extends CleanMarkdownInlineSpan {
  const CleanMarkdownStyledSpan({
    required this.kind,
    required this.children,
  });

  final CleanMarkdownInlineStyle kind;
  final List<CleanMarkdownInlineSpan> children;
}

final class CleanMarkdownLinkSpan extends CleanMarkdownInlineSpan {
  const CleanMarkdownLinkSpan({
    required this.href,
    required this.title,
    required this.children,
  });

  final String href;
  final String title;
  final List<CleanMarkdownInlineSpan> children;
}

final class CleanMarkdownImageSpan extends CleanMarkdownInlineSpan {
  const CleanMarkdownImageSpan();
}

final class CleanMarkdownDocument {
  const CleanMarkdownDocument({
    required this.blocks,
    required this.truncated,
    required this.maxObservedNesting,
  });

  final List<CleanMarkdownBlock> blocks;
  final bool truncated;
  final int maxObservedNesting;

  int get plainTextLength => _countBlocksPlainTextLength(blocks);
}

final class CleanMarkdownParser {
  CleanMarkdownParser._();

  static bool isSafeExternalUri(String rawHref) {
    final trimmed = rawHref.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null) {
      return false;
    }
    return (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.hasAuthority &&
        uri.host.isNotEmpty;
  }

  static CleanMarkdownDocument parse(
    String rawData, {
    bool softLineBreak = true,
  }) {
    if (rawData.isEmpty) {
      return const CleanMarkdownDocument(
        blocks: <CleanMarkdownBlock>[],
        truncated: false,
        maxObservedNesting: 0,
      );
    }

    var truncated = false;
    var boundedInput = rawData;
    if (rawData.length > CleanMarkdownBody.maxCharacters) {
      var cut = CleanMarkdownBody.maxCharacters;
      if (cut > 0 && _isHighSurrogate(rawData.codeUnitAt(cut - 1))) {
        cut -= 1;
      }
      boundedInput = rawData.substring(0, cut);
      truncated = true;
    }

    final lines = _splitLines(boundedInput);
    final budget = _ParseBudget(maxBlocks: CleanMarkdownBody.maxBlocks);
    final blocks = _parseLines(
      lines,
      depth: 0,
      softLineBreak: softLineBreak,
      budget: budget,
    );

    return CleanMarkdownDocument(
      blocks: List<CleanMarkdownBlock>.unmodifiable(blocks),
      truncated: truncated || budget.truncated,
      maxObservedNesting: budget.maxObservedNesting,
    );
  }

  static List<CleanMarkdownBlock> _parseLines(
    List<String> lines, {
    required int depth,
    required bool softLineBreak,
    required _ParseBudget budget,
  }) {
    final blocks = <CleanMarkdownBlock>[];
    var i = 0;

    while (i < lines.length) {
      final line = lines[i];
      if (_isBlank(line)) {
        i += 1;
        continue;
      }

      if (!budget.canAddBlock) {
        budget.truncated = true;
        break;
      }

      final fenceMatch = _matchFenceStart(line);
      if (fenceMatch != null) {
        final codeLines = <String>[];
        i += 1;
        while (i < lines.length) {
          if (_isFenceEnd(lines[i], fenceMatch.charCode, fenceMatch.length)) {
            i += 1;
            break;
          }
          codeLines.add(lines[i]);
          i += 1;
        }
        if (budget.consumeBlock()) {
          blocks.add(
            CleanMarkdownCodeBlock(
              code: codeLines.join('\n'),
              language: fenceMatch.language,
            ),
          );
        }
        continue;
      }

      final headingMatch = _matchAtxHeading(line);
      if (headingMatch != null) {
        if (budget.consumeBlock()) {
          blocks.add(
            CleanMarkdownHeadingBlock(
              level: headingMatch.level,
              spans: _parseInline(
                headingMatch.text,
                baseDepth: depth,
                budget: budget,
              ),
            ),
          );
        }
        i += 1;
        continue;
      }

      if (_isHorizontalRule(line)) {
        if (budget.consumeBlock()) {
          blocks.add(const CleanMarkdownHorizontalRuleBlock());
        }
        i += 1;
        continue;
      }

      if (_isBlockquoteLine(line) && depth < CleanMarkdownBody.maxNesting) {
        final quoteLines = <String>[];
        while (i < lines.length && _isBlockquoteLine(lines[i])) {
          quoteLines.add(_stripBlockquotePrefix(lines[i]));
          i += 1;
        }
        final nextDepth = depth + 1;
        budget.recordNesting(nextDepth);
        if (budget.consumeBlock()) {
          final innerBlocks = _parseLines(
            quoteLines,
            depth: nextDepth,
            softLineBreak: softLineBreak,
            budget: budget,
          );
          blocks.add(
            CleanMarkdownBlockquoteBlock(
              blocks: List<CleanMarkdownBlock>.unmodifiable(innerBlocks),
              depth: nextDepth,
            ),
          );
        }
        continue;
      }

      if (i + 1 < lines.length) {
        final tableCandidate = _tryParseTableHeader(lines[i], lines[i + 1]);
        if (tableCandidate != null) {
          final headers = tableCandidate.headerCells
              .map(
                (cell) => _parseInline(cell, baseDepth: depth, budget: budget),
              )
              .toList(growable: false);
          final rows = <List<List<CleanMarkdownInlineSpan>>>[];
          i += 2;
          while (i < lines.length &&
              !_isBlank(lines[i]) &&
              lines[i].contains('|') &&
              !_startsNonParagraphBlock(lines[i], lines, i, depth)) {
            if (!budget.canAddBlock) {
              budget.truncated = true;
              break;
            }
            final rawCells = _splitTableRow(lines[i]);
            final rowSpans = <List<CleanMarkdownInlineSpan>>[];
            for (var c = 0; c < headers.length; c += 1) {
              final cellText = c < rawCells.length ? rawCells[c] : '';
              rowSpans.add(
                _parseInline(cellText, baseDepth: depth, budget: budget),
              );
            }
            rows.add(List<List<CleanMarkdownInlineSpan>>.unmodifiable(rowSpans));
            i += 1;
          }
          if (budget.consumeBlock()) {
            blocks.add(
              CleanMarkdownTableBlock(
                headers: List<List<CleanMarkdownInlineSpan>>.unmodifiable(headers),
                alignments: List<TextAlign>.unmodifiable(tableCandidate.alignments),
                rows: List<List<List<CleanMarkdownInlineSpan>>>.unmodifiable(rows),
              ),
            );
          }
          continue;
        }
      }

      final firstListMarker = _matchListMarker(line);
      if (firstListMarker != null) {
        final items = <CleanMarkdownListItem>[];
        if (!budget.consumeBlock()) {
          budget.truncated = true;
          break;
        }

        while (i < lines.length) {
          final marker = _matchListMarker(lines[i]);
          if (marker == null) {
            break;
          }
          if (items.isNotEmpty && !budget.consumeBlock()) {
            budget.truncated = true;
            break;
          }

          final itemBuffer = StringBuffer(marker.content);
          i += 1;
          while (i < lines.length &&
              !_isBlank(lines[i]) &&
              _matchListMarker(lines[i]) == null &&
              !_startsNonParagraphBlock(lines[i], lines, i, depth)) {
            itemBuffer.write(softLineBreak ? '\n' : ' ');
            itemBuffer.write(lines[i].trimLeft());
            i += 1;
          }

          final availableIndentSlots =
              (CleanMarkdownBody.maxNesting - depth - 1).clamp(0, 7);
          final indentLevel =
              (marker.leadingSpaces ~/ 2).clamp(0, availableIndentSlots);
          budget.recordNesting(depth + indentLevel + 1);

          items.add(
            CleanMarkdownListItem(
              ordered: marker.ordered,
              ordinal: marker.ordinal,
              indentLevel: indentLevel,
              spans: _parseInline(
                itemBuffer.toString(),
                baseDepth: depth + indentLevel,
                budget: budget,
              ),
            ),
          );

          while (i < lines.length &&
              _isBlank(lines[i]) &&
              i + 1 < lines.length &&
              _matchListMarker(lines[i + 1]) != null) {
            i += 1;
          }
        }

        blocks.add(
          CleanMarkdownListBlock(
            items: List<CleanMarkdownListItem>.unmodifiable(items),
          ),
        );
        continue;
      }

      final paragraphBuffer = StringBuffer(_stripExcessBlockquotes(line, depth));
      i += 1;
      while (i < lines.length &&
          !_isBlank(lines[i]) &&
          !_startsNonParagraphBlock(lines[i], lines, i, depth)) {
        paragraphBuffer.write(softLineBreak ? '\n' : ' ');
        paragraphBuffer.write(_stripExcessBlockquotes(lines[i], depth));
        i += 1;
      }

      final spans = _parseInline(
        paragraphBuffer.toString(),
        baseDepth: depth,
        budget: budget,
      );
      if (budget.consumeBlock()) {
        if (_containsOnlyImagesOrEmptyWhitespace(spans)) {
          blocks.add(const CleanMarkdownImageBlock());
        } else {
          blocks.add(CleanMarkdownParagraphBlock(spans: spans));
        }
      }
    }

    return blocks;
  }

  static String _stripExcessBlockquotes(String line, int depth) {
    if (depth >= CleanMarkdownBody.maxNesting && _isBlockquoteLine(line)) {
      return _stripAllBlockquotePrefixes(line);
    }
    return line;
  }

  static String _stripAllBlockquotePrefixes(String line) {
    var cursor = 0;
    while (cursor < line.length) {
      var spaces = 0;
      while (cursor + spaces < line.length &&
          spaces < 3 &&
          line.codeUnitAt(cursor + spaces) == 32) {
        spaces += 1;
      }
      final idx = cursor + spaces;
      if (idx < line.length && line.codeUnitAt(idx) == 62) {
        cursor = idx + 1;
        if (cursor < line.length && line.codeUnitAt(cursor) == 32) {
          cursor += 1;
        }
        continue;
      }
      break;
    }
    return line.substring(cursor);
  }

  static bool _startsNonParagraphBlock(
    String line,
    List<String> lines,
    int index,
    int depth,
  ) {
    if (_matchFenceStart(line) != null ||
        _matchAtxHeading(line) != null ||
        _isHorizontalRule(line) ||
        (_isBlockquoteLine(line) && depth < CleanMarkdownBody.maxNesting) ||
        _matchListMarker(line) != null) {
      return true;
    }
    if (index + 1 < lines.length &&
        _tryParseTableHeader(line, lines[index + 1]) != null) {
      return true;
    }
    return false;
  }

  static List<CleanMarkdownInlineSpan> _parseInline(
    String input, {
    required int baseDepth,
    required _ParseBudget budget,
  }) {
    if (input.isEmpty) {
      return const <CleanMarkdownInlineSpan>[];
    }

    final frames = <_InlineFrame>[
      _InlineFrame(marker: '', children: <CleanMarkdownInlineSpan>[]),
    ];
    final buffer = StringBuffer();
    var spanCount = 0;
    var unmatchedBackticks = 0;
    var noMoreClosingBrackets = false;
    var noMoreClosingParens = false;

    void flushText() {
      if (buffer.isEmpty) {
        return;
      }
      if (spanCount >= CleanMarkdownBody.maxInlineSpans) {
        buffer.clear();
        return;
      }
      frames.last.children.add(CleanMarkdownTextSpan(buffer.toString()));
      spanCount += 1;
      buffer.clear();
    }

    bool canEmitSpan() => spanCount < CleanMarkdownBody.maxInlineSpans;

    var i = 0;
    final length = input.length;
    while (i < length) {
      if (!canEmitSpan()) {
        break;
      }

      final cu = input.codeUnitAt(i);

      // Escaped ASCII punctuation.
      if (cu == 92 &&
          i + 1 < length &&
          _isEscapableAscii(input.codeUnitAt(i + 1))) {
        buffer.writeCharCode(input.codeUnitAt(i + 1));
        i += 2;
        continue;
      }

      // Inline code backtick span.
      if (cu == 96) {
        var tickCount = 1;
        while (i + tickCount < length && input.codeUnitAt(i + tickCount) == 96) {
          tickCount += 1;
        }
        final bitMissing =
            tickCount < 63 && (unmatchedBackticks & (1 << tickCount)) != 0;
        if (!bitMissing) {
          final closeIdx = _findClosingBackticks(input, i + tickCount, tickCount);
          if (closeIdx >= 0) {
            flushText();
            if (canEmitSpan()) {
              final rawCode =
                  input.substring(i + tickCount, closeIdx).replaceAll('\n', ' ');
              final trimmedCode = _trimInlineCodeSpaces(rawCode);
              frames.last.children.add(CleanMarkdownCodeSpan(trimmedCode));
              spanCount += 1;
            }
            i = closeIdx + tickCount;
            continue;
          }
          if (tickCount < 63) {
            unmatchedBackticks |= 1 << tickCount;
          }
        }
        for (var t = 0; t < tickCount; t += 1) {
          buffer.writeCharCode(96);
        }
        i += tickCount;
        continue;
      }

      // Markdown image `![alt](url)` (suppressed cleanly).
      if (cu == 33 &&
          i + 1 < length &&
          input.codeUnitAt(i + 1) == 91 &&
          !noMoreClosingBrackets &&
          !noMoreClosingParens) {
        final parsedImage = _tryParseLinkOrImage(input, i + 1);
        if (parsedImage != null) {
          flushText();
          if (canEmitSpan()) {
            frames.last.children.add(const CleanMarkdownImageSpan());
            spanCount += 1;
          }
          i = parsedImage.nextIndex;
          continue;
        }
        if (!_hasCharAhead(input, i + 2, 93)) {
          noMoreClosingBrackets = true;
        } else if (!_hasCharAhead(input, i + 2, 41)) {
          noMoreClosingParens = true;
        }
      }

      // Markdown link `[label](url "title")`.
      if (cu == 91 && !noMoreClosingBrackets && !noMoreClosingParens) {
        final parsedLink = _tryParseLinkOrImage(input, i);
        if (parsedLink != null) {
          flushText();
          final currentDepth = baseDepth + frames.length - 1;
          final labelSpans = currentDepth < CleanMarkdownBody.maxNesting
              ? _parseInline(
                  parsedLink.label,
                  baseDepth: currentDepth + 1,
                  budget: budget,
                )
              : <CleanMarkdownInlineSpan>[CleanMarkdownTextSpan(parsedLink.label)];
          budget.recordNesting(currentDepth + 1);

          if (canEmitSpan()) {
            if (isSafeExternalUri(parsedLink.href)) {
              frames.last.children.add(
                CleanMarkdownLinkSpan(
                  href: parsedLink.href.trim(),
                  title: parsedLink.title,
                  children: List<CleanMarkdownInlineSpan>.unmodifiable(labelSpans),
                ),
              );
              spanCount += 1;
            } else {
              for (final span in labelSpans) {
                if (!canEmitSpan()) {
                  break;
                }
                frames.last.children.add(span);
                spanCount += 1;
              }
            }
          }
          i = parsedLink.nextIndex;
          continue;
        }
        if (!_hasCharAhead(input, i + 1, 93)) {
          noMoreClosingBrackets = true;
        } else if (!_hasCharAhead(input, i + 1, 41)) {
          noMoreClosingParens = true;
        }
      }

      // Delimiters: **, __, ~~, *, _.
      final marker = _matchDelimiterAt(input, i, frames);
      if (marker != null) {
        final nextIdx = i + marker.length;
        final prevCu = i > 0 ? input.codeUnitAt(i - 1) : -1;
        final nextCu = nextIdx < length ? input.codeUnitAt(nextIdx) : -1;
        final intrawordUnderscore = (marker == '_' || marker == '__') &&
            _isWordChar(prevCu) &&
            _isWordChar(nextCu);

        if (!intrawordUnderscore) {
          final openIdx = _findOpenFrame(frames, marker);
          final canClose = openIdx > 0 && !_isWhitespace(prevCu);
          if (canClose) {
            flushText();
            while (frames.length - 1 > openIdx) {
              final unclosed = frames.removeLast();
              _appendText(frames.last.children, unclosed.marker);
              frames.last.children.addAll(unclosed.children);
            }
            final matched = frames.removeLast();
            if (matched.children.isEmpty) {
              _appendText(
                frames.last.children,
                '${matched.marker}${matched.marker}',
              );
            } else if (canEmitSpan()) {
              frames.last.children.add(
                CleanMarkdownStyledSpan(
                  kind: _styleForMarker(matched.marker),
                  children: List<CleanMarkdownInlineSpan>.unmodifiable(
                    matched.children,
                  ),
                ),
              );
              spanCount += 1;
            }
            i = nextIdx;
            continue;
          }

          final currentDepth = baseDepth + frames.length - 1;
          final canOpen = nextIdx < length &&
              !_isWhitespace(nextCu) &&
              currentDepth < CleanMarkdownBody.maxNesting;
          if (canOpen) {
            flushText();
            budget.recordNesting(currentDepth + 1);
            frames.add(
              _InlineFrame(
                marker: marker,
                children: <CleanMarkdownInlineSpan>[],
              ),
            );
            i = nextIdx;
            continue;
          }
        }

        buffer.write(marker);
        i = nextIdx;
        continue;
      }

      buffer.writeCharCode(cu);
      i += 1;
    }

    flushText();
    while (frames.length > 1) {
      final unclosed = frames.removeLast();
      _appendText(frames.last.children, unclosed.marker);
      frames.last.children.addAll(unclosed.children);
    }

    final coalesced = _coalesceSpans(frames.first.children);
    if (coalesced.length > CleanMarkdownBody.maxInlineSpans) {
      return List<CleanMarkdownInlineSpan>.unmodifiable(
        coalesced.sublist(0, CleanMarkdownBody.maxInlineSpans),
      );
    }
    return List<CleanMarkdownInlineSpan>.unmodifiable(coalesced);
  }
}

final class _ParseBudget {
  _ParseBudget({required this.maxBlocks});

  final int maxBlocks;
  int _blocksUsed = 0;
  int maxObservedNesting = 0;
  bool truncated = false;

  bool get canAddBlock => _blocksUsed < maxBlocks;

  bool consumeBlock() {
    if (_blocksUsed >= maxBlocks) {
      truncated = true;
      return false;
    }
    _blocksUsed += 1;
    return true;
  }

  void recordNesting(int depth) {
    if (depth > maxObservedNesting) {
      maxObservedNesting = depth;
    }
  }
}

final class _InlineFrame {
  _InlineFrame({required this.marker, required this.children});

  final String marker;
  final List<CleanMarkdownInlineSpan> children;
}

final class _FenceStart {
  const _FenceStart({
    required this.charCode,
    required this.length,
    required this.language,
  });

  final int charCode;
  final int length;
  final String language;
}

final class _AtxHeading {
  const _AtxHeading({required this.level, required this.text});

  final int level;
  final String text;
}

final class _ListMarkerMatch {
  const _ListMarkerMatch({
    required this.ordered,
    required this.ordinal,
    required this.leadingSpaces,
    required this.content,
  });

  final bool ordered;
  final int ordinal;
  final int leadingSpaces;
  final String content;
}

final class _TableHeaderCandidate {
  const _TableHeaderCandidate({
    required this.headerCells,
    required this.alignments,
  });

  final List<String> headerCells;
  final List<TextAlign> alignments;
}

final class _LinkParseResult {
  const _LinkParseResult({
    required this.label,
    required this.href,
    required this.title,
    required this.nextIndex,
  });

  final String label;
  final String href;
  final String title;
  final int nextIndex;
}

bool _isHighSurrogate(int codeUnit) => codeUnit >= 0xD800 && codeUnit <= 0xDBFF;

List<String> _splitLines(String text) {
  final lines = <String>[];
  var start = 0;
  final length = text.length;
  for (var i = 0; i < length; i += 1) {
    if (text.codeUnitAt(i) == 10) {
      var end = i;
      if (end > start && text.codeUnitAt(end - 1) == 13) {
        end -= 1;
      }
      lines.add(text.substring(start, end));
      start = i + 1;
    }
  }
  var tailEnd = length;
  if (tailEnd > start && text.codeUnitAt(tailEnd - 1) == 13) {
    tailEnd -= 1;
  }
  lines.add(text.substring(start, tailEnd));
  return lines;
}

bool _isBlank(String line) {
  for (var i = 0; i < line.length; i += 1) {
    final cu = line.codeUnitAt(i);
    if (cu != 32 && cu != 9) {
      return false;
    }
  }
  return true;
}

int _leadingSpacesCount(String line, {int maxCount = 16}) {
  var count = 0;
  while (count < line.length && count < maxCount && line.codeUnitAt(count) == 32) {
    count += 1;
  }
  return count;
}

_FenceStart? _matchFenceStart(String line) {
  final lead = _leadingSpacesCount(line, maxCount: 4);
  if (lead > 3 || lead >= line.length) {
    return null;
  }
  final fenceChar = line.codeUnitAt(lead);
  if (fenceChar != 96 && fenceChar != 126) {
    return null;
  }
  var count = 1;
  while (lead + count < line.length &&
      line.codeUnitAt(lead + count) == fenceChar) {
    count += 1;
  }
  if (count < 3) {
    return null;
  }
  final info = line.substring(lead + count).trim();
  if (fenceChar == 96 && info.contains('`')) {
    return null;
  }
  return _FenceStart(charCode: fenceChar, length: count, language: info);
}

bool _isFenceEnd(String line, int fenceChar, int minLength) {
  final lead = _leadingSpacesCount(line, maxCount: 4);
  if (lead > 3 || lead >= line.length) {
    return false;
  }
  var count = 0;
  while (lead + count < line.length &&
      line.codeUnitAt(lead + count) == fenceChar) {
    count += 1;
  }
  if (count < minLength) {
    return false;
  }
  for (var i = lead + count; i < line.length; i += 1) {
    final cu = line.codeUnitAt(i);
    if (cu != 32 && cu != 9) {
      return false;
    }
  }
  return true;
}

_AtxHeading? _matchAtxHeading(String line) {
  final lead = _leadingSpacesCount(line, maxCount: 4);
  if (lead > 3 || lead >= line.length) {
    return null;
  }
  if (line.codeUnitAt(lead) != 35) {
    return null;
  }
  var hashes = 0;
  while (lead + hashes < line.length &&
      hashes < 7 &&
      line.codeUnitAt(lead + hashes) == 35) {
    hashes += 1;
  }
  if (hashes < 1 || hashes > 6) {
    return null;
  }
  final after = lead + hashes;
  if (after < line.length) {
    final cu = line.codeUnitAt(after);
    if (cu != 32 && cu != 9) {
      return null;
    }
  }
  var text = after >= line.length ? '' : line.substring(after).trim();
  var end = text.length;
  while (end > 0 && text.codeUnitAt(end - 1) == 35) {
    end -= 1;
  }
  if (end < text.length && (end == 0 || text.codeUnitAt(end - 1) == 32)) {
    text = text.substring(0, end).trimRight();
  }
  return _AtxHeading(level: hashes, text: text);
}

bool _isHorizontalRule(String line) {
  final lead = _leadingSpacesCount(line, maxCount: 4);
  if (lead > 3 || lead >= line.length) {
    return false;
  }
  final marker = line.codeUnitAt(lead);
  if (marker != 45 && marker != 42 && marker != 95) {
    return false;
  }
  var count = 0;
  for (var i = lead; i < line.length; i += 1) {
    final cu = line.codeUnitAt(i);
    if (cu == marker) {
      count += 1;
    } else if (cu != 32 && cu != 9) {
      return false;
    }
  }
  return count >= 3;
}

bool _isBlockquoteLine(String line) {
  final lead = _leadingSpacesCount(line, maxCount: 4);
  if (lead > 3 || lead >= line.length) {
    return false;
  }
  return line.codeUnitAt(lead) == 62;
}

String _stripBlockquotePrefix(String line) {
  final lead = _leadingSpacesCount(line, maxCount: 4);
  var start = lead + 1;
  if (start < line.length && line.codeUnitAt(start) == 32) {
    start += 1;
  }
  return start >= line.length ? '' : line.substring(start);
}

_ListMarkerMatch? _matchListMarker(String line) {
  final lead = _leadingSpacesCount(line, maxCount: 16);
  if (lead >= line.length) {
    return null;
  }
  final first = line.codeUnitAt(lead);
  if ((first == 45 || first == 42 || first == 43) &&
      lead + 1 < line.length &&
      (line.codeUnitAt(lead + 1) == 32 || line.codeUnitAt(lead + 1) == 9)) {
    return _ListMarkerMatch(
      ordered: false,
      ordinal: 0,
      leadingSpaces: lead,
      content: line.substring(lead + 2),
    );
  }

  if (first >= 48 && first <= 57) {
    var cursor = lead;
    var digits = 0;
    var ordinal = 0;
    while (cursor < line.length && digits < 9) {
      final d = line.codeUnitAt(cursor) - 48;
      if (d < 0 || d > 9) {
        break;
      }
      ordinal = ordinal * 10 + d;
      cursor += 1;
      digits += 1;
    }
    if (digits > 0 &&
        cursor + 1 < line.length &&
        (line.codeUnitAt(cursor) == 46 || line.codeUnitAt(cursor) == 41) &&
        (line.codeUnitAt(cursor + 1) == 32 ||
            line.codeUnitAt(cursor + 1) == 9)) {
      return _ListMarkerMatch(
        ordered: true,
        ordinal: ordinal,
        leadingSpaces: lead,
        content: line.substring(cursor + 2),
      );
    }
  }

  return null;
}

_TableHeaderCandidate? _tryParseTableHeader(
  String headerLine,
  String delimiterLine,
) {
  if (!headerLine.contains('|') || !delimiterLine.contains('-')) {
    return null;
  }
  final headerCells = _splitTableRow(headerLine);
  final delimiterCells = _splitTableRow(delimiterLine);
  if (headerCells.isEmpty || headerCells.length != delimiterCells.length) {
    return null;
  }

  final alignments = <TextAlign>[];
  for (final cell in delimiterCells) {
    final alignment = _parseTableAlignment(cell);
    if (alignment == null) {
      return null;
    }
    alignments.add(alignment);
  }

  return _TableHeaderCandidate(
    headerCells: headerCells,
    alignments: alignments,
  );
}

List<String> _splitTableRow(String line) {
  var trimmed = line.trim();
  if (trimmed.isEmpty) {
    return const <String>[];
  }
  if (trimmed.startsWith('|')) {
    trimmed = trimmed.substring(1);
  }
  if (trimmed.endsWith('|') &&
      (trimmed.length < 2 || trimmed.codeUnitAt(trimmed.length - 2) != 92)) {
    trimmed = trimmed.substring(0, trimmed.length - 1);
  }

  final cells = <String>[];
  final current = StringBuffer();
  var inCode = false;
  var i = 0;
  while (i < trimmed.length) {
    final cu = trimmed.codeUnitAt(i);
    if (cu == 92 &&
        i + 1 < trimmed.length &&
        trimmed.codeUnitAt(i + 1) == 124) {
      current.writeCharCode(124);
      i += 2;
      continue;
    }
    if (cu == 96) {
      inCode = !inCode;
      current.writeCharCode(cu);
      i += 1;
      continue;
    }
    if (cu == 124 && !inCode) {
      cells.add(current.toString().trim());
      current.clear();
      i += 1;
      continue;
    }
    current.writeCharCode(cu);
    i += 1;
  }
  cells.add(current.toString().trim());
  return cells;
}

TextAlign? _parseTableAlignment(String cell) {
  final trimmed = cell.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final startsColon = trimmed.startsWith(':');
  final endsColon = trimmed.endsWith(':');
  final startIdx = startsColon ? 1 : 0;
  final endIdx = endsColon ? trimmed.length - 1 : trimmed.length;
  if (endIdx - startIdx < 1) {
    return null;
  }
  for (var i = startIdx; i < endIdx; i += 1) {
    if (trimmed.codeUnitAt(i) != 45) {
      return null;
    }
  }
  if (startsColon && endsColon) {
    return TextAlign.center;
  }
  if (endsColon) {
    return TextAlign.right;
  }
  return TextAlign.left;
}

bool _isEscapableAscii(int cu) {
  return (cu >= 33 && cu <= 47) ||
      (cu >= 58 && cu <= 64) ||
      (cu >= 91 && cu <= 96) ||
      (cu >= 123 && cu <= 126);
}

int _findClosingBackticks(String input, int start, int tickCount) {
  var i = start;
  while (i < input.length) {
    if (input.codeUnitAt(i) == 96) {
      var run = 1;
      while (i + run < input.length && input.codeUnitAt(i + run) == 96) {
        run += 1;
      }
      if (run == tickCount) {
        return i;
      }
      i += run;
    } else {
      i += 1;
    }
  }
  return -1;
}

String _trimInlineCodeSpaces(String raw) {
  if (raw.length >= 2 &&
      raw.codeUnitAt(0) == 32 &&
      raw.codeUnitAt(raw.length - 1) == 32) {
    for (var i = 0; i < raw.length; i += 1) {
      if (raw.codeUnitAt(i) != 32) {
        return raw.substring(1, raw.length - 1);
      }
    }
  }
  return raw;
}

bool _hasCharAhead(String input, int start, int targetCodeUnit) {
  for (var i = start; i < input.length; i += 1) {
    if (input.codeUnitAt(i) == targetCodeUnit) {
      return true;
    }
  }
  return false;
}

_LinkParseResult? _tryParseLinkOrImage(String input, int openBracketIndex) {
  final length = input.length;
  var cursor = openBracketIndex + 1;
  var closeBracket = -1;

  while (cursor < length) {
    final cu = input.codeUnitAt(cursor);
    if (cu == 92 && cursor + 1 < length) {
      cursor += 2;
      continue;
    }
    if (cu == 96) {
      var run = 1;
      while (cursor + run < length && input.codeUnitAt(cursor + run) == 96) {
        run += 1;
      }
      final closeTick = _findClosingBackticks(input, cursor + run, run);
      if (closeTick >= 0) {
        cursor = closeTick + run;
        continue;
      }
      cursor += run;
      continue;
    }
    if (cu == 91 || cu == 10) {
      return null;
    }
    if (cu == 93) {
      closeBracket = cursor;
      break;
    }
    cursor += 1;
  }

  if (closeBracket < 0 ||
      closeBracket + 1 >= length ||
      input.codeUnitAt(closeBracket + 1) != 40) {
    return null;
  }

  var urlCursor = closeBracket + 2;
  while (urlCursor < length && input.codeUnitAt(urlCursor) == 32) {
    urlCursor += 1;
  }
  if (urlCursor >= length) {
    return null;
  }

  final hrefBuffer = StringBuffer();
  var parenDepth = 0;
  var closeParen = -1;
  var title = '';

  while (urlCursor < length) {
    final cu = input.codeUnitAt(urlCursor);
    if (cu == 10) {
      return null;
    }
    if (cu == 92 && urlCursor + 1 < length) {
      hrefBuffer.writeCharCode(input.codeUnitAt(urlCursor + 1));
      urlCursor += 2;
      continue;
    }
    if (cu == 40) {
      parenDepth += 1;
      hrefBuffer.writeCharCode(cu);
      urlCursor += 1;
      continue;
    }
    if (cu == 41) {
      if (parenDepth == 0) {
        closeParen = urlCursor;
        break;
      }
      parenDepth -= 1;
      hrefBuffer.writeCharCode(cu);
      urlCursor += 1;
      continue;
    }
    if (cu == 32 || cu == 9) {
      var afterSpace = urlCursor;
      while (afterSpace < length &&
          (input.codeUnitAt(afterSpace) == 32 ||
              input.codeUnitAt(afterSpace) == 9)) {
        afterSpace += 1;
      }
      if (afterSpace < length &&
          (input.codeUnitAt(afterSpace) == 34 ||
              input.codeUnitAt(afterSpace) == 39)) {
        final quote = input.codeUnitAt(afterSpace);
        final titleEnd = input.indexOf(String.fromCharCode(quote), afterSpace + 1);
        if (titleEnd >= 0) {
          var afterQuote = titleEnd + 1;
          while (afterQuote < length && input.codeUnitAt(afterQuote) == 32) {
            afterQuote += 1;
          }
          if (afterQuote < length && input.codeUnitAt(afterQuote) == 41) {
            title = input.substring(afterSpace + 1, titleEnd);
            closeParen = afterQuote;
            break;
          }
        }
      }
      if (afterSpace < length && input.codeUnitAt(afterSpace) == 41) {
        closeParen = afterSpace;
        break;
      }
      return null;
    }
    hrefBuffer.writeCharCode(cu);
    urlCursor += 1;
  }

  if (closeParen < 0) {
    return null;
  }

  var href = hrefBuffer.toString().trim();
  if (href.startsWith('<') && href.endsWith('>') && href.length >= 2) {
    href = href.substring(1, href.length - 1);
  }

  return _LinkParseResult(
    label: input.substring(openBracketIndex + 1, closeBracket),
    href: href,
    title: title,
    nextIndex: closeParen + 1,
  );
}

String? _matchDelimiterAt(
  String input,
  int index,
  List<_InlineFrame> frames,
) {
  final cu = input.codeUnitAt(index);
  final hasNext = index + 1 < input.length;
  if (cu == 42) {
    if (hasNext && input.codeUnitAt(index + 1) == 42) {
      final hasThird = index + 2 < input.length && input.codeUnitAt(index + 2) == 42;
      if (hasThird &&
          frames.length >= 3 &&
          frames.last.marker == '*' &&
          frames[frames.length - 2].marker == '**') {
        return '*';
      }
      return '**';
    }
    return '*';
  }
  if (cu == 95) {
    if (hasNext && input.codeUnitAt(index + 1) == 95) {
      return '__';
    }
    return '_';
  }
  if (cu == 126 && hasNext && input.codeUnitAt(index + 1) == 126) {
    return '~~';
  }
  return null;
}

int _findOpenFrame(List<_InlineFrame> frames, String marker) {
  for (var i = frames.length - 1; i >= 1; i -= 1) {
    if (frames[i].marker == marker) {
      return i;
    }
  }
  return -1;
}

CleanMarkdownInlineStyle _styleForMarker(String marker) {
  return switch (marker) {
    '**' || '__' => CleanMarkdownInlineStyle.strong,
    '~~' => CleanMarkdownInlineStyle.strikethrough,
    _ => CleanMarkdownInlineStyle.emphasis,
  };
}

bool _isWhitespace(int cu) => cu == 32 || cu == 9 || cu == 10 || cu == 13;

bool _isWordChar(int cu) {
  return (cu >= 48 && cu <= 57) ||
      (cu >= 65 && cu <= 90) ||
      (cu >= 97 && cu <= 122) ||
      (cu >= 0xAC00 && cu <= 0xD7A3) ||
      (cu >= 0x3131 && cu <= 0x318E);
}

void _appendText(List<CleanMarkdownInlineSpan> target, String text) {
  if (text.isEmpty) {
    return;
  }
  if (target.isNotEmpty && target.last is CleanMarkdownTextSpan) {
    final prev = target.removeLast() as CleanMarkdownTextSpan;
    target.add(CleanMarkdownTextSpan('${prev.text}$text'));
  } else {
    target.add(CleanMarkdownTextSpan(text));
  }
}

List<CleanMarkdownInlineSpan> _coalesceSpans(
  List<CleanMarkdownInlineSpan> raw,
) {
  final result = <CleanMarkdownInlineSpan>[];
  for (final span in raw) {
    if (span is CleanMarkdownTextSpan) {
      _appendText(result, span.text);
    } else {
      result.add(span);
    }
  }
  return result;
}

bool _containsOnlyImagesOrEmptyWhitespace(
  List<CleanMarkdownInlineSpan> spans,
) {
  var sawImage = false;
  for (final span in spans) {
    if (span is CleanMarkdownImageSpan) {
      sawImage = true;
    } else if (span is CleanMarkdownTextSpan && span.text.trim().isEmpty) {
      continue;
    } else {
      return false;
    }
  }
  return sawImage;
}

String _collectInlinePlainText(List<CleanMarkdownInlineSpan> spans) {
  final buffer = StringBuffer();
  for (final span in spans) {
    switch (span) {
      case CleanMarkdownTextSpan(:final text):
        buffer.write(text);
      case CleanMarkdownCodeSpan(:final code):
        buffer.write(code);
      case CleanMarkdownStyledSpan(:final children):
        buffer.write(_collectInlinePlainText(children));
      case CleanMarkdownLinkSpan(:final children):
        buffer.write(_collectInlinePlainText(children));
      case CleanMarkdownImageSpan():
        break;
    }
  }
  return buffer.toString();
}

int _countBlocksPlainTextLength(List<CleanMarkdownBlock> blocks) {
  var total = 0;
  for (final block in blocks) {
    switch (block) {
      case CleanMarkdownHeadingBlock(:final spans):
        total += _collectInlinePlainText(spans).length;
      case CleanMarkdownParagraphBlock(:final spans):
        total += _collectInlinePlainText(spans).length;
      case CleanMarkdownListBlock(:final items):
        for (final item in items) {
          total += _collectInlinePlainText(item.spans).length;
        }
      case CleanMarkdownBlockquoteBlock(:final blocks):
        total += _countBlocksPlainTextLength(blocks);
      case CleanMarkdownCodeBlock(:final code):
        total += code.length;
      case CleanMarkdownHorizontalRuleBlock():
        break;
      case CleanMarkdownTableBlock(:final headers, :final rows):
        for (final header in headers) {
          total += _collectInlinePlainText(header).length;
        }
        for (final row in rows) {
          for (final cell in row) {
            total += _collectInlinePlainText(cell).length;
          }
        }
      case CleanMarkdownImageBlock():
        break;
    }
  }
  return total;
}
