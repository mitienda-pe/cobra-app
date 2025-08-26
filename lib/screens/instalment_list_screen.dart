import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/instalment.dart';
import '../services/instalment_service.dart';
import '../providers/auth_provider.dart';
import '../utils/currency_formatter.dart';
import '../utils/logger.dart';

enum InstalmentSortOption {
  dueDate,
  amount,
  status,
}

class InstalmentListScreen extends StatefulWidget {
  const InstalmentListScreen({super.key});

  @override
  State<InstalmentListScreen> createState() => _InstalmentListScreenState();
}

class _InstalmentListScreenState extends State<InstalmentListScreen> {
  final InstalmentService _instalmentService = InstalmentService();
  
  String _statusFilter = 'pending';
  String _dueDateFilter = 'all';
  InstalmentSortOption _sortOption = InstalmentSortOption.dueDate;
  bool _isLoading = true;
  List<Instalment> _instalments = [];
  
  @override
  void initState() {
    super.initState();
    
    // Cargar las cuotas al iniciar la pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadInstalments();
      }
    });
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Este método se llama cuando el widget se inserta en el árbol
    // y cuando sus dependencias cambian (incluyendo cuando se navega de vuelta a esta pantalla)
  }
  
  // Método para refrescar la lista cuando se regresa a esta pantalla
  @override
  void didUpdateWidget(InstalmentListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Este método se llama cuando el widget se reconstruye
  }
  
  // Método para detectar cuando la pantalla vuelve a estar visible
  @override
  void activate() {
    super.activate();
    // Este método se llama cuando el widget se vuelve a activar en el árbol
    // Es ideal para refrescar datos cuando se regresa a esta pantalla
    _loadInstalments();
  }
  
  Future<void> _loadInstalments() async {
    setState(() => _isLoading = true);
    
    try {
      final instalments = await _instalmentService.getMyInstalments(
        status: _statusFilter,
        dueDate: _dueDateFilter,
      );
      
      // Debug first instalment to see where invoice number is coming from
      if (instalments.isNotEmpty && kDebugMode) {
        final instalment = instalments.first;
        Logger.debug('===== LIST SCREEN DEBUG =====');
        Logger.debug('Instalment ID: ${instalment.id}');
        Logger.debug('Invoice ID: ${instalment.invoiceId}');
        Logger.debug('Has invoice object: ${instalment.invoice != null}');
        if (instalment.invoice != null) {
          Logger.debug('Invoice Number: ${instalment.invoice!.invoiceNumber}');
        }
        Logger.debug('Has client object: ${instalment.client != null}');
        if (instalment.client != null) {
          Logger.debug('Client Name: ${instalment.client!.businessName}');
        }
        Logger.debug('Has additionalData: ${instalment.additionalData != null}');
        if (instalment.additionalData != null) {
          Logger.debug('AdditionalData keys: ${instalment.additionalData!.keys.join(", ")}');
          instalment.additionalData!.forEach((key, value) {
            if (key.toLowerCase().contains('invoice') || 
                key.toLowerCase().contains('factura') ||
                key.toLowerCase().contains('client') ||
                key.toLowerCase().contains('cliente')) {
              Logger.debug('Key: $key, Value: $value');
            }
          });
        }
        Logger.debug('===== END LIST SCREEN DEBUG =====');
      }
      
      if (mounted) {
        setState(() {
          _instalments = instalments;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar cuotas: $e')),
        );
      }
    }
  }
  
  void _applySort() {
    setState(() {
      switch (_sortOption) {
        case InstalmentSortOption.dueDate:
          _instalments.sort((a, b) => a.dueDate.compareTo(b.dueDate));
          break;
        case InstalmentSortOption.amount:
          _instalments.sort((a, b) => a.remainingAmount.compareTo(b.remainingAmount));
          break;
        case InstalmentSortOption.status:
          _instalments.sort((a, b) => a.status.compareTo(b.status));
          break;
      }
    });
  }
  
  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtrar cuotas'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Estado:'),
            const SizedBox(height: 8),
            DropdownButton<String>(
              isExpanded: true,
              value: _statusFilter,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('Todos')),
                DropdownMenuItem(value: 'pending', child: Text('Pendientes')),
                DropdownMenuItem(value: 'paid', child: Text('Pagadas')),
                DropdownMenuItem(value: 'cancelled', child: Text('Canceladas')),
              ],
              onChanged: (value) {
                setState(() {
                  _statusFilter = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            const Text('Vencimiento:'),
            const SizedBox(height: 8),
            DropdownButton<String>(
              isExpanded: true,
              value: _dueDateFilter,
              items: const [
                DropdownMenuItem(value: 'all', child: Text('Todos')),
                DropdownMenuItem(value: 'overdue', child: Text('Vencidas')),
                DropdownMenuItem(value: 'upcoming', child: Text('Próximas')),
              ],
              onChanged: (value) {
                setState(() {
                  _dueDateFilter = value!;
                });
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _loadInstalments();
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
  }
  
  void _showSortDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ordenar cuotas'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ignore: deprecated_member_use
            RadioListTile<InstalmentSortOption>(
              title: const Text('Fecha de vencimiento'),
              value: InstalmentSortOption.dueDate,
              // ignore: deprecated_member_use
              groupValue: _sortOption,
              // ignore: deprecated_member_use
              onChanged: (value) {
                setState(() {
                  _sortOption = value!;
                });
              },
            ),
            // ignore: deprecated_member_use
            RadioListTile<InstalmentSortOption>(
              title: const Text('Monto'),
              value: InstalmentSortOption.amount,
              // ignore: deprecated_member_use
              groupValue: _sortOption,
              // ignore: deprecated_member_use
              onChanged: (value) {
                setState(() {
                  _sortOption = value!;
                });
              },
            ),
            // ignore: deprecated_member_use
            RadioListTile<InstalmentSortOption>(
              title: const Text('Estado'),
              value: InstalmentSortOption.status,
              // ignore: deprecated_member_use
              groupValue: _sortOption,
              // ignore: deprecated_member_use
              onChanged: (value) {
                setState(() {
                  _sortOption = value!;
                });
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _applySort();
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cobranza'),
        actions: [
          IconButton(
            icon: const Icon(Icons.map),
            onPressed: () {
              context.go('/instalment-map');
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: () => _showSortDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadInstalments();
            },
          ),
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _instalments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.receipt_long,
                        size: 80,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No hay cuotas disponibles',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Las cuotas pendientes aparecerán aquí',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          _loadInstalments();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Actualizar'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadInstalments,
                  child: ListView.builder(
                    itemCount: _instalments.length,
                    itemBuilder: (context, index) {
                      final instalment = _instalments[index];
                      return InstalmentListItem(
                        instalment: instalment,
                        onTap: () {
                          // Navegar a la pantalla de detalle de la cuota
                          GoRouter.of(context).go('/instalments/${instalment.id}');
                        },
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              final userData = authProvider.userData;
              final userName =
                  userData != null && userData.containsKey('name')
                      ? userData['name']
                      : 'Usuario';
              final userEmail =
                  userData != null && userData.containsKey('email')
                      ? userData['email']
                      : authProvider.phoneNumber;

              return UserAccountsDrawerHeader(
                accountName: Text(userName),
                accountEmail: Text(userEmail),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                    style: const TextStyle(fontSize: 40.0),
                  ),
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long),
            title: const Text('Cobranza'),
            selected: true,
            onTap: () {
              Navigator.pop(context); // Cerrar el drawer
              GoRouter.of(context).go('/instalments');
            },
          ),
          ListTile(
            leading: const Icon(Icons.receipt),
            title: const Text('Facturas'),
            onTap: () {
              Navigator.pop(context); // Cerrar el drawer
              GoRouter.of(context).go('/invoices');
            },
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Perfil'),
            onTap: () {
              Navigator.pop(context); // Cerrar el drawer
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Función de perfil en desarrollo'),
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.exit_to_app),
            title: const Text('Cerrar Sesión'),
            onTap: () {
              // Capturar el AuthProvider antes de cualquier operación asíncrona
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              // Capturar el router antes de cualquier operación asíncrona
              final goRouter = GoRouter.of(context);
              // Mostrar el diálogo de confirmación
              showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Cerrar sesión'),
                  content: const Text(
                      '¿Estás seguro de que quieres cerrar sesión?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Cerrar sesión'),
                    ),
                  ],
                ),
              ).then((shouldLogout) async {
                // Procesar el resultado del diálogo
                if (shouldLogout == true) {
                  // Realizar la operación asíncrona
                  await authProvider.logout();
                  // Verificar si el widget sigue montado
                  if (!mounted) return;
                  // Usar la referencia capturada para la navegación
                  goRouter.go('/login');
                }
              });
            },
          ),
        ],
      ),
    );
  }
}

