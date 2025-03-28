import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/account.dart';
import '../providers/account_provider.dart';
import '../widgets/user_profile_widget.dart';

enum SortOption {
  status,
  expirationDate,
  amount,
  distance,
}

class AccountListScreen extends StatefulWidget {
  const AccountListScreen({super.key});

  @override
  State<AccountListScreen> createState() => _AccountListScreenState();
}

class _AccountListScreenState extends State<AccountListScreen> {
  AccountStatus? _selectedStatus;
  SortOption _sortOption = SortOption.expirationDate;
  bool _hidePaidAccounts = false;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _determinePosition();
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
        setState(() {
          _currentPosition = position;
        });
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
        title: const Text('Cuentas por Cobrar'),
        leading: const UserProfileWidget(),
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
              GoRouter.of(context).go('/map');
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Recargar las cuentas
              Provider.of<AccountProvider>(context, listen: false).loadAccounts();
            },
          ),
        ],
      ),
      body: Consumer<AccountProvider>(
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
                      // Reintentar cargar las cuentas
                      accountProvider.loadAccounts();
                    },
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
          }
          
          final accounts = accountProvider.accounts;
          
          if (accounts.isEmpty) {
            return const Center(
              child: Text('No hay cuentas por cobrar disponibles'),
            );
          }
          
          // Filtrar cuentas por estado si hay un filtro seleccionado
          List<Account> filteredAccounts = List<Account>.from(accounts);
          
          // Ocultar cuentas pagadas si la opción está activada
          if (_hidePaidAccounts) {
            filteredAccounts = filteredAccounts.where((account) => 
              account.status != AccountStatus.paid
            ).toList();
          }
          
          if (_selectedStatus != null) {
            filteredAccounts = filteredAccounts.where((account) {
              if (_selectedStatus == AccountStatus.expired) {
                return account.isExpired && account.status != AccountStatus.paid;
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
                  const Text('No hay cuentas con el filtro seleccionado'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _selectedStatus = null;
                        _hidePaidAccounts = false;
                      });
                    },
                    child: const Text('Limpiar filtros'),
                  ),
                ],
              ),
            );
          }
          
          return Column(
            children: [
              if (_selectedStatus != null || _hidePaidAccounts)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        const Text('Filtros: '),
                        if (_selectedStatus != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Chip(
                              label: Text(_getStatusText(_selectedStatus!)),
                              deleteIcon: const Icon(Icons.close, size: 18),
                              onDeleted: () {
                                setState(() {
                                  _selectedStatus = null;
                                });
                              },
                              backgroundColor: _getStatusColor(_selectedStatus!).withOpacity(0.2),
                              side: BorderSide(color: _getStatusColor(_selectedStatus!)),
                            ),
                          ),
                        if (_hidePaidAccounts)
                          Chip(
                            label: const Text('Ocultar Pagados'),
                            deleteIcon: const Icon(Icons.close, size: 18),
                            onDeleted: () {
                              setState(() {
                                _hidePaidAccounts = false;
                              });
                            },
                            backgroundColor: Colors.grey.withOpacity(0.2),
                            side: const BorderSide(color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    Text('Ordenado por: ${_getSortText()}'),
                    const Spacer(),
                    Text('${filteredAccounts.length} cuentas'),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: filteredAccounts.length,
                  itemBuilder: (context, index) {
                    final account = filteredAccounts[index];
                    return AccountListItem(account: account);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _sortAccounts(List<Account> accounts) {
    switch (_sortOption) {
      case SortOption.status:
        accounts.sort((a, b) {
          // Orden: Vencido > Pendiente > Pago Parcial > Pagado
          int getStatusPriority(Account account) {
            if (account.isExpired && account.status != AccountStatus.paid) return 0;
            switch (account.status) {
              case AccountStatus.pending: return 1;
              case AccountStatus.partiallyPaid: return 2;
              case AccountStatus.paid: return 3;
              case AccountStatus.expired: return 0;
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
            
            // Si ambas cuentas no tienen ubicación, mantener el orden original
            if (aLocation == null && bLocation == null) return 0;
            
            // Priorizar cuentas con ubicación
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
          // Si no hay ubicación del usuario, ordenar por fecha de vencimiento
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

  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtrar Cuentas'),
        content: StatefulBuilder(
          builder: (context, setStateDialog) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Estado:', style: TextStyle(fontWeight: FontWeight.bold)),
                _buildFilterOption(context, null, 'Todos'),
                _buildFilterOption(context, AccountStatus.pending, 'Pendientes'),
                _buildFilterOption(context, AccountStatus.partiallyPaid, 'Pago Parcial'),
                _buildFilterOption(context, AccountStatus.paid, 'Pagados'),
                _buildFilterOption(context, AccountStatus.expired, 'Vencidos'),
                const Divider(),
                SwitchListTile(
                  title: const Text('Ocultar cuentas pagadas'),
                  value: _hidePaidAccounts,
                  onChanged: (value) {
                    setStateDialog(() {
                      setState(() {
                        _hidePaidAccounts = value;
                      });
                    });
                  },
                ),
              ],
            );
          }
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
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
            _buildSortOption(context, SortOption.expirationDate, 'Fecha de vencimiento (menor a mayor)'),
            _buildSortOption(context, SortOption.amount, 'Monto (mayor a menor)'),
            _buildSortOption(context, SortOption.distance, 'Distancia (más cercano primero)'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterOption(BuildContext context, AccountStatus? status, String label) {
    return ListTile(
      title: Text(label),
      leading: Radio<AccountStatus?>(
        value: status,
        groupValue: _selectedStatus,
        onChanged: (value) {
          setState(() {
            _selectedStatus = value;
          });
          Navigator.of(context).pop();
        },
      ),
      onTap: () {
        setState(() {
          _selectedStatus = status;
        });
        Navigator.of(context).pop();
      },
    );
  }

  Widget _buildSortOption(BuildContext context, SortOption option, String label) {
    return ListTile(
      title: Text(label),
      leading: Radio<SortOption>(
        value: option,
        groupValue: _sortOption,
        onChanged: (value) {
          setState(() {
            _sortOption = value!;
          });
          Navigator.of(context).pop();
        },
      ),
      onTap: () {
        setState(() {
          _sortOption = option;
        });
        Navigator.of(context).pop();
      },
    );
  }

  Color _getStatusColor(AccountStatus status) {
    switch (status) {
      case AccountStatus.paid:
        return Colors.green;
      case AccountStatus.partiallyPaid:
        return Colors.orange;
      case AccountStatus.expired:
        return Colors.red;
      case AccountStatus.pending:
        return Colors.blue;
    }
  }

  String _getStatusText(AccountStatus status) {
    switch (status) {
      case AccountStatus.paid:
        return 'Pagado';
      case AccountStatus.partiallyPaid:
        return 'Pago Parcial';
      case AccountStatus.expired:
        return 'Vencido';
      case AccountStatus.pending:
        return 'Pendiente';
    }
  }
}

class AccountListItem extends StatelessWidget {
  final Account account;
  
  const AccountListItem({super.key, required this.account});
  
  Color _getStatusColor() {
    switch (account.status) {
      case AccountStatus.paid:
        return Colors.green;
      case AccountStatus.partiallyPaid:
        return Colors.orange;
      case AccountStatus.expired:
        return Colors.red;
      case AccountStatus.pending:
        return account.isExpired ? Colors.red : Colors.blue;
    }
  }
  
  String _getStatusText() {
    switch (account.status) {
      case AccountStatus.paid:
        return 'Pagado';
      case AccountStatus.partiallyPaid:
        return 'Pago Parcial';
      case AccountStatus.expired:
        return 'Vencido';
      case AccountStatus.pending:
        return account.isExpired ? 'Vencido' : 'Pendiente';
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final currencyFormat = NumberFormat.currency(
      locale: 'es_PE',
      symbol: 'S/',
      decimalDigits: 2,
    );
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          GoRouter.of(context).go('/account-detail/${account.id}');
        },
        borderRadius: BorderRadius.circular(12),
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
              Text(
                account.concept,
                style: TextStyle(
                  color: Colors.grey[700],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
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
              if (account.status == AccountStatus.partiallyPaid) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: account.paidAmount / account.totalAmount,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getStatusColor(),
                  ),
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
