import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../models/account.dart';
import '../providers/account_provider.dart';

enum SortOption {
  status,
  expirationDate,
  amount,
  distance,
}

class AccountMapScreen extends StatefulWidget {
  const AccountMapScreen({super.key});

  @override
  State<AccountMapScreen> createState() => _AccountMapScreenState();
}

class _AccountMapScreenState extends State<AccountMapScreen> {
  final MapController _mapController = MapController();
  AccountStatus? _selectedStatus;
  SortOption _sortOption = SortOption.distance;
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
        title: const Text('Mapa de Cobranzas'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/accounts'),
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
        ],
      ),
      body: Consumer<AccountProvider>(
        builder: (context, accountProvider, child) {
          final accounts = accountProvider.accounts;
          
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
          
          // Filtrar cuentas que tienen ubicación
          final accountsWithLocation = filteredAccounts.where((account) {
            return account.customer.contact.location != null;
          }).toList();
          
          // Ordenar cuentas según la opción seleccionada
          _sortAccounts(accountsWithLocation);
          
          if (accountsWithLocation.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('No hay cuentas con ubicación disponible'),
                  if (_selectedStatus != null || _hidePaidAccounts) ...[
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
                ],
              ),
            );
          }
          
          // Calcular el centro del mapa basado en todas las ubicaciones
          final allLocations = accountsWithLocation
              .map((account) => account.customer.contact.location!)
              .toList();
          
          final centerLat = allLocations
              .map((loc) => loc.latitude)
              .reduce((a, b) => a + b) / allLocations.length;
          
          final centerLng = allLocations
              .map((loc) => loc.longitude)
              .reduce((a, b) => a + b) / allLocations.length;
          
          final center = LatLng(centerLat, centerLng);
          
          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 13.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.cobra_app',
                  ),
                  MarkerLayer(
                    markers: accountsWithLocation.map((account) {
                      return Marker(
                        width: 40.0,
                        height: 40.0,
                        point: account.customer.contact.location!,
                        child: GestureDetector(
                          onTap: () {
                            _showAccountInfo(context, account);
                          },
                          child: _buildMarkerIcon(account),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('${accountsWithLocation.length} cuentas en el mapa'),
                            const Spacer(),
                            Text('Ordenado por: ${_getSortText()}'),
                          ],
                        ),
                        if (_selectedStatus != null || _hidePaidAccounts) ...[
                          const SizedBox(height: 8),
                          SingleChildScrollView(
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
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.go('/accounts');
        },
        child: const Icon(Icons.list),
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
            // Todas las cuentas en el mapa ya tienen ubicación, pero verificamos por seguridad
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
  
  Widget _buildMarkerIcon(Account account) {
    Color markerColor;
    
    switch (account.status) {
      case AccountStatus.paid:
        markerColor = Colors.green;
        break;
      case AccountStatus.partiallyPaid:
        markerColor = Colors.orange;
        break;
      case AccountStatus.expired:
        markerColor = Colors.red;
        break;
      case AccountStatus.pending:
        markerColor = account.isExpired ? Colors.red : Colors.blue;
        break;
    }
    
    return Container(
      decoration: BoxDecoration(
        color: markerColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Icon(
        Icons.location_on,
        color: Colors.white,
        size: 24,
      ),
    );
  }
  
  void _showAccountInfo(BuildContext context, Account account) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                account.customer.commercialName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                account.customer.contact.address,
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Monto:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text('S/ ${account.totalAmount.toStringAsFixed(2)}'),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Estado:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(_getStatusText(account.status)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.go('/account-detail/${account.id}');
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Ver Detalles'),
                ),
              ),
            ],
          ),
        );
      },
    );
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
}
