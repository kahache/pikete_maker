import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_typography.dart';
import '../../theme/dimens.dart';
import '../../widgets/pk_buttons.dart';
import 'story_export.dart';
import 'story_layout.dart';
import 'story_preferences.dart';

/// Renders one state of the story (with or without the photo) to PNG bytes.
/// Receives the sheet's context (Theme, Localizations, View) to render with.
typedef StoryRenderer = Future<Uint8List> Function(BuildContext context);

/// Reports a finished OS share (analytics): the platform `status`, the PNG
/// size, whether the photo was in it and `previewMs` (sheet open → first
/// preview ready: the on-device check of the < 600 ms budget). Never the
/// image or its path.
typedef StoryShareLogger = void Function({
  required String status,
  required int bytes,
  required bool photo,
  required int? previewMs,
});

/// How the preview sheet ended.
enum StoryShareOutcome {
  /// The OS share sheet reported success/unavailable: the sheet closed.
  shared,

  /// The user closed the sheet (swipe down, scrim, back) without sharing.
  closed,

  /// Nothing could be rendered, or the share threw: the caller shows the
  /// existing `storyFailedSnack`.
  failed,
}

/// Opens the N1 preview sheet (D37, spec §3) and resolves when it closes.
///
/// "Súbela a tu story" → this sheet (the exact PNG + "Incluir mi foto" +
/// privacy line + "Compartir") → the OS share sheet. Shared by outfit and
/// sneaker mode: each result screen passes its own renderers.
///
///  - [cardOnly] renders the r13 card-only story (switch OFF).
///  - [withPhoto] renders the photo story (switch ON); null (no photo bytes,
///    legacy layout) hides the switch and shares the card.
///  - [initialIncludePhoto] forces the first state instead of the remembered
///    one, and [rememberChoice] = false keeps toggles out of [preferences]
///    (pass 2: screenshot-sourced sneaker photos always open OFF, spec §5.3).
///
/// Whatever happens, the story file is DELETED when the sheet closes, so
/// "no la guardamos" stays literally true (the share plugin keeps its own
/// copy in its cache folder until its next share).
Future<StoryShareOutcome> showStorySharePreview({
  required BuildContext context,
  required StoryRenderer cardOnly,
  StoryRenderer? withPhoto,
  required StorySharer sharer,
  required StoryPreferences preferences,
  bool? initialIncludePhoto,
  bool rememberChoice = true,
  StoryFileWriter writeFile = writeStoryPng,
  StoryShareLogger? onShared,
}) async {
  final AppColors c = context.colors;
  try {
    final StoryShareOutcome? outcome =
        await showModalBottomSheet<StoryShareOutcome>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: c.bg,
      barrierColor: c.scrim,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radii.rLg),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (BuildContext _) => StorySharePreviewSheet(
        cardOnly: cardOnly,
        withPhoto: withPhoto,
        sharer: sharer,
        preferences: preferences,
        initialIncludePhoto: initialIncludePhoto,
        rememberChoice: rememberChoice,
        writeFile: writeFile,
        onShared: onShared,
      ),
    );
    return outcome ?? StoryShareOutcome.closed;
  } finally {
    deleteStoryFile();
  }
}

/// The preview sheet itself (spec §3.2 layout, §3.3 states). Use
/// [showStorySharePreview] to open it.
class StorySharePreviewSheet extends StatefulWidget {
  const StorySharePreviewSheet({
    super.key,
    required this.cardOnly,
    this.withPhoto,
    required this.sharer,
    required this.preferences,
    this.initialIncludePhoto,
    this.rememberChoice = true,
    this.writeFile = writeStoryPng,
    this.onShared,
  });

  final StoryRenderer cardOnly;
  final StoryRenderer? withPhoto;
  final StorySharer sharer;
  final StoryPreferences preferences;
  final bool? initialIncludePhoto;
  final bool rememberChoice;
  final StoryFileWriter writeFile;
  final StoryShareLogger? onShared;

  /// Test keys.
  static const Key previewKey = Key('story_preview');
  static const Key previewPlaceholderKey = Key('story_preview_loading');
  static const Key toggleKey = Key('story_include_photo');
  static const Key ctaKey = Key('story_share_cta');

  /// Preview height (9:16): 480 on a 844-tall phone, flexing down to 280.
  static const double previewMaxHeight = 480;
  static const double previewMinHeight = 280;

  /// Where the sheet's top edge sits on the 844 reference (the result peeks
  /// behind it).
  static const double sheetTopOffset = 112;

  @override
  State<StorySharePreviewSheet> createState() => _StorySharePreviewSheetState();
}

