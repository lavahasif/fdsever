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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text('WhatsApp Direct Message',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(
            'Open WhatsApp chats without saving numbers to contacts.',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),

          const SizedBox(height: 18),

          // Compose Card
          ShadCard(
            title: const Text('Compose Direct Message'),
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Phone input row
                  const Text('Phone Number',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ShadInput(
                          controller: _phoneController,
                          placeholder: const Text('e.g. 919876543210'),
                          keyboardType: TextInputType.phone,
                          onChanged: (v) => waProvider.setPhoneNumber(v.trim()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ShadButton.outline(
                        size: ShadButtonSize.sm,
                        onPressed: () async {
                          final data = await Clipboard.getData(Clipboard.kTextPlain);
                          if (data?.text != null) {
                            final clean =
                                data!.text!.replaceAll(RegExp(r'[^0-9]'), '');
                            _phoneController.text = clean;
                            waProvider.setPhoneNumber(clean);
                          }
                        },
                        child: const Icon(LucideIcons.clipboard, size: 14),
                      ),
                      const SizedBox(width: 4),
                      ShadButton.ghost(
                        size: ShadButtonSize.sm,
                        onPressed: () {
                          _phoneController.clear();
                          waProvider.setPhoneNumber('');
                        },
                        child: const Icon(LucideIcons.x, size: 15),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Country Code chips
                  const Text('Quick Country Code',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _prefixChip('+91 (IN)', '91'),
                      _prefixChip('+1 (US)', '1'),
                      _prefixChip('+44 (UK)', '44'),
                      _prefixChip('+971 (UAE)', '971'),
                      _prefixChip('+966 (KSA)', '966'),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Message input
                  const Text('Message (Optional)',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  ShadInput(
                    controller: _messageController,
                    placeholder: const Text('Type your message here...'),
                    maxLines: 4,
                    minLines: 2,
                    onChanged: (v) => waProvider.setMessage(v),
                  ),

                  const SizedBox(height: 8),

                  // Templates
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _templateChip('Hi there!'),
                      _templateChip('Here is the link for our meeting.'),
                      _templateChip('Please share the document.'),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Launch buttons — always Wrap
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ShadButton(
                        onPressed: waProvider.isLoading
                            ? null
                            : () => waProvider.launchChat(tryNative: true),
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.messageCircle, size: 15),
                            SizedBox(width: 8),
                            Text('Open WhatsApp'),
                          ],
                        ),
                      ),
                      ShadButton.outline(
                        onPressed: waProvider.isLoading
                            ? null
                            : () => waProvider.launchChat(tryNative: false),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.globe, size: 15),
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

          const SizedBox(height: 22),

          // Recent Numbers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent Numbers',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              if (waProvider.recentNumbers.isNotEmpty)
                ShadButton.ghost(
                  size: ShadButtonSize.sm,
                  onPressed: () => waProvider.clearHistory(),
                  child: const Text('Clear', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 10),

          if (waProvider.recentNumbers.isEmpty)
            ShadCard(
              padding: const EdgeInsets.all(20),
              child: const Center(
                child: Text(
                  'No recent numbers yet.\nNumbers you chat with appear here for fast re-use.',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ShadCard(
              padding: const EdgeInsets.all(6),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: waProvider.recentNumbers.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final number = waProvider.recentNumbers[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.phoneCall,
                            size: 17, color: Color(0xFF25D366)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(number,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                        ),
                        ShadButton.ghost(
                          size: ShadButtonSize.sm,
                          onPressed: () {
                            _phoneController.text = number;
                            waProvider.setPhoneNumber(number);
                          },
                          child:
                              const Text('Use', style: TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 4),
                        ShadButton.ghost(
                          size: ShadButtonSize.sm,
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: number));
                            ShadToaster.of(context).show(
                              ShadToast(
                                title: const Text('Copied'),
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

  Widget _prefixChip(String label, String prefix) {
    return ShadButton.outline(
      size: ShadButtonSize.sm,
      onPressed: () {
        context.read<WhatsAppProvider>().appendCountryCode(prefix);
        _phoneController.text = context.read<WhatsAppProvider>().phoneNumber;
      },
      child: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }

  Widget _templateChip(String text) {
    return ShadButton.ghost(
      size: ShadButtonSize.sm,
      onPressed: () {
        _messageController.text = text;
        context.read<WhatsAppProvider>().setMessage(text);
      },
      child: Text('"$text"',
          style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
    );
  }
}
