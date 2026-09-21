import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../shared/widgets/category_segmented_bar.dart';
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
    ];

    Widget body;
    switch (_selectedSubIndex) {
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
