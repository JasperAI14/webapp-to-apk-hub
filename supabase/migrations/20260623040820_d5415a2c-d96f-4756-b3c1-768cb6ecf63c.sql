
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS premium_expires_at timestamptz;

CREATE OR REPLACE FUNCTION public.is_user_premium(_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = _user_id
      AND (is_premium = true OR (premium_expires_at IS NOT NULL AND premium_expires_at > now()))
  );
$$;

CREATE TABLE public.ai_images (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  prompt text NOT NULL,
  storage_path text NOT NULL,
  image_url text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ai_images_user_idx ON public.ai_images(user_id);
CREATE INDEX ai_images_created_idx ON public.ai_images(created_at DESC);

GRANT SELECT, INSERT, DELETE ON public.ai_images TO authenticated;
GRANT ALL ON public.ai_images TO service_role;

ALTER TABLE public.ai_images ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Premium users can view all AI images"
  ON public.ai_images FOR SELECT TO authenticated
  USING (public.is_user_premium(auth.uid()));

CREATE POLICY "Premium users can insert their own AI images"
  ON public.ai_images FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id AND public.is_user_premium(auth.uid()));

CREATE POLICY "Users can delete their own AI images"
  ON public.ai_images FOR DELETE TO authenticated
  USING (auth.uid() = user_id OR public.has_role(auth.uid(), 'admin'));

CREATE TABLE public.promo_codes (
  code text PRIMARY KEY,
  grant_type text NOT NULL CHECK (grant_type IN ('premium','trial')),
  trial_days integer,
  max_uses integer,
  uses integer NOT NULL DEFAULT 0,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT ON public.promo_codes TO authenticated;
GRANT ALL ON public.promo_codes TO service_role;

ALTER TABLE public.promo_codes ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.promo_redemptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  code text NOT NULL REFERENCES public.promo_codes(code) ON DELETE CASCADE,
  redeemed_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, code)
);
CREATE INDEX promo_redemptions_user_idx ON public.promo_redemptions(user_id);

GRANT SELECT ON public.promo_redemptions TO authenticated;
GRANT ALL ON public.promo_redemptions TO service_role;

ALTER TABLE public.promo_redemptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can see their own redemptions"
  ON public.promo_redemptions FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

INSERT INTO public.promo_codes (code, grant_type, trial_days, max_uses, active)
VALUES ('JASPER AI', 'premium', NULL, NULL, true)
ON CONFLICT (code) DO NOTHING;
