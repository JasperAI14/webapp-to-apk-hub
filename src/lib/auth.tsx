import { createContext, useContext, useEffect, useState, type ReactNode } from "react";
import type { Session, User } from "@supabase/supabase-js";
import { supabase } from "@/integrations/supabase/client";

type AuthCtx = {
  user: User | null;
  session: Session | null;
  loading: boolean;
  signOut: () => Promise<void>;
};

const Ctx = createContext<AuthCtx>({ user: null, session: null, loading: true, signOut: async () => {} });

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Set up the listener for auth state changes
    const { data: subscription } = supabase.auth.onAuthStateChange((_event, newSession) => {
      console.log("[Auth] State changed:", _event, "Session:", newSession ? "present" : "null");
      setSession(newSession);
      setLoading(false);
    });

    // Also fetch current session on mount
    const fetchSession = async () => {
      try {
        const { data } = await supabase.auth.getSession();
        console.log("[Auth] Initial session fetch:", data.session ? "found" : "not found");
        setSession(data.session);
      } catch (err) {
        console.error("[Auth] Failed to fetch session:", err);
      } finally {
        setLoading(false);
      }
    };

    fetchSession();

    // Return cleanup function
    return () => {
      subscription?.subscription.unsubscribe();
    };
  }, []);

  return (
    <Ctx.Provider
      value={{
        user: session?.user ?? null,
        session,
        loading,
        signOut: async () => {
          await supabase.auth.signOut();
        },
      }}
    >
      {children}
    </Ctx.Provider>
  );
}

export const useAuth = () => useContext(Ctx);
