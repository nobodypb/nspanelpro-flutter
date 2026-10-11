import 'package:flutter_test/flutter_test.dart';
import 'package:nspanel_app/util/navigation_controller.dart';

void main() {
  test('navigation holds block timers and external navigation; release renews deadline', () {
    int now = 0;
    final nav = PanelNavigation(now: () => now);
    nav.configure(
      count: 6,
      start: 2,
      after: 15,
      overrides: {5: 60},
      structure: 'test',
    );
    nav.navigate(5);
    final release = nav.hold();
    now = 120000;
    nav.check();
    expect(nav.current, 5);
    expect(nav.navigate(1), false);
    release();
    release();
    now += 59999;
    nav.check();
    expect(nav.current, 5);
    now++;
    nav.check();
    expect(nav.current, 2);
    nav.dispose();
  });
}
