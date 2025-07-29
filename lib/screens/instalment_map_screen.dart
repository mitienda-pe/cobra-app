import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../models/instalment.dart';
import '../services/instalment_service.dart';
import '../utils/currency_formatter.dart';

enum InstalmentSortOption {
  status,
  dueDate,
  amount,
  distance,
}

class InstalmentMapScreen extends StatefulWidget {
  const InstalmentMapScreen({super.key});

  @override
  State<InstalmentMapScreen> createState() => _InstalmentMapScreenState();
}

class _InstalmentMapScreenState extends State<InstalmentMapScreen> {
  final MapController _mapController = MapController();
  String? _selectedStatus;
  InstalmentSortOption _sortOption = InstalmentSortOption.distance;
  bool _hidePaidInstalments = false;
  Position? _currentPosition;
  List<Instalment> _instalments = [];
  bool _isLoading = false;
  
  final InstalmentService _instalmentService = InstalmentService();
  
  @override
  void initState() {
    super.initState();
    _determinePosition();
    
    // Cargar las cuotas al iniciar la pantalla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInstalments();
    });
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
        if (kDebugMode) {
          print('Error al obtener la ubicación: $e');
        }
      }
    } catch (e) {
      // Error general con el servicio de ubicación
      if (kDebugMode) {
        print('Error con el servicio de ubicación: $e');
      }
    }
  }
  
  Future<void> _loadInstalments() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      String statusFilter = _selectedStatus ?? 'all';
      String dueDateFilter = 'all';
      
      if (_hidePaidInstalments && statusFilter == 'all') {
        statusFilter = 'pending';
      }
      
      final instalments = await _instalmentService.getMyInstalments(
        status: statusFilter,
        dueDate: dueDateFilter,
        includeClient: true,
        includeInvoice: true,
      );
      
      // Depurar información de clientes y ubicaciones
      if (kDebugMode) {
        print('Cuotas cargadas: ${instalments.length}');
        for (var instalment in instalments) {
          print('Cuota ID: ${instalment.id}');
          print('  Cliente: ${instalment.client?.businessName}');
          if (instalment.client != null) {
            print('  Latitud: ${instalment.client!.latitude}');
            print('  Longitud: ${instalment.client!.longitude}');
            print('  Tiene ubicación: ${instalment.client!.location != null}');
          } else {
            print('  No tiene cliente asociado');
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _instalments = instalments;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar cuotas: $e')),
        );
      }
    }
  }
  
  void _forceReloadInstalments() {
    _loadInstalments();
  }
  
  void _sortInstalments(List<Instalment> instalments) {
    switch (_sortOption) {
      case InstalmentSortOption.status:
        instalments.sort((a, b) => a.status.compareTo(b.status));
        break;
      case InstalmentSortOption.dueDate:
        instalments.sort((a, b) => a.dueDate.compareTo(b.dueDate));
        break;
      case InstalmentSortOption.amount:
        instalments.sort((a, b) => b.amount.compareTo(a.amount));
        break;
      case InstalmentSortOption.distance:
        if (_currentPosition != null) {
          instalments.sort((a, b) {
            final aLocation = a.client?.location;
            final bLocation = b.client?.location;
            
            if (aLocation == null && bLocation == null) return 0;
            if (aLocation == null) return 1;
            if (bLocation == null) return -1;
            
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
          });
        }
        break;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de Cuotas'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Verificar si se puede hacer pop, sino navegar a la pantalla principal
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/instalments');
            }
          },
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
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Recargar las cuotas con los filtros actuales
              _forceReloadInstalments();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildMapContent(),
    );
  }
  
  Widget _buildMapContent() {
    // Filtrar cuotas por estado si hay un filtro seleccionado
    List<Instalment> filteredInstalments = List<Instalment>.from(_instalments);
    
    // Ocultar cuotas pagadas si la opción está activada
    if (_hidePaidInstalments) {
      filteredInstalments = filteredInstalments.where((instalment) => 
        instalment.status != 'paid'
      ).toList();
    }
    
    if (_selectedStatus != null && _selectedStatus != 'all') {
      filteredInstalments = filteredInstalments.where((instalment) {
        if (_selectedStatus == 'overdue') {
          return instalment.isOverdue && instalment.status != 'paid';
        }
        return instalment.status == _selectedStatus;
      }).toList();
    }
    
    // Filtrar cuotas que tienen ubicación
    final instalmentsWithLocation = filteredInstalments.where((instalment) {
      return instalment.client?.location != null;
    }).toList();
    
    // Ordenar cuotas según la opción seleccionada
    _sortInstalments(instalmentsWithLocation);
    
    if (instalmentsWithLocation.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No hay cuotas con ubicación disponible'),
            if (_selectedStatus != null || _hidePaidInstalments) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedStatus = null;
                    _hidePaidInstalments = false;
                  });
                  _loadInstalments();
                },
                child: const Text('Limpiar filtros'),
              ),
            ],
          ],
        ),
      );
    }
    
    // Calcular el centro del mapa basado en todas las ubicaciones
    LatLng center;
    
    if (instalmentsWithLocation.isNotEmpty) {
      final allLocations = instalmentsWithLocation
          .map((instalment) => instalment.client!.location!)
          .toList();
      
      final centerLat = allLocations
          .map((loc) => loc.latitude)
          .reduce((a, b) => a + b) / allLocations.length;
      
      final centerLng = allLocations
          .map((loc) => loc.longitude)
          .reduce((a, b) => a + b) / allLocations.length;
      
      center = LatLng(centerLat, centerLng);
    } else if (_currentPosition != null) {
      center = LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    } else {
      // Coordenadas por defecto (Lima, Perú)
      center = LatLng(-12.0464, -77.0428);
    }
    
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 13.0,
            onTap: (tapPosition, point) {
              // Cerrar cualquier marcador abierto
              setState(() {
                // Implementar lógica para cerrar marcadores si es necesario
              });
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.cobra_app',
            ),
            // Marcador para la ubicación actual
            if (_currentPosition != null)
              MarkerLayer(
                markers: [
                  Marker(
                    width: 40.0,
                    height: 40.0,
                    point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                    child: const Icon(
                      Icons.my_location,
                      color: Colors.blue,
                      size: 30.0,
                    ),
                  ),
                ],
              ),
            // Marcadores para las cuotas
            MarkerLayer(
              markers: instalmentsWithLocation.map((instalment) {
                final location = instalment.client!.location!;
                return Marker(
                  width: 40.0,
                  height: 40.0,
                  point: location,
                  child: GestureDetector(
                    onTap: () {
                      _showInstalmentDetails(instalment);
                    },
                    child: _buildMarkerIcon(instalment),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        // Panel de información de cuotas
        Positioned(
          bottom: 16.0,
          left: 16.0,
          right: 16.0,
          child: Card(
            elevation: 4.0,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Cuotas: ${instalmentsWithLocation.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.0,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatusIndicator(
                        'Pendientes',
                        Colors.blue,
                        instalmentsWithLocation.where((i) => i.status == 'pending' && !i.isOverdue).length,
                      ),
                      _buildStatusIndicator(
                        'Vencidas',
                        Colors.red,
                        instalmentsWithLocation.where((i) => i.isOverdue).length,
                      ),
                      _buildStatusIndicator(
                        'Pagadas',
                        Colors.green,
                        instalmentsWithLocation.where((i) => i.status == 'paid').length,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildMarkerIcon(Instalment instalment) {
    Color markerColor;
    
    if (instalment.status == 'paid') {
      markerColor = Colors.green;
    } else if (instalment.isOverdue) {
      markerColor = Colors.red;
    } else {
      markerColor = Colors.blue;
    }
    
    return Container(
      decoration: BoxDecoration(
        color: markerColor.withAlpha(204), // 0.8 * 255 = 204
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white,
          width: 2.0,
        ),
      ),
      child: const Icon(
        Icons.receipt_long,
        color: Colors.white,
        size: 20.0,
      ),
    );
  }
  
  Widget _buildStatusIndicator(String label, Color color, int count) {
    return Column(
      children: [
        Container(
          width: 12.0,
          height: 12.0,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 4.0),
        Text('$label: $count'),
      ],
    );
  }
  
  void _showInstalmentDetails(Instalment instalment) {
    final currencyFormat = CurrencyFormatter.getCurrencyFormat(
      instalment.invoice?.currency,
    );
    
    final dateFormat = DateFormat('dd/MM/yyyy');
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Cuota ${instalment.number}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18.0,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 4.0,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(instalment.status).withAlpha(51), // 0.2 * 255 = 51
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(
                      color: _getStatusColor(instalment.status),
                      width: 1.0,
                    ),
                  ),
                  child: Text(
                    _getStatusText(instalment.status),
                    style: TextStyle(
                      color: _getStatusColor(instalment.status),
                      fontWeight: FontWeight.bold,
                      fontSize: 12.0,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16.0),
            if (instalment.client != null) ...[
              Text(
                'Cliente: ${instalment.client!.businessName}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (instalment.client!.address.isNotEmpty)
                Text('Dirección: ${instalment.client!.address}'),
              if (instalment.client!.phone.isNotEmpty)
                Text('Teléfono: ${instalment.client!.phone}'),
            ],
            const SizedBox(height: 16.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Monto: ${currencyFormat.format(instalment.amount)}'),
                Text('Vence: ${dateFormat.format(instalment.dueDate)}'),
              ],
            ),
            const SizedBox(height: 8.0),
            if (instalment.invoice != null)
              Text('Factura: ${instalment.invoice!.invoiceNumber}'),
            const SizedBox(height: 16.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.pop(context);
                    }
                    context.push('/instalments/${instalment.id}');
                  },
                  icon: const Icon(Icons.visibility),
                  label: const Text('Ver Detalle'),
                ),
                if (instalment.status == 'pending')
                  ElevatedButton.icon(
                    onPressed: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.pop(context);
                      }
                      context.push('/instalments/${instalment.id}/pay');
                    },
                    icon: const Icon(Icons.payment),
                    label: const Text('Registrar Pago'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
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
              value: _selectedStatus ?? 'all',
              items: const [
                DropdownMenuItem(value: 'all', child: Text('Todos')),
                DropdownMenuItem(value: 'pending', child: Text('Pendientes')),
                DropdownMenuItem(value: 'paid', child: Text('Pagadas')),
                DropdownMenuItem(value: 'overdue', child: Text('Vencidas')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedStatus = value;
                });
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: _hidePaidInstalments,
                  onChanged: (value) {
                    setState(() {
                      _hidePaidInstalments = value ?? false;
                    });
                  },
                ),
                const Text('Ocultar cuotas pagadas'),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.pop(context);
              }
            },
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.pop(context);
              }
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
            RadioListTile<InstalmentSortOption>(
              title: const Text('Fecha de vencimiento'),
              value: InstalmentSortOption.dueDate,
              groupValue: _sortOption,
              onChanged: (value) {
                setState(() {
                  _sortOption = value!;
                });
              },
            ),
            RadioListTile<InstalmentSortOption>(
              title: const Text('Estado'),
              value: InstalmentSortOption.status,
              groupValue: _sortOption,
              onChanged: (value) {
                setState(() {
                  _sortOption = value!;
                });
              },
            ),
            RadioListTile<InstalmentSortOption>(
              title: const Text('Monto'),
              value: InstalmentSortOption.amount,
              groupValue: _sortOption,
              onChanged: (value) {
                setState(() {
                  _sortOption = value!;
                });
              },
            ),
            RadioListTile<InstalmentSortOption>(
              title: const Text('Distancia'),
              value: InstalmentSortOption.distance,
              groupValue: _sortOption,
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
              if (Navigator.of(context).canPop()) {
                Navigator.pop(context);
              }
            },
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.pop(context);
              }
              setState(() {});
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
  }
  
  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.blue;
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
  
  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Pendiente';
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
}
