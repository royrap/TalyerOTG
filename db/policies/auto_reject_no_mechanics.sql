-- Optional: Auto-reject shop_based requests when there are no active/available mechanics for the selected shop
-- This trigger runs AFTER INSERT on service_requests and checks shop_based requests.
-- If no eligible mechanics are found, it updates the request.status to 'rejected' and sets broadcast_status to 'no_mechanics_available'
-- and inserts a notification for the customer (optional).

BEGIN;

DROP FUNCTION IF EXISTS public.fn_reject_if_no_mechanics();

CREATE OR REPLACE FUNCTION public.fn_reject_if_no_mechanics()
RETURNS trigger AS $$
DECLARE
    has_mechanic boolean;
BEGIN
    IF (TG_OP = 'INSERT') THEN
        IF (NEW.request_type = 'shop_based' AND NEW.shop_id IS NOT NULL) THEN
            SELECT EXISTS (
                SELECT 1 FROM public.shop_mechanics sm
                JOIN public.mechanic_availability_status mas ON sm.mechanic_id = mas.mechanic_id
                WHERE sm.shop_id = NEW.shop_id
                AND sm.is_active = true
                AND mas.current_status = 'available'
                AND mas.is_accepting_requests = true
            ) INTO has_mechanic;

            IF NOT has_mechanic THEN
                -- Update the request to rejected status
                UPDATE public.service_requests
                SET status = 'rejected', broadcast_status = 'no_mechanics_available', rejection_reason = 'No available mechanics in selected shop'
                WHERE id = NEW.id;

                -- Optional: insert a notification for the customer
                INSERT INTO public.notifications (user_id, title, body, data)
                VALUES (
                    NEW.customer_id,
                    'No available mechanics in your chosen shop',
                    'We could not find available mechanics in the shop you selected. Please try another shop or try again later.',
                    jsonb_build_object('request_id', NEW.id)
                );
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_reject_no_mechanics ON public.service_requests;
CREATE TRIGGER trg_reject_no_mechanics
    AFTER INSERT ON public.service_requests
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_reject_if_no_mechanics();

COMMIT;

-- Note: This trigger runs AFTER INSERT and updates the same row; if you use strict audit triggers or have other processes that expect to handle the INSERT atomically, consider converting this to a BEFORE INSERT trigger that raises an exception which the client can catch, or integrate the check into application-level create logic instead.
