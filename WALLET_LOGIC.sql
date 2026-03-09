-- Atomic Wallet Deduction
CREATE OR REPLACE FUNCTION deduct_wallet_balance(u_id UUID, amount NUMERIC)
RETURNS VOID AS $$
BEGIN
  UPDATE public.wallets
  SET balance = balance - amount,
      updated_at = NOW()
  WHERE user_id = u_id AND balance >= amount;
  
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Insufficient balance or user not found';
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to create wallet on profile creation
CREATE OR REPLACE FUNCTION public.handle_new_customer()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.wallets (user_id, balance)
  VALUES (new.id, 0);
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Check if trigger exists before creating
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_trigger WHERE tgname = 'on_customer_created_wallet') THEN
    CREATE TRIGGER on_customer_created_wallet
      AFTER INSERT ON public.customer_profiles
      FOR EACH ROW EXECUTE FUNCTION public.handle_new_customer();
  END IF;
END $$;
