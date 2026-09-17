import 'package:flutter/material.dart';

import '../models/creation_project.dart';
import '../services/creation_project_store.dart';
import '../services/creation_publish_service.dart';
import '../services/creation_validation_service.dart';

class CreationPostComposerScreen extends StatefulWidget {
  const CreationPostComposerScreen({super.key, required this.project});
  final CreationProject project;
  @override
  State<CreationPostComposerScreen> createState() => _CreationPostComposerScreenState();
}

class _CreationPostComposerScreenState extends State<CreationPostComposerScreen> {
  late CreationProject _project;
  late final TextEditingController _captionController;
  bool _publishing = false;
  bool _saving = false;
  bool _allowComments = true;
  bool _recommend = true;
  bool _copyrightConfirmed = false;
  bool _aiGeneratedDisclosure = false;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
    _captionController = TextEditingController(text: _project.caption);
    final state = _project.publishState;
    _allowComments = state['allowComments'] is bool ? state['allowComments'] as bool : true;
    _recommend = state['recommend'] is bool ? state['recommend'] as bool : _project.privacy == 'Public';
    _copyrightConfirmed = _project.rights['copyrightConfirmed'] == true;
    _aiGeneratedDisclosure = _project.rights['aiGeneratedDisclosure'] == true;
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _save({bool showFeedback = true}) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      _project = _project.copyWith(
        status: CreationProjectStatus.autosaved,
        caption: _captionController.text.trim(),
        updatedAt: DateTime.now(),
        publishState: <String, dynamic>{..._project.publishState, 'allowComments': _allowComments, 'recommend': _recommend, 'composerSavedAt': DateTime.now().toIso8601String()},
        rights: <String, dynamic>{..._project.rights, 'copyrightConfirmed': _copyrightConfirmed, 'aiGeneratedDisclosure': _aiGeneratedDisclosure},
      );
      await CreationProjectStore.instance.save(_project);
      if (showFeedback && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post settings saved to draft.')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _chooseAudience() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.fromLTRB(8, 8, 8, 10), child: Text('Audience', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)))),
            ...const <String>['Public', 'Followers', 'Only Me'].map((value) => ListTile(leading: const Icon(Icons.visibility_outlined), title: Text(value), trailing: null, onTap: () => Navigator.pop(sheetContext, value))),
          ]),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _project = _project.copyWith(privacy: selected);
      if (selected != 'Public') _recommend = false;
    });
    await _save(showFeedback: false);
  }

  Future<void> _publish() async {
    if (_publishing) return;
    setState(() => _publishing = true);
    try {
      _project = _project.copyWith(
        status: CreationProjectStatus.ready,
        caption: _captionController.text.trim(),
        publishState: <String, dynamic>{..._project.publishState, 'allowComments': _allowComments, 'recommend': _recommend},
        rights: <String, dynamic>{..._project.rights, 'copyrightConfirmed': _copyrightConfirmed, 'aiGeneratedDisclosure': _aiGeneratedDisclosure},
      );
      await CreationProjectStore.instance.save(_project);

      final validation = await CreationValidationService.validateProject(_project, requirePublishRights: true);
      if (!validation.isValid) throw CreationPublishException(validation.message);

      final result = await CreationPublishService().publish(_project);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(result.isProcessing ? 'Upload queued' : 'Published successfully'),
          content: Text(result.isProcessing ? 'Your video is uploaded and queued for processing. It will appear in Show after the media pipeline marks it ready.\nPost ID: ${result.postId}' : 'Your post is live.\nPost ID: ${result.postId}'),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Done'))],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error is CreationPublishException ? error.message : 'Publishing failed: $error')));
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaCount = _project.mediaAssets.length;
    final singleVideo = mediaCount == 1 && _project.mediaAssets.first.type == 'video';
    final canPublish = !_publishing && !_saving && singleVideo && _copyrightConfirmed;
    final captionReady = _captionController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      appBar: AppBar(backgroundColor: Colors.white, surfaceTintColor: Colors.transparent, elevation: 0, title: const Text('Post', style: TextStyle(fontWeight: FontWeight.w800)), actions: [TextButton(onPressed: _saving ? null : () => _save(), child: const Text('Draft', style: TextStyle(fontWeight: FontWeight.w700)))]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _SectionCard(title: 'Caption', child: TextField(controller: _captionController, maxLength: 2200, minLines: 4, maxLines: 8, textCapitalization: TextCapitalization.sentences, onChanged: (_) => setState(() {}), decoration: InputDecoration(hintText: 'Write a caption…', filled: true, fillColor: const Color(0xFFF3F4F6), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)))),
          const SizedBox(height: 12),
          _SectionCard(title: 'Audience', child: ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.visibility_outlined), title: Text(_project.privacy, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: const Text('Choose who can see this post.'), trailing: const Icon(Icons.chevron_right_rounded), onTap: _chooseAudience)),
          const SizedBox(height: 12),
          _SectionCard(title: 'Engagement & recommendations', child: Column(children: [
            SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, value: _allowComments, title: const Text('Allow comments'), subtitle: const Text('People can comment on this post.'), onChanged: (value) { setState(() => _allowComments = value); _save(showFeedback: false); }),
            SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, value: _recommend, title: const Text('Allow recommendations'), subtitle: Text(_project.privacy == 'Public' ? 'Eligible for OJAS recommendation surfaces.' : 'Only public posts can enter recommendation surfaces.'), onChanged: _project.privacy == 'Public' ? (value) { setState(() => _recommend = value); _save(showFeedback: false); } : null),
          ])),
          const SizedBox(height: 12),
          _SectionCard(title: 'Rights & transparency', child: Column(children: [
            CheckboxListTile(contentPadding: EdgeInsets.zero, value: _copyrightConfirmed, title: const Text('I have the rights to publish this media'), subtitle: const Text('Only confirm when you have permission or ownership.'), onChanged: (value) { setState(() => _copyrightConfirmed = value ?? false); _save(showFeedback: false); }),
            SwitchListTile.adaptive(contentPadding: EdgeInsets.zero, value: _aiGeneratedDisclosure, title: const Text('AI-generated or AI-assisted content'), subtitle: const Text('This disclosure is stored with the published post.'), onChanged: (value) { setState(() => _aiGeneratedDisclosure = value); _save(showFeedback: false); }),
          ])),
          const SizedBox(height: 12),
          _SectionCard(title: 'Publish checklist', child: Column(children: [
            _CheckRow(label: 'Media selected', value: mediaCount > 0),
            _CheckRow(label: 'Single video publish path', value: singleVideo),
            _CheckRow(label: 'Caption ready', value: captionReady),
            _CheckRow(label: 'Audience selected', value: _project.privacy.isNotEmpty),
            _CheckRow(label: 'Rights confirmed', value: _copyrightConfirmed),
          ])),
          const SizedBox(height: 18),
          SizedBox(width: double.infinity, height: 54, child: FilledButton.icon(onPressed: canPublish ? _publish : null, icon: _publishing ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.publish_rounded), label: Text(_publishing ? 'Publishing…' : 'Publish to OJAS'))),
          if (!canPublish) const Padding(padding: EdgeInsets.only(top: 10), child: Text('Confirm media rights before publishing. The verified production path currently accepts one video.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF6B7280), fontSize: 12, height: 1.35))),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(elevation: 0, color: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), child: Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), const SizedBox(height: 10), child])));
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.label, required this.value});
  final String label;
  final bool value;
  @override
  Widget build(BuildContext context) => ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(value ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: value ? const Color(0xFF16A34A) : const Color(0xFF9CA3AF)), title: Text(label));
}
