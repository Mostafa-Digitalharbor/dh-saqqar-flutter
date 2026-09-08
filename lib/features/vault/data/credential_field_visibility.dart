/// Which credential fields apply to which authentication mode.
///
/// Some schemas ship a select that decides what the *rest* of the form means.
/// `server_shell` is the clear case: it carries both `password` and
/// `private_key`, and exactly one of them is relevant depending on `auth`.
/// The server marks both optional and ships no mapping, so showing them both
/// asks the user to answer a question they have no way to resolve — and
/// invites them to fill the wrong one.
///
/// The web encodes the same rule in `wireAuthModeDependencies`. This is that
/// rule, as data rather than as DOM manipulation, so it can be read and
/// tested without a form on screen.
library;

/// The select fields that drive dependent visibility, most specific first.
///
/// `auth_type` is Odoo's and email's; `auth` is the SSH schema's. A schema
/// has at most one, so the first match wins.
const credentialAuthDriverFields = <String>['auth_type', 'auth'];

/// `<driver field>.<dependent field>` → the driver values it applies to.
///
/// A field absent from this map applies to every mode, which is the right
/// default: a new field the backend adds tomorrow must render, not vanish.
const _appliesToModes = <String, Set<String>>{
  // SSH: a password login and a key login want different secrets, and
  // submitting the one you did not mean is a failed connection with no
  // message explaining why.
  'auth.password': {'password'},
  'auth.private_key': {'key'},
};

/// Whether [fieldName] should be shown while [driverField] holds [mode].
///
/// [mode] being null means the form has no driver select at all (or has not
/// resolved it yet), and everything shows — hiding a field on a guess is
/// worse than showing one that turns out not to apply.
bool credentialFieldApplies({
  required String fieldName,
  required String? driverField,
  required String? mode,
}) {
  if (driverField == null || mode == null) return true;
  final modes = _appliesToModes['$driverField.$fieldName'];
  return modes == null || modes.contains(mode);
}
