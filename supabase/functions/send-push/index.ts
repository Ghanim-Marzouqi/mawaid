import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { createClient } from 'jsr:@supabase/supabase-js@2';
import webpush from 'npm:web-push@3';

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const vapidPublicKey = Deno.env.get('VAPID_PUBLIC_KEY')!;
const vapidPrivateKey = Deno.env.get('VAPID_PRIVATE_KEY')!;
const vapidSubject = Deno.env.get('VAPID_SUBJECT') || 'mailto:admin@mawaid.local';

webpush.setVapidDetails(vapidSubject, vapidPublicKey, vapidPrivateKey);

Deno.serve(async (req) => {
  const { record } = await req.json(); // notification row from webhook

  const supabase = createClient(supabaseUrl, supabaseServiceKey);

  const { data: profile } = await supabase
    .from('profiles')
    .select('push_token')
    .eq('id', record.recipient_id)
    .single();

  if (!profile?.push_token) {
    return new Response(JSON.stringify({ skipped: true }), { status: 200 });
  }

  let subscription: webpush.PushSubscription;
  try {
    subscription = JSON.parse(profile.push_token);
  } catch {
    return new Response(JSON.stringify({ error: 'Invalid push token' }), { status: 400 });
  }

  if (!subscription?.endpoint) {
    return new Response(
      JSON.stringify({ skipped: true, reason: 'no endpoint' }),
      { status: 200 },
    );
  }

  const payload = JSON.stringify({
    title: record.title,
    body: record.body,
    data: { appointmentId: record.appointment_id },
  });

  try {
    await webpush.sendNotification(subscription, payload);
    return new Response(JSON.stringify({ success: true }), { status: 200 });
  } catch (error: unknown) {
    const statusCode = (error as { statusCode?: number })?.statusCode;

    // 410 Gone — subscription expired, clear it from the profile.
    if (statusCode === 410) {
      await supabase
        .from('profiles')
        .update({ push_token: null })
        .eq('id', record.recipient_id);
      return new Response(
        JSON.stringify({ expired: true }),
        { status: 200 },
      );
    }

    return new Response(
      JSON.stringify({ error: String(error) }),
      { status: 500 },
    );
  }
});
