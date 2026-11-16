import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.46.1'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const json = (body: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (request.method !== 'POST') return json({ error: 'Only POST is supported.' }, 405)

  const authorization = request.headers.get('Authorization')
  if (!authorization?.startsWith('Bearer ')) {
    return json({ error: 'A signed-in user is required.' }, 401)
  }

  const url = Deno.env.get('SUPABASE_URL')
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? Deno.env.get('SUPABASE_PUBLISHABLE_KEY')
  if (!url || !anonKey) return json({ error: 'The export function is not configured.' }, 500)

  const client = createClient(url, anonKey, {
    global: { headers: { Authorization: authorization } },
  })
  const { data: userData, error: userError } = await client.auth.getUser()
  if (userError || !userData.user) return json({ error: 'Oturum doğrulanamadı.' }, 401)

  const { data, error } = await client.rpc('get_my_account_export')
  if (error || !data || typeof data !== 'object') {
    return json({ error: 'Hesap verileri hazırlanamadı.' }, 500)
  }

  return json({
    exported_at: new Date().toISOString(),
    account: {
      id: userData.user.id,
      email: userData.user.email ?? null,
      created_at: userData.user.created_at,
      email_confirmed_at: userData.user.email_confirmed_at ?? null,
      profile_name: {
        first_name: typeof userData.user.user_metadata?.first_name === 'string'
          ? userData.user.user_metadata.first_name
          : null,
        last_name: typeof userData.user.user_metadata?.last_name === 'string'
          ? userData.user.user_metadata.last_name
          : null,
      },
    },
    data,
  })
})
