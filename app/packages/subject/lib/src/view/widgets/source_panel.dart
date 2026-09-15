import 'package:app_ui/app_ui.dart' hide Overlay;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:subject/subject.dart';

/// {@template source_panel}
/// Panel for uploading and viewing a subject's source PDFs.
/// {@endtemplate}
class SourcePanel extends StatelessWidget {
  /// {@macro source_panel}
  const SourcePanel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SourceCubit, SourceState>(
      builder: (context, state) {
        if (state.isUploading) {
          return const _LoadingState();
        }

        if (!state.hasSources) {
          return _EmptyState(
            errorMessage: state.errorMessage,
          );
        }

        return _SourcesState(
          sources: state.sources,
          selectedSource: state.selectedSource,
          errorMessage: state.errorMessage,
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.errorMessage});

  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppButton(
            text: 'Upload File',
            onPressed: () async {
              await context.read<SourceCubit>().pickAndUpload();
            },
          ),
          if (errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                errorMessage!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _SourcesState extends StatelessWidget {
  const _SourcesState({
    required this.sources,
    required this.selectedSource,
    this.errorMessage,
  });

  final List<Source> sources;
  final Source? selectedSource;
  final String? errorMessage;

  Future<void> _handlePdfTap(BuildContext context, TapUpDetails details) async {
    final cubit = context.read<SourceCubit>();
    final overlay = await showOverlayDialog(context, details.localPosition);
    if (overlay == null) return;

    await cubit.addOverlay(
      x: overlay.position.dx,
      y: overlay.position.dy,
      text: overlay.text,
      color: overlay.color,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SourceTabs(
          sources: sources,
          selectedSourceId: selectedSource?.id,
        ),
        if (errorMessage != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              errorMessage!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        Expanded(
          child: selectedSource != null
              ? _PdfViewerWithOverlays(
                  source: selectedSource!,
                  onTap: (details) => _handlePdfTap(context, details),
                )
              : const Center(child: Text('Select a source')),
        ),
      ],
    );
  }
}

class _PdfViewerWithOverlays extends StatelessWidget {
  const _PdfViewerWithOverlays({
    required this.source,
    required this.onTap,
  });

  final Source source;
  final GestureTapUpCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTapUp: onTap,
            behavior: HitTestBehavior.translucent,
            child: PdfViewer.uri(
              Uri.parse(source.url),
              params: const PdfViewerParams(
                enableTextSelection: true,
              ),
            ),
          ),
        ),
        ...source.overlays.map((overlay) {
          return Positioned(
            left: overlay.x,
            top: overlay.y,
            child: _OverlayBadge(overlay: overlay),
          );
        }),
      ],
    );
  }
}

class _OverlayBadge extends StatelessWidget {
  const _OverlayBadge({required this.overlay});

  final Overlay overlay;

  Color _parseColor(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _parseColor(overlay.color).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: _parseColor(overlay.color),
        ),
      ),
      child: Text(
        overlay.text,
        style: TextStyle(
          color: _parseColor(overlay.color),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SourceTabs extends StatelessWidget {
  const _SourceTabs({
    required this.sources,
    required this.selectedSourceId,
  });

  final List<Source> sources;
  final String? selectedSourceId;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: sources.length + 1,
        separatorBuilder: (_, _) => const VerticalDivider(width: 1),
        itemBuilder: (context, index) {
          if (index == sources.length) {
            return _AddSourceButton(
              onPressed: () async {
                await context.read<SourceCubit>().pickAndUpload();
              },
            );
          }

          final source = sources[index];
          final isSelected = source.id == selectedSourceId;

          return _SourceTab(
            label: source.name,
            isSelected: isSelected,
            onTap: () async {
              await context.read<SourceCubit>().selectSource(source.id);
            },
          );
        },
      ),
    );
  }
}

class _SourceTab extends StatelessWidget {
  const _SourceTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected
                  ? theme.colorScheme.primary
                  : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface,
            fontWeight:
                isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _AddSourceButton extends StatelessWidget {
  const _AddSourceButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Data returned from the overlay creation dialog.
class OverlayInput {
  /// {@macro overlay_input}
  const OverlayInput({
    required this.position,
    required this.text,
    required this.color,
  });

  /// Position where the overlay was tapped.
  final Offset position;

  /// Text for the overlay.
  final String text;

  /// Color of the overlay, as a hex string.
  final String color;
}

/// Shows a dialog to create a new overlay.
Future<OverlayInput?> showOverlayDialog(
  BuildContext context,
  Offset position,
) {
  return showDialog<OverlayInput>(
    context: context,
    builder: (context) => _OverlayDialog(position: position),
  );
}

class _OverlayDialog extends StatefulWidget {
  const _OverlayDialog({required this.position});

  final Offset position;

  @override
  State<_OverlayDialog> createState() => _OverlayDialogState();
}

class _OverlayDialogState extends State<_OverlayDialog> {
  final _controller = TextEditingController();
  String _selectedColor = '#FF0000';

  final _colors = const {
    'Red': '#FF0000',
    'Yellow': '#FFCC00',
    'Green': '#00AA00',
    'Blue': '#0066FF',
  };

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add note'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            decoration: const InputDecoration(hintText: 'Your note'),
            autofocus: true,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: _colors.entries.map((entry) {
              final isSelected = entry.value == _selectedColor;
              return ChoiceChip(
                label: Text(entry.key),
                selected: isSelected,
                selectedColor: _parseColor(entry.value).withValues(alpha: 0.3),
                onSelected: (_) {
                  setState(() {
                    _selectedColor = entry.value;
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final text = _controller.text.trim();
            if (text.isEmpty) return;

            Navigator.of(context).pop(
              OverlayInput(
                position: widget.position,
                text: text,
                color: _selectedColor,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }

  Color _parseColor(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}
