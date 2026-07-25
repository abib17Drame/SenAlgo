// ---------------------------------------------------------------------------
// COPIE LOCALE CORRIGÉE DE `CodeField` (package flutter_code_editor 0.3.5).
//Why : parceque 

//   Le paramètre `wrap` de `CodeField` est déclaré et documenté, mais n'est
//   JAMAIS lu par la méthode `build()` : le champ est systématiquement placé
//   dans un `SingleChildScrollView` horizontal. Résultat, `wrap: true` n'a
//   aucun effet et les lignes longues débordent au lieu de revenir à la ligne
//    inutilisable sur un écran de téléphone.
//
//   Les imports internes du package (gutter, popup, sizes, actions…) ne sont
//   pas exportés publiquement : `CodeField` ne peut donc être ni sous-classé
//   ni corrigé de l'extérieur. D'où cette copie.
//
// Différences avec l'original (chercher « CORRECTIF SENALGO ») :
//   1. Classes renommées `WrappingCodeField` / `_WrappingCodeFieldState`
//      pour ne pas entrer en conflit avec celles du package.
//   2. Imports relatifs convertis en imports absolus `package:…/src/…`.
//   3. `build()` court-circuite `_wrapInScrollView()` lorsque `wrap` est vrai.

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';

import 'package:flutter_code_editor/src/code_theme/code_theme.dart';
import 'package:flutter_code_editor/src/gutter/gutter.dart';
import 'package:flutter_code_editor/src/line_numbers/gutter_style.dart';
import 'package:flutter_code_editor/src/search/widget/search_widget.dart';
import 'package:flutter_code_editor/src/sizes.dart';
import 'package:flutter_code_editor/src/wip/autocomplete/popup.dart';
import 'package:flutter_code_editor/src/code_field/actions/comment_uncomment.dart';
import 'package:flutter_code_editor/src/code_field/actions/enter_key.dart';
import 'package:flutter_code_editor/src/code_field/actions/indent.dart';
import 'package:flutter_code_editor/src/code_field/actions/outdent.dart';
import 'package:flutter_code_editor/src/code_field/actions/search.dart';
import 'package:flutter_code_editor/src/code_field/actions/tab.dart';
import 'package:flutter_code_editor/src/code_field/code_controller.dart';
import 'package:flutter_code_editor/src/code_field/default_styles.dart';
import 'package:flutter_code_editor/src/code_field/js_workarounds/js_workarounds.dart';

final _shortcuts = <ShortcutActivator, Intent>{
  // Copy
  LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.keyC,
  ): CopySelectionTextIntent.copy,
  const SingleActivator(
    LogicalKeyboardKey.keyC,
    meta: true,
  ): CopySelectionTextIntent.copy,
  LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.insert,
  ): CopySelectionTextIntent.copy,

  // Cut
  LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.keyX,
  ): const CopySelectionTextIntent.cut(SelectionChangedCause.keyboard),
  const SingleActivator(
    LogicalKeyboardKey.keyX,
    meta: true,
  ): const CopySelectionTextIntent.cut(SelectionChangedCause.keyboard),
  LogicalKeySet(
    LogicalKeyboardKey.shift,
    LogicalKeyboardKey.delete,
  ): const CopySelectionTextIntent.cut(SelectionChangedCause.keyboard),

  // Undo
  LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.keyZ,
  ): const UndoTextIntent(SelectionChangedCause.keyboard),
  const SingleActivator(
    LogicalKeyboardKey.keyZ,
    meta: true,
  ): const UndoTextIntent(SelectionChangedCause.keyboard),

  // Redo
  LogicalKeySet(
    LogicalKeyboardKey.shift,
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.keyZ,
  ): const RedoTextIntent(SelectionChangedCause.keyboard),
  LogicalKeySet(
    LogicalKeyboardKey.shift,
    LogicalKeyboardKey.meta,
    LogicalKeyboardKey.keyZ,
  ): const RedoTextIntent(SelectionChangedCause.keyboard),

  // Indent
  LogicalKeySet(
    LogicalKeyboardKey.tab,
  ): const IndentIntent(),

  // Outdent
  LogicalKeySet(
    LogicalKeyboardKey.shift,
    LogicalKeyboardKey.tab,
  ): const OutdentIntent(),

  // Comment Uncomment
  LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.slash,
  ): const CommentUncommentIntent(),
  const SingleActivator(
    LogicalKeyboardKey.slash,
    meta: true,
  ): const CommentUncommentIntent(),

  // Search
  LogicalKeySet(
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.keyF,
  ): const SearchIntent(),
  const SingleActivator(
    LogicalKeyboardKey.keyF,
    meta: true,
  ): const SearchIntent(),

  // Dismiss
  LogicalKeySet(
    LogicalKeyboardKey.escape,
  ): const DismissIntent(),

  // EnterKey
  LogicalKeySet(
    LogicalKeyboardKey.enter,
  ): const EnterKeyIntent(),

  // TabKey
  LogicalKeySet(
    LogicalKeyboardKey.tab,
  ): const TabKeyIntent(),
};

