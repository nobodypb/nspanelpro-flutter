import 'package:flutter/widgets.dart';

/// Optional host capability. Cards know no device, transport or session types.
abstract class CameraInteraction implements Listenable {
  bool get suspendsStillImages;
  VoidCallback? action(BuildContext context, Map<String, dynamic> config);
}
