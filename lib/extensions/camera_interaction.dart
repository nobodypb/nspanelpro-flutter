import 'package:flutter/widgets.dart';

/// Optional host capability. Cards know no device, transport or session types.
abstract class CameraInteraction implements Listenable {
  bool get suspendsStillImages;

  /// Decorate a camera in place; null retains the ordinary still-image card.
  /// The supplied picture has no title overlay so the view owns its labels.
  Widget? build(
    BuildContext context,
    Map<String, dynamic> config,
    Widget picture,
  );
}
