import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_place/google_place.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/failure.dart';
import '../../../generated/l10n.dart';
import '../../../models/address_model.dart';
import '../../../widgets/app_button.dart';
import '../providers/address_notifier.dart';
import '../../../core/di/providers.dart';
import '../../../services/maps/maps_service.dart';

class EditAddressScreen extends HookConsumerWidget {
  const EditAddressScreen({
    super.key,
    required this.address,
  });

  final AddressModel address;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = S.of(context);
    final formKey = useMemoized(GlobalKey<FormState>.new);
    final addressController = useTextEditingController(text: address.formatted);
    final instructionsController =
        useTextEditingController(text: address.instructions ?? '');
    final predictions = useState<List<AutocompletePrediction>>(<AutocompletePrediction>[]);
    final selectedLatLng =
        useState<LatLng?>(LatLng(address.lat, address.lng));
    final isSubmitting = useState<bool>(false);
    final mapController = useState<GoogleMapController?>(null);
    final MapsService mapsService = ref.watch(mapsServiceProvider);
    final notifier = ref.read(addressNotifierProvider.notifier);
    final debouncer = useRef<Timer?>(null);

    useEffect(() {
      return () {
        debouncer.value?.cancel();
      };
    }, const []);

    Future<void> handleSearch(String value) async {
      debouncer.value?.cancel();
      debouncer.value = Timer(const Duration(milliseconds: 350), () async {
        final trimmed = value.trim();
        if (trimmed.length < 3) {
          predictions.value = const [];
          return;
        }
        final results = await mapsService.autocomplete(trimmed);
        predictions.value = results;
      });
    }

    Future<void> selectPrediction(AutocompletePrediction prediction) async {
      final placeId = prediction.placeId;
      if (placeId == null) {
        return;
      }
      final location = await mapsService.getDetails(placeId);
      if (location == null) {
        if (context.mounted) {
          _showFailure(
            context,
            Failure(message: l10n.addressCoordinatesError),
          );
        }
        return;
      }
      final formatted = prediction.description ?? '';
      selectedLatLng.value = location;
      selectedFormatted.value = formatted;
      addressController.text = formatted;
      predictions.value = const [];
      final controller = mapController.value;
      if (controller != null) {
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(location, 16),
        );
      }
    }

    Future<void> submit() async {
      final formState = formKey.currentState;
      if (formState == null || !formState.validate()) {
        return;
      }
      final location = selectedLatLng.value;
      if (location == null) {
        _showFailure(
          context,
          Failure(message: l10n.addressLocationRequired),
        );
        return;
      }
      isSubmitting.value = true;
      final updatedAddress = address.copyWith(
        formatted: addressController.text.trim(),
        lat: location.latitude,
        lng: location.longitude,
        instructions: _normalizeText(instructionsController.text),
      );
      final failure = await notifier.updateAddress(updatedAddress);
      isSubmitting.value = false;
      if (!context.mounted) {
        return;
      }
      if (failure != null) {
        _showFailure(context, failure);
        return;
      }
      _showSnackBar(context, l10n.addressUpdated);
      context.pop(updatedAddress);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.editAddress),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: addressController,
                      decoration: InputDecoration(
                        labelText: l10n.searchAddress,
                        hintText: l10n.addressSearchPlaceholder,
                      ),
                      onChanged: handleSearch,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return l10n.requiredField;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    if (predictions.value.isNotEmpty)
                      Card(
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: predictions.value.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final prediction = predictions.value[index];
                            return ListTile(
                              title: Text(prediction.description ?? ''),
                              onTap: () => selectPrediction(prediction),
                            );
                          },
                        ),
                      )
                    else if (addressController.text.trim().length >= 3)
                      Text(
                        l10n.addressSuggestionsEmpty,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Theme.of(context).hintColor),
                      ),
                    const SizedBox(height: 16),
                    Container(
                      height: 240,
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(AppConstants.defaultRadius),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius.circular(AppConstants.defaultRadius),
                        child: GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: selectedLatLng.value ??
                                const LatLng(55.751244, 37.618423),
                            zoom: selectedLatLng.value != null ? 16 : 11,
                          ),
                          markers: {
                            if (selectedLatLng.value != null)
                              Marker(
                                markerId: const MarkerId('selected'),
                                position: selectedLatLng.value!,
                              ),
                          },
                          onMapCreated: (controller) {
                            mapController.value = controller;
                          },
                          myLocationButtonEnabled: false,
                          zoomControlsEnabled: false,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (selectedLatLng.value == null)
                      Text(
                        l10n.addressMapHint,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Theme.of(context).hintColor),
                      ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: instructionsController,
                      decoration: InputDecoration(
                        labelText: l10n.addressInstructions,
                        hintText: l10n.addressInstructionsHint,
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    AppButton(
                      label: l10n.addressUpdateButton,
                      isLoading: isSubmitting.value,
                      onPressed: isSubmitting.value ? null : submit,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFailure(BuildContext context, Failure failure) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(failure.message)),
      );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  String? _normalizeText(String text) {
    final trimmed = text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
