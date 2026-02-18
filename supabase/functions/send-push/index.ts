import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { createClient } from 'jsr:@supabase/supabase-js@2';

Deno.serve(async (req) => {
  const { record } = await req.json(); // notification row from webhook

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  );

  const { data: profile } = await supabase
    .from('profiles')
    .select('push_token')
    .eq('id', record.recipient_id)
    .single();

  if (!profile?.push_token) {
    return new Response(JSON.stringify({ skipped: true }), { status: 200 });
  }

  const pushResponse = await fetch('https://exp.host/--/api/v2/push/send', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      to: profile.push_token,
      title: record.title,
      body: record.body,
      data: { appointmentId: record.appointment_id },
    }),
  });

  const result = await pushResponse.json();
  return new Response(JSON.stringify(result), { status: 200 });
});
