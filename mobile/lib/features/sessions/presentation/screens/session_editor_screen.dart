import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../../core/resources/app_icons.dart';
import '../../../../core/resources/app_sizes.dart';
import '../../../../core/resources/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_icon.dart';
import '../../../../core/widgets/jbb_button.dart';
import '../../models/session_model.dart';
import '../providers/session_provider.dart';

/// Single unified create/edit screen for a bookable session — replaces the
/// old split Programs/Membership Prices/Class Schedule Times admin UI.
class SessionEditorScreen extends ConsumerStatefulWidget {
  const SessionEditorScreen({super.key, this.session});
  final SessionModel? session;
  @override
  ConsumerState<SessionEditorScreen> createState() => _SessionEditorState();
}

class _EditorSlot {
  _EditorSlot({this.startTime, this.endTime});
  TimeOfDay? startTime;
  TimeOfDay? endTime;
}

class _SessionEditorState extends ConsumerState<SessionEditorScreen> {
  final form = GlobalKey<FormState>();
  late final id = widget.session?.id ?? ref.read(sessionRepositoryProvider).newId();
  late final title = TextEditingController(text: widget.session?.title);
  late final description = TextEditingController(text: widget.session?.description);
  late final price = TextEditingController(
    text: widget.session != null ? widget.session!.price.toString() : '',
  );
  late final maxParticipants = TextEditingController(
    text: widget.session != null ? '${widget.session!.maxParticipants}' : '',
  );
  late String imageUrl = widget.session?.images.firstOrNull ?? '';
  late String type = widget.session?.type ?? 'individual';
  DateTime? startDate, endDate;
  late final List<_EditorSlot> timeSlots;
  bool busy = false, photoBusy = false;

  @override
  void initState() {
    super.initState();
    final s = widget.session;
    if (s != null) {
      startDate = s.startDate;
      endDate = s.endDate;
      if (s.timeSlots.isNotEmpty) {
        timeSlots = s.timeSlots
            .map((slot) => _EditorSlot(
                  startTime: _parseTime(slot.startTime),
                  endTime: _parseTime(slot.endTime),
                ))
            .toList();
      } else if (s.startTime.isNotEmpty && s.endTime.isNotEmpty) {
        timeSlots = [
          _EditorSlot(
            startTime: _parseTime(s.startTime),
            endTime: _parseTime(s.endTime),
          )
        ];
      } else {
        timeSlots = [_EditorSlot()];
      }
    } else {
      timeSlots = [_EditorSlot()];
    }
  }

