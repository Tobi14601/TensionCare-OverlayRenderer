import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:fl_chart/src/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sprintf/sprintf.dart';
import 'package:tc_overlay_renderer/consts.dart';

class ChartHelper {
  ChartHelper._();

  static FlTitlesData buildTitlesData([double? min, double? max, double? width, int? offset, bool titles = false]) {
    return FlTitlesData(
      show: true,
      topTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: false,
        ),
      ),
      rightTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: false,
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          reservedSize: 22,
          showTitles: true,
          interval: min == null || max == null || width == null ? null : Utils().getEfficientInterval(
            width,
            max - min,
          ) * 1.75,
          getTitlesWidget: (value, meta) {
            if (value == meta.max || value == meta.min) {
              return Container();
            }


            var date = value - (offset ?? 0);
            var string = '';

            if (date >= 0) {
              if (offset != null) {
                var second = (date ~/ 1000) % 60;
                var minute = ((date ~/ 1000) ~/ 60) % 60;
                var hour = ((date ~/ 1000) ~/ 60) ~/ 60;

                if (hour > 0) {
                  string = sprintf('%d:%02d:%02d', [hour.toInt(), minute.toInt(), second.toInt()]);
                } else {
                  string = sprintf('%d:%02d', [minute.toInt(), second.toInt()]);
                }

              } else {
                string = DateFormat('mm:ss').format(
                  DateTime.fromMillisecondsSinceEpoch(
                    date.toInt(),
                    isUtc: true,
                  ),
                );
              }
            }
            return SideTitleWidget(
              meta: meta,
              child: Text(string),
            );
          },
        ),
      ),
    );
  }

  static List<HorizontalRangeAnnotation> buildHorizontalRangeAnnotations(
      double maxValue,
      ) {
    // var warningValue = PreferenceManager.shared.warningThreshold;
    // var alarmThreshold = PreferenceManager.shared.alarmThreshold;

    var warningValue = defaultWarningThreshold;
    var alarmThreshold = defaultAlarmThreshold;
    return [
      HorizontalRangeAnnotation(
        y1: 0,
        y2: defaultRelieveThreshold,
        color: graphOrangeColor.withAlpha(100),
      ),
      if (maxValue > 0)
        HorizontalRangeAnnotation(
          y1: defaultRelieveThreshold,
          y2: min(warningValue, maxValue),
          color: graphGreenColor.withAlpha(100),
        ),
      if (maxValue > warningValue)
        HorizontalRangeAnnotation(
          y1: warningValue,
          y2: min(alarmThreshold, maxValue),
          color: graphOrangeColor.withAlpha(100),
        ),
      if (maxValue > alarmThreshold)
        HorizontalRangeAnnotation(
          y1: alarmThreshold,
          y2: maxValue,
          color: graphRedColor.withAlpha(100),
        ),
    ];
  }
}
