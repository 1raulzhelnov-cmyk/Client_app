import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../generated/l10n.dart';
import '../../../widgets/app_button.dart';
import '../providers/review_notifier.dart';

class RatingModal extends ConsumerStatefulWidget {
  const RatingModal({
    super.key,
    required this.orderId,
    required this.venueId,
    this.venueName,
  });

  final String orderId;
  final String venueId;
  final String? venueName;

  @override
  ConsumerState<RatingModal> createState() => _RatingModalState();
}

class _RatingModalState extends ConsumerState<RatingModal> {
  static const int _maxPhotos = 5;

  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();

  int _rating = 5;
  bool _isSubmitting = false;
  List<XFile> _photos = const <XFile>[];

  @override
  void dispose() {
    _textController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _buildTitle(l10n),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.reviewModalSubtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.reviewModalRatingLabel,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          RatingBar.builder(
            initialRating: _rating.toDouble(),
            minRating: 1,
            maxRating: 5,
            allowHalfRating: false,
            itemCount: 5,
            itemSize: 36,
            itemPadding: const EdgeInsets.symmetric(horizontal: 4),
            unratedColor: theme.colorScheme.surfaceVariant,
            itemBuilder: (context, _) => Icon(
              Icons.star_rounded,
              color: theme.colorScheme.secondary,
            ),
            onRatingUpdate: (value) {
              setState(() {
                _rating = value.round().clamp(1, 5);
              });
            },
          ),
          const SizedBox(height: 24),
          Text(
            l10n.reviewModalTextLabel,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _textController,
            focusNode: _textFocusNode,
            enabled: !_isSubmitting,
            minLines: 3,
            maxLines: 6,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: l10n.reviewModalTextHint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            textInputAction: TextInputAction.newline,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.reviewModalPhotosLabel(_photos.length, _maxPhotos),
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton.icon(
                onPressed: _isSubmitting ||
                        (_photos.length >= _maxPhotos && _maxPhotos > 0)
                    ? null
                    : _pickImages,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(l10n.reviewModalAddPhotos),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _PhotoPreviewGrid(
            photos: _photos,
            onRemove: _isSubmitting ? null : _removePhoto,
          ),
          const SizedBox(height: 24),
          AppButton(
            label: l10n.reviewModalSubmit,
            isLoading: _isSubmitting,
            onPressed: _isSubmitting ? null : _submit,
          ),
        ],
      ),
    );
  }

  Future<void> _pickImages() async {
    final picker = ref.read(imagePickerProvider);
    try {
      final images = await picker.pickMultiImage(
        imageQuality: 85,
      );
      if (images == null || images.isEmpty) {
        return;
      }
      setState(() {
        final combined = List<XFile>.from(_photos)..addAll(images);
        if (combined.length > _maxPhotos) {
          combined.removeRange(_maxPhotos, combined.length);
        }
        _photos = combined;
      });
    } catch (error, stackTrace) {
      debugPrint('Image pick error: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).reviewModalImagePickError)),
      );
    }
  }

  void _removePhoto(XFile file) {
    setState(() {
      _photos = _photos.where((photo) => photo.path != file.path).toList();
    });
  }

  Future<void> _submit() async {
    if (_rating < 1 || _rating > 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).reviewModalValidationRating)),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _isSubmitting = true;
    });

    List<File> files = const <File>[];
    if (!kIsWeb) {
      files = _photos
          .map((photo) => File(photo.path))
          .where((file) => file.existsSync())
          .toList();
    }

    final notifier = ref.read(reviewProvider.notifier);
    final failure = await notifier.submitReview(
      orderId: widget.orderId,
      venueId: widget.venueId,
      stars: _rating,
      text: _textController.text,
      photos: files,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
    });

    if (failure != null) {
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
      return;
    }

    messenger.showSnackBar(
      SnackBar(content: Text(S.of(context).reviewModalSuccess)),
    );
    Navigator.of(context).pop(true);
  }

  String _buildTitle(S l10n) {
    final venueName = widget.venueName;
    if (venueName == null || venueName.trim().isEmpty) {
      return l10n.reviewModalTitle;
    }
    return l10n.reviewModalTitleWithName(venueName);
  }
}

class _PhotoPreviewGrid extends StatelessWidget {
  const _PhotoPreviewGrid({
    required this.photos,
    required this.onRemove,
  });

  final List<XFile> photos;
  final ValueChanged<XFile>? onRemove;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: photos
          .map(
            (photo) => _PhotoThumbnail(
              photo: photo,
              onRemove: onRemove,
            ),
          )
          .toList(),
    );
  }
}

class _PhotoThumbnail extends StatefulWidget {
  const _PhotoThumbnail({
    required this.photo,
    required this.onRemove,
  });

  final XFile photo;
  final ValueChanged<XFile>? onRemove;

  @override
  State<_PhotoThumbnail> createState() => _PhotoThumbnailState();
}

class _PhotoThumbnailState extends State<_PhotoThumbnail> {
  Uint8List? _bytes;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadBytes();
  }

  Future<void> _loadBytes() async {
    if (!kIsWeb) {
      return;
    }
    setState(() {
      _isLoading = true;
    });
    try {
      final data = await widget.photo.readAsBytes();
      if (!mounted) {
        return;
      }
      setState(() {
        _bytes = data;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageWidget = _buildImage(theme);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 96,
            height: 96,
            child: imageWidget,
          ),
        ),
        if (widget.onRemove != null)
          Positioned(
            top: -8,
            right: -8,
            child: IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.surface,
                foregroundColor: theme.colorScheme.error,
                padding: const EdgeInsets.all(4),
              ),
              tooltip: S.of(context).reviewModalRemovePhotoTooltip,
              onPressed: () => widget.onRemove?.call(widget.photo),
            ),
          ),
      ],
    );
  }

  Widget _buildImage(ThemeData theme) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            theme.colorScheme.primary,
          ),
        ),
      );
    }
    if (kIsWeb && _bytes != null) {
      return Image.memory(
        _bytes!,
        fit: BoxFit.cover,
      );
    }
    if (!kIsWeb) {
      final file = File(widget.photo.path);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
        );
      }
    }
    return Container(
      color: theme.colorScheme.surfaceVariant,
      alignment: Alignment.center,
      child: Icon(
        Icons.image_outlined,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
