import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart'
    as places_sdk;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/services/location_service.dart';
import 'home_controller.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _timeFormat = DateFormat('HH:mm');

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeControllerProvider);
    final controller = ref.read(homeControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('JITA'), centerTitle: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Text(
                'Where do you need to be?',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),

              // Origin field
              _PlaceAutocompleteField(
                controller: _originController,
                label: 'Origin',
                hint: 'Where are you leaving from?',
                locationService: controller.locationService,
                onPlaceSelected: (place) {
                  controller.setOrigin(place);
                  _originController.text = place.displayName;
                },
                onClear: () {
                  controller.clearOrigin();
                  _originController.clear();
                },
              ),
              const SizedBox(height: 16),

              // Destination field
              _PlaceAutocompleteField(
                controller: _destinationController,
                label: 'Destination',
                hint: 'Where do you need to arrive?',
                locationService: controller.locationService,
                onPlaceSelected: (place) {
                  controller.setDestination(place);
                  _destinationController.text = place.displayName;
                },
                onClear: () {
                  controller.clearDestination();
                  _destinationController.clear();
                },
              ),
              const SizedBox(height: 16),

              // Arrival time picker
              InkWell(
                onTap: () => _pickArrivalTime(context, controller),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Arrival Time',
                    suffixIcon: const Icon(Icons.access_time),
                    border: const OutlineInputBorder(),
                  ),
                  child: Text(
                    state.arrivalTime != null
                        ? _formatTimeOfDay(state.arrivalTime!)
                        : 'Select arrival time',
                    style: TextStyle(
                      color: state.arrivalTime != null
                          ? null
                          : Theme.of(context).hintColor,
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // Error message
              if (state.errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    state.errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Start monitoring button
              FilledButton(
                onPressed: state.isLoading || !state.isValid
                    ? null
                    : () => _startMonitoring(controller),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                child: state.isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Start Monitoring',
                        style: TextStyle(fontSize: 18),
                      ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickArrivalTime(
    BuildContext context,
    HomeController controller,
  ) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null) {
      controller.setArrivalTime(time);
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return _timeFormat.format(dt);
  }

  Future<void> _startMonitoring(HomeController controller) async {
    final success = await controller.startMonitoring();
    if (success && mounted) {
      Navigator.of(context).pushReplacementNamed('/monitoring');
    }
  }
}

/// A text field with autocomplete dropdown for Google Places.
class _PlaceAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final LocationService locationService;
  final ValueChanged<PlaceResult> onPlaceSelected;
  final VoidCallback onClear;

  const _PlaceAutocompleteField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.locationService,
    required this.onPlaceSelected,
    required this.onClear,
  });

  @override
  State<_PlaceAutocompleteField> createState() =>
      _PlaceAutocompleteFieldState();
}

class _PlaceAutocompleteFieldState extends State<_PlaceAutocompleteField> {
  List<places_sdk.AutocompletePrediction> _predictions = [];
  Timer? _debounce;
  bool _showDropdown = false;
  bool _isSelected = false;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onTextChanged(String query) {
    if (_isSelected) {
      _isSelected = false;
      return;
    }
    _debounce?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _predictions = [];
        _showDropdown = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final predictions = await widget.locationService.getAutocomplete(query);
        if (mounted) {
          setState(() {
            _predictions = predictions;
            _showDropdown = predictions.isNotEmpty;
          });
        }
      } catch (_) {
        // Silently fail — user can keep typing.
      }
    });
  }

  Future<void> _onPredictionSelected(
    places_sdk.AutocompletePrediction prediction,
  ) async {
    setState(() {
      _showDropdown = false;
      _predictions = [];
    });

    final placeId = prediction.placeId;
    final details = await widget.locationService.getPlaceDetails(placeId);
    if (details != null) {
      _isSelected = true;
      widget.onPlaceSelected(details);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: widget.controller,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            suffixIcon: widget.controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      widget.onClear();
                      setState(() {
                        _predictions = [];
                        _showDropdown = false;
                        _isSelected = false;
                      });
                    },
                  )
                : const Icon(Icons.search),
          ),
          onChanged: _onTextChanged,
        ),
        if (_showDropdown && _predictions.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(8),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _predictions.length,
              itemBuilder: (context, index) {
                final prediction = _predictions[index];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.place, size: 20),
                  title: Text(
                    prediction.fullText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _onPredictionSelected(prediction),
                );
              },
            ),
          ),
      ],
    );
  }
}
