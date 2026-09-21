import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/tutorials_provider.dart';

class TutorialsScreen extends StatelessWidget {
  const TutorialsScreen({super.key});

  void _showAddDialog(BuildContext context) {
    final titleController = TextEditingController();
    final categoryController = TextEditingController(text: 'General');
    final descController = TextEditingController();
    final linkController = TextEditingController();

    showShadDialog(
      context: context,
      builder: (context) {
        return ShadDialog(
          title: const Text('Register Tutorial'),
          description: const Text('Add documentation, guide, or tutorial links for your reference.'),
          actions: [
            ShadButton.outline(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ShadButton(
              onPressed: () {
                if (titleController.text.trim().isEmpty) return;
                context.read<TutorialsProvider>().addTutorial(
                  title: titleController.text,
                  category: categoryController.text,
                  description: descController.text,
                  link: linkController.text,
                );
                Navigator.of(context).pop();
              },
              child: const Text('Save Tutorial'),
            ),
          ],
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Title', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                ShadInput(controller: titleController, placeholder: const Text('Tutorial Title...')),
                const SizedBox(height: 12),
                const Text('Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                ShadInput(controller: categoryController, placeholder: const Text('e.g. Server, Network, Flutter')),
                const SizedBox(height: 12),
                const Text('Description', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                ShadInput(controller: descController, placeholder: const Text('Brief summary of the tutorial...')),
                const SizedBox(height: 12),
                const Text('URL Link', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                ShadInput(controller: linkController, placeholder: const Text('https://...')),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tutsProvider = context.watch<TutorialsProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tutorials & Documentation',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text(
                      'Curated engineering tutorials, references, and network how-to guides.',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ShadButton(
                size: ShadButtonSize.sm,
                onPressed: () => _showAddDialog(context),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.plus, size: 14),
                    SizedBox(width: 6),
                    Text('Add Guide'),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Category Chips Filter
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tutsProvider.categories.map((cat) {
              final isSelected = tutsProvider.selectedCategory == cat;
              return isSelected
                  ? ShadButton(
                      size: ShadButtonSize.sm,
                      onPressed: () => tutsProvider.selectCategory(cat),
                      child: Text(cat),
                    )
                  : ShadButton.outline(
                      size: ShadButtonSize.sm,
                      onPressed: () => tutsProvider.selectCategory(cat),
                      child: Text(cat),
                    );
            }).toList(),
          ),

          const SizedBox(height: 18),

          // Tutorials List
          if (tutsProvider.tutorials.isEmpty)
            ShadCard(
              padding: const EdgeInsets.all(32),
              child: const Center(
                child: Text('No tutorials found in this category.',
                    style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: tutsProvider.tutorials.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final tut = tutsProvider.tutorials[index];
                return ShadCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(LucideIcons.bookMarked, color: Colors.blue, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(tut.title,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 15)),
                                ShadBadge.secondary(
                                  child: Text(tut.category, style: const TextStyle(fontSize: 10)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(tut.description,
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                            if (tut.link.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              ShadButton.outline(
                                size: ShadButtonSize.sm,
                                onPressed: () => launchUrl(
                                  Uri.parse(tut.link),
                                  mode: LaunchMode.externalApplication,
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(LucideIcons.externalLink, size: 12),
                                    SizedBox(width: 5),
                                    Text('Open Tutorial', style: TextStyle(fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ShadButton.ghost(
                        size: ShadButtonSize.sm,
                        onPressed: () => tutsProvider.deleteTutorial(tut.id),
                        child: const Icon(LucideIcons.trash2, size: 15, color: Colors.redAccent),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
