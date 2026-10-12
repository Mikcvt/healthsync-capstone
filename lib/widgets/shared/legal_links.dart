import 'package:flutter/material.dart';
import '../../constants/app_strings.dart';
import '../../services/link_service.dart';
import '../../utils/snackbar_helper.dart';

/// Opens the Terms of Service or Privacy Policy, telling the user the address
/// if no browser could open it.
Future<void> openLegalPage(BuildContext context, {required bool privacy}) async {
  final url = privacy ? AppStrings.privacyUrl : AppStrings.termsUrl;
  final opened = await LinkService().open(url);
  if (!opened && context.mounted) {
    SnackbarHelper.showError(context, 'Could not open the page. Visit $url');
  }
}
