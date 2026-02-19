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

  // push_token stores the Web Push subscription JSON
  // { endpoint, keys: { p256dh, auth } }
  let subscription;
  try {
    subscription = JSON.parse(profile.push_token);
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid push token' }), { status: 400 });
  }

  if (!subscription?.endpoint) {
    return new Response(JSON.stringify({ skipped: true, reason: 'no endpoint' }), { status: 200 });
  }

  // Send Web Push notification
  // Uses the Web Push protocol with VAPID authentication
  // In production, implement VAPID signing or use a web-push library
  const payload = JSON.stringify({
    title: record.title,
    body: record.body,
    data: { appointmentId: record.appointment_id },
  });

  try {
    const pushResponse = await fetch(subscription.endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Encoding': 'aes128gcm',
        'TTL': '86400',
      },
      body: payload,
    });

    return new Response(
      JSON.stringify({ success: pushResponse.ok, status: pushResponse.status }),
      { status: 200 }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: String(error) }),
      { status: 500 }
    );
  }
});
