import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NavScreen {
  pos,
  returns,
  dashboard,
  inventory,
  medicines,
  purchases,
  sales,
  customers,
  reports,
  settings,
  scanner,
}

class NavigationState {
  final NavScreen currentScreen;
  final bool isSidebarCollapsed;

  NavigationState({
    required this.currentScreen,
    this.isSidebarCollapsed = false,
  });

  NavigationState copyWith({
    NavScreen? currentScreen,
    bool? isSidebarCollapsed,
  }) {
    return NavigationState(
      currentScreen: currentScreen ?? this.currentScreen,
      isSidebarCollapsed: isSidebarCollapsed ?? this.isSidebarCollapsed,
    );
  }
}

class NavigationNotifier extends StateNotifier<NavigationState> {
  NavigationNotifier() : super(NavigationState(currentScreen: NavScreen.pos));

  void navigateTo(NavScreen screen) {
    state = state.copyWith(currentScreen: screen);
  }

  void toggleSidebar() {
    state = state.copyWith(isSidebarCollapsed: !state.isSidebarCollapsed);
  }
}

final navigationProvider = StateNotifierProvider<NavigationNotifier, NavigationState>(
  (ref) => NavigationNotifier(),
);
