import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/assistance_command_screen.dart';
import 'screens/boot_screen.dart';
import 'screens/comms_screen.dart';
import 'screens/convoy_screen.dart';
import 'screens/drive_screen.dart';
import 'screens/dispatch_screen.dart';
import 'screens/field_assistance_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/missions_screen.dart';
import 'screens/navigation_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/trips_screen.dart';
import 'screens/vehicle_screen.dart';
import 'services/push_service.dart';
import 'state/app_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await PushService.initFirebase();
  final state = AppState();
  await state.init();
  runApp(AppScope(state: state, child: const StpgApp()));
}

class StpgApp extends StatelessWidget {
  const StpgApp({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    Stpg.day = app.isDay;
    return MaterialApp(
      title: 'STPG Command Center',
      debugShowCheckedModeBanner: false,
      theme: Stpg.theme(),
      home: const _Root(),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    Widget body;
    switch (app.stage) {
      case AuthStage.booting:
        body = const BootScreen();
      case AuthStage.checking:
        body = const LoadingScreen();
      case AuthStage.loggedOut:
        body = const LoginScreen();
      case AuthStage.loggedIn:
        body = switch (app.screen) {
          CommandScreen.home => const HomeScreen(),
          CommandScreen.navigation => const NavigationScreen(),
          CommandScreen.comms => const CommsScreen(),
          CommandScreen.dispatch => const DispatchScreen(),
          CommandScreen.missions => const MissionsScreen(),
          CommandScreen.assistanceCommand => const AssistanceCommandScreen(),
          CommandScreen.fieldAssistance => const FieldAssistanceScreen(),
          CommandScreen.orders => const OrdersScreen(),
          CommandScreen.vehicle => const VehicleScreen(),
          CommandScreen.convoy => const ConvoyScreen(),
          CommandScreen.trips => const TripsScreen(),
          CommandScreen.drive => const DriveScreen(),
        };
    }
    return PopScope(
      canPop: app.stage != AuthStage.loggedIn || app.screen == CommandScreen.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) app.back();
      },
      child: Scaffold(
        backgroundColor: Stpg.dark,
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: KeyedSubtree(key: ValueKey('${app.stage}-${app.screen}'), child: body),
        ),
      ),
    );
  }
}
