-- Migration: create cash_payment_verifications table

CREATE TABLE public.cash_payment_verifications (
  id uuid not null default gen_random_uuid(),
  invoice_id uuid not null,
  payment_id uuid not null,
  request_id uuid not null,
  customer_id uuid not null,
  mechanic_id uuid not null,
  cash_amount numeric not null,
  receipt_photo_url text not null,
  cash_photo_url text not null,
  verification_status text null default 'pending'::text,
  verified_by uuid null,
  verified_at timestamp with time zone null,
  verification_notes text null,
  location_latitude numeric null,
  location_longitude numeric null,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  constraint cash_payment_verifications_pkey primary key (id),
  constraint cash_payment_verifications_invoice_id_fkey foreign KEY (invoice_id) references invoices (id),
  constraint cash_payment_verifications_mechanic_id_fkey foreign KEY (mechanic_id) references user_profiles (id),
  constraint cash_payment_verifications_payment_id_fkey foreign KEY (payment_id) references payments (id),
  constraint cash_payment_verifications_request_id_fkey foreign KEY (request_id) references service_requests (id),
  constraint cash_payment_verifications_verified_by_fkey foreign KEY (verified_by) references auth.users (id),
  constraint cash_payment_verifications_customer_id_fkey foreign KEY (customer_id) references user_profiles (id),
  constraint cash_payment_verifications_verification_status_check check (
    (
      verification_status = any (
        array[
          'pending'::text,
          'verified'::text,
          'rejected'::text,
          'disputed'::text
        ]
      )
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_cash_payment_verifications_invoice_id on public.cash_payment_verifications using btree (invoice_id) TABLESPACE pg_default;

create index IF not exists idx_cash_payment_verifications_status on public.cash_payment_verifications using btree (verification_status) TABLESPACE pg_default;
