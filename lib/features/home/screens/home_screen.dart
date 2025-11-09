import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../generated/l10n.dart';
import '../../auth/providers/auth_notifier.dart';
import '../providers/home_providers.dart';
import '../../cart/screens/cart_screen.dart';
import 'home_tab.dart';
import '../../orders/screens/orders_history_screen.dart';
import 'profile_tab.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navIndex = ref.watch(navProvider);
    final authState = ref.watch(authNotifierProvider);
    final l10n = S.of(context);
    final theme = Theme.of(context);

    final tabs = <Widget>[
      const HomeTab(),
      const CartScreen(),
      const OrdersHistoryScreen(),
      const ProfileTab(),
    ];

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        children: [
          Positioned.fill(
            child: SafeArea(
              child: IndexedStack(
                index: navIndex,
                children: tabs,
              ),
            ),
          ),
          if (authState.isLoading)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: LinearProgressIndicator(
                  minHeight: 2,
                  color: theme.colorScheme.primary,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: theme.colorScheme.primary,
        unselectedItemColor: theme.colorScheme.onSurface.withOpacity(0.6),
        onTap: (index) => ref.read(navProvider.notifier).state = index,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            activeIcon: const Icon(Icons.home),
            label: l10n.home,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.shopping_cart_outlined),
            activeIcon: const Icon(Icons.shopping_cart),
            label: l10n.cart,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.receipt_long_outlined),
            activeIcon: const Icon(Icons.receipt_long),
            label: l10n.orders,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            activeIcon: const Icon(Icons.person),
            label: l10n.profileTitle,
          ),
        ],
      ),
    );
  }
}
