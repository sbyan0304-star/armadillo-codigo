import 'package:armadillo/screens/admin_profile_screen.dart';
import 'package:armadillo/screens/admin_search_screen.dart';
import 'package:flutter/material.dart';

import '../screens/admin_home_screen.dart';
import '../screens/admin_create_recipe_screen.dart';

class AdminBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final Future<void> Function()? onRecipeSaved;

  const AdminBottomNavigation({
    super.key,
    required this.currentIndex,
    this.onRecipeSaved,
  });

  Future<void> _navigate(BuildContext context, int index) async {
    if (index == currentIndex) return;

    // Crear receta: abrir sin reemplazar la pantalla anterior.
    if (index == 1) {
      final resultado = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const AdminCreateRecipeScreen()),
      );

      if (!context.mounted) return;

      if (resultado == true) {
        await onRecipeSaved?.call();
      }

      return;
    }

    // Las demás opciones conservan la navegación existente.
    late final Widget screen;

    switch (index) {
      case 0:
        screen = const AdminHomeScreen();
        break;
      case 2:
        screen = const AdminSearchScreen();
        break;
      case 3:
        screen = const AdminProfileScreen();
        break;
      default:
        screen = const AdminHomeScreen();
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          width: 300,
          height: 52,
          margin: const EdgeInsets.only(bottom: 15),
          decoration: BoxDecoration(
            color: const Color(0xFF16D928),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildIcon(context, Icons.home_outlined, 0),
              _buildIcon(context, Icons.add_box_outlined, 1),
              _buildIcon(context, Icons.search, 2),
              _buildIcon(context, Icons.person_outline, 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(BuildContext context, IconData icon, int index) {
    final bool selected = currentIndex == index;

    return GestureDetector(
      onTap: () => _navigate(context, index),
      child: SizedBox(
        width: 45,
        height: 52,
        child: Center(
          child: Icon(
            icon,
            size: 24,
            color: Colors.white,
            weight: selected ? 700 : null,
          ),
        ),
      ),
    );
  }
}
