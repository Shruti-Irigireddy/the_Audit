import 'package:flutter/material.dart';
import 'package:the_audit/core/utils/navbar.dart';

enum VehicleType { MULTIROTAR, FIXED_WING, VTOL }
enum status { ACTIVE, MAINTENANCE, RETIRED }
enum FrameStyle {FOLDING, FIXED}

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
                  const Text (
                    'Add Vehicle',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Vehicle Name / Nickname',
                      border: OutlineInputBorder(),
                    )
                  ),

                  const SizedBox(height: 16.0),

                  DropdownButtonFormField<VehicleType>(
                    value: _selectedVehicleType,
                    decoration: const InputDecoration(
                      labelText: 'Vehicle Type',
                      border: OutlineInputBorder(),
                    ),
                    items: VehicleType.values.map((VehicleType type) {
                      return DropdownMenuItem<VehicleType>(
                        value: type,
                        child: Text(type.toString().split('.').last),
                      );
                    }).toList(),
                    onChanged: (VehicleType? newValue) {
                      setState(() {
                        _selectedVehicleType = newValue;
                      });
                    },
                  ),
                  const SizedBox(height: 16.0),
                  const Text(
                    'Frame Details',
                    style: TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  Wrap(
                    spacing: 16.0,
                    runSpacing: 16.0,
                    children: [
                      halfField(
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Make',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      halfField(
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Model',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      halfField(
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Motor Count',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      halfField(
                        DropdownButtonFormField<FrameStyle>(
                          value: _selectedFrameStyle,
                          decoration: const InputDecoration(
                            labelText: 'Frame Style',
                            border: OutlineInputBorder(),
                          ),
                          items: FrameStyle.values.map((FrameStyle style) {
                            return DropdownMenuItem<FrameStyle>(
                              value: style,
                              child: Text(style.toString().split('.').last),
                            );
                          }).toList(),
                          onChanged: (FrameStyle? newValue) {
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
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Default Fail Safe Profile',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  DropdownButtonFormField<status>(
                    value: _selectedVehicleStatus,
                    decoration: const InputDecoration(
                      labelText: 'Vehicle Status',
                      border: OutlineInputBorder(),
                    ),
                    items: status.values.map((status stat) {
                      return DropdownMenuItem<status>(
                        value: stat,
                        child: Text(stat.toString().split('.').last),
                      );
                    }).toList(),
                    onChanged: (status? newValue) {
                      setState(() {
                        _selectedVehicleStatus = newValue;
                      });
                    },
                  ),
                  const SizedBox(height: 16.0),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24.0),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (formKey.currentState!.validate()) {
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