class WrappingCodeField extends StatefulWidget {
  /// {@macro flutter.widgets.textField.minLines}
  final int? minLines;

  /// {@macro flutter.widgets.textField.maxLInes}
  final int? maxLines;

  /// {@macro flutter.widgets.textField.expands}
  final bool expands;

  /// Whether overflowing lines should wrap around
  /// or make the field scrollable horizontally.
  final bool wrap;

  /// A CodeController instance to apply
  /// language highlight, themeing and modifiers.
  final CodeController controller;

  /// An UndoHistoryController instance
  /// to control TextField history.
  final UndoHistoryController? undoController;

  @Deprecated('Use gutterStyle instead')
  final GutterStyle lineNumberStyle;

  /// {@macro flutter.widgets.textField.cursorColor}
  final Color? cursorColor;

  /// {@macro flutter.widgets.textField.textStyle}
  final TextStyle? textStyle;

  /// {@macro flutter.widgets.textField.smartDashesType}
  final SmartDashesType smartDashesType;

  /// {@macro flutter.widgets.textField.smartQuotesType}
  final SmartQuotesType smartQuotesType;

  /// A way to replace specific line numbers by a custom TextSpan
  final TextSpan Function(int, TextStyle?)? lineNumberBuilder;

  /// {@macro flutter.widgets.textField.enabled}
  final bool? enabled;

  /// {@macro flutter.widgets.editableText.onChanged}
  final void Function(String)? onChanged;

  /// {@macro flutter.widgets.editableText.readOnly}
  ///
  /// This is just passed as a parameter to a [TextField].
  /// See also [CodeController.readOnly].
  final bool readOnly;

  final Color? background;
  final EdgeInsets padding;
  final Decoration? decoration;
  final TextSelectionThemeData? textSelectionTheme;
  final FocusNode? focusNode;

  @Deprecated('Use gutterStyle instead')
  final bool? lineNumbers;

  final GutterStyle gutterStyle;

  const WrappingCodeField({
    super.key,
    required this.controller,
    this.undoController,
    this.minLines,
    this.maxLines,
    this.expands = false,
    this.wrap = false,
    this.background,
    this.decoration,
    this.textStyle,
    this.smartDashesType = SmartDashesType.disabled,
    this.smartQuotesType = SmartQuotesType.disabled,
    this.padding = EdgeInsets.zero,
    GutterStyle? gutterStyle,
    this.enabled,
    this.readOnly = false,
    this.cursorColor,
    this.textSelectionTheme,
    this.lineNumberBuilder,
    this.focusNode,
    this.onChanged,
    @Deprecated('Use gutterStyle instead') this.lineNumbers,
    @Deprecated('Use gutterStyle instead')
    this.lineNumberStyle = const GutterStyle(),
  })  : assert(
            gutterStyle == null || lineNumbers == null,
            'Can not provide gutterStyle and lineNumbers at the same time. '
            'Please use gutterStyle and provide necessary columns to show/hide'),
        gutterStyle = gutterStyle ??
            ((lineNumbers == false) ? GutterStyle.none : lineNumberStyle);

  @override
  State<WrappingCodeField> createState() => _WrappingCodeFieldState();
}

class _WrappingCodeFieldState extends State<WrappingCodeField> {
  // Add a controller
  LinkedScrollControllerGroup? _controllers;
  ScrollController? _numberScroll;
  ScrollController? _codeScroll;
  ScrollController? _horizontalCodeScroll;
  final _wrappingCodeFieldKey = GlobalKey();

  OverlayEntry? _suggestionsPopup;
  OverlayEntry? _searchPopup;
  Offset _normalPopupOffset = Offset.zero;
  Offset _flippedPopupOffset = Offset.zero;
  double painterWidth = 0;
  double painterHeight = 0;