class _StorySharePreviewSheetState extends State<StorySharePreviewSheet> {
  // Layout constants of the sheet (spec §3.2, 390 × 844 reference).
  static const double _handleTop = Space.sm;
  static const double _handleWidth = 36;
  static const double _handleHeight = 4;
  static const double _previewTop = 28;
  static const double _previewGap = 20;
  static const double _toggleRowHeight = 56;
  static const double _privacyGap = 2;
  static const double _privacyHeight = 18;
  static const double _ctaGap = Space.xxxl;

  /// Everything except the preview, stacked (for the preview's flex height).
  static const double _fixedHeight = _previewTop +
      _previewGap +
      _toggleRowHeight +
      _privacyGap +
      _privacyHeight +
      _ctaGap +
      Sizes.ctaHeight +
      Space.thumbZoneCta;

  /// Rendered PNGs by state (true = with photo), cached for the sheet's life
  /// and dropped with it.
  final Map<bool, Uint8List> _pngs = <bool, Uint8List>{};
  final Set<bool> _inFlight = <bool>{};

  /// Key on the CTA: its rect anchors the share popover on iPad.
  final GlobalKey _ctaKey = GlobalKey();

  /// Null until the initial state is resolved (remembered choice).
  bool? _includePhoto;

  /// False when there is no photo renderer or the photo render failed: the
  /// switch is hidden and the card is shared.
  late bool _photoAvailable = widget.withPhoto != null;

  /// The PNG on screen. During a switch it keeps the previous state's image
  /// until the new one is ready (then crossfades).
  Uint8List? _shown;

  /// Double-tap guard while the OS share sheet is open.
  bool _sharing = false;

  /// Sheet open → first preview on screen (perceived-latency measurement).
  final Stopwatch _openClock = Stopwatch()..start();
  int? _previewMs;

  /// The PNG of the CURRENT state, once ready — what "Compartir" shares.
  Uint8List? get _current =>
      _includePhoto == null ? null : _pngs[_includePhoto!];

  @override
  void initState() {
    super.initState();
    // Right after the sheet's first frame (it is still animating in, so the
    // render overlaps the slide-up): the renderers read the sheet's inherited
    // Theme/Localizations, which initState must not do.
    WidgetsBinding.instance
        .addPostFrameCallback((Duration _) => unawaited(_start()));
  }

  Future<void> _start() async {
    bool include = false;
    if (_photoAvailable) {
      include = widget.initialIncludePhoto ??
          await widget.preferences.includePhoto();
    }
    if (!mounted) return;
    setState(() => _includePhoto = include);
    await _ensureRendered(include);
  }

  /// Renders [photo]'s state once (cached), showing it if still selected.
  Future<void> _ensureRendered(bool photo) async {
    final Uint8List? cached = _pngs[photo];
    if (cached != null) {
      if (_includePhoto == photo) setState(() => _shown = cached);
      return;
    }
    if (!_inFlight.add(photo)) return;
    try {
      final Uint8List png = photo
          ? await widget.withPhoto!(context)
          : await widget.cardOnly(context);
      if (!mounted) return;
      _pngs[photo] = png;
      _previewMs ??= _openClock.elapsedMilliseconds;
      if (_includePhoto == photo) setState(() => _shown = png);
    } on Object {
      if (!mounted) return;
      if (photo) {
        // Spec §2.4: the photo render threw → silently card-only, switch
        // hidden (no new error string).
        setState(() {
          _photoAvailable = false;
          _includePhoto = false;
        });
        await _ensureRendered(false);
      } else {
        // The card render failed too: close; the caller shows the existing
        // storyFailedSnack.
        Navigator.of(context).pop(StoryShareOutcome.failed);
      }
    } finally {
      _inFlight.remove(photo);
    }
  }

  void _setIncludePhoto(bool value) {
    if (!_photoAvailable || _includePhoto == null || _includePhoto == value) {
      return;
    }
    setState(() {
      _includePhoto = value;
      final Uint8List? cached = _pngs[value];
      if (cached != null) _shown = cached;
    });
    if (widget.rememberChoice) {
      unawaited(widget.preferences.setIncludePhoto(value));
    }
    unawaited(_ensureRendered(value));
  }

