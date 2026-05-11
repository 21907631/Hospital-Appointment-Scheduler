import { createContext, useContext, useEffect, useState } from 'react';
import { supabase, apiFetch } from '../lib/supabase.js';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [session, setSession] = useState(null);
  const [profile, setProfile] = useState(null);
  const [loading, setLoading] = useState(true);

  // Load current session on mount + subscribe to auth changes
  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session);
      if (data.session) loadProfile();
      else setLoading(false);
    });

    const { data: sub } = supabase.auth.onAuthStateChange((_event, session) => {
      setSession(session);
      if (session) loadProfile();
      else { setProfile(null); setLoading(false); }
    });

    return () => sub.subscription.unsubscribe();
  }, []);

  async function loadProfile() {
    try {
      const { user } = await apiFetch('/api/auth/me');
      setProfile(user);
    } catch (err) {
      console.error('Failed to load profile:', err);
      setProfile(null);
    } finally {
      setLoading(false);
    }
  }

  async function signUp({ email, password, fullName, role }) {
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: { full_name: fullName, role }, // → raw_user_meta_data → trigger fills profiles
      },
    });
    if (error) throw error;
    return data;
  }

  async function signIn({ email, password }) {
    const { data, error } = await supabase.auth.signInWithPassword({ email, password });
    if (error) throw error;
    return data;
  }

  async function signOut() {
    await supabase.auth.signOut();
  }

  const value = {
    session,
    profile,
    role: profile?.role || null,
    loading,
    signUp,
    signIn,
    signOut,
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used inside <AuthProvider>');
  return ctx;
}
