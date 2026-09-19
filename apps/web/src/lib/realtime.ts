import { createClient } from "@supabase/supabase-js";

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

export function subscribeToSession(
    sessionId: string,
    onUpdate: () => void
  ) {
    const channel = supabase
      .channel(`session-${sessionId}`)
      .on(
        "postgres_changes",
        {
          event: "*",
          schema: "public",
          table: "buy_ins",
          filter: `session_id=eq.${sessionId}`,
        },
        () => onUpdate()
      )
      .on(
        "postgres_changes",
        {
          event: "*",
          schema: "public",
          table: "session_players",
          filter: `session_id=eq.${sessionId}`,
        },
        () => onUpdate()
      )
      .on(
        "postgres_changes",
        {
          event: "*",
          schema: "public",
          table: "game_sessions",
          filter: `id=eq.${sessionId}`,
        },
        () => onUpdate()
      )
      .subscribe();
  
    return () => {
      supabase.removeChannel(channel);
    };
  }