  Future<void> _share() async {
    final Uint8List? png = _current;
    final bool? photo = _includePhoto;
    if (png == null || photo == null || _sharing) return;
    setState(() => _sharing = true);
    final NavigatorState nav = Navigator.of(context);
    final Rect? origin = _ctaRect();
    try {
      // What you see is what you share: the SAME bytes the preview decodes.
      final File file = await widget.writeFile(png);
      if (!mounted) return;
      final String status = await widget.sharer(file, origin);
      widget.onShared?.call(
        status: status,
        bytes: png.length,
        photo: photo,
        previewMs: _previewMs,
      );
      if (!mounted) return;
      // Dismissed = the user backed out of the OS sheet: keep the preview.
      if (status != 'dismissed') nav.pop(StoryShareOutcome.shared);
    } on Object {
      if (mounted) nav.pop(StoryShareOutcome.failed);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Rect? _ctaRect() {
    final RenderObject? box = _ctaKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final AppLocalizations l10n = context.l10n;
    final MediaQueryData mq = MediaQuery.of(context);
    final double previewHeight = (mq.size.height -
            StorySharePreviewSheet.sheetTopOffset -
            _fixedHeight -
            mq.viewPadding.bottom)
        .clamp(StorySharePreviewSheet.previewMinHeight,
            StorySharePreviewSheet.previewMaxHeight);
    final double previewWidth = previewHeight *
        StoryGeometry.logicalSize.width /
        StoryGeometry.logicalSize.height;
    final bool ready = _current != null && !_sharing;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.screenMargin),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(height: _handleTop),
          Container(
            width: _handleWidth,
            height: _handleHeight,
            decoration: BoxDecoration(
              color: c.borderStrong,
              borderRadius: BorderRadius.circular(_handleHeight / 2),
            ),
          ),
          const SizedBox(height: _previewTop - _handleTop - _handleHeight),
          _Preview(
            png: _shown,
            width: previewWidth,
            height: previewHeight,
            label: l10n.storyPreviewLabel,
          ),
          const SizedBox(height: _previewGap),
          if (_photoAvailable)
            _IncludePhotoRow(
              label: l10n.storyIncludePhoto,
              value: _includePhoto ?? true,
              onChanged: _includePhoto == null ? null : _setIncludePhoto,
            ),
          const SizedBox(height: _privacyGap),
          SizedBox(
            width: double.infinity,
            child: Text(
              l10n.storyPhotoPrivacy,
              style: AppType.caption.copyWith(color: c.textTertiary),
            ),
          ),
          const SizedBox(height: _ctaGap),
          // Spec §3.3: disabled = surfaceSubtle / textDisabled (the sheet's
          // own disabled look; everything else is the theme's pill).
          KeyedSubtree(
            key: _ctaKey,
            child: FilledButtonTheme(
              data: FilledButtonThemeData(
                style: FilledButton.styleFrom(
                  disabledBackgroundColor: c.surfaceSubtle,
                  disabledForegroundColor: c.textDisabled,
                ).merge(Theme.of(context).filledButtonTheme.style),
              ),
              child: PkPrimaryButton(
                key: StorySharePreviewSheet.ctaKey,
                label: l10n.storyShareCta,
                onPressed: ready ? _share : null,
              ),
            ),
          ),
          SizedBox(height: Space.thumbZoneCta + mq.viewPadding.bottom),
        ],
      ),
    );
  }
}

/// The exact PNG that will be shared (decoded at preview size), or a plain
/// 9:16 `surfaceSubtle` box while it renders (no spinner: well under a
/// second). Crossfades (motion.base) when the other state becomes ready.
class _Preview extends StatelessWidget {
  const _Preview({
    required this.png,
    required this.width,
    required this.height,
    required this.label,
  });

  final Uint8List? png;
  final double width;
  final double height;
  final String label;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    final Uint8List? bytes = png;
    return Semantics(
      label: label,
      image: true,
      child: Container(
        key: StorySharePreviewSheet.previewKey,
        width: width,
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: c.surfaceSubtle,
          borderRadius: BorderRadius.circular(Radii.md),
          boxShadow: <BoxShadow>[AppShadows.ring(c.border), ...AppShadows.md],
        ),
        child: AnimatedSwitcher(
          duration: AppMotion.base,
          child: bytes == null
              ? const SizedBox.expand(
                  key: StorySharePreviewSheet.previewPlaceholderKey)
              : Image.memory(
                  bytes,
                  key: ObjectKey(bytes),
                  width: width,
                  height: height,
                  fit: BoxFit.cover,
                  cacheWidth: (width * dpr).round(),
                  gaplessPlayback: true,
                  excludeFromSemantics: true,
                ),
        ),
      ),
    );
  }
}

/// "Incluir mi foto": 56 tall, the WHOLE row toggles (≥ 44 touch target).
/// ON = action track, OFF = borderStrong track, white thumb.
class _IncludePhotoRow extends StatelessWidget {
  const _IncludePhotoRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  static const double _height = 56;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return MergeSemantics(
      child: InkWell(
        key: StorySharePreviewSheet.toggleKey,
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: SizedBox(
          height: _height,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  label,
                  style: AppType.heading.copyWith(color: c.textPrimary),
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeTrackColor: c.action,
                activeThumbColor: c.actionOnFill,
                inactiveTrackColor: c.borderStrong,
                inactiveThumbColor: c.actionOnFill,
                trackOutlineColor:
                    const WidgetStatePropertyAll<Color>(Colors.transparent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
