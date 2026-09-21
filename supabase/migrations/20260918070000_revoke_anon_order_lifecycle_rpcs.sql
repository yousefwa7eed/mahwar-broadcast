-- Migration: Revoke anonymous EXECUTE on order-lifecycle RPCs.
-- Date: 2026-09-18
--
-- H1 sub-fix 1. These RPCs mutate orders / ratings and are guarded by
-- `IF <id> <> auth.uid()`. Because the anon JWT has no `sub` claim,
-- auth.uid() is NULL for anonymous calls, and `x <> NULL` never raises.
-- Anonymous callers could cancel/confirm/price/reject/rate/assign orders.
--
-- Every function here loses PUBLIC + anon EXECUTE; authenticated and
-- service_role keep EXECUTE. The ownership-guard rewrite is H1 sub-fix 2.

REVOKE ALL ON FUNCTION public.owner_cancel_order(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.owner_cancel_order(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.owner_cancel_order(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.owner_confirm_price(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.owner_confirm_price(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.owner_confirm_price(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.owner_accept_price(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.owner_accept_price(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.owner_accept_price(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.owner_reject_price(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.owner_reject_price(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.owner_reject_price(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.rate_provider(uuid, integer, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.rate_provider(uuid, integer, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.rate_provider(uuid, integer, text) TO authenticated;

REVOKE ALL ON FUNCTION public.assign_order_to_provider(uuid, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.assign_order_to_provider(uuid, uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.assign_order_to_provider(uuid, uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.provider_reject_order(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.provider_reject_order(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.provider_reject_order(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.provider_complete_order(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.provider_complete_order(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.provider_complete_order(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.set_order_attachments(uuid, text[]) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.set_order_attachments(uuid, text[]) FROM anon;
GRANT EXECUTE ON FUNCTION public.set_order_attachments(uuid, text[]) TO authenticated;

REVOKE ALL ON FUNCTION public.provider_set_price(uuid, numeric) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.provider_set_price(uuid, numeric) FROM anon;
GRANT EXECUTE ON FUNCTION public.provider_set_price(uuid, numeric) TO authenticated;

REVOKE ALL ON FUNCTION public.provider_set_price(uuid, numeric, text, integer, text[]) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.provider_set_price(uuid, numeric, text, integer, text[]) FROM anon;
GRANT EXECUTE ON FUNCTION public.provider_set_price(uuid, numeric, text, integer, text[]) TO authenticated;