import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'dart:ui' as ui;

Future<Uint8List?> createImageFromWidget(
    Widget widget, {
      Duration? wait,
      Size? logicalSize,
      Size? imageSize,
      double scale = 1,
      Color backgroundColor = Colors.white,
    }) async {
  // 1) Ein FlutterView muss existieren (auch bei "headless" Desktop-Runner).
  final pd = WidgetsBinding.instance.platformDispatcher;
  final ui.FlutterView? flutterView =
      pd.implicitView ?? (pd.views.isNotEmpty ? pd.views.first : null);

  if (flutterView == null) {
    throw StateError(
      'Kein FlutterView verfügbar. Unter Linux braucht die App ein Display '
          '(lokal oder via Xvfb).',
    );
  }

  // 2) Größen ableiten
  logicalSize ??= flutterView.physicalSize / flutterView.devicePixelRatio;
  imageSize ??= flutterView.physicalSize;

  assert(
  (logicalSize.width / logicalSize.height) ==
      (imageSize.width / imageSize.height),
  'logicalSize und imageSize müssen dasselbe Seitenverhältnis haben.',
  );

  final repaintBoundary = RenderRepaintBoundary();

  final renderView = RenderView(
    child: RenderPositionedBox(
      alignment: Alignment.center,
      child: repaintBoundary,
    ),
    configuration: ViewConfiguration(
      devicePixelRatio: scale,
      physicalConstraints: BoxConstraints(
        minWidth: logicalSize.width / scale,
        maxWidth: logicalSize.width / scale,
        minHeight: 0,
        maxHeight: 100000,
      ),
      logicalConstraints: BoxConstraints(
        minWidth: logicalSize.width / scale,
        maxWidth: logicalSize.width / scale,
        minHeight: 0,
        maxHeight: 100000,
      ),
    ),
    view: flutterView,
  );

  final pipelineOwner = PipelineOwner();
  final buildOwner = BuildOwner(focusManager: FocusManager());

  pipelineOwner.rootNode = renderView;
  renderView.prepareInitialFrame();

  final rootElement = RenderObjectToWidgetAdapter<RenderBox>(
    container: repaintBoundary,
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Theme(
        data: ThemeData(brightness: Brightness.light),
        child: Material(
          color: backgroundColor,
          child: MediaQuery(
            data: MediaQueryData(
              textScaler: const TextScaler.linear(1),
              devicePixelRatio: scale,
            ),
            child: DefaultTextStyle.merge(
              style: const TextStyle(
                color: Colors.black,
                fontFamily: 'Roboto', // eigene Schrift falls gebündelt
                letterSpacing: 0.1,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [widget],
              ),
            ),
          ),
        ),
      ),
    ),
  ).attachToRenderTree(buildOwner);

  buildOwner.buildScope(rootElement);

  if (wait != null) {
    await Future.delayed(wait);
  }

  buildOwner
    ..buildScope(rootElement)
    ..finalizeTree();

  pipelineOwner
    ..flushLayout()
    ..flushCompositingBits()
    ..flushPaint();

  final ratio = imageSize.width / (logicalSize.width / scale);

  final image = await repaintBoundary.toImage(pixelRatio: ratio);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();

  // Aufräumen
  buildOwner.finalizeTree();
  pipelineOwner.rootNode = null;
  renderView.child = null;
  repaintBoundary.child = null;
  pipelineOwner.dispose();
  renderView.dispose();

  return byteData?.buffer.asUint8List();
}