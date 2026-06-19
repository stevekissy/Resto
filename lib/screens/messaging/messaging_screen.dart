import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../../models/models.dart';

class MessagingScreen extends StatefulWidget {
  const MessagingScreen({super.key});

  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> {
  AppUser? _selectedContact; // null = group chat
  CallSession? _shownCall;   // appel entrant affiché dans le popup

  void _handleIncomingCall(AppProvider provider) {
    final call = provider.incomingCall;
    if (call != null && call.id != _shownCall?.id) {
      _shownCall = call;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => _IncomingCallDialog(
            call: call,
            onAnswer: () async {
              Navigator.pop(context);
              await provider.answerCall(call.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('📞 En communication avec ${call.callerName}'),
                    backgroundColor: AppTheme.success,
                    duration: const Duration(seconds: 30),
                    action: SnackBarAction(
                      label: 'Raccrocher',
                      textColor: Colors.white,
                      onPressed: () => provider.endCall(call.id),
                    ),
                  ),
                );
              }
            },
            onReject: () async {
              Navigator.pop(context);
              await provider.rejectCall(call.id);
              setState(() => _shownCall = null);
            },
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    // Détecter appel entrant
    _handleIncomingCall(provider);
    final otherUsers = provider.users.where((u) => u.id != provider.currentUser?.id).toList();

    return Row(
      children: [
        // Sidebar contacts
        Container(
          width: 220,
          decoration: BoxDecoration(
            color: AppTheme.surface,
            border: Border(right: BorderSide(color: const Color(0xFF2A2A5A))),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF2A2A5A)))),
                child: const Text('Messagerie', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              // Bouton Conférence Équipe
              _ConferenceButton(provider: provider),
              // Canal groupe
              GestureDetector(
                onTap: () => setState(() => _selectedContact = null),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _selectedContact == null ? AppTheme.primary.withValues(alpha: 0.15) : Colors.transparent,
                    border: Border(bottom: BorderSide(color: const Color(0xFF2A2A5A))),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.groups, color: AppTheme.primary, size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Équipe', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                          Text('Canal général', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Contacts individuels
              Expanded(
                child: ListView.builder(
                  itemCount: otherUsers.length,
                  itemBuilder: (context, i) {
                    final user = otherUsers[i];
                    final isSelected = _selectedContact?.id == user.id;
                    final unread = provider.getConversation(provider.currentUser?.id ?? '', user.id)
                      .where((m) => !m.isRead && m.senderId == user.id).length;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedContact = user),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primary.withValues(alpha: 0.15) : Colors.transparent,
                          border: Border(bottom: BorderSide(color: const Color(0xFF2A2A5A))),
                        ),
                        child: Row(
                          children: [
                            Stack(
                              children: [
                                Container(
                                  width: 40, height: 40,
                                  decoration: BoxDecoration(color: user.roleColor.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                                  child: Center(child: Text(user.name[0].toUpperCase(), style: TextStyle(color: user.roleColor, fontWeight: FontWeight.w800, fontSize: 16))),
                                ),
                                if (user.isOnline)
                                  Positioned(right: 0, bottom: 0, child: Container(width: 10, height: 10, decoration: BoxDecoration(color: AppTheme.success, shape: BoxShape.circle, border: Border.all(color: AppTheme.surface, width: 1.5)))),
                              ],
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(user.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                                  Text(user.roleLabel, style: TextStyle(color: user.roleColor, fontSize: 10)),
                                ],
                              ),
                            ),
                            if (unread > 0)
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                                child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        // Zone de chat
        Expanded(
          child: ChatArea(
            contact: _selectedContact,
            provider: provider,
          ),
        ),
      ],
    );
  }
}

// =================== BOUTON CONFÉRENCE ===================
class _ConferenceButton extends StatelessWidget {
  final AppProvider provider;
  const _ConferenceButton({required this.provider});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openConference(context),
      child: Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primary, const Color(0xFF1976D2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 3))],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_add, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Conférence Équipe', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  void _openConference(BuildContext context) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => TeamConferenceScreen(provider: provider),
    ));
  }
}

// =================== ÉCRAN CONFÉRENCE ===================
class TeamConferenceScreen extends StatefulWidget {
  final AppProvider provider;
  const TeamConferenceScreen({super.key, required this.provider});

