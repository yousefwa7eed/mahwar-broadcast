/// بُناة معاملات RPC فحص تفرّد رقم الهاتف.
///
/// These maps must match the exact PostgREST argument names of the SECURITY
/// DEFINER function in the database. PostgREST resolves an RPC by function
/// name + argument names, so a missing *required* argument makes the call fail
/// with `PGRST202 <function> not found` — even though the function exists.
///
/// Live signature (verified with `pg_get_function_arguments`):
///   is_phone_available(p_phone text)
///
/// The number is sent in its local 11-digit form (`01xxxxxxxxx`); the server
/// re-normalizes it and compares against BOTH `auth.users.phone` and
/// `profiles.phone_number`, excluding the caller's own account.
library;

Map<String, dynamic> buildIsPhoneAvailableParams({required String phone}) {
  return {'p_phone': phone};
}
