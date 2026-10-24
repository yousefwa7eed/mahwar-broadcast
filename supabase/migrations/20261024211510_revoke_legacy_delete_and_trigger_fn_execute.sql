-- delete_user_account(): دالة قديمة تحذف الحساب وطلباته بجلسة فقط وبلا كلمة سر، فتتجاوز حماية delete-account v17. الحذف الفعلي يمر بدالة الحافة.
revoke execute on function public.delete_user_account() from public, anon, authenticated;
revoke execute on function public.provider_availability_snapshot(uuid) from public, anon;
revoke execute on function public.enforce_provider_online_requires_verified_phone() from public, anon, authenticated;
revoke execute on function public.sync_phone_verified_from_auth() from public, anon, authenticated;