  FocusNode? _focusNode;
  String? lines;
  String longestLine = '';
  Size? windowSize;
  late TextStyle textStyle;
  Color? _backgroundCol;

  final _editorKey = GlobalKey();
  Offset? _editorOffset;

  @override
  void initState() {
    super.initState();
    _controllers = LinkedScrollControllerGroup();
    _numberScroll = _controllers?.addAndGet();
    _codeScroll = _controllers?.addAndGet();

    widget.controller.addListener(_onTextChanged);
    widget.controller.addListener(_updatePopupOffset);
    widget.controller.popupController.addListener(_onPopupStateChanged);
    widget.controller.searchController.addListener(
      _onSearchControllerChange,
    );
    _horizontalCodeScroll = ScrollController();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode!.attach(context, onKeyEvent: _onKeyEvent);

    widget.controller.searchController.codeFieldFocusNode = _focusNode;

    // Workaround for disabling spellchecks in FireFox
    // https://github.com/akvelon/flutter-code-editor/issues/197
    disableSpellCheckIfWeb();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final double width = _wrappingCodeFieldKey.currentContext!.size!.width;
      final double height = _wrappingCodeFieldKey.currentContext!.size!.height;
      windowSize = Size(width, height);
    });
    _onTextChanged();
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    return widget.controller.onKey(event);
  }

  @override
  void dispose() {
    widget.controller.searchController.codeFieldFocusNode = null;
    widget.controller.removeListener(_onTextChanged);
    widget.controller.removeListener(_updatePopupOffset);
    widget.controller.popupController.removeListener(_onPopupStateChanged);
    _suggestionsPopup?.remove();
    widget.controller.searchController.removeListener(
      _onSearchControllerChange,
    );
    _searchPopup?.remove();
    _searchPopup = null;
    _numberScroll?.dispose();
    _codeScroll?.dispose();
    _horizontalCodeScroll?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant WrappingCodeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    oldWidget.controller.removeListener(_onTextChanged);
    oldWidget.controller.removeListener(_updatePopupOffset);
    oldWidget.controller.popupController.removeListener(_onPopupStateChanged);
    oldWidget.controller.searchController.removeListener(
      _onSearchControllerChange,
    );

    widget.controller.searchController.codeFieldFocusNode = _focusNode;
    widget.controller.addListener(_onTextChanged);
    widget.controller.addListener(_updatePopupOffset);
    widget.controller.popupController.addListener(_onPopupStateChanged);
    widget.controller.searchController.addListener(
      _onSearchControllerChange,
    );
  }

  void rebuild() {
    setState(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        // For some reason _wrappingCodeFieldKey.currentContext is null in tests
        // so check first.
        final context = _wrappingCodeFieldKey.currentContext;
        if (context != null) {
          final double width = context.size!.width;
          final double height = context.size!.height;
          windowSize = Size(width, height);
        }
      });
    });
  }

  void _onTextChanged() {
    // Rebuild line number
    final str = widget.controller.text.split('\n');
    final buf = <String>[];

    for (var k = 0; k < str.length; k++) {
      buf.add((k + 1).toString());
    }

    // Find longest line
    longestLine = '';
    widget.controller.text.split('\n').forEach((line) {
      if (line.length > longestLine.length) longestLine = line;
    });

    if (_codeScroll != null && _editorKey.currentContext != null) {
      final box = _editorKey.currentContext!.findRenderObject() as RenderBox?;
      _editorOffset = box?.localToGlobal(Offset.zero);
      if (_editorOffset != null) {
        var fixedOffset = _editorOffset!;
        fixedOffset += Offset(0, _codeScroll!.offset);
        _editorOffset = fixedOffset;
      }
    }

    rebuild();
  }

  // Wrap the codeField in a horizontal scrollView
  Widget _wrapInScrollView(
    Widget codeField,
    TextStyle textStyle,
    double minWidth,
  ) {
    final intrinsic = IntrinsicWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: 0,
              minWidth: minWidth,
            ),
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(longestLine, style: textStyle),
            ), // Add extra padding
          ),
          widget.expands ? Expanded(child: codeField) : codeField,
        ],
      ),
    );

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        right: widget.padding.right,
      ),
      scrollDirection: Axis.horizontal,
      controller: _horizontalCodeScroll,
      child: intrinsic,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Default color scheme
    const rootKey = 'root';

    final themeData = Theme.of(context);
    final styles = CodeTheme.of(context)?.styles;
    _backgroundCol = widget.background ??
        styles?[rootKey]?.backgroundColor ??
        DefaultStyles.backgroundColor;

    if (widget.decoration != null) {
      _backgroundCol = null;
    }

    final defaultTextStyle = TextStyle(
      color: styles?[rootKey]?.color ?? DefaultStyles.textColor,
      fontSize: themeData.textTheme.titleMedium?.fontSize,
      height: themeData.textTheme.titleMedium?.height,
    );

    textStyle = defaultTextStyle.merge(widget.textStyle);

    final codeField = TextField(
      focusNode: _focusNode,
      scrollPadding: widget.padding,
      style: textStyle,
      smartDashesType: widget.smartDashesType,
      smartQuotesType: widget.smartQuotesType,
      controller: widget.controller,
      undoController: widget.undoController,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      expands: widget.expands,
      scrollController: _codeScroll,
      decoration: const InputDecoration(
        isCollapsed: true,
        contentPadding: EdgeInsets.symmetric(vertical: 16),
        disabledBorder: InputBorder.none,
        border: InputBorder.none,
        focusedBorder: InputBorder.none,
      ),
      cursorColor: widget.cursorColor ?? defaultTextStyle.color,
      autocorrect: false,
      enableSuggestions: false,
      enabled: widget.enabled,
      onChanged: widget.onChanged,
      readOnly: widget.readOnly,
    );

    final editingField = Theme(
      data: Theme.of(context).copyWith(
        textSelectionTheme: widget.textSelectionTheme,
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // ---- CORRECTIF SENALGO ----
          // En amont, cette ligne était exécutée inconditionnellement et le
          // champ `wrap` n'était jamais lu. Le champ était donc toujours placé
          // dans un défilement horizontal, ce qui l'élargit à la longueur de
          // la ligne la plus longue et empêche tout retour à la ligne.
          // Quand `wrap` est vrai, on rend simplement le champ tel quel : il
          // reçoit alors la largeur du parent et le TextField enroule le texte.
          if (widget.wrap) {
            return codeField;
          }
          // Control horizontal scrolling
          return _wrapInScrollView(codeField, textStyle, constraints.maxWidth);
        },
      ),
    );

    return FocusableActionDetector(
      actions: widget.controller.actions,
      shortcuts: _shortcuts,
      child: Container(
        decoration: widget.decoration,
        color: _backgroundCol,
        key: _wrappingCodeFieldKey,
        padding: const EdgeInsets.only(left: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.gutterStyle.showGutter) _buildGutter(),
            Expanded(key: _editorKey, child: editingField),
          ],
        ),
      ),
    );
  }

  Widget _buildGutter() {
    final lineNumberSize = textStyle.fontSize;
    final lineNumberColor =
        widget.gutterStyle.textStyle?.color ?? textStyle.color?.withOpacity(.5);

    final lineNumberTextStyle =
        (widget.gutterStyle.textStyle ?? textStyle).copyWith(
      color: lineNumberColor,
      fontFamily: textStyle.fontFamily,
      fontSize: lineNumberSize,
    );

    final gutterStyle = widget.gutterStyle.copyWith(
      textStyle: lineNumberTextStyle,
      errorPopupTextStyle: widget.gutterStyle.errorPopupTextStyle ??
          CodeTheme.of(context)?.styles['root'] ??
          textStyle.copyWith(
            fontSize: DefaultStyles.errorPopupTextSize,
            backgroundColor: DefaultStyles.backgroundColor,
            fontStyle: DefaultStyles.fontStyle,
          ),
    );

    return GutterWidget(
      codeController: widget.controller,
      style: gutterStyle,
      scrollController: _numberScroll,
    );
  }

  void _updatePopupOffset() {
    final textPainter = _getTextPainter(widget.controller.text);
    final caretHeight = _getCaretHeight(textPainter);

    final leftOffset = _getPopupLeftOffset(textPainter);
    final normalTopOffset = _getPopupTopOffset(textPainter, caretHeight);
    final flippedTopOffset = normalTopOffset -
        (Sizes.autocompletePopupMaxHeight + caretHeight + Sizes.caretPadding);

    setState(() {
      _normalPopupOffset = Offset(leftOffset, normalTopOffset);
      _flippedPopupOffset = Offset(leftOffset, flippedTopOffset);
    });
  }

  TextPainter _getTextPainter(String text) {
    return TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(text: text, style: textStyle),
    )..layout();
  }

  Offset _getCaretOffset(TextPainter textPainter) {
    return textPainter.getOffsetForCaret(
      widget.controller.selection.base,
      Rect.zero,
    );
  }

  double _getCaretHeight(TextPainter textPainter) {
    final double? caretFullHeight = textPainter.getFullHeightForCaret(
      widget.controller.selection.base,
      Rect.zero,
    );
    return caretFullHeight ?? 0;
  }

  double _getPopupLeftOffset(TextPainter textPainter) {
    // ---- CORRECTIF SENALGO ----
    // En mode retour à la ligne, `_wrapInScrollView` n'est pas utilisé et
    // `_horizontalCodeScroll` n'est donc attaché à aucune zone défilante :
    // lire `.offset` déclencherait une assertion. Il n'y a alors aucun
    // décalage horizontal à compenser.
    final horizontalOffset = (_horizontalCodeScroll?.hasClients ?? false)
        ? _horizontalCodeScroll!.offset
        : 0.0;
    return max(
      _getCaretOffset(textPainter).dx +
          widget.padding.left -
          horizontalOffset +
          (_editorOffset?.dx ?? 0),
      0,
    );
  }

  double _getPopupTopOffset(TextPainter textPainter, double caretHeight) {
    return max(
      _getCaretOffset(textPainter).dy +
          caretHeight +
          16 +
          widget.padding.top -
          _codeScroll!.offset +
          (_editorOffset?.dy ?? 0),
      0,
    );
  }

  void _onPopupStateChanged() {
    final shouldShow =
        widget.controller.popupController.shouldShow && windowSize != null;
    if (!shouldShow) {
      _suggestionsPopup?.remove();
      _suggestionsPopup = null;
      return;
    }

    if (_suggestionsPopup == null) {
      _suggestionsPopup = _buildSuggestionOverlay();
      Overlay.of(context).insert(_suggestionsPopup!);
    }

    _suggestionsPopup!.markNeedsBuild();
  }

  void _onSearchControllerChange() {
    final shouldShow = widget.controller.searchController.shouldShow;

    if (!shouldShow) {
      _searchPopup?.remove();
      _searchPopup = null;
      return;
    }

    if (_searchPopup == null) {
      _searchPopup = _buildSearchOverlay();
      Overlay.of(context).insert(_searchPopup!);
    }
  }

  OverlayEntry _buildSearchOverlay() {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = _getTextColorFromTheme() ?? colorScheme.onBackground;
    return OverlayEntry(
      builder: (context) {
        return Positioned(
          bottom: 10,
          right: 10,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              border: Border.all(
                color: borderColor,
              ),
              borderRadius: const BorderRadius.all(
                Radius.circular(5),
              ),
            ),
            child: Material(
              child: SearchWidget(
                searchController: widget.controller.searchController,
              ),
            ),
          ),
        );
      },
    );
  }

  Color? _getTextColorFromTheme() {
    final textTheme = Theme.of(context).textTheme;

    return textTheme.bodyLarge?.color ??
        textTheme.bodyMedium?.color ??
        textTheme.bodySmall?.color ??
        textTheme.displayLarge?.color ??
        textTheme.displayMedium?.color ??
        textTheme.displaySmall?.color ??
        textTheme.headlineLarge?.color ??
        textTheme.headlineMedium?.color ??
        textTheme.headlineSmall?.color ??
        textTheme.labelLarge?.color ??
        textTheme.labelMedium?.color ??
        textTheme.labelSmall?.color ??
        textTheme.titleLarge?.color ??
        textTheme.titleMedium?.color ??
        textTheme.titleSmall?.color;
  }

  OverlayEntry _buildSuggestionOverlay() {
    return OverlayEntry(
      builder: (context) {
        return Popup(
          normalOffset: _normalPopupOffset,
          flippedOffset: _flippedPopupOffset,
          controller: widget.controller.popupController,
          editingWindowSize: windowSize!,
          style: textStyle,
          backgroundColor: _backgroundCol,
          parentFocusNode: _focusNode!,
          editorOffset: _editorOffset,
        );
      },
    );
  }
}
