-- RPC: Return canonical service_request payload including shop and customer details
-- Run this in Supabase SQL editor as admin

CREATE OR REPLACE FUNCTION public.get_service_request_payload(p_request_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE AS $$
DECLARE
  res jsonb;
BEGIN
  SELECT jsonb_build_object(
    'request_id', sr.id,
    'customer_id', sr.customer_id,
    'title', sr.title,
    'description', sr.description,
    'pickup_latitude', sr.pickup_latitude,
    'pickup_longitude', sr.pickup_longitude,
    'pickup_address', sr.pickup_address,
    'service_type', sr.service_type,
    'priority', sr.priority,
    'status', sr.status,
    'created_at', sr.created_at,
    'estimated_price', sr.estimated_price,
    'request_type', sr.request_type,
    'shop_id', sr.shop_id,
    'preferred_shop_id', sr.preferred_shop_id,
    'customer_first_name', up.first_name,
    'customer_last_name', up.last_name,
    'customer_phone', up.phone_number,
    'customer_profile_image', up.profile_image_url
  ) INTO res
  FROM public.service_requests sr
  LEFT JOIN public.user_profiles up ON sr.customer_id = up.id
  WHERE sr.id = p_request_id;

  RETURN res;
END;
$$;

-- Grant execute to authenticated
GRANT EXECUTE ON FUNCTION public.get_service_request_payload(uuid) TO authenticated;