class InstalmentListItem extends StatelessWidget {
  final Instalment instalment;
  final VoidCallback onTap;
  
  const InstalmentListItem({
    super.key,
    required this.instalment,
    required this.onTap,
  });
  
  Color _getStatusColor() {
    switch (instalment.status) {
      case 'pending':
        return instalment.isOverdue ? Colors.red : Colors.blue;
      case 'paid':
        return Colors.green;
      case 'cancelled':
        return Colors.grey;
      case 'rejected':
        return Colors.red.shade900;
      default:
        return Colors.grey;
    }
  }
  
  String _getStatusText() {
    switch (instalment.status) {
      case 'pending':
        return instalment.isOverdue ? 'Vencida' : 'Pendiente';
      case 'paid':
        return 'Pagada';
      case 'cancelled':
        return 'Cancelada';
      case 'rejected':
        return 'Rechazada';
      default:
        return 'Desconocido';
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Usar el formateador de moneda con la moneda correcta de la cuota
    final currencyFormat = CurrencyFormatter.getCurrencyFormat(
      instalment.invoice?.currency,
    );
    
    final dateFormat = DateFormat('dd/MM/yyyy');
    
    // Nombre del cliente (usar client_business_name si está disponible)
    final clientName = instalment.client?.businessName ?? 
                       (instalment.additionalData != null && 
                        instalment.additionalData!.containsKey('client_business_name') ? 
                        instalment.additionalData!['client_business_name']?.toString() : null) ?? 
                       'Cliente no disponible';
    
    // Número de factura
    final invoiceNumber = instalment.invoice?.invoiceNumber ?? 'N/A';
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.business, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      clientName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor().withAlpha(51), // 0.2 * 255 = 51
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _getStatusColor(),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _getStatusText(),
                      style: TextStyle(
                        color: _getStatusColor(),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.receipt, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Factura: $invoiceNumber',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.receipt_long, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Cuota: ${instalment.number}/${instalment.invoice?.instalmentCount ?? 1}',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vence:',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        dateFormat.format(instalment.dueDate),
                        style: TextStyle(
                          color: instalment.isOverdue ? Colors.red : Colors.black,
                          fontWeight: instalment.isOverdue
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Monto:',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        currencyFormat.format(instalment.amount),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (instalment.paidAmount > 0) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: instalment.paidAmount / instalment.amount,
                  backgroundColor: Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pagado: ${currencyFormat.format(instalment.paidAmount)}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'Pendiente: ${currencyFormat.format(instalment.remainingAmount)}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
