
import 'dart:async';
import 'dart:convert';

import 'package:smart_home/device/state/datapointTypes/datapoint_types.dart';
import 'package:smart_home/device/iobroker_device.dart';
import 'package:smart_home/manager/history/history_data.dart';

import '../device.dart';

Map<String, dynamic>? _decodeOtherDetails(
    dynamic value, String dataPointId) {
  var current = value;

  while (true) {
    if (current is String) {
      try {
        current = jsonDecode(current);
      } on FormatException {
        return null;
      }
    }

    if (current is! Map) {
      return null;
    }

    final details = Map<String, dynamic>.from(current);

    // Erkennen und entfernen eines alten, verschachtelten DataPoint-Objekts.
    final isWrappedDataPoint =
        details["id"]?.toString() == dataPointId &&
        details.containsKey("name") &&
        (details.containsKey("valueType") ||
            details.containsKey("type")) &&
        details.containsKey("otherDetails");

    if (isWrappedDataPoint) {
      current = details["otherDetails"];
      continue;
    }

    return details;
  }
}

class DataPoint {
  dynamic value;
  dynamic olderValue;
  String name;
  String id;
  Device? device;
  StateType? type;
  String? role;
  String? valueType;

  Map<String, dynamic>? otherDetails;

  HistoryData historyData = HistoryData();

  StreamController valueStreamController = StreamController.broadcast();

  DataPoint({
    required this.name,
    required this.device,
    required this.id,
    this.role,
    this.type,
    this.otherDetails,
  });

  factory DataPoint.fromJSON(Map<String, dynamic> json, Device? device) {
    final id = json["id"].toString();

    return DataPoint(
      name: json["name"].toString(),
      device: device,
      id: id,
      role: json["role"],
      type: json["valueType"],
      otherDetails: json.containsKey("otherDetails")
          ? _decodeOtherDetails(json["otherDetails"], id)
          : Map<String, dynamic>.from(json),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "type": type,
      "role": role,
      "valueType": valueType,
      "otherDetails": jsonEncode(otherDetails),
    };
  }

  set setValue(dynamic value) {
    if (value != this.value) {
      if (this.value != null) {
        olderValue = this.value;
      } else {
        olderValue = value;
      }
      this.value = value;
      valueStreamController.add(value);
    }
  }

  get isIoBrokerDataPoint => device is IoBrokerDevice;

  dynamic getInformation(String key) {
    return otherDetails?[key];
  }

  @override
  bool operator ==(Object other) {
    return identical(other, this) ||
        other is DataPoint && other.type == type && other.id == id;
  }
}
