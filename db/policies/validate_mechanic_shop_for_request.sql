-- Validate mechanic shop membership for a service request
-- Returns boolean true when mechanic is allowed to accept the request.
-- Raises P0001 on mismatch with a clear message compatible with existing code that expects a P0001.

CREATE OR REPLACE FUNCTION public.validate_mechanic_shop_for_request(
  p_request_id uuid,
  p_mechanic_user_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_request_shop_id uuid;
  v_mechanic_shop_id uuid;
BEGIN
  -- get canonical shop for request
  SELECT shop_id INTO v_request_shop_id
  FROM public.service_requests
  WHERE id = p_request_id;

  -- resolve mechanic's shop from multiple possible sources
  SELECT sp.shop_id INTO v_mechanic_shop_id
  FROM public.service_providers sp
  WHERE sp.user_id = p_mechanic_user_id
  LIMIT 1;

  IF v_mechanic_shop_id IS NULL THEN
    SELECT m.shop_id INTO v_mechanic_shop_id
    FROM public.mechanics m
    WHERE m.user_id = p_mechanic_user_id
    LIMIT 1;
  END IF;

  IF v_mechanic_shop_id IS NULL THEN
    SELECT sm.shop_id INTO v_mechanic_shop_id
    FROM public.shop_mechanics sm
    WHERE sm.mechanic_id = p_mechanic_user_id
      AND (sm.is_active IS TRUE OR sm.is_active IS NULL)
    LIMIT 1;
  END IF;

  -- If either side is null or mismatch, raise the same error used by the accept RPC
  IF v_request_shop_id IS NULL THEN
    RAISE EXCEPTION 'Shop isolation violation: request % has no shop_id', p_request_id USING ERRCODE = 'P0001';
  END IF;

  IF v_mechanic_shop_id IS NULL THEN
    RAISE EXCEPTION 'Shop isolation violation: mechanic % has no assigned shop', p_mechanic_user_id USING ERRCODE = 'P0001';
  END IF;

  IF v_mechanic_shop_id != v_request_shop_id THEN
    RAISE EXCEPTION 'Shop isolation violation: Mechanic % is not assigned to shop %', p_mechanic_user_id, v_request_shop_id USING ERRCODE = 'P0001';
  END IF;

  RETURN true;
END;
$$;

-- Grant execute to authenticated so client-side calls via RPC can use it
GRANT EXECUTE ON FUNCTION public.validate_mechanic_shop_for_request(uuid, uuid) TO authenticated;
