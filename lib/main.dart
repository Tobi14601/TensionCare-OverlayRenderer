import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:collection/algorithms.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:sprintf/sprintf.dart';
import 'package:tc_overlay_renderer/chart_helper.dart';
import 'package:tc_overlay_renderer/consts.dart';
import 'package:tc_overlay_renderer/record_util.dart';
import 'package:path/path.dart' as path;
import 'package:tc_overlay_renderer/recording_model.dart';

late File metaDataFile;
late Directory imagesFolder;
late Directory outFolder;
late Recording recording;

var _showVideoForceLive = true;


var maxValue = 0.0;

late List<MeasurePoint> leftPoints;
late List<MeasurePoint> rightPoints;

void main(List<String> args) {
  if (args.length != 3) {
    print("Invalid args");
    exit(2);
  }

  metaDataFile = File(args[0]);
  imagesFolder = Directory(args[1]);
  outFolder = Directory(args[2]);

  WidgetsFlutterBinding.ensureInitialized();


  scheduleMicrotask(() async {
    try {
      await _process();

      exit(0);
    } catch (ex) {
      print(ex);
      exit(1);
    }
  });

  runApp(const SizedBox.shrink());
}

Future<void> _process() async {
  recording = Recording.readRecordingFromBuffer(metaDataFile.readAsBytesSync());

  leftPoints = [];
  rightPoints = [];

  for (var entry in recording.replay) {
    if (entry.value > maxValue) {
      maxValue = entry.value;
    }

    var point = MeasurePoint(entry.timestamp.toDouble(), entry.value);

    switch (entry.position) {
      case SensorPosition.left:
        leftPoints.add(point);
        break;
      case SensorPosition.right:
        rightPoints.add(point);
        break;
    }
  }
  if (!await outFolder.exists()) {
    await outFolder.create();
  }

  var images = await imagesFolder.list().toList();

  for (var image in images) {
    if (image is File) {
      print(image);
      await _processImage(image);
    }
  }
}

Future<void> _processImage(File image) async {
  if (!await image.exists()) {
    return;
  }
  var name = path.basename(image.path);
  if (!name.toLowerCase().endsWith('.png')) {
    return;
  }

  var regex = RegExp('frame_(\\d+).png');
  var match = regex.firstMatch(name);
  if (match == null) {
    print('unable to find sequence $name');
    return;
  }

  var frame = int.parse(match.group(1)!);

  File outFile = File(path.join(outFolder.path, name));

  var decodedImage = await decodeImageFromList(await image.readAsBytes());

  var imageData = await createImageFromWidget(
    SizedBox(
      width: decodedImage.width.toDouble(),
      height: decodedImage.height.toDouble(),
      child: _buildVideoBody((frame * (1000/30)).round(), decodedImage),
    ),
    scale: 1,
    logicalSize: Size(decodedImage.width.toDouble(), decodedImage.height.toDouble()),
    imageSize: Size(decodedImage.width.toDouble(), decodedImage.height.toDouble()),
  );

  await outFile.writeAsBytes(imageData!);
}

Widget _buildVideoBody(int replayOffset, ui.Image image) {
  var timestamp = recording.startTimestamp + replayOffset;

  return Container(
    color: Colors.black,
    child: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Stack(
          children: [
            RawImage(image: image),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child:
                Container(
                  color: Colors.black54,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: _buildBottomVideoData(timestamp),
                  ),
                ),
            ),
          ],
        ),
      ),
    ),
  );
}


Column _buildBottomVideoData(int timestamp, [bool includeSlider = true]) {
  MeasurePoint? left;
  MeasurePoint? right;

  var leftReplay = <MeasurePoint>[];
  if (leftPoints.isNotEmpty) {
    var index = lowerBound(
      leftPoints,
      MeasurePoint(timestamp.toDouble(), 0),
      compare: (p0, p1) => p0.timestamp.compareTo(p1.timestamp),
    );

    for (var i = max(0, index - (10 * 15)); i < leftPoints.length && i <= index; i++) {
      leftReplay.add(leftPoints[i]);
    }

    if (index >= 0 && index < leftPoints.length) {
      left = leftPoints[index];

      if (timestamp - left.timestamp > 5000) {
        left = null;
      }
    }
  }

  var rightReplay = <MeasurePoint>[];
  if (rightPoints.isNotEmpty) {
    var index = lowerBound(
      rightPoints,
      MeasurePoint(timestamp.toDouble(), 0),
      compare: (p0, p1) => p0.timestamp.compareTo(p1.timestamp),
    );

    for (var i = max(0, index - (10 * 15)); i < rightPoints.length && i <= index; i++) {
      rightReplay.add(rightPoints[i]);
    }

    if (index >= 0 && index < rightPoints.length) {
      right = rightPoints[index];

      if (timestamp - right.timestamp > 5000) {
        right = null;
      }
    }
  }

  rightReplay.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  leftReplay.sort((a, b) => a.timestamp.compareTo(b.timestamp));

  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (_showVideoForceLive) _buildGraph(timestamp, leftReplay, rightReplay),
      Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          Expanded(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_showVideoForceLive)
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(100), color: leftGraphColor),
                    ),
                  if (_showVideoForceLive) const SizedBox(width: 8),
                  SensorForceWidget(
                    rawForce: left?.value,
                    position: SensorPosition.left,
                    duration: 66,
                    usedInReplay: true,
                    showCircle: !_showVideoForceLive,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_showVideoForceLive)
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(100), color: rightGraphColor),
                    ),
                  if (_showVideoForceLive) const SizedBox(width: 8),
                  SensorForceWidget(
                    rawForce: right?.value,
                    position: SensorPosition.right,
                    duration: 66,
                    usedInReplay: true,
                    showCircle: !_showVideoForceLive,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ],
  );
}