  TimeOfDay? _parseTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]), m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    price.dispose();
    maxParticipants.dispose();
    super.dispose();
  }

  Future<void> pickPhoto() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (image == null) return;
    setState(() => photoBusy = true);
    try {
      final url = await ref
          .read(sessionRepositoryProvider)
          .uploadImage(id, File(image.path));
      if (mounted) setState(() => imageUrl = url);
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => photoBusy = false);
    }
  }

  Future<void> pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? startDate : endDate) ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 730)),
    );
    if (picked != null) {
      setState(() => isStart ? startDate = picked : endDate = picked);
    }
  }

  Future<void> pickSlotTime({required int index, required bool isStart}) async {
    final slot = timeSlots[index];
    final picked = await showTimePicker(
      context: context,
      initialTime: (isStart ? slot.startTime : slot.endTime) ??
          const TimeOfDay(hour: 16, minute: 0),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          slot.startTime = picked;
        } else {
          slot.endTime = picked;
        }
      });
    }
  }

  Future<void> save() async {
    final validSlots = timeSlots
        .where((s) => s.startTime != null && s.endTime != null)
        .map((s) => {
              'startTime': _fmtTime(s.startTime!),
              'endTime': _fmtTime(s.endTime!),
            })
        .toList();

    if (!form.currentState!.validate() ||
        startDate == null ||
        endDate == null ||
        validSlots.isEmpty) {
      showMessage(context, AppStrings.uiPickDate);
      return;
    }
    setState(() => busy = true);
    try {
      await ref.read(sessionRepositoryProvider).save(id, {
        'title': title.text.trim(),
        'description': description.text.trim(),
        'price': double.parse(price.text),
        'images': imageUrl.isEmpty ? <String>[] : [imageUrl],
        'type': type,
        'startDate': startDate,
        'endDate': endDate,
        'timeSlots': validSlots,
        'startTime': validSlots.first['startTime'],
        'endTime': validSlots.first['endTime'],
        'maxParticipants': int.parse(maxParticipants.text),
        'joinedUserIds': widget.session?.joinedUserIds ?? <String>[],
      });
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }


  Future<void> delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.uiDeleteSession),
        content: Text('Remove "${title.text}" from the home page.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => busy = true);
    try {
      await ref.read(sessionRepositoryProvider).delete(id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showMessage(context, friendlyError(e));
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.session == null ? AppStrings.addSession : AppStrings.uiEditSession),
      actions: [
        if (widget.session != null)
          IconButton(onPressed: busy ? null : delete, icon: const AppIcon(AppIcons.trash)),
      ],
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSizes.s24),
      child: Form(
        key: form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: GestureDetector(
                onTap: photoBusy ? null : pickPhoto,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: double.infinity,
                      height: 160,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppSizes.radius12),
                        color: context.palette.accentTint,
                        image: imageUrl.isNotEmpty
                            ? DecorationImage(
                                image: CachedNetworkImageProvider(imageUrl),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: imageUrl.isEmpty
                          ? const Center(child: AppIcon(AppIcons.imagePlus, size: 36))
                          : null,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(AppSizes.s8),
                      child: CircleAvatar(
                        radius: 15,
                        child: photoBusy
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const AppIcon(AppIcons.imagePlus, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSizes.s20),
            TextFormField(
              controller: title,
              decoration: const InputDecoration(labelText: AppStrings.title),
              validator: Validators.required,
            ),
            const SizedBox(height: AppSizes.s16),
            TextFormField(
              controller: description,
              decoration: const InputDecoration(labelText: AppStrings.descriptionOptional),
              maxLines: 2,
            ),
            const SizedBox(height: AppSizes.s16),
            TextFormField(
              controller: price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: AppStrings.uiPrice),
              validator: (v) => double.tryParse(v ?? '') != null ? null : 'Enter a valid price',
            ),
            const SizedBox(height: AppSizes.s16),
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: const InputDecoration(labelText: AppStrings.uiSessionType),
              items: const [
                DropdownMenuItem(value: 'individual', child: Text(AppStrings.uiIndividual)),
                DropdownMenuItem(value: 'duo', child: Text(AppStrings.uiDuo)),
                DropdownMenuItem(value: 'team', child: Text(AppStrings.uiTeam)),
              ],
              onChanged: (v) => setState(() => type = v ?? 'individual'),
            ),
            const SizedBox(height: AppSizes.s16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(AppStrings.uiStartDate),
              subtitle: Text(
                startDate == null ? AppStrings.uiPickDate : DateFormat('EEE, MMM d, yyyy').format(startDate!),
              ),
              trailing: const AppIcon(AppIcons.calendar),
              onTap: () => pickDate(isStart: true),
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(AppStrings.uiEndDate),
              subtitle: Text(
                endDate == null ? AppStrings.uiPickDate : DateFormat('EEE, MMM d, yyyy').format(endDate!),
              ),
              trailing: const AppIcon(AppIcons.calendar),
              onTap: () => pickDate(isStart: false),
            ),
            const SizedBox(height: AppSizes.s20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Session Timings (${timeSlots.length})',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: AppSizes.font14,
                    color: context.palette.textPrimary,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => timeSlots.add(_EditorSlot())),
                  icon: const AppIcon(AppIcons.plus, size: 16),
                  label: const Text('Add Time'),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.s8),
            ...List.generate(timeSlots.length, (index) {
              final slot = timeSlots[index];
              return Container(
                margin: const EdgeInsets.only(bottom: AppSizes.s12),
                padding: const EdgeInsets.all(AppSizes.s12),
                decoration: BoxDecoration(
                  color: context.palette.surface,
                  borderRadius: BorderRadius.circular(AppSizes.radius8),
                  border: Border.all(color: context.palette.separator),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Time ${index + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: AppSizes.font12,
                            color: context.palette.accent,
                          ),
                        ),
                        if (timeSlots.length > 1)
                          IconButton(
                            icon: const AppIcon(AppIcons.trash, size: 16),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => setState(() => timeSlots.removeAt(index)),
                          ),
                      ],
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(AppStrings.startTime),
                      subtitle: Text(
                        slot.startTime == null ? AppStrings.uiPickDate : _fmtTime(slot.startTime!),
                      ),
                      trailing: const AppIcon(AppIcons.clock),
                      onTap: () => pickSlotTime(index: index, isStart: true),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(AppStrings.endTime),
                      subtitle: Text(
                        slot.endTime == null ? AppStrings.chooseEndTime : _fmtTime(slot.endTime!),
                      ),
                      trailing: const AppIcon(AppIcons.clock),
                      onTap: () => pickSlotTime(index: index, isStart: false),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: AppSizes.s16),
            TextFormField(
              controller: maxParticipants,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: AppStrings.uiMaxParticipants),
              validator: (v) =>
                  int.tryParse(v ?? '') != null && int.parse(v!) > 0 ? null : 'Enter a valid number',
            ),
            const SizedBox(height: AppSizes.s28),
            JbbButton(label: AppStrings.addSession, busy: busy, onPressed: save),
          ],
        ),
      ),
    ),
  );
}
