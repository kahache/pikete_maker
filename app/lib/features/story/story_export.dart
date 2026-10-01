import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import 'story_layout.dart';
import 'story_photo.dart';

/// Story export plumbing (F6 → A3 r13 → N1 / D37): render the 9:16 story
/// frame to a PNG OFFSCREEN, drop it in the app cache, hand it to the OS
/// share sheet, delete it afterwards. Shared by outfit and sneaker mode.

/// Renders [child] to PNG bytes in a standalone, offscreen widget tree of
/// [logicalSize] × [pixelRatio] physical pixels — nothing is ever shown on
/// screen.
///
/// Why offscreen (and not `RepaintBoundary.toImage` on the visible card, as
/// F6 did): the shared image is a true 9:16 composition that differs from the
/// on-screen layout. A private [PipelineOwner]/[BuildOwner] pair builds, lays
/// out and paints the tree ONCE — the same technique Flutter uses internally
/// for `runApp`, without attaching to the real view.
///
/// ⚠ One-shot means SYNCHRONOUS paint: anything that resolves asynchronously
/// (an `Image`/`Image.memory` widget) paints empty here. Images must be
/// decoded to a `ui.Image` BEFORE the call and painted with `RawImage` — see
/// [renderPhotoStoryPng].
///
/// [context] supplies the ambient Theme (incl. the AppColors extension),
/// Localizations (active locale + delegates) and Directionality, so the frame
/// renders exactly as the screen would. Text scaling is fixed at 1.0: the
/// output is an image of fixed size, not an accessible UI.
///
/// Real async (image encoding): in widget tests call it inside `runAsync`.
Future<Uint8List> renderWidgetToPng(
  BuildContext context,
  Widget child, {
  required Size logicalSize,
  double pixelRatio = 3.0,
}) async {
  final Widget tree = InheritedTheme.captureAll(
    context,
    Localizations.override(
      context: context,
      child: MediaQuery(
        data: MediaQueryData(size: logicalSize, devicePixelRatio: pixelRatio),
        child: child,
      ),
    ),
  );

  final RenderRepaintBoundary boundary = RenderRepaintBoundary();
  final RenderView renderView = RenderView(
    view: View.of(context),
    configuration: ViewConfiguration(
      logicalConstraints: BoxConstraints.tight(logicalSize),
      physicalConstraints: BoxConstraints.tight(logicalSize * pixelRatio),
      devicePixelRatio: pixelRatio,
    ),
    child: RenderPositionedBox(child: boundary),
  );
  final PipelineOwner pipelineOwner = PipelineOwner()..rootNode = renderView;
  renderView.prepareInitialFrame();
  final FocusManager focusManager = FocusManager();
  final BuildOwner buildOwner = BuildOwner(focusManager: focusManager);

  final RenderObjectToWidgetElement<RenderBox> root =
      RenderObjectToWidgetAdapter<RenderBox>(container: boundary, child: tree)
          .attachToRenderTree(buildOwner);
  try {
    buildOwner
      ..buildScope(root)
      ..finalizeTree();
    pipelineOwner
      ..flushLayout()
      ..flushCompositingBits()
      ..flushPaint();

    final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      final ByteData? data =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        throw StateError('Could not encode the story PNG');
      }
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      image.dispose();
    }
  } finally {
    // Unmount the offscreen tree (same move as runApp replacing its root) so
    // no element/state outlives the capture.
    RenderObjectToWidgetAdapter<RenderBox>(container: boundary)
        .attachToRenderTree(buildOwner, root);
    buildOwner.finalizeTree();
    focusManager.dispose();
    pipelineOwner.rootNode = null;
    renderView.dispose();
    pipelineOwner.dispose();
  }
}

/// Renders a story frame at native story size ([StoryGeometry]).
Future<Uint8List> renderStoryPng(BuildContext context, Widget frame) =>
    renderWidgetToPng(
      context,
      frame,
      logicalSize: StoryGeometry.logicalSize,
      pixelRatio: StoryGeometry.pixelRatio,
    );

/// Renders the N1 photo story: decodes [photoBytes] to an upright, story-sized
/// `ui.Image` FIRST (awaited), builds the frame around it with [frame] and
/// renders it. The bitmap is released once the PNG is encoded.
///
/// This ordering is the whole fix for the offscreen blank-photo trap (spec
/// §8.4): the one-shot render only ever sees an already-decoded image.
Future<Uint8List> renderPhotoStoryPng(
  BuildContext context,
  Uint8List photoBytes,
  Widget Function(ui.Image photo) frame,
) async {
  final ui.Image photo = await decodeStoryPhoto(photoBytes);
  try {
    if (!context.mounted) throw StateError('story host unmounted');
    return await renderStoryPng(context, frame(photo));
  } finally {
    photo.dispose();
  }
}

/// File name of the exported story in the app cache. FIXED on purpose: each
/// export overwrites the previous one, so the cache holds at most one story.
/// The share plugin copies the file into its own share folder
/// ([kSharePluginCacheFolder], cleared by the plugin on its next share)
/// before handing it out, so deleting ours right after the share never
/// breaks it.
const String kStoryFileName = 'piketemaker_story.png';

