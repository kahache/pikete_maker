import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_shadows.dart';
import '../../../theme/app_typography.dart';
import '../../../theme/dimens.dart';
import '../../../widgets/logo_mark.dart';
import '../story_layout.dart';

/// The 9:16 image "Súbela a tu story" hands to the OS share sheet
/// (A3 r13 → N1 / D37). Rendered OFFSCREEN only (never shown in the UI) by
/// `renderWidgetToPng`, at [StoryGeometry.logicalSize] × [StoryGeometry.pixelRatio]
/// = 1080 × 1920.
///
/// Two layouts, one frame, shared by outfit and sneaker mode (pass 2 reuses
/// both with the sneaker copy/spec):
///
///  - [StoryFrame.photo] (N1, default ON): headline · ONE card = the user's
///    whole photo with the recommendation band glued under it · full-colour
///    lockup 28 below. Nothing is drawn over the photo. Geometry:
///    [PhotoStoryLayout] (spec §2.1).
///  - [StoryFrame.card] (r13, the "Incluir mi foto" OFF image): a mode's share
///    card (watermark off) + the lockup 32 below it, the group vertically
///    centred inside the story-safe insets. Byte-identical to r13's
///    `OutfitStoryFrame`.
///
/// Brand budget (D7/D8): white ground, UI mint 0, UI purple 0; the only brand
/// colours are the logo's own (logo turquoise ≠ action mint, USAGE §9).
class StoryFrame extends StatelessWidget {
  /// Photo story: [headline] (reused on-screen string), the decoded,
  /// UPRIGHT [photo] (see `decodeStoryPhoto`: it must already be a
  /// `ui.Image`, the one-shot offscreen render cannot wait for an async image
  /// provider) and the recommendation [band], which fills the card width ×
  /// [StoryGeometry.bandHeight]. [headlineLines] forces the headline to 2
  /// lines (null = auto fit, spec §2.1; see [StoryHeadlineFit]).
  const StoryFrame.photo({
    super.key,
    required String this.headline,
    required ui.Image this.photo,
    required Widget this.band,
    this.headlineLines,
  }) : card = null;

  /// Card-only story (r13): [card] is the mode's share canvas with its
  /// in-card watermark OFF (the lockup below replaces it).
  const StoryFrame.card({super.key, required Widget this.card})
      : headline = null,
        photo = null,
        band = null,
        headlineLines = null;

  final String? headline;
  final int? headlineLines;
  final ui.Image? photo;
  final Widget? band;
  final Widget? card;

  /// Card-only layout: card width = frame minus the standard screen margins
  /// (same air as on a phone).
  static const double _sideInset = Space.screenMargin;

  /// Card-only lockup height (r13): 32, a step up from the Home top bar's 24
  /// so the wordmark survives platform recompression (USAGE §6: card-only
  /// story keeps 32 / 80 px).
  static const double cardLockupHeight = 32;

  /// Card-only: air between the card and the lockup (USAGE §3 clearspace).
  static const double _cardLockupGap = Space.xl;

  @override
  Widget build(BuildContext context) {
    final AppColors c = context.colors;
    return SizedBox.fromSize(
      size: StoryGeometry.logicalSize,
      // Material (not a bare ColoredBox) as the plain `bg` surface: it also
      // provides the theme's DefaultTextStyle to this standalone, offscreen
      // tree — without it, text would pick up the app-level fallback style.
      child: Material(
        color: c.bg,
        child: card != null ? _cardLayout() : Builder(builder: _photoLayout),
      ),
    );
  }

  /// r13 card-only layout (kept byte-identical).
  Widget _cardLayout() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: _sideInset,
        vertical: StoryGeometry.safeInsetV,
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: StoryGeometry.logicalSize.width - 2 * _sideInset,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                card!,
                const SizedBox(height: _cardLockupGap),
                const LogoLockup(height: cardLockupHeight),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// N1 photo layout (spec §2.1), absolutely positioned from
  /// [PhotoStoryLayout] so every spec number maps 1:1.
  Widget _photoLayout(BuildContext context) {
    final AppColors c = context.colors;
    final ui.Image image = photo!;
    final TextStyle headlineStyle = DefaultTextStyle.of(context)
        .style
        .merge(AppType.display)
        .copyWith(color: c.textPrimary);
    final StoryHeadlineFit fit = headlineLines == 2
        ? const StoryHeadlineFit(lines: 2, scale: 1)
        : StoryHeadlineFit.of(
            headline!,
            headlineStyle,
            maxWidth: StoryGeometry.contentWidth,
          );
    final PhotoStoryLayout layout = PhotoStoryLayout.compute(
      photoAspect: image.width / image.height,
      headlineLines: fit.lines,
    );
    final Rect card = layout.card;
    return Stack(
      children: <Widget>[
        Positioned(
          left: (StoryGeometry.logicalSize.width - StoryGeometry.contentWidth) /
              2,
          width: StoryGeometry.contentWidth,
          top: layout.headlineTop,
          height: layout.headlineHeight,
          child: _Headline(text: headline!, style: headlineStyle, fit: fit),
        ),
        Positioned.fromRect(
          rect: card,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.lg),
              boxShadow: <BoxShadow>[
                // Hairline ring OUTSIDE the card (mockup `0 0 0 1px border`),
                // so it never eats a pixel of the photo or the band.
                AppShadows.ring(c.border),
                ...AppShadows.sm,
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.lg),
              child: Column(
                children: <Widget>[
                  SizedBox(
                    width: layout.photo.width,
                    height: layout.photo.height,
                    // Painted synchronously from the decoded bitmap. `cover`
                    // + centred: identical to "contain" inside the 5:8–16:9
                    // range (the box has the photo's own aspect); outside it,
                    // the excess is cut evenly from both ends.
                    child: RawImage(
                      image: image,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                  SizedBox(
                    width: layout.band.width,
                    height: layout.band.height,
                    child: band,
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: layout.logoTop,
          height: StoryGeometry.logoHeight,
          child: const Center(
            child: LogoLockup(height: StoryGeometry.logoHeight),
          ),
        ),
      ],
    );
  }
}

/// How the story headline fits the 392 px content width (spec §2.1): one line
/// at 32 px; if too wide, one line scaled down (floor 24 px); if it still
/// doesn't fit, two lines at 32 px.
@immutable
class StoryHeadlineFit {
  const StoryHeadlineFit({required this.lines, required this.scale});

  /// Lays [text] out in [style] and picks the fit for [maxWidth].
  factory StoryHeadlineFit.of(
    String text,
    TextStyle style, {
    required double maxWidth,
  }) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final double natural = painter.width;
    painter.dispose();
    if (natural <= maxWidth) return const StoryHeadlineFit(lines: 1, scale: 1);
    final double scale = maxWidth / natural;
    if (scale >= minScale) return StoryHeadlineFit(lines: 1, scale: scale);
    return const StoryHeadlineFit(lines: 2, scale: 1);
  }

  /// One-line floor: 24 / 32.
  static const double minScale = 24 / 32;

  final int lines;

  /// Scale applied to a 1-line headline (1 = natural size).
  final double scale;
}

/// The story headline: `display` 32/38, weight 800, centred.
class _Headline extends StatelessWidget {
  const _Headline({required this.text, required this.style, required this.fit});

  final String text;
  final TextStyle style;
  final StoryHeadlineFit fit;

  @override
  Widget build(BuildContext context) {
    if (fit.lines == 1) {
      return Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            maxLines: 1,
            softWrap: false,
            textAlign: TextAlign.center,
            style: style,
          ),
        ),
      );
    }
    return Center(
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: style,
      ),
    );
  }
}
