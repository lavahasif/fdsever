import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../shared/widgets/category_segmented_bar.dart';
import '../../auto_trail/providers/auto_trail_provider.dart';
import '../../auto_trail/screens/auto_trail_screen.dart';
import '../../call_recorder/providers/call_recorder_provider.dart';
import '../../call_recorder/screens/call_recorder_screen.dart';
import '../../focus_guard/providers/focus_guard_provider.dart';
import '../../focus_guard/screens/focus_guard_hub_screen.dart';
import '../../notes/providers/notes_provider.dart';
import '../../notes/screens/notes_screen.dart';
import '../../tutorials/providers/tutorials_provider.dart';
import '../../tutorials/screens/tutorials_screen.dart';

class WorkspaceHubScreen extends StatefulWidget {
  final int initialSubIndex;

  const WorkspaceHubScreen({super.key, this.initialSubIndex = 0});

  @override
  State<WorkspaceHubScreen> createState() => _WorkspaceHubScreenState();
}

class _WorkspaceHubScreenState extends State<WorkspaceHubScreen> {
  late int _selectedSubIndex;

  @override
  void initState() {
    super.initState();
    _selectedSubIndex = widget.initialSubIndex;
  }

  @override
  void didUpdateWidget(covariant WorkspaceHubScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSubIndex != widget.initialSubIndex) {
      _selectedSubIndex = widget.initialSubIndex;
    }
  }

  @override
  Widget build(BuildContext context) {
    final notes = context.watch<NotesProvider>();
    final tutorials = context.watch<TutorialsProvider>();
    final autoTrail = context.watch<AutoTrailProvider>();
    final focusGuard = context.watch<FocusGuardProvider>();
    final callRecorder = context.watch<CallRecorderProvider>();

    final tabs = [
      CategoryTabItem(
        title: 'Notes & KB',
        icon: LucideIcons.notebookPen,
        badgeText: notes.notes.isNotEmpty ? '${notes.notes.length}' : null,
      ),
      CategoryTabItem(
        title: 'Tutorials & Docs',
        icon: LucideIcons.bookOpen,
        badgeText: tutorials.tutorials.isNotEmpty ? '${tutorials.tutorials.length}' : null,
      ),
      CategoryTabItem(
        title: 'Auto Trail',
        icon: LucideIcons.navigation,
        badgeText: autoTrail.isServiceRunning ? 'Active' : (autoTrail.points.isNotEmpty ? '${autoTrail.points.length}' : null),
      ),
      CategoryTabItem(
        title: 'Focus Guard',
        icon: LucideIcons.shieldAlert,
        badgeText: focusGuard.isLockActive ? 'Locked' : (focusGuard.temptationsResisted > 0 ? '${focusGuard.temptationsResisted}' : null),
        showActiveDot: focusGuard.isLockActive,
      ),
      CategoryTabItem(
        title: 'Call Recorder',
        icon: LucideIcons.phoneCall,
        badgeText: callRecorder.isRecording ? 'REC' : (callRecorder.recordings.isNotEmpty ? '${callRecorder.recordings.length}' : null),
        showActiveDot: callRecorder.isRecording,
      ),
    ];

    Widget body;
    switch (_selectedSubIndex) {
      case 4:
        body = const CallRecorderScreen();
        break;
      case 3:
        body = const FocusGuardHubScreen();
        break;
      case 2:
        body = const AutoTrailScreen();
        break;
      case 1:
        body = const TutorialsScreen();
        break;
      case 0:
      default:
        body = const NotesScreen();
        break;
    }

    return Column(
      children: [
        CategorySegmentedBar(
          tabs: tabs,
          selectedIndex: _selectedSubIndex,
          onTabSelected: (idx) => setState(() => _selectedSubIndex = idx),
        ),
        Expanded(child: body),
      ],
    );
  }
}
