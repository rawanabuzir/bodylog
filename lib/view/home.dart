import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:async';
import 'dart:typed_data';
import 'dart:math';

class ScaleConnectPage extends StatefulWidget {
  const ScaleConnectPage({Key? key}) : super(key: key);

  @override
  State<ScaleConnectPage> createState() => _ScaleConnectPageState();
}

class _ScaleConnectPageState extends State<ScaleConnectPage> {
  final String targetMacAddress = "24:16:51:0E:49:87";
  final String targetDeviceName = "Chipsea-BLE";

  BluetoothDevice? targetDevice;
  bool isConnecting = false;
  bool isConnected = false;
  String connectionStatus = "ابحث عن الميزان...";
  String currentWeight = "---";
  String currentUnit = "---";
  int currentDecimalPlaces = 1;

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;
  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothCharacteristic? _notifyCharacteristic;

  final Guid okokServiceUUID = Guid("0000FFF0-0000-1000-8000-00805F9B34FB");
  final Guid okokNotifyCharacteristicUUID = Guid(
    "0000FFF1-0000-1000-8000-00805F9B34FB",
  );
  final Guid okokWriteCharacteristicUUID = Guid(
    "0000FFF2-0000-1000-8000-00805F9B34FB",
  );

  @override
  void initState() {
    super.initState();
    _checkBluetoothAndStartScan();
  }

