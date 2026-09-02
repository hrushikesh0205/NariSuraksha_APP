/// Nari Suraksha — Core Widget Library
///
/// Import this single file to access the entire reusable widget library:
///
/// ```dart
/// import 'package:nari_suraksha/core/widgets/widgets.dart';
/// ```
///
/// ## Buttons
/// - [PrimaryButton]   — full-width filled CTA button
/// - [SecondaryButton] — outlined alternate-action button
/// - [DangerButton]    — filled error-colour button for SOS / destructive actions
///
/// ## Inputs
/// - [CustomTextField] — themed text input with validation support
/// - [PasswordField]   — password input with animated show/hide toggle
///
/// ## Cards
/// - [FeatureCard] — icon + title + subtitle tappable card
/// - [StatusCard]  — accent-striped semantic status card (success/warning/error/info/neutral)
///
/// ## Layout / Chrome
/// - [SectionHeader]     — section label row with optional action link
/// - [CustomAppBar]      — [PreferredSizeWidget] AppBar with auto back-button
/// - [GradientBackground]— gradient container (brand or surface variant)
///
/// ## Feedback / State
/// - [LoadingWidget]    — centred spinner with optional message + overlay factory
/// - [EmptyStateWidget] — zero-state icon + title + optional CTA
///
/// ## Misc
/// - [CircularAvatarWidget] — image → initials → icon cascade with badge support
/// - [ConfirmationDialog]   — M3 AlertDialog with danger mode + static `.show()`
/// - [BottomActionSheet]    — modal bottom sheet with action list + static `.show()`

library;

export 'primary_button.dart';
export 'secondary_button.dart';
export 'danger_button.dart';
export 'custom_text_field.dart';
export 'password_field.dart';
export 'feature_card.dart';
export 'status_card.dart';
export 'section_header.dart';
export 'custom_app_bar.dart';
export 'loading_widget.dart';
export 'empty_state_widget.dart';
export 'gradient_background.dart';
export 'circular_avatar_widget.dart';
export 'confirmation_dialog.dart';
export 'bottom_action_sheet.dart';
export 'sos_success_sheet.dart';
export 'safety_check_sheet.dart';