  @override
  State<TeamConferenceScreen> createState() => _TeamConferenceScreenState();
}

class _TeamConferenceScreenState extends State<TeamConferenceScreen> {
  bool _isConferenceActive = false;
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  final Set<String> _mutedParticipants = {};
  Timer? _callTimer;
  int _callSeconds = 0;
  String? _conferenceCallId;

  @override
  void dispose() {
    _callTimer?.cancel();
    if (_isConferenceActive && _conferenceCallId != null) {
      widget.provider.endCall(_conferenceCallId!).catchError((_) {});
    }
    super.dispose();
  }

  Future<void> _startConference() async {
    try {
      final callId = await widget.provider.initiateCall(
        calleeId: '',
        calleeName: '',
        isConference: true,
      );
      setState(() {
        _isConferenceActive = true;
        _callSeconds = 0;
        _conferenceCallId = callId;
      });
      _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _callSeconds++);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur conférence: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _endConference() async {
    _callTimer?.cancel();
    if (_conferenceCallId != null) {
      await widget.provider.endCall(_conferenceCallId!).catchError((_) {});
    }
    setState(() {
      _isConferenceActive = false;
      _callSeconds = 0;
      _isMuted = false;
      _isSpeakerOn = true;
      _mutedParticipants.clear();
      _conferenceCallId = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conférence terminée'), backgroundColor: AppTheme.error),
      );
      Navigator.pop(context);
    }
  }

  String get _callDuration {
    final m = _callSeconds ~/ 60;
    final s = _callSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final users = widget.provider.users;
    final currentUser = widget.provider.currentUser;
    final participants = users; // Tous les membres de l'équipe

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A2E),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Conférence Vocale Équipe', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text(
              _isConferenceActive ? 'En cours • $_callDuration' : 'SANKADIOKRO • ${participants.length} membres',
              style: TextStyle(
                fontSize: 12,
                color: _isConferenceActive ? AppTheme.success : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isConferenceActive ? null : () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Barre d'état conférence
          if (_isConferenceActive)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.15),
                border: Border(bottom: BorderSide(color: AppTheme.success.withValues(alpha: 0.3))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.fiber_manual_record, color: AppTheme.success, size: 10),
                  const SizedBox(width: 6),
                  Text('Conférence active • $_callDuration', style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.w700, fontSize: 13)),
                ],
              ),
            ),
          // Grille des participants
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Participants', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.1,
                      ),
                      itemCount: participants.length,
                      itemBuilder: (context, i) {
                        final user = participants[i];
                        final isMe = user.id == currentUser?.id;
                        final isMuted = isMe ? _isMuted : _mutedParticipants.contains(user.id);
                        final isActive = _isConferenceActive;

                        return _ParticipantTile(
                          user: user,
                          isMe: isMe,
                          isMuted: isMuted,
                          isConferenceActive: isActive,
                          onMuteToggle: isMe
                            ? () => setState(() => _isMuted = !_isMuted)
                            : () => setState(() {
                                if (_mutedParticipants.contains(user.id)) {
                                  _mutedParticipants.remove(user.id);
                                } else {
                                  _mutedParticipants.add(user.id);
                                }
                              }),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Barre de contrôle
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D35),
              border: Border(top: BorderSide(color: const Color(0xFF2A2A5A))),
            ),
            child: _isConferenceActive
              ? _ActiveCallControls(
                  isMuted: _isMuted,
                  isSpeakerOn: _isSpeakerOn,
                  onMuteToggle: () => setState(() => _isMuted = !_isMuted),
                  onSpeakerToggle: () => setState(() => _isSpeakerOn = !_isSpeakerOn),
                  onEndCall: () => _endConference(),
                )
              : _StartCallButton(
                  participantCount: participants.length,
                  onStart: () => _startConference(),
                ),
          ),
        ],
      ),
    );
  }
}

// =================== TUILE PARTICIPANT ===================
class _ParticipantTile extends StatelessWidget {
  final AppUser user;
  final bool isMe;
  final bool isMuted;
  final bool isConferenceActive;
  final VoidCallback onMuteToggle;

