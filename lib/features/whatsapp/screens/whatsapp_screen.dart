import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../providers/whatsapp_provider.dart';

class WhatsAppScreen extends StatefulWidget {
  const WhatsAppScreen({super.key});

  @override
  State<WhatsAppScreen> createState() => _WhatsAppScreenState();
}

class _WhatsAppScreenState extends State<WhatsAppScreen> {
  late final TextEditingController _phoneController;
  late final TextEditingController _messageController;

  @override
  void initState() {
    super.initState();
    final provider = context.read<WhatsAppProvider>();
    _phoneController = TextEditingController(text: provider.phoneNumber);
    _messageController = TextEditingController(text: provider.message);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final waProvider = context.watch<WhatsAppProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text('WhatsApp Direct Message', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(
            'Initiate direct WhatsApp & WhatsApp Business chats without saving the number in contacts.',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          ),

          const SizedBox(height: 20),

          // Main Form Card
          ShadCard(
            title: const Text('Compose Direct Message'),
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Phone input
                  const Text('Phone Number', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ShadInput(
                          controller: _phoneController,
                          placeholder: const Text('e.g. 919876543210'),
                          keyboardType: TextInputType.phone,
                          onChanged: (val) => waProvider.setPhoneNumber(val.trim()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ShadButton.outline(
                        onPressed: () async {
                          final data = await Clipboard.getData(Clipboard.kTextPlain);
                          if (data?.text != null) {
                            final clean = data!.text!.replaceAll(RegExp(r'[^0-9]'), '');
                            _phoneController.text = clean;
                            waProvider.setPhoneNumber(clean);
                          }
                        },
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.clipboard, size: 14),
                            SizedBox(width: 4),
                            Text('Paste'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ShadButton.ghost(
                        onPressed: () {
                          _phoneController.clear();
                          waProvider.setPhoneNumber('');
                        },
                        child: const Icon(LucideIcons.x, size: 16),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Country Code Quick Prepend
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildPrefixChip('+91 (IN)', '91'),
                      _buildPrefixChip('+1 (US)', '1'),
                      _buildPrefixChip('+44 (UK)', '44'),
                      _buildPrefixChip('+971 (UAE)', '971'),
                      _buildPrefixChip('+966 (KSA)', '966'),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Message textarea
                  const Text('Message (Optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  ShadInput(
                    controller: _messageController,
                    placeholder: const Text('Type your message here...'),
                    maxLines: 4,
                    minLines: 2,
                    onChanged: (val) => waProvider.setMessage(val),
                  ),

                  const SizedBox(height: 10),

                  // Message Templates
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildTemplateChip('Hi there!'),
                      _buildTemplateChip('Here is the link for our meeting.'),
                      _buildTemplateChip('Please share the document.'),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Launch Actions
                  Row(
                    children: [
                      ShadButton(
                        onPressed: waProvider.isLoading
                            ? null
                            : () => waProvider.launchChat(tryNative: true),
                        backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                        foregroundColor: Colors.white,
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.messageCircle, size: 16),
                            SizedBox(width: 8),
                            Text('Open WhatsApp'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ShadButton.outline(
                        onPressed: waProvider.isLoading
                            ? null
                            : () => waProvider.launchChat(tryNative: false),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.globe, size: 16),
                            SizedBox(width: 8),
                            Text('Open via Web (wa.me)'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Recent Numbers History
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent Numbers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              if (waProvider.recentNumbers.isNotEmpty)
                ShadButton.ghost(
                  size: ShadButtonSize.sm,
                  onPressed: () => waProvider.clearHistory(),
                  child: const Text('Clear History'),
                ),
            ],
          ),
          const SizedBox(height: 12),

          if (waProvider.recentNumbers.isEmpty)
            ShadCard(
              padding: const EdgeInsets.all(20),
              child: const Center(
                child: Text('No recent numbers yet. Numbers you chat with will appear here for fast re-use.', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ShadCard(
              padding: const EdgeInsets.all(8),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: waProvider.recentNumbers.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final number = waProvider.recentNumbers[index];
                  return ListTile(
                    dense: true,
                    leading: const Icon(LucideIcons.phoneCall, size: 18, color: Color(0xFF25D366)),
                    title: Text(number, style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        ShadButton.ghost(
                          size: ShadButtonSize.sm,
                          onPressed: () {
                            _phoneController.text = number;
                            waProvider.setPhoneNumber(number);
                          },
                          child: const Text('Use'),
                        ),
                        ShadButton.ghost(
                          size: ShadButtonSize.sm,
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: number));
                            ShadToaster.of(context).show(
                              ShadToast(
                                title: const Text('Number Copied'),
                                description: Text(number),
                              ),
                            );
                          },
                          child: const Icon(LucideIcons.copy, size: 14),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPrefixChip(String label, String prefix) {
    return ShadButton.outline(
      size: ShadButtonSize.sm,
      onPressed: () {
        context.read<WhatsAppProvider>().appendCountryCode(prefix);
        _phoneController.text = context.read<WhatsAppProvider>().phoneNumber;
      },
      child: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }

  Widget _buildTemplateChip(String text) {
    return ShadButton.ghost(
      size: ShadButtonSize.sm,
      onPressed: () {
        _messageController.text = text;
        context.read<WhatsAppProvider>().setMessage(text);
      },
      child: Text('"$text"', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
    );
  }
}