  void _checkBluetoothAndStartScan() async {
    var adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      setState(() {
        connectionStatus = "البلوتوث غير مفعل. يرجى تفعيله.";
        isConnecting = false;
      });
      FlutterBluePlus.turnOn();
      return;
    }
    startScanAndConnect();
  }

  void startScanAndConnect() async {
    setState(() {
      connectionStatus = "جاري البحث عن الميزان...";
      isConnecting = true;
      currentWeight = "---";
    });

    await FlutterBluePlus.stopScan();

    _scanSubscription = FlutterBluePlus.scanResults.listen(
      (results) {
        for (ScanResult r in results) {
          bool hasTargetService = r.advertisementData.serviceUuids.contains(
            okokServiceUUID.str.toUpperCase(),
          );
          if ((r.device.remoteId.str == targetMacAddress ||
                  r.device.platformName == targetDeviceName) &&
              hasTargetService) {
            print(
              'الجهاز المكتشف: ${r.device.platformName} (ID: ${r.device.remoteId.str})',
            );
            _scanSubscription?.cancel();
            connectToDevice(r.device);
            return;
          }
        }
      },
      onError: (e) {
        print("خطأ في المسح: $e");
        setState(() {
          connectionStatus = "خطأ في المسح: $e";
          isConnecting = false;
        });
      },
    );

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));

    if (!isConnected && isConnecting && targetDevice == null) {
      setState(() {
        connectionStatus = "لم يتم العثور على الميزان. حاول مرة أخرى.";
        isConnecting = false;
      });
    }
  }

  void connectToDevice(BluetoothDevice device) async {
    setState(() {
      targetDevice = device;
      connectionStatus =
          "جاري الاتصال بالميزان ${device.platformName.isEmpty ? 'المجهول' : device.platformName} ...";
      isConnecting = true;
    });

    _connectionStateSubscription = targetDevice!.connectionState.listen((
      BluetoothConnectionState state,
    ) async {
      if (state == BluetoothConnectionState.connected) {
        setState(() {
          isConnected = true;
          isConnecting = false;
          connectionStatus =
              "تم الاتصال بنجاح بالميزان ${device.platformName.isEmpty ? 'المجهول' : device.platformName}";
        });
        discoverOkokServiceAndCharacteristics();
      } else if (state == BluetoothConnectionState.disconnected) {
        setState(() {
          isConnected = false;
          isConnecting = false;
          connectionStatus = "تم قطع الاتصال بالميزان.";
          currentWeight = "---";
          currentUnit = "---";
        });
        _writeCharacteristic = null;
        _notifyCharacteristic = null;
      }
    });

    try {
      await targetDevice!.connect(timeout: const Duration(seconds: 30));
    } catch (e) {
      print("فشل الاتصال: $e");
      setState(() {
        isConnecting = false;
        connectionStatus = "فشل الاتصال بالميزان: $e";
      });
      targetDevice?.disconnect();
    }
  }

  void discoverOkokServiceAndCharacteristics() async {
    if (targetDevice == null || !isConnected) return;

    try {
      List<BluetoothService> services = await targetDevice!.discoverServices();
      print('تم اكتشاف ${services.length} خدمة.');

      for (var service in services) {
        if (service.uuid == okokServiceUUID) {
          print(
            'تم العثور على خدمة OKOK المخصصة: ${service.uuid.str.toUpperCase()}',
          );
          for (var characteristic in service.characteristics) {
            print(
              'Characteristic UUID: ${characteristic.uuid.str.toUpperCase()}, Properties: ${characteristic.properties}',
            );

            if (characteristic.uuid == okokWriteCharacteristicUUID &&
                characteristic.properties.write) {
              _writeCharacteristic = characteristic;
              print(
                'تم تحديد خاصية الكتابة (Write Characteristic): ${characteristic.uuid.str.toUpperCase()}.',
              );
            }
            if (characteristic.uuid == okokNotifyCharacteristicUUID &&
                (characteristic.properties.notify ||
                    characteristic.properties.indicate)) {
              _notifyCharacteristic = characteristic;
              print(
                'تم تحديد خاصية الإشعارات (Notify Characteristic): ${characteristic.uuid.str.toUpperCase()}.',
              );
            }
          }
          break;
        }
      }

      if (_writeCharacteristic != null && _notifyCharacteristic != null) {
        await _notifyCharacteristic!.setNotifyValue(true);
        print('تم الاشتراك في إشعارات خاصية OKOK.');

        _notifyCharacteristic!.value.listen(
          (value) {
            print('بيانات خام جديدة (إطار OKOK): $value');
            _parseOkokFrame(value);
          },
          onError: (e) {
            print("خطأ في الاستماع لبيانات OKOK: $e");
          },
        );
      } else {
        setState(() {
          connectionStatus =
              "لم يتم العثور على خصائص OKOK المطلوبة (الكتابة: ${okokWriteCharacteristicUUID.str.toUpperCase()}/الإشعارات: ${okokNotifyCharacteristicUUID.str.toUpperCase()}).";
        });
        print('يرجى التأكد من أن UUIDs الخصائص صحيحة (هذه القيم من الوثيقة).');
      }
    } catch (e) {
      print('خطأ أثناء اكتشاف خدمات OKOK أو إعدادها: $e');
      setState(() {
        connectionStatus = "خطأ في إعداد الاتصال: $e";
      });
    }
  }

  int _calculateChecksum(List<int> data) {
    if (data.length < 3) {
      return 0;
    }
    int checksum = 0;
    for (int i = 1; i < (2 + data[2] + 1); i++) {
      checksum ^= data[i];
    }
    return checksum & 0xFF;
  }

  Future<void> sendOkokCommand(List<int> commandFrame) async {
    if (_writeCharacteristic != null) {
      try {
        await _writeCharacteristic!.write(commandFrame, withoutResponse: false);
        print('تم إرسال الأمر: $commandFrame');
      } catch (e) {
        print('فشل إرسال الأمر: $e');
      }
    } else {
      print('خاصية الكتابة غير متاحة.');
    }
  }

  void _parseOkokFrame(List<int> rawData) {
    if (rawData.isEmpty || rawData[0] != 0xCA) {
      print("ليس إطار OKOK صالحًا (لا يبدأ بـ 0xCA) أو فارغًا.");
      return;
    }

    int version = rawData[1];
    int dataLength = rawData[2];

    if (rawData.length < 4) {
      print("إطار قصير جدًا لحساب Checksum.");
      return;
    }

    int receivedChecksum = rawData.last;
    int calculatedChecksum = _calculateChecksum(
      rawData.sublist(0, rawData.length - 1),
    );

    if (receivedChecksum != calculatedChecksum) {
      print("Checksum غير متطابق. البيانات قد تكون تالفة.");
      print(
        "المستلم: ${receivedChecksum.toRadixString(16)}, المحسوب: ${calculatedChecksum.toRadixString(16)}",
      );
      return;
    } else {
      print("Checksum متطابق.");
    }

    if (rawData.length != (3 + dataLength + 1)) {
      print(
        "طول الإطار غير صحيح. الإطار: $rawData, الطول المعلن: $dataLength.",
      );
      return;
    }

    List<int> dataPayload = rawData.sublist(3, 3 + dataLength);

    if (dataPayload.length < 12) {
      print(
        "حمولة البيانات قصيرة جدًا لبيانات الوزن (تحتاج 12 بايت على الأقل). الحمولة: $dataPayload",
      );
      return;
    }

    int lockStatusByte = dataPayload[0];

    int messagePropertiesByte = dataPayload[8];

    int unitBits = (messagePropertiesByte >> 3) & 0x03;
    switch (unitBits) {
      case 0x00:
        currentUnit = "كجم";
        break;
      case 0x01:
        currentUnit = "Jin";
        break;
      case 0x02:
        currentUnit = "رطل";
        break;
      case 0x03:
        currentUnit = "ST:LB";
        break;
      default:
        currentUnit = "غير معروف";
    }

    int decimalBits = (messagePropertiesByte >> 1) & 0x03;
    switch (decimalBits) {
      case 0x00:
        currentDecimalPlaces = 1;
        break;
      case 0x01:
        currentDecimalPlaces = 0;
        break;
      case 0x02:
        currentDecimalPlaces = 2;
        break;
      default:
        currentDecimalPlaces = 1;
    }

    ByteData weightByteData = ByteData.view(
      Uint8List.fromList(dataPayload.sublist(5, 7)).buffer,
    );
    int rawWeight = weightByteData.getUint16(0, Endian.little);

    double actualWeight = rawWeight / pow(10, currentDecimalPlaces);

    setState(() {
      currentWeight = actualWeight.toStringAsFixed(currentDecimalPlaces);
      connectionStatus =
          "متصل. الوزن: ${currentWeight} ${currentUnit} (مؤمن: ${lockStatusByte == 0x01 ? 'نعم' : 'لا'})";
    });
    print(
      "تم تحليل الوزن: $currentWeight $currentUnit (أعلام: ${messagePropertiesByte.toRadixString(16)}, وزن خام: $rawWeight)",
    );
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    targetDevice?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ميزان الصحة الذكي"),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blueAccent, Colors.purpleAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.blue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Text(
                        connectionStatus,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "الوزن الحالي:",
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "$currentWeight $currentUnit",
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              if (isConnecting)
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                )
              else if (isConnected && !isConnecting)
                Column(
                  children: [
                    const Icon(
                      Icons.bluetooth_connected,
                      color: Colors.green,
                      size: 100,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          connectionStatus =
                              "الميزان متصل. انتظر القياس أو قم بالوقوف عليه.";
                        });
                      },
                      icon: const Icon(Icons.monitor_weight),
                      label: const Text("الميزان متصل (انتظر القياس)"),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.lightBlueAccent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 25,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 5,
                      ),
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton.icon(
                      onPressed: () {
                        targetDevice?.disconnect();
                      },
                      icon: const Icon(Icons.link_off),
                      label: const Text("قطع الاتصال"),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 25,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 5,
                      ),
                    ),
                  ],
                )
              else if (!isConnecting && !isConnected)
                ElevatedButton.icon(
                  onPressed: _checkBluetoothAndStartScan,
                  icon: const Icon(Icons.bluetooth_searching),
                  label: const Text("البدء بالبحث والاتصال"),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.deepPurpleAccent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 5,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