  const _ParticipantTile({
    required this.user,
    required this.isMe,
    required this.isMuted,
    required this.isConferenceActive,
    required this.onMuteToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMe
            ? AppTheme.primary.withValues(alpha: 0.6)
            : isConferenceActive && !isMuted
              ? AppTheme.success.withValues(alpha: 0.3)
              : const Color(0xFF2A2A5A),
          width: isMe ? 2 : 1,
        ),
        boxShadow: isConferenceActive && !isMuted
          ? [BoxShadow(color: AppTheme.success.withValues(alpha: 0.15), blurRadius: 10, spreadRadius: 2)]
          : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Avatar
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: user.roleColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isConferenceActive && !isMuted ? AppTheme.success : Colors.transparent,
                    width: 2.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    user.name[0].toUpperCase(),
                    style: TextStyle(color: user.roleColor, fontWeight: FontWeight.w900, fontSize: 22),
                  ),
                ),
              ),
              if (isConferenceActive)
                Container(
                  width: 18, height: 18,
                  decoration: BoxDecoration(
                    color: isMuted ? AppTheme.error : AppTheme.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF0D0D35), width: 2),
                  ),
                  child: Icon(
                    isMuted ? Icons.mic_off : Icons.mic,
                    color: Colors.white, size: 10,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Nom
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              isMe ? '${user.name} (moi)' : user.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isMe ? AppTheme.primary : Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            user.roleLabel,
            style: TextStyle(color: user.roleColor, fontSize: 9),
          ),
          const SizedBox(height: 6),
          // Bouton micro (si conférence active)
          if (isConferenceActive)
            GestureDetector(
              onTap: onMuteToggle,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: isMuted ? AppTheme.error.withValues(alpha: 0.2) : AppTheme.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isMuted ? 'Muet' : 'Actif',
                  style: TextStyle(
                    color: isMuted ? AppTheme.error : AppTheme.success,
                    fontSize: 9, fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// =================== CONTRÔLES APPEL ACTIF ===================
class _ActiveCallControls extends StatelessWidget {
  final bool isMuted;
  final bool isSpeakerOn;
  final VoidCallback onMuteToggle;
  final VoidCallback onSpeakerToggle;
  final VoidCallback onEndCall;

  const _ActiveCallControls({
    required this.isMuted,
    required this.isSpeakerOn,
    required this.onMuteToggle,
    required this.onSpeakerToggle,
    required this.onEndCall,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _CallControl(
          icon: isMuted ? Icons.mic_off : Icons.mic,
          label: isMuted ? 'Activier\nMicro' : 'Couper\nMicro',
          color: isMuted ? AppTheme.error : AppTheme.success,
          onTap: onMuteToggle,
        ),
        // Bouton raccrocher (central, grand)
        GestureDetector(
          onTap: onEndCall,
          child: Container(
            width: 70, height: 70,
            decoration: BoxDecoration(
              color: AppTheme.error,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: AppTheme.error.withValues(alpha: 0.5), blurRadius: 16, spreadRadius: 2)],
            ),
            child: const Icon(Icons.call_end, color: Colors.white, size: 30),
          ),
        ),
        _CallControl(
          icon: isSpeakerOn ? Icons.volume_up : Icons.volume_off,
          label: isSpeakerOn ? 'Haut-\nParleur' : 'Oreillette',
          color: isSpeakerOn ? AppTheme.primary : AppTheme.textSecondary,
          onTap: onSpeakerToggle,
        ),
      ],
    );
  }
}

