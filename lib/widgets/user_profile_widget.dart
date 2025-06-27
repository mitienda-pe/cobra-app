import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

class UserProfileWidget extends StatelessWidget {
  const UserProfileWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userData = authProvider.userData;
    
    return PopupMenuButton<String>(
      offset: const Offset(0, 50),
      icon: CircleAvatar(
        backgroundColor: Theme.of(context).primaryColor.withAlpha(51), // 0.2 * 255 = 51
        child: userData != null && userData['profile_picture'] != null
            ? Image.network(userData['profile_picture'])
            : Icon(
                Icons.person,
                color: Theme.of(context).primaryColor,
              ),
      ),
      itemBuilder: (BuildContext context) => [
        PopupMenuItem<String>(
          value: 'profile',
          child: Row(
            children: [
              Icon(
                Icons.person_outline,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 8),
              const Text('Mi Perfil'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(
                Icons.logout,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(width: 8),
              const Text('Cerrar Sesión'),
            ],
          ),
        ),
      ],
      onSelected: (String value) async {
        if (value == 'logout') {
          // Mostrar diálogo de confirmación
          final shouldLogout = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Cerrar Sesión'),
              content: const Text('¿Estás seguro que deseas cerrar sesión?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Cerrar Sesión'),
                ),
              ],
            ),
          );
          
          if (shouldLogout == true) {
            await authProvider.logout();
            if (context.mounted) {
              GoRouter.of(context).go('/login');
            }
          }
        } else if (value == 'profile') {
          // Navegar a la pantalla de perfil (por implementar)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Función de perfil en desarrollo'),
            ),
          );
        }
      },
    );
  }
}