/// Directory the story PNG is written to: `Directory.systemTemp`, app-private
/// and outside any backup. On Android that is NOT `Context.getCacheDir()`:
/// the Flutter engine points `TMPDIR` at `Context.getCodeCacheDir()`
/// (`<data>/code_cache`, see [kAndroidCodeCacheDirName]) — VERIFIED on device
/// (F2.5 spike, 2026-07-14: a file written to `systemTemp` was read back from
/// `code_cache/` with `run-as`) and in the embedding
/// (`io.flutter.util.PathUtils.getCacheDirectory` returns the code cache).
/// `path_provider` is not a direct dependency (APK weight G1). Tests point it
/// at a private temp dir so parallel test processes never race on one file.
@visibleForTesting
Directory Function() storyCacheDirectory = () => Directory.systemTemp;

/// Basename of the directory `Directory.systemTemp` resolves to on Android.
const String kAndroidCodeCacheDirName = 'code_cache';

/// Basename of Android's `Context.getCacheDir()`, the sibling of
/// [kAndroidCodeCacheDirName] in the app's data dir.
const String kAndroidCacheDirName = 'cache';

/// The directory share_plus keeps its copy in (Android: `Context.getCacheDir()`
/// + [kSharePluginCacheFolder]), derived from [tempDir] (=
/// [storyCacheDirectory]) without a platform call, so app start can stay
/// synchronous:
///  * [tempDir] is `<data>/code_cache` (Android) → `<data>/cache`;
///  * anything else (iOS, host tests) → [tempDir] itself.
///
/// Security audit Q2 (2026-10-01): the purge used to look in
/// `systemTemp/share_plus` = `code_cache/share_plus`, which never exists on
/// Android, so the plugin's copy of the last shared story — the user's photo
/// — survived app restarts until the next share.
Directory shareCacheDirectoryFor(Directory tempDir) {
  final List<String> segments = tempDir.path
      .split(RegExp(r'[/\\]'))
      .where((String s) => s.isNotEmpty)
      .toList();
  if (segments.isNotEmpty && segments.last == kAndroidCodeCacheDirName) {
    return Directory('${tempDir.parent.path}/$kAndroidCacheDirName');
  }
  return tempDir;
}

/// The story PNG's path (it may not exist).
File storyFile() => File('${storyCacheDirectory().path}/$kStoryFileName');

/// Writes [png] to the story file and returns it.
Future<File> writeStoryPng(Uint8List png) async {
  final File file = storyFile();
  await file.writeAsBytes(png, flush: true);
  return file;
}

/// Seam type of [writeStoryPng] (tests capture the exact bytes written).
typedef StoryFileWriter = Future<File> Function(Uint8List png);

/// Deletes the story PNG if present (N1 / D37). Called when the preview sheet
/// closes AND on app start: the image now contains the user's photo, and ONB-1
/// promises "no la guardamos". Synchronous (one `unlink` of one small file)
/// so app start can run it before the first frame; never throws.
void deleteStoryFile() {
  try {
    final File file = storyFile();
    if (file.existsSync()) file.deleteSync();
  } on Object {
    // Best effort: a locked/missing file is not worth a crash. The next
    // export overwrites it anyway and the next start retries.
  }
}

/// The folder, inside the app cache (`Context.getCacheDir()`, see
/// [shareCacheDirectoryFor]), where share_plus (Android) keeps the copy of
/// the last shared file until its next share. It contains the user's photo
/// after a photo story share.
const String kSharePluginCacheFolder = 'share_plus';

/// Deletes EVERYTHING the story share may have left on disk: our story PNG
/// and the share plugin's copy ([kSharePluginCacheFolder]). Called on app
/// start (N1 / D37): with the photo in the story, "no la guardamos" must stay
/// literally true, and the plugin's copy counts. Not called when the sheet
/// closes: the target app (WhatsApp, Instagram…) may still be reading the
/// plugin's copy then; at the next start nothing is. Synchronous, never
/// throws; only this app shares through share_plus, so the folder only ever
/// holds stories.
void purgeStoryCache() {
  deleteStoryFile();
  final Directory temp = storyCacheDirectory();
  // The real location (Android cache dir) AND the temp dir itself, in case a
  // future engine points TMPDIR at the cache dir directly.
  for (final Directory root in <Directory>[
    shareCacheDirectoryFor(temp),
    temp,
  ]) {
    try {
      final Directory shared =
          Directory('${root.path}/$kSharePluginCacheFolder');
      if (shared.existsSync()) shared.deleteSync(recursive: true);
    } on Object {
      // Best effort, retried at the next start.
    }
  }
}

/// Hands the story PNG to the OS and reports what the user did:
/// `'success'` (picked a target), `'dismissed'` (closed the sheet) or
/// `'unavailable'` (the platform can't tell). Seam type so tests can inject a
/// fake instead of the platform channel.
typedef StorySharer = Future<String> Function(File png, Rect? origin);

/// Production [StorySharer]: the OS share sheet via share_plus (Android:
/// `Intent.ACTION_SEND` chooser through the plugin's FileProvider — no
/// INTERNET permission, nothing leaves the device unless the user picks a
/// target). [origin] anchors the popover on iPad (ignored on phones).
Future<String> shareStoryWithSystemSheet(File png, Rect? origin) async {
  final ShareResult result = await SharePlus.instance.share(
    ShareParams(
      files: <XFile>[XFile(png.path, mimeType: 'image/png')],
      sharePositionOrigin: origin,
    ),
  );
  return result.status.name;
}