class _CallControl extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CallControl({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, textAlign: TextAlign.center, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// =================== BOUTON DÉMARRER ===================
class _StartCallButton extends StatelessWidget {
  final int participantCount;
  final VoidCallback onStart;

  const _StartCallButton({required this.participantCount, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Démarrer une conférence avec tous les $participantCount membres',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: onStart,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppTheme.primary, const Color(0xFF1976D2)]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.5), blurRadius: 16, offset: const Offset(0, 4))],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.call, color: Colors.white, size: 24),
                SizedBox(width: 12),
                Text('Lancer la Conférence', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// =================== ZONE DE CHAT ===================
class ChatArea extends StatefulWidget {
  final AppUser? contact;
  final AppProvider provider;

  const ChatArea({super.key, this.contact, required this.provider});

  @override
  State<ChatArea> createState() => _ChatAreaState();
}

class _ChatAreaState extends State<ChatArea> {
  final _messageCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _imagePicker = ImagePicker();
  bool _isCallActive = false;
  String? _activeCallId;

  @override
  void dispose() {
    // Terminer l'appel actif si l'utilisateur quitte l'écran
    if (_isCallActive && _activeCallId != null) {
      widget.provider.endCall(_activeCallId!).catchError((_) {});
    }
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _sendMessage(String content, MessageType type, {String? fileUrl, String? fileName}) {
    final msg = ChatMessage(
      id: const Uuid().v4(),
      senderId: widget.provider.currentUser?.id ?? '',
      senderName: widget.provider.currentUser?.name ?? '',
      receiverId: widget.contact?.id,
      content: content,
      type: type,
      fileUrl: fileUrl,
      fileName: fileName,
    );
    widget.provider.sendMessage(msg); // async fire-and-forget
    _messageCtrl.clear();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  void _pickImage() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      _sendMessage('📷 Photo partagée', MessageType.image, fileUrl: picked.path, fileName: 'photo.jpg');
    }
  }

  void _pickCamera() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.camera);
    if (picked != null) {
      _sendMessage('📷 Photo capturée', MessageType.image, fileUrl: picked.path, fileName: 'photo.jpg');
    }
  }

  Future<void> _startCall() async {
    if (_isCallActive && _activeCallId != null) {
      // Raccrocher
      try {
        await widget.provider.endCall(_activeCallId!);
      } catch (e) {
        debugPrint('[ChatArea] endCall error: $e');
      }
      setState(() { _isCallActive = false; _activeCallId = null; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Appel terminé'), duration: Duration(seconds: 2)),
        );
      }
      return;
    }

    // Initier l'appel
    if (widget.contact == null) {
      // Conférence de groupe — ouvre le panneau
      if (mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => TeamConferenceScreen(provider: widget.provider),
        );
      }
      return;
    }

    try {
      final callId = await widget.provider.initiateCall(
        calleeId: widget.contact!.id,
        calleeName: widget.contact!.name,
      );
      setState(() { _isCallActive = true; _activeCallId = callId; });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📞 Appel en cours avec ${widget.contact!.name}...'),
            backgroundColor: AppTheme.success,
            duration: const Duration(seconds: 30),
            action: SnackBarAction(
              label: 'Raccrocher',
              textColor: Colors.white,
              onPressed: () async {
                await widget.provider.endCall(callId);
                setState(() { _isCallActive = false; _activeCallId = null; });
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur appel: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  List<ChatMessage> get _messages {
    if (widget.contact == null) {
      return widget.provider.groupMessages;
    }
    return widget.provider.getConversation(widget.provider.currentUser?.id ?? '', widget.contact!.id);
  }

  @override
  Widget build(BuildContext context) {
    final msgs = _messages;
    final isGroup = widget.contact == null;

    return Column(
      children: [
        // En-tête chat
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            border: Border(bottom: BorderSide(color: const Color(0xFF2A2A5A))),
          ),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: isGroup ? AppTheme.primary.withValues(alpha: 0.2) : (widget.contact?.roleColor ?? AppTheme.primary).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: isGroup
                    ? const Icon(Icons.groups, color: AppTheme.primary)
                    : Text(widget.contact!.name[0].toUpperCase(),
                        style: TextStyle(color: widget.contact!.roleColor, fontWeight: FontWeight.w800, fontSize: 18)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isGroup ? 'Équipe SANKADIOKRO' : widget.contact!.name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                    Text(isGroup ? 'Tous les membres' : (widget.contact!.isOnline ? 'En ligne' : widget.contact!.roleLabel),
                      style: TextStyle(color: isGroup ? AppTheme.primary : (widget.contact!.isOnline ? AppTheme.success : AppTheme.textSecondary), fontSize: 11)),
                  ],
                ),
              ),
              // Bouton appel individuel (contacts) ou conférence (groupe)
              if (isGroup)
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => TeamConferenceScreen(provider: widget.provider),
                  )),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [AppTheme.primary, const Color(0xFF1976D2)]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.group_add, color: Colors.white, size: 16),
                        SizedBox(width: 4),
                        Text('Conférence', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                )
              else
                GestureDetector(
                  onTap: () => _startCall(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _isCallActive ? AppTheme.success.withValues(alpha: 0.2) : AppTheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _isCallActive ? Icons.call_end : Icons.call,
                      color: _isCallActive ? AppTheme.success : AppTheme.primary,
                      size: 18,
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Messages
        Expanded(
          child: msgs.isEmpty
            ? const EmptyState(icon: Icons.chat_bubble_outline, title: 'Aucun message', subtitle: 'Commencez la conversation')
            : ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(12),
                itemCount: msgs.length,
                itemBuilder: (context, i) => _MessageBubble(
                  message: msgs[i],
                  isMe: msgs[i].senderId == widget.provider.currentUser?.id,
                ),
              ),
        ),
        // Saisie message
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            border: Border(top: BorderSide(color: const Color(0xFF2A2A5A))),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: _pickCamera,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.camera_alt, color: AppTheme.primary, size: 18),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.attach_file, color: AppTheme.primary, size: 18),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _messageCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (text) {
                    if (text.trim().isNotEmpty) _sendMessage(text.trim(), MessageType.text);
                  },
                  decoration: InputDecoration(
                    hintText: 'Écrire un message...',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    fillColor: AppTheme.cardBg,
                    filled: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  if (_messageCtrl.text.trim().isNotEmpty) {
                    _sendMessage(_messageCtrl.text.trim(), MessageType.text);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.send, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =================== BULLE MESSAGE ===================
class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(
              width: 30, height: 30,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(color: AppTheme.primary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
              child: Center(child: Text(message.senderName.isNotEmpty ? message.senderName[0].toUpperCase() : '?',
                style: const TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w700))),
            ),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppTheme.primary : AppTheme.cardBg,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                  bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe) ...[
                    Text(message.senderName, style: const TextStyle(color: AppTheme.primary, fontSize: 10, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                  ],
                  if (message.type == MessageType.image)
                    Row(children: [
                      const Icon(Icons.image, color: Colors.white70, size: 16),
                      const SizedBox(width: 6),
                      Text(message.content, style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ])
                  else if (message.type == MessageType.file)
                    Row(children: [
                      const Icon(Icons.attach_file, color: Colors.white70, size: 16),
                      const SizedBox(width: 6),
                      Expanded(child: Text(message.fileName ?? message.content, style: const TextStyle(color: Colors.white, fontSize: 13))),
                    ])
                  else
                    Text(message.content, style: const TextStyle(color: Colors.white, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    '${message.sentAt.hour.toString().padLeft(2, '0')}:${message.sentAt.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(color: isMe ? Colors.white.withValues(alpha: 0.7) : AppTheme.textSecondary, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  POPUP APPEL ENTRANT
// ════════════════════════════════════════════════════════════════════════════

class _IncomingCallDialog extends StatelessWidget {
  final CallSession call;
  final VoidCallback onAnswer;
  final VoidCallback onReject;

  const _IncomingCallDialog({
    required this.call,
    required this.onAnswer,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icône appel entrant animée
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.success, width: 2),
            ),
            child: const Icon(Icons.call_received, color: AppTheme.success, size: 36),
          ),
          const SizedBox(height: 16),
          const Text(
            'Appel entrant',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            call.callerName,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          if (call.isConference)
            const Text(
              'Conférence d\'équipe',
              style: TextStyle(color: AppTheme.primary, fontSize: 12),
            ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Refuser
              GestureDetector(
                onTap: onReject,
                child: Column(
                  children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: AppTheme.error.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.error),
                      ),
                      child: const Icon(Icons.call_end, color: AppTheme.error, size: 26),
                    ),
                    const SizedBox(height: 6),
                    const Text('Refuser', style: TextStyle(color: AppTheme.error, fontSize: 12)),
                  ],
                ),
              ),
              // Décrocher
              GestureDetector(
                onTap: onAnswer,
                child: Column(
                  children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: AppTheme.success.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.success),
                      ),
                      child: const Icon(Icons.call, color: AppTheme.success, size: 26),
                    ),
                    const SizedBox(height: 6),
                    const Text('Décrocher', style: TextStyle(color: AppTheme.success, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
