import 'package:flutter/material.dart';
import 'package:the_audit/features/vehicle/domain/vehicle_type.dart';
import 'package:the_audit/core/utils/app_logger.dart';
import 'package:the_audit/core/utils/navbar.dart';
import 'package:the_audit/core/utils/theme.dart';

enum status { ACTIVE, MAINTENANCE, RETIRED }

enum FrameStyle { FOLDING, FIXED }

const _log = AppLogger('AddVehicle');

class AddVehicle extends StatefulWidget {
  const AddVehicle({super.key});

  @override
  State<AddVehicle> createState() => _AddVehicleState();
}

class _AddVehicleState extends State<AddVehicle> {
  final formKey = GlobalKey<FormState>();

  VehicleType? _selectedVehicleType;
  status? _selectedVehicleStatus;
  FrameStyle? _selectedFrameStyle;

  @override
  void initState() {
    super.initState();
    _log.t('initState');
  }

  @override
  void dispose() {
    _log.t('dispose');
    super.dispose();
  }

  Widget halfField(Widget child) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.45,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: NavBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Add Vehicle', style: AppTextStyles.pageTitle),
                const SizedBox(height: 16.0),

                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Vehicle Name / Nickname',
                  ),
                ),

                const SizedBox(height: 16.0),

                DropdownButtonFormField<VehicleType>(
                  value: _selectedVehicleType,
                  decoration: const InputDecoration(labelText: 'Vehicle Type'),
                  items: VehicleType.values.map((VehicleType type) {
                    return DropdownMenuItem<VehicleType>(
                      value: type,
                      child: Text(type.label),
                    );
                  }).toList(),
                  onChanged: (VehicleType? newValue) {
                    _log.d('vehicle type: ${newValue?.name}');
                    setState(() {
                      _selectedVehicleType = newValue;
                    });
                  },
                ),
                const SizedBox(height: 16.0),
                const Text('Frame Details', style: AppTextStyles.sectionTitle),
                const SizedBox(height: 16.0),
                Wrap(
                  spacing: 16.0,
                  runSpacing: 16.0,
                  children: [
                    halfField(
                      TextFormField(
                        decoration: const InputDecoration(labelText: 'Make'),
                      ),
                    ),
                    halfField(
                      TextFormField(
                        decoration: const InputDecoration(labelText: 'Model'),
                      ),
                    ),
                    halfField(
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Motor Count',
                        ),
                      ),
                    ),
                    halfField(
                      DropdownButtonFormField<FrameStyle>(
                        value: _selectedFrameStyle,
                        decoration: const InputDecoration(
                          labelText: 'Frame Style',
                        ),
                        items: FrameStyle.values.map((FrameStyle style) {
                          return DropdownMenuItem<FrameStyle>(
                            value: style,
                            child: Text(style.toString().split('.').last),
                          );
                        }).toList(),
                        onChanged: (FrameStyle? newValue) {
                          _log.d('frame style: ${newValue?.name}');
                          setState(() {
                            _selectedFrameStyle = newValue;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16.0),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Firmware Target',
                  ),
                ),
                const SizedBox(height: 16.0),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Default Fail Safe Profile',
                  ),
                ),
                const SizedBox(height: 16.0),
                DropdownButtonFormField<status>(
                  value: _selectedVehicleStatus,
                  decoration: const InputDecoration(
                    labelText: 'Vehicle Status',
                  ),
                  items: status.values.map((status stat) {
                    return DropdownMenuItem<status>(
                      value: stat,
                      child: Text(stat.toString().split('.').last),
                    );
                  }).toList(),
                  onChanged: (status? newValue) {
                    _log.d('vehicle status: ${newValue?.name}');
                    setState(() {
                      _selectedVehicleStatus = newValue;
                    });
                  },
                ),
                const SizedBox(height: 16.0),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Notes'),
                  maxLines: 3,
                ),
                const SizedBox(height: 24.0),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      _log.i(
                        'next tapped (type: ${_selectedVehicleType?.name}, '
                        'status: ${_selectedVehicleStatus?.name})',
                      );
                      if (formKey.currentState!.validate()) {
                        _log.d('form valid');
                        // Handle form submission
                      }
                    },
                    child: const Text('Next'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
