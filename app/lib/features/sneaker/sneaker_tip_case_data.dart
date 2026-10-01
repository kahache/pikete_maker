import '../../l10n/l10n.dart';
import '../capture/photo_picker.dart';
import 'sneaker_tip_illustrations.dart';

/// Per-case copy + behavior map (extends [SneakerTipCase] with the copy-map
/// strings — now ARB keys resolved in the active locale — and the source each
/// card resolves to).
extension SneakerTipCaseData on SneakerTipCase {
  /// `source` param of the `sneaker_source_selected` event.
  String get analyticsValue => switch (this) {
        SneakerTipCase.casa => 'casa',
        SneakerTipCase.tienda => 'tienda',
        SneakerTipCase.web => 'web',
      };

  /// "Captura de pantalla" (web) = a shop's product image, i.e. a THIRD
  /// PARTY's copyrighted photo (decision #3 risk). N1 / D37 spec §5.3: the
  /// story preview opens with "Incluir mi foto" OFF for it and never
  /// remembers the choice. Camera photos (casa/tienda) are the user's own.
  bool get isThirdPartyImage => this == SneakerTipCase.web;

  /// The card determines the source: casa/tienda shoot fresh (camera); a web
  /// screenshot already lives on the phone (gallery).
  PhotoSource get photoSource => switch (this) {
        SneakerTipCase.casa => PhotoSource.camera,
        SneakerTipCase.tienda => PhotoSource.camera,
        SneakerTipCase.web => PhotoSource.gallery,
      };

  String get emoji => switch (this) {
        SneakerTipCase.casa => '\u{1F3E0}', // 🏠
        SneakerTipCase.tienda => '\u{1F3EC}', // 🏬
        SneakerTipCase.web => '\u{1F4BB}', // 💻
      };

  String cardTitle(AppLocalizations l10n) => switch (this) {
        SneakerTipCase.casa => l10n.sneakerSourceCasaTitle,
        SneakerTipCase.tienda => l10n.sneakerSourceTiendaTitle,
        SneakerTipCase.web => l10n.sneakerSourceWebTitle,
      };

  String cardHint(AppLocalizations l10n) => switch (this) {
        SneakerTipCase.casa => l10n.sneakerSourceCasaHint,
        SneakerTipCase.tienda => l10n.sneakerSourceTiendaHint,
        SneakerTipCase.web => l10n.sneakerSourceWebHint,
      };

  String tipTitle(AppLocalizations l10n) => switch (this) {
        SneakerTipCase.casa => l10n.sneakerTipCasaTitle,
        SneakerTipCase.tienda => l10n.sneakerTipTiendaTitle,
        SneakerTipCase.web => l10n.sneakerTipWebTitle,
      };

  String tipBody(AppLocalizations l10n) => switch (this) {
        SneakerTipCase.casa => l10n.sneakerTipCasaBody,
        SneakerTipCase.tienda => l10n.sneakerTipTiendaBody,
        SneakerTipCase.web => l10n.sneakerTipWebBody,
      };

  String tipCta(AppLocalizations l10n) => switch (this) {
        SneakerTipCase.casa => l10n.sneakerTipCasaCta,
        SneakerTipCase.tienda => l10n.sneakerTipTiendaCta,
        SneakerTipCase.web => l10n.sneakerTipWebCta,
      };
}
