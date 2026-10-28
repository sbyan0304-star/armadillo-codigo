import 'dart:async';

import 'package:armadillo/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'admin_create_recipe_screen.dart';
import '../widgets/admin_bottom_navigation.dart';
import 'recipe_detail_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  static const Color verde = Color(0xff16D928);
  static const Color verdeOscuro = Color(0xff16A923);
  static const Color grisTexto = Color(0xff777777);
  static const Color grisClaro = Color(0xfff1f1f1);

  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  StreamSubscription<User?>? _sesionSubscription;

  List<Map<String, dynamic>> recetas = [];

  int cantidadUsuarios = 0;

  bool cargando = true;
  String? error;

  String uidAdmin = '';

  @override
  void initState() {
    super.initState();
    _escucharSesion();
  }

  @override
  void dispose() {
    _sesionSubscription?.cancel();
    super.dispose();
  }

  void _escucharSesion() {
    _sesionSubscription = auth.authStateChanges().listen((User? usuario) {
      if (!mounted) return;

      if (usuario == null) {
        _irAlLogin();
        return;
      }

      if (uidAdmin != usuario.uid) {
        uidAdmin = usuario.uid;
        cargarDatos();
      }
    });
  }

  Future<void> cargarDatos() async {
    final User? usuarioFirebase = auth.currentUser;

    if (usuarioFirebase == null) {
      if (!mounted) return;

      _irAlLogin();
      return;
    }

    uidAdmin = usuarioFirebase.uid;

    await Future.wait([cargarRecetas(), cargarUsuarios()]);
  }

  Future<void> cargarRecetas() async {
    if (mounted) {
      setState(() {
        cargando = true;
        error = null;
      });
    }

    try {
      final User? usuarioFirebase = auth.currentUser;

      if (usuarioFirebase == null) {
        _irAlLogin();
        return;
      }

      final String uid = usuarioFirebase.uid;

      final documentoAdmin = await firestore
          .collection('usuarios')
          .doc(uid)
          .get();

      if (!documentoAdmin.exists) {
        throw Exception('No existe el perfil del usuario autenticado');
      }

      final datosAdmin = documentoAdmin.data();

      if (datosAdmin == null ||
          datosAdmin['rol']?.toString().trim().toLowerCase() != 'admin') {
        throw Exception('La cuenta actual no tiene permisos de administrador');
      }

      final snapshot = await firestore.collection('recetas').get();

      final List<Map<String, dynamic>> lista = [];

      for (final documento in snapshot.docs) {
        final data = documento.data();

        final String idReceta = documento.id;

        if (idReceta.trim().isEmpty) {
          continue;
        }

        lista.add({...data, 'id_receta': idReceta, '_docId': idReceta});
      }

      lista.sort((a, b) {
        final fechaA = _obtenerFecha(a['fecha_publicacion']);

        final fechaB = _obtenerFecha(b['fecha_publicacion']);

        return fechaB.compareTo(fechaA);
      });

      if (!mounted) return;

      setState(() {
        recetas = lista;
        cargando = false;
      });
    } catch (e) {
      debugPrint('ERROR FIRESTORE RECETAS ADMIN: $e');

      if (!mounted) return;

      setState(() {
        cargando = false;
        error = 'No se pudieron cargar las recetas';
      });
    }
  }

  Future<void> cargarUsuarios() async {
    try {
      final User? usuarioFirebase = auth.currentUser;

      if (usuarioFirebase == null) {
        _irAlLogin();
        return;
      }

      final documentoAdmin = await firestore
          .collection('usuarios')
          .doc(usuarioFirebase.uid)
          .get();

      if (!documentoAdmin.exists) {
        return;
      }

      final datosAdmin = documentoAdmin.data();

      if (datosAdmin == null ||
          datosAdmin['rol']?.toString().trim().toLowerCase() != 'admin') {
        return;
      }

      final snapshot = await firestore
          .collection('usuarios')
          .where('rol', isEqualTo: 'usuario')
          .get();

      if (!mounted) return;

      setState(() {
        cantidadUsuarios = snapshot.docs.length;
      });
    } catch (e) {
      debugPrint('ERROR FIRESTORE USUARIOS ADMIN: $e');

      if (!mounted) return;

      setState(() {
        cantidadUsuarios = 0;
      });
    }
  }

  DateTime _obtenerFecha(dynamic valor) {
    if (valor is Timestamp) {
      return valor.toDate();
    }

    if (valor is DateTime) {
      return valor;
    }

    if (valor is String) {
      return DateTime.tryParse(valor) ?? DateTime(2000);
    }

    return DateTime(2000);
  }

  Future<void> abrirCrearReceta(BuildContext context) async {
    final User? usuarioFirebase = auth.currentUser;

    if (usuarioFirebase == null) {
      _irAlLogin();
      return;
    }

    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AdminCreateRecipeScreen()),
    );

    if (!mounted) return;

    if (resultado == true) {
      await cargarDatos();
    }
  }

  Future<void> abrirEditarReceta(
    BuildContext context,
    Map<String, dynamic> receta,
  ) async {
    final User? usuarioFirebase = auth.currentUser;

    if (usuarioFirebase == null) {
      _irAlLogin();
      return;
    }

    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminCreateRecipeScreen(receta: receta),
      ),
    );

    if (!mounted) return;

    if (resultado == true) {
      await cargarDatos();
    }
  }

  Future<void> eliminarReceta(
    BuildContext context,
    Map<String, dynamic> receta,
  ) async {
    final User? usuarioFirebase = auth.currentUser;

    if (usuarioFirebase == null) {
      _irAlLogin();
      return;
    }

    final String docId = receta['_docId']?.toString() ?? '';

    if (docId.isEmpty) {
      _mostrarMensaje(
        'No se encontró el documento de la receta',
        esError: true,
      );
      return;
    }

    final String nombre = receta['nombre']?.toString() ?? 'esta receta';

    final bool confirmar =
        await showDialog<bool>(
          context: context,
          builder: (context) {
            return Dialog(
              backgroundColor: Colors.white,
              insetPadding: const EdgeInsets.symmetric(horizontal: 28),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(
                        color: Color(0xfffff1f1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.red,
                        size: 23,
                      ),
                    ),
                    const SizedBox(height: 17),
                    Text(
                      'Eliminar receta',
                      style: GoogleFonts.poppins(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF000000),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '¿Estás seguro de que deseas '
                      'eliminar "$nombre"?',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        height: 1.45,
                        color: grisTexto,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(context, false);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.black,
                              side: const BorderSide(color: Color(0xffdddddd)),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13),
                              ),
                            ),
                            child: Text(
                              'Cancelar',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context, true);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xff16D928),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13),
                              ),
                            ),
                            child: Text(
                              'Eliminar',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ) ??
        false;

    if (!confirmar) return;

    try {
      await firestore.collection('recetas').doc(docId).delete();

      if (!mounted) return;

      _mostrarMensaje('Receta eliminada correctamente');

      await cargarDatos();
    } catch (e) {
      debugPrint('ERROR ELIMINANDO RECETA: $e');

      if (!mounted) return;

      _mostrarMensaje('No se pudo eliminar la receta', esError: true);
    }
  }

  void abrirDetalleReceta(BuildContext context, Map<String, dynamic> receta) {
    final User? usuarioFirebase = auth.currentUser;

    if (usuarioFirebase == null) {
      _irAlLogin();
      return;
    }

    final String idReceta =
        receta['_docId']?.toString() ?? receta['id_receta']?.toString() ?? '';

    if (idReceta.trim().isEmpty) {
      _mostrarMensaje('No se encontró el ID de la receta', esError: true);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecipeDetailScreen(idReceta: idReceta),
      ),
    );
  }

  void _irAlLogin() {
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _mostrarMensaje(String mensaje, {bool esError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mensaje,
          style: GoogleFonts.poppins(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: esError ? Colors.red : Colors.black,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SafeArea(child: _buildContenido()),

          // ======================================================
          // NAVEGACIÓN FLOTANTE
          // ======================================================
          Positioned(
            left: 0,
            right: 0,
            bottom: 15,
            child: Center(
              child: SizedBox(
                width: 300,
                child: AdminBottomNavigation(
                  currentIndex: 0,
                  onRecipeSaved: cargarDatos,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContenido() {
    if (cargando && recetas.isEmpty) {
      return _buildLoading();
    }

    if (error != null && recetas.isEmpty) {
      return _buildError();
    }

    if (recetas.isEmpty) {
      return _buildEmpty();
    }

    return RefreshIndicator(
      color: verde,
      backgroundColor: Colors.white,
      onRefresh: cargarDatos,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(child: _buildWelcome()),
          SliverToBoxAdapter(child: _buildStatistics()),
          SliverToBoxAdapter(child: _buildAddButton()),
          SliverToBoxAdapter(child: _buildSectionTitle()),

          // ======================================================
          // RECETAS
          // Se dejan 130 px al final para que la navegación
          // flotante no tape la última fila.
          // ======================================================
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 130),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate((context, index) {
                return _buildRecipeCard(context, receta: recetas[index]);
              }, childCount: recetas.length),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 20,
                childAspectRatio: 0.70,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 12, 4),
      child: Row(
        children: [
          Image.asset(
            'assets/images/logo.png',
            width: 38,
            height: 38,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 9),
          Text(
            'armadillo',
            style: GoogleFonts.poppins(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcome() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tu recetario',
            style: GoogleFonts.poppins(
              fontSize: 28,
              height: 1.05,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.8,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'en tus manos',
            style: GoogleFonts.poppins(
              fontSize: 28,
              height: 1.05,
              fontWeight: FontWeight.w400,
              letterSpacing: -0.8,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Administra y comparte los sabores '
            'de nuestra región.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              height: 1.45,
              color: grisTexto,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatistics() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          Expanded(
            child: _buildStatistic(
              value: recetas.length.toString(),
              label: 'Recetas',
              icon: Icons.restaurant_menu_outlined,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatistic(
              value: '0',
              label: 'Pendientes',
              icon: Icons.schedule_outlined,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildStatistic(
              value: cantidadUsuarios.toString(),
              label: 'Usuarios',
              icon: Icons.people_outline_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatistic({
    required String value,
    required String label,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 13, 10, 13),
      decoration: BoxDecoration(
        color: grisClaro,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, size: 19, color: verdeOscuro),
          const SizedBox(height: 7),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: GoogleFonts.poppins(fontSize: 10.5, color: grisTexto),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 30),
      child: GestureDetector(
        onTap: () => abrirCrearReceta(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          decoration: BoxDecoration(
            color: verde,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Agregar nueva receta',
                      style: GoogleFonts.poppins(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Comparte un nuevo sabor regional',
                      style: GoogleFonts.poppins(
                        fontSize: 10.5,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 17),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              'Mis recetas',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: Colors.black,
              ),
            ),
          ),
          Text(
            '${recetas.length} publicadas',
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: verdeOscuro,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeCard(
    BuildContext context, {
    required Map<String, dynamic> receta,
  }) {
    final String nombre = receta['nombre']?.toString() ?? 'Sin nombre';

    final String imagen = receta['imagen']?.toString() ?? '';

    return GestureDetector(
      onTap: () {
        abrirDetalleReceta(context, receta);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: grisClaro,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _buildRecipeImage(imagen),
                ),
                Positioned(
                  left: 9,
                  top: 9,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'PUBLICADA',
                      style: GoogleFonts.poppins(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: verdeOscuro,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 9,
                  top: 9,
                  child: _buildRecipeMenu(context, receta),
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          Text(
            nombre,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 14,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              const Icon(
                Icons.restaurant_outlined,
                size: 13,
                color: Color(0xff888888),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Receta regional',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    color: const Color(0xff888888),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeMenu(BuildContext context, Map<String, dynamic> receta) {
    return PopupMenuButton<String>(
      onSelected: (valor) {
        if (valor == 'ver') {
          abrirDetalleReceta(context, receta);
        }

        if (valor == 'editar') {
          abrirEditarReceta(context, receta);
        }

        if (valor == 'eliminar') {
          eliminarReceta(context, receta);
        }
      },
      padding: EdgeInsets.zero,
      offset: const Offset(0, 43),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Colors.white,
      elevation: 4,
      icon: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.95),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.more_horiz_rounded,
          size: 21,
          color: Colors.black,
        ),
      ),
      itemBuilder: (context) {
        return [
          PopupMenuItem(
            value: 'ver',
            child: _buildMenuItem(Icons.visibility_outlined, 'Ver receta'),
          ),
          PopupMenuItem(
            value: 'editar',
            child: _buildMenuItem(Icons.edit_outlined, 'Editar receta'),
          ),
          PopupMenuItem(
            value: 'eliminar',
            child: _buildMenuItem(
              Icons.delete_outline_rounded,
              'Eliminar receta',
              color: Colors.red,
            ),
          ),
        ];
      },
    );
  }

  Widget _buildMenuItem(
    IconData icon,
    String texto, {
    Color color = Colors.black,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(
          texto,
          style: GoogleFonts.poppins(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildRecipeImage(String imagenUrl) {
    if (imagenUrl.trim().isEmpty) {
      return _buildImageError();
    }

    return Image.network(
      imagenUrl,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        debugPrint(
          'ERROR IMAGEN RECETA: '
          '$imagenUrl',
        );

        return _buildImageError();
      },
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }

        return Container(
          color: grisClaro,
          alignment: Alignment.center,
          child: const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: verde),
          ),
        );
      },
    );
  }

  Widget _buildImageError() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: grisClaro,
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_outlined,
        color: Color(0xffaaaaaa),
        size: 35,
      ),
    );
  }

  Widget _buildLoading() {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildHeader()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 25, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _skeletonBox(175, 30),
                const SizedBox(height: 7),
                _skeletonBox(155, 30),
                const SizedBox(height: 12),
                _skeletonBox(double.infinity, 15),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Expanded(child: _skeletonBox(double.infinity, 100, radius: 16)),
                const SizedBox(width: 10),
                Expanded(child: _skeletonBox(double.infinity, 100, radius: 16)),
                const SizedBox(width: 10),
                Expanded(child: _skeletonBox(double.infinity, 100, radius: 16)),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 30),
            child: _skeletonBox(double.infinity, 65, radius: 16),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 17),
            child: _skeletonBox(150, 22),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 130),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate((context, index) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: _skeletonBox(
                      double.infinity,
                      double.infinity,
                      radius: 17,
                    ),
                  ),
                  const SizedBox(height: 9),
                  _skeletonBox(125, 14),
                  const SizedBox(height: 5),
                  _skeletonBox(90, 11),
                ],
              );
            }, childCount: 4),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 20,
              childAspectRatio: 0.70,
            ),
          ),
        ),
      ],
    );
  }

  Widget _skeletonBox(double width, double height, {double radius = 8}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xffeeeeee),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  Widget _buildError() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 130),
      child: Column(
        children: [
          _buildHeader(),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.55,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 35),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: const BoxDecoration(
                        color: Color(0xfff4f4f4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.cloud_off_outlined,
                        size: 32,
                        color: Color(0xff777777),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'No pudimos cargar tus recetas',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      error ?? 'Ocurrió un error inesperado.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        height: 1.4,
                        color: grisTexto,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: cargarDatos,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: verde,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: Text(
                        'Reintentar',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return RefreshIndicator(
      color: verde,
      backgroundColor: Colors.white,
      onRefresh: cargarDatos,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 130),
        children: [
          _buildHeader(),
          const SizedBox(height: 130),
          const Icon(
            Icons.restaurant_menu_outlined,
            size: 55,
            color: Color(0xffaaaaaa),
          ),
          const SizedBox(height: 18),
          Center(
            child: Text(
              'Todavía no hay recetas',
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 7),
          Center(
            child: Text(
              'Agrega la primera receta de tu '
              'recetario regional.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 13, color: grisTexto),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 60),
            child: ElevatedButton(
              onPressed: () => abrirCrearReceta(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: verde,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: Text(
                'Agregar receta',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
