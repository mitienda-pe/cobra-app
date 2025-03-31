import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../models/invoice_account.dart';
import '../providers/invoice_account_provider.dart';
import '../providers/auth_provider.dart';

enum SortOption {
  status,
  expirationDate,
  amount,
  distance,
}

class InvoiceListScreen extends StatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  InvoiceAccountStatus? _selectedStatus;
  SortOption _sortOption = SortOption.expirationDate;
  bool _hidePaidAccounts = false;
  Position? _currentPosition;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _dateStart;
  String? _dateEnd;

  @override
  void initState() {
    super.initState();
    _determinePosition();

    // Cargar las facturas al iniciar la pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _reloadInvoicesWithFilters();
      }
    });
  }

  @override
  void dispose() {
    // Asegurarse de que no queden listeners o recursos sin liberar
    super.dispose();
  }

  Future<void> _determinePosition() async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Los servicios de ubicación no están habilitados, no podemos obtener la ubicación
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // Permisos denegados, no podemos obtener la ubicación
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Permisos denegados permanentemente, no podemos obtener la ubicación
        return;
      }

      try {
        Position position = await Geolocator.getCurrentPosition();
        // Verificar si el widget sigue montado antes de llamar a setState
        if (mounted) {
          setState(() {
            _currentPosition = position;
          });
        }
      } catch (e) {
        // Error al obtener la ubicación
        print('Error al obtener la ubicación: $e');
      }
    } catch (e) {
      // Error general con el servicio de ubicación
      print('Error con el servicio de ubicación: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Facturas'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              _showFilterDialog(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: () {
              _showSortDialog(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.map),
            onPressed: () {
              GoRouter.of(context).go('/invoice-map');
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Recargar las facturas con los filtros actuales
              _forceReloadInvoices();
            },
          ),
        ],
      ),
      drawer: Drawer(
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
              leading: const Icon(Icons.receipt),
              title: const Text('Facturas'),
              selected: true,
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
              onTap: () async {
                // Mostrar diálogo de confirmación
                final shouldLogout = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Cerrar Sesión'),
                        content: const Text(
                            '¿Estás seguro de que deseas cerrar sesión?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancelar'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Cerrar Sesión'),
                          ),
                        ],
                      ),
                    ) ??
                    false;

                if (shouldLogout) {
                  Navigator.pop(context); // Cerrar el drawer
                  final authProvider =
                      Provider.of<AuthProvider>(context, listen: false);
                  await authProvider.logout();
                  // La redirección a la pantalla de login se manejará automáticamente
                  // a través del redirect configurado en el GoRouter
                }
              },
            ),
          ],
        ),
      ),
      body: Consumer<InvoiceAccountProvider>(
        builder: (context, accountProvider, child) {
          // Mostrar indicador de carga si está cargando
          if (accountProvider.isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Cargando facturas...'),
                ],
              ),
            );
          }

          // Mostrar mensaje de error si hay un error
          if (accountProvider.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(accountProvider.errorMessage!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Reintentar cargar las facturas
                      _reloadInvoicesWithFilters();
                    },
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }

          final accounts = accountProvider.invoiceAccounts;

          if (accounts.isEmpty) {
            return const Center(
              child: Text('No hay facturas disponibles'),
            );
          }

          // Filtrar cuentas por estado si hay un filtro seleccionado
          List<InvoiceAccount> filteredAccounts =
              List<InvoiceAccount>.from(accounts);

          // Ocultar cuentas pagadas si la opción está activada
          if (_hidePaidAccounts) {
            filteredAccounts = filteredAccounts
                .where((account) => account.status != InvoiceAccountStatus.paid)
                .toList();
          }

          if (_selectedStatus != null) {
            filteredAccounts = filteredAccounts.where((account) {
              if (_selectedStatus == InvoiceAccountStatus.expired) {
                return account.isExpired &&
                    account.status != InvoiceAccountStatus.paid;
              }
              return account.status == _selectedStatus;
            }).toList();
          }

          // Ordenar cuentas según la opción seleccionada
          _sortAccounts(filteredAccounts);

          if (filteredAccounts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No hay facturas con el filtro seleccionado'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _selectedStatus = null;
                        _hidePaidAccounts = false;
                        _dateStart = null;
                        _dateEnd = null;
                        _startDate = null;
                        _endDate = null;
                      });
                      _reloadInvoicesWithFilters();
                    },
                    child: const Text('Limpiar filtros'),
                  ),
                ],
              ),
            );
          }

          // Mostrar filtros activos
          return Column(
            children: [
              // Mostrar filtros activos
              if (_selectedStatus != null ||
                  _hidePaidAccounts ||
                  _startDate != null ||
                  _endDate != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.grey[200],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Filtros activos:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedStatus = null;
                                _hidePaidAccounts = false;
                                _dateStart = null;
                                _dateEnd = null;
                                _startDate = null;
                                _endDate = null;
                              });
                              _reloadInvoicesWithFilters();
                            },
                            child: const Text('Limpiar todos'),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (_selectedStatus != null)
                            Chip(
                              label: Text(_getStatusText(_selectedStatus!)),
                              deleteIcon: const Icon(Icons.close, size: 18),
                              onDeleted: () {
                                setState(() {
                                  _selectedStatus = null;
                                });
                                _reloadInvoicesWithFilters();
                              },
                              backgroundColor: _getStatusColor(_selectedStatus!)
                                  .withOpacity(0.2),
                              side: BorderSide(
                                  color: _getStatusColor(_selectedStatus!)),
                            ),
                          if (_hidePaidAccounts)
                            Chip(
                              label: const Text('Ocultar Pagados'),
                              deleteIcon: const Icon(Icons.close, size: 18),
                              onDeleted: () {
                                setState(() {
                                  _hidePaidAccounts = false;
                                });
                                _reloadInvoicesWithFilters();
                              },
                              backgroundColor: Colors.grey.withOpacity(0.2),
                              side: const BorderSide(color: Colors.grey),
                            ),
                          if (_startDate != null)
                            Chip(
                              label: Text(
                                  'Desde: ${DateFormat('dd/MM/yyyy').format(_startDate!)}'),
                              deleteIcon: const Icon(Icons.close, size: 18),
                              onDeleted: () {
                                setState(() {
                                  _startDate = null;
                                  _dateStart = null;
                                });
                                _reloadInvoicesWithFilters();
                              },
                              backgroundColor: Colors.blue.withOpacity(0.2),
                              side: const BorderSide(color: Colors.blue),
                            ),
                          if (_endDate != null)
                            Chip(
                              label: Text(
                                  'Hasta: ${DateFormat('dd/MM/yyyy').format(_endDate!)}'),
                              deleteIcon: const Icon(Icons.close, size: 18),
                              onDeleted: () {
                                setState(() {
                                  _endDate = null;
                                  _dateEnd = null;
                                });
                                _reloadInvoicesWithFilters();
                              },
                              backgroundColor: Colors.blue.withOpacity(0.2),
                              side: const BorderSide(color: Colors.blue),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

              // Mostrar información de ordenamiento
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.grey[100],
                child: Row(
                  children: [
                    Text(
                      'Ordenado por: ${_getSortText()}',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${filteredAccounts.length} facturas',
                      style: TextStyle(
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),

              // Lista de facturas
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _forceReloadInvoices,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: filteredAccounts.length,
                    itemBuilder: (context, index) {
                      final account = filteredAccounts[index];
                      return InvoiceListItem(
                        account: account,
                        onTap: () {
                          GoRouter.of(context)
                              .go('/invoice-detail/${account.id}');
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Acción para crear una nueva factura
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Función para crear facturas en desarrollo'),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _sortAccounts(List<InvoiceAccount> accounts) {
    switch (_sortOption) {
      case SortOption.status:
        accounts.sort((a, b) {
          // Orden: Vencido > Pendiente > Pago Parcial > Pagado
          int getStatusPriority(InvoiceAccount account) {
            if (account.isExpired &&
                account.status != InvoiceAccountStatus.paid) return 0;
            switch (account.status) {
              case InvoiceAccountStatus.pending:
                return 1;
              case InvoiceAccountStatus.partiallyPaid:
                return 2;
              case InvoiceAccountStatus.paid:
                return 3;
              case InvoiceAccountStatus.expired:
                return 0;
            }
          }

          return getStatusPriority(a).compareTo(getStatusPriority(b));
        });
        break;
      case SortOption.expirationDate:
        accounts.sort((a, b) => a.expirationDate.compareTo(b.expirationDate));
        break;
      case SortOption.amount:
        accounts.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
        break;
      case SortOption.distance:
        if (_currentPosition != null) {
          accounts.sort((a, b) {
            final aLocation = a.customer.contact.location;
            final bLocation = b.customer.contact.location;

            if (aLocation == null && bLocation == null) return 0;
            if (aLocation == null) return 1;
            if (bLocation == null) return -1;

            try {
              final aDistance = Geolocator.distanceBetween(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
                aLocation.latitude,
                aLocation.longitude,
              );

              final bDistance = Geolocator.distanceBetween(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
                bLocation.latitude,
                bLocation.longitude,
              );

              return aDistance.compareTo(bDistance);
            } catch (e) {
              // Si hay un error al calcular la distancia, mantener el orden original
              print('Error al calcular distancia: $e');
              return 0;
            }
          });
        } else {
          // Si no hay ubicación del usuario, ordenar por fecha de vencimiento como alternativa
          accounts.sort((a, b) => a.expirationDate.compareTo(b.expirationDate));
        }
        break;
    }
  }

  String _getSortText() {
    switch (_sortOption) {
      case SortOption.status:
        return 'Estado';
      case SortOption.expirationDate:
        return 'Fecha de vencimiento';
      case SortOption.amount:
        return 'Monto (mayor a menor)';
      case SortOption.distance:
        return 'Distancia (más cercano)';
    }
  }

  Color _getStatusColor(InvoiceAccountStatus status) {
    switch (status) {
      case InvoiceAccountStatus.paid:
        return Colors.green;
      case InvoiceAccountStatus.partiallyPaid:
        return Colors.orange;
      case InvoiceAccountStatus.expired:
        return Colors.red;
      case InvoiceAccountStatus.pending:
        return Colors.blue;
    }
  }

  String _getStatusText(InvoiceAccountStatus status) {
    switch (status) {
      case InvoiceAccountStatus.paid:
        return 'Pagado';
      case InvoiceAccountStatus.partiallyPaid:
        return 'Pago Parcial';
      case InvoiceAccountStatus.expired:
        return 'Vencido';
      case InvoiceAccountStatus.pending:
        return 'Pendiente';
    }
  }

  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtrar Facturas'),
        content: StatefulBuilder(
          builder: (context, setStateDialog) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Estado:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  _buildFilterOption(context, null, 'Todos'),
                  _buildFilterOption(
                      context, InvoiceAccountStatus.pending, 'Pendientes'),
                  _buildFilterOption(context,
                      InvoiceAccountStatus.partiallyPaid, 'Pago Parcial'),
                  _buildFilterOption(
                      context, InvoiceAccountStatus.paid, 'Pagados'),
                  _buildFilterOption(
                      context, InvoiceAccountStatus.expired, 'Vencidos'),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Ocultar facturas pagadas'),
                    value: _hidePaidAccounts,
                    onChanged: (value) {
                      setStateDialog(() {
                        setState(() {
                          _hidePaidAccounts = value;
                        });
                      });
                    },
                  ),
                  const Divider(),
                  const Text('Rango de fechas:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: _startDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2025),
                            );
                            if (picked != null) {
                              setStateDialog(() {
                                setState(() {
                                  _startDate = picked;
                                  _dateStart =
                                      DateFormat('yyyy-MM-dd').format(picked);
                                });
                              });
                            }
                          },
                          child: Text(_startDate != null
                              ? DateFormat('dd/MM/yyyy').format(_startDate!)
                              : 'Fecha Inicio'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: _endDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2025),
                            );
                            if (picked != null) {
                              setStateDialog(() {
                                setState(() {
                                  _endDate = picked;
                                  _dateEnd =
                                      DateFormat('yyyy-MM-dd').format(picked);
                                });
                              });
                            }
                          },
                          child: Text(_endDate != null
                              ? DateFormat('dd/MM/yyyy').format(_endDate!)
                              : 'Fecha Fin'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedStatus = null;
                _hidePaidAccounts = false;
                _dateStart = null;
                _dateEnd = null;
                _startDate = null;
                _endDate = null;
              });
              Navigator.of(context).pop();
              _reloadInvoicesWithFilters();
            },
            child: const Text('Limpiar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _reloadInvoicesWithFilters();
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
        title: const Text('Ordenar por'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSortOption(context, SortOption.status, 'Estado'),
            _buildSortOption(context, SortOption.expirationDate,
                'Fecha de vencimiento (menor a mayor)'),
            _buildSortOption(
                context, SortOption.amount, 'Monto (mayor a menor)'),
            _buildSortOption(context, SortOption.distance,
                'Distancia (más cercano primero)'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {}); // Forzar reconstrucción
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterOption(
      BuildContext context, InvoiceAccountStatus? status, String label) {
    return ListTile(
      title: Text(label),
      leading: Radio<InvoiceAccountStatus?>(
        value: status,
        groupValue: _selectedStatus,
        onChanged: (value) {
          setState(() {
            _selectedStatus = value;
          });
        },
      ),
      onTap: () {
        setState(() {
          _selectedStatus = status;
        });
      },
    );
  }

  Widget _buildSortOption(
      BuildContext context, SortOption option, String label) {
    return ListTile(
      title: Text(label),
      leading: Radio<SortOption>(
        value: option,
        groupValue: _sortOption,
        onChanged: (value) {
          setState(() {
            _sortOption = value!;
          });
        },
      ),
      onTap: () {
        setState(() {
          _sortOption = option;
        });
      },
    );
  }

  Future<void> _reloadInvoicesWithFilters() async {
    final accountProvider =
        Provider.of<InvoiceAccountProvider>(context, listen: false);

    // Convertir el estado seleccionado al formato esperado por la API
    String? apiStatus;
    if (_selectedStatus != null) {
      switch (_selectedStatus!) {
        case InvoiceAccountStatus.pending:
          apiStatus = 'pending';
          break;
        case InvoiceAccountStatus.partiallyPaid:
          apiStatus = 'partial';
          break;
        case InvoiceAccountStatus.paid:
          apiStatus = 'paid';
          break;
        case InvoiceAccountStatus.expired:
          apiStatus = 'expired';
          break;
      }
    }

    await accountProvider.loadInvoiceAccounts(
      status: apiStatus,
      dateStart: _dateStart,
      dateEnd: _dateEnd,
      // No forzamos la recarga a menos que sea explícitamente solicitado por el botón de refresh
    );
  }

  // Método para forzar la recarga de datos
  Future<void> _forceReloadInvoices() async {
    if (!mounted) return;
    
    final accountProvider =
        Provider.of<InvoiceAccountProvider>(context, listen: false);

    // Convertir el estado seleccionado al formato esperado por la API
    String? apiStatus;
    if (_selectedStatus != null) {
      switch (_selectedStatus!) {
        case InvoiceAccountStatus.pending:
          apiStatus = 'pending';
          break;
        case InvoiceAccountStatus.partiallyPaid:
          apiStatus = 'partial';
          break;
        case InvoiceAccountStatus.paid:
          apiStatus = 'paid';
          break;
        case InvoiceAccountStatus.expired:
          apiStatus = 'expired';
          break;
      }
    }

    // Mostrar un SnackBar indicando que se están recargando los datos
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Actualizando datos desde el servidor...'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    try {
      await accountProvider.loadInvoiceAccounts(
        status: apiStatus,
        dateStart: _dateStart,
        dateEnd: _dateEnd,
        forceRefresh: true, // Forzar la recarga de datos
      );
    } catch (e) {
      print('Error al recargar facturas: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class InvoiceListItem extends StatelessWidget {
  final InvoiceAccount account;
  final VoidCallback onTap;

  const InvoiceListItem({
    Key? key,
    required this.account,
    required this.onTap,
  }) : super(key: key);

  Color _getStatusColor() {
    switch (account.status) {
      case InvoiceAccountStatus.paid:
        return Colors.green;
      case InvoiceAccountStatus.partiallyPaid:
        return Colors.orange;
      case InvoiceAccountStatus.expired:
        return Colors.red;
      case InvoiceAccountStatus.pending:
        return account.isExpired ? Colors.red : Colors.blue;
    }
  }

  String _getStatusText() {
    switch (account.status) {
      case InvoiceAccountStatus.paid:
        return 'Pagado';
      case InvoiceAccountStatus.partiallyPaid:
        return 'Pago Parcial';
      case InvoiceAccountStatus.expired:
        return 'Vencido';
      case InvoiceAccountStatus.pending:
        return account.isExpired ? 'Vencido' : 'Pendiente';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final currencyFormat = NumberFormat.currency(
      symbol: '\$',
      decimalDigits: 2,
    );

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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      account.customer.commercialName,
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
                      color: _getStatusColor().withOpacity(0.2),
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
                      'Factura: ${account.invoiceNumber}',
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
                        dateFormat.format(account.expirationDate),
                        style: TextStyle(
                          color: account.isExpired ? Colors.red : Colors.black,
                          fontWeight: account.isExpired
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
                        currencyFormat.format(account.totalAmount),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (account.paidAmount > 0) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: account.paidAmount / account.totalAmount,
                  backgroundColor: Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pagado: ${currencyFormat.format(account.paidAmount)}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'Pendiente: ${currencyFormat.format(account.remainingAmount)}',
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
