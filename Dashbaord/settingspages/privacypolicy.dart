import 'package:dating_app/themesfolder/theme.dart';
import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy Policy',
              // titles use bodyMedium
              style: AppTheme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            _para(
              'At The PairUp, your privacy is important to us. This Privacy Policy outlines how we collect, use, '
                  'and safeguard your personal information when you visit our website and use our services. By using our website, '
                  'you consent to the data practices described in this policy.',
            ),

            const SizedBox(height: 24),
            _title('1. Information We Collect'),
            const SizedBox(height: 8),
            _para('We collect various types of information to provide and enhance our services, including:'),
            const SizedBox(height: 8),
            _bullet('Personal Information: When you create an account or interact with our services, we may collect information such as your name, email address, phone number, and profile information.'),
            _bullet('Usage Information: We gather information about how you access and use our website, such as your IP address, browser type, pages viewed, and time spent on the site.'),
            _bullet('Cookies and Tracking Technologies: We use cookies and similar technologies to collect information about your browsing activities to improve your experience and analyze site usage.'),

            const SizedBox(height: 24),
            _title('2. How We Use Your Information'),
            const SizedBox(height: 8),
            _para('We utilize the information collected for various purposes, including:'),
            const SizedBox(height: 8),
            _bullet('To Provide Services: To create, manage, and provide you with our services, including user account management and matchmaking features.'),
            _bullet('Improvement and Personalization: To analyze usage patterns and enhance our website and services based on user preferences.'),
            _bullet('Communication: To send you updates, newsletters, marketing materials, and respond to your inquiries.'),
            _bullet('Security: To prevent fraudulent activities and protect the integrity and security of our services.'),

            const SizedBox(height: 24),
            _title('3. Sharing Your Information'),
            const SizedBox(height: 8),
            _para('We do not sell or rent your personal data to third parties. However, we may share your information in the following situations:'),
            _bullet('Service Providers: We may employ third-party companies and individuals to facilitate our services, perform services on our behalf, or assist us in analyzing how our services are used. They will have access to your personal information only to perform these tasks and are obligated not to disclose or use it for any other purpose.'),
            _bullet('Legal Requirements: We may disclose your personal information if required to do so by law or in response to valid requests by public authorities.'),

            const SizedBox(height: 24),
            _title('4. Data Security'),
            const SizedBox(height: 8),
            _para(
              'We are committed to protecting your personal information. We use various security measures, including encryption and access '
                  'controls, to safeguard your data from unauthorized access. However, no method of transmission over the Internet or method of '
                  'electronic storage is 100% secure.',
            ),

            const SizedBox(height: 24),
            _title('5. Your Choices and Rights'),
            const SizedBox(height: 8),
            _para('You have options regarding your personal data:'),
            _bullet('Access and Update: You can access and update your account information through your profile settings.'),
            _bullet('Marketing Communications: You can opt-out of receiving promotional emails from us by following the instructions included in each email or contacting us directly.'),
            _bullet('Cookies: You can manage your cookie preferences through your browser settings.'),

            const SizedBox(height: 24),
            _title('6. Third-Party Links'),
            const SizedBox(height: 8),
            _para(
              'Our website may contain links to third-party websites. We are not responsible for the privacy practices of these sites. '
                  'We encourage you to review the privacy policies of any third-party sites you visit.',
            ),

            const SizedBox(height: 24),
            _title('7. Children’s Privacy'),
            const SizedBox(height: 8),
            _para(
              'The PairUp website is not intended for individuals under the age of 18. We do not knowingly collect personal information from children. '
                  'If we become aware that we have collected personal information from a child, we will take steps to delete that information.',
            ),

            const SizedBox(height: 24),
            _title('8. Changes to This Privacy Policy'),
            const SizedBox(height: 8),
            _para(
              'We may update this Privacy Policy from time to time. Changes will be posted on this page with an updated effective date. '
                  'We encourage you to review this Privacy Policy periodically for any changes.',
            ),

            const SizedBox(height: 24),
            _title('9. Contact Us'),
            const SizedBox(height: 8),
            _para(
              'If you have any questions, concerns, or requests regarding this Privacy Policy or our data practices, please contact us at:',
            ),

            // Email line
            const SizedBox(height: 8),
            _inlineLabelValue(label: 'Email', value: 'support@thepairup.com'),

            // Address label + non-editable field
            const SizedBox(height: 16),
            _title('Address'),
            const SizedBox(height: 8),
            _addressField(),

            const SizedBox(height: 24),
            Text(
              'Thank you for trusting The PairUp with your personal information!',
              style: AppTheme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  // ===== Helpers (styles per your spec) =====

  /// Titles/headings -> bodyMedium
  static Widget _title(String text) {
    return Text(
      text,
      style: AppTheme.textTheme.bodyMedium,
    );
  }

  /// Paragraph text -> titleMedium
  static Widget _para(String text) {
    return Text(
      text,
      style: AppTheme.textTheme.titleMedium,
    );
  }

  /// Bullet item -> titleMedium, with a leading bullet
  static Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•  ', style: AppTheme.textTheme.titleMedium),
          Expanded(child: Text(text, style: AppTheme.textTheme.titleMedium)),
        ],
      ),
    );
  }

  /// "Email: value" inline row.
  static Widget _inlineLabelValue({required String label, required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ', style: AppTheme.textTheme.bodyMedium),
        Expanded(child: SelectableText(value, style: AppTheme.textTheme.titleMedium)),
      ],
    );
  }

  /// Address input field styled to match the Figma look (rounded, filled)
  /// Now prefilled, non-editable, and non-clickable.
  static Widget _addressField() {
    const String addressText = '10304 Eaton Place Suite 100 Fairfax, VA, US 22030';

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.black26, width: 1),
    );

    // Keep normal enabled styling but block all interaction.
    return IgnorePointer(
      ignoring: true,
      child: TextField(
        controller: TextEditingController(text: addressText),
        readOnly: true,
        enableInteractiveSelection: false,
        style: AppTheme.textTheme.titleMedium,
        decoration: InputDecoration(
          hintText: addressText,
          hintStyle: AppTheme.textTheme.titleMedium?.copyWith(color: Colors.black87),
          filled: true,
          fillColor: const Color(0xFFFFEFEF),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: const BorderSide(color: Colors.black54, width: 1.2),
          ),
        ),
      ),
    );
  }
}