Widget _buildGraph(int currentTimestamp, List<MeasurePoint> leftData, List<MeasurePoint> rightData) {
  var min = currentTimestamp.toDouble() - 5000;
  var maxLeft = 0.0;
  for (var point in leftData) {
    if (point.timestamp >= min && point.timestamp <= currentTimestamp && point.value > maxLeft) {
      maxLeft = point.value;
    }
  }

  var maxRight = 0.0;
  for (var point in rightData) {
    if (point.timestamp >= min && point.timestamp <= currentTimestamp && point.value > maxRight) {
      maxRight = point.value;
    }
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                sprintf("%.2f kg", [maxLeft]),
                style: const TextStyle(color: leftGraphColor, fontWeight: fontWeightMedium),
              ),
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                sprintf("%.2f kg", [maxRight]),
                style: const TextStyle(color: rightGraphColor, fontWeight: fontWeightMedium),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 2),
      Container(
        width: double.infinity,
        height: 75,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
        child: LineChart(
          LineChartData(
            backgroundColor: Colors.transparent,
            rangeAnnotations: RangeAnnotations(
              horizontalRangeAnnotations: ChartHelper.buildHorizontalRangeAnnotations(maxValue),
            ),
            minY: 0,
            minX: min,
            maxX: currentTimestamp.toDouble(),
            clipData: const FlClipData.all(),
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              show: true,
              drawHorizontalLine: true,
              drawVerticalLine: true,
              horizontalInterval: 1,
              verticalInterval: 1000,
              getDrawingHorizontalLine: (value) {
                return const FlLine(color: Colors.blueGrey, strokeWidth: 0.4, dashArray: [8, 0]);
              },
              getDrawingVerticalLine: (value) {
                return const FlLine(color: Colors.blueGrey, strokeWidth: 0.4, dashArray: [8, 0]);
              },
            ),
            titlesData: const FlTitlesData(
              show: false,
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            lineBarsData: [
              LineChartBarData(spots: leftData, color: leftGraphColor, dotData: FlDotData(show: false)),
              LineChartBarData(spots: rightData, color: rightGraphColor, dotData: FlDotData(show: false)),
            ],
            lineTouchData: const LineTouchData(enabled: false),
          ),
          duration: Duration.zero,
        ),
      ),
    ],
  );
}


class SensorForceWidget extends StatelessWidget {
  final double? rawForce;
  final int duration;
  final SensorPosition position;
  final bool usedInReplay;
  final bool showCircle;

  const SensorForceWidget({
    super.key,
    required this.rawForce,
    required this.position,
    this.duration = 250,
    this.usedInReplay = false,
    this.showCircle = true,
  });

  @override
  Widget build(BuildContext context) {
    var force = rawForce ?? 0;
    var displayValue = min(force, defaultAlarmThreshold);
    var percentage = max(0, displayValue / defaultAlarmThreshold);

    Color percentageColor;
    Color textColor;

    if (force >= defaultAlarmThreshold) {
      percentageColor = graphRedColor;
      textColor = graphRedColor;
    } else if (force >= defaultWarningThreshold) {
      percentageColor = graphOrangeColor;
      textColor = graphOrangeColor;
    } else if (force < defaultRelieveThreshold) {
      percentageColor = graphOrangeColor;
      textColor = graphOrangeColor;
    } else {
      percentageColor = graphGreenColor;
      if (usedInReplay) {
        textColor = graphGreenColor;
      } else {
        textColor = greenColor;
      }
    }

    if (rawForce == null) {
      percentageColor = Colors.grey;
      textColor = Colors.grey;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showCircle)
          SizedBox(
            width: 100,
            height: 100,
            child: CircularPercentIndicator(
              percent: percentage.toDouble(),
              radius: 50,
              animation: true,
              animationDuration: duration,
              animateFromLastPercent: true,
              lineWidth: 10,
              progressColor: percentageColor,
              center: Padding(
                padding: const EdgeInsets.all(15.0),
                child: Image.asset(
                  position.asset,
                  gaplessPlayback: true,
                  color: textColor,
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        Opacity(
          opacity: rawForce == null ? 0 : 1,
          child: Text(
            sprintf("%.2f kg", [force]),
            style: TextStyle(
              fontSize: 26,
              fontWeight: fontWeightMedium,
              color: textColor,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}


class MeasurePoint extends FlSpot {
  final double timestamp;
  final double value;

  const MeasurePoint(this.timestamp, this.value) : super(timestamp, value);
}