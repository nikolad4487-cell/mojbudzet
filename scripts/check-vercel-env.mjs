// Vercel must never publish an unconfigured sign-in screen or a secret API key.
if (process.env.VERCEL === '1') {
  const url = process.env.VITE_SUPABASE_URL
  const key = process.env.VITE_SUPABASE_PUBLISHABLE_KEY
  if (!url || !key) {
    throw new Error('Vercel: postavite VITE_SUPABASE_URL i VITE_SUPABASE_PUBLISHABLE_KEY u Settings > Environment Variables za odabrano okruženje, zatim ponovite deployment.')
  }
  const parsed = new URL(url)
  if (parsed.protocol !== 'https:' || parsed.username || parsed.password) {
    throw new Error('VITE_SUPABASE_URL mora biti HTTPS URL bez korisničkih podataka.')
  }
  let legacyRole
  try { legacyRole = JSON.parse(Buffer.from(key.split('.')[1], 'base64url').toString()).role } catch {}
  if (!key.startsWith('sb_publishable_') && legacyRole !== 'anon') {
    throw new Error('VITE_SUPABASE_PUBLISHABLE_KEY smije sadržavati samo publishable ili legacy anon ključ. Secret/service-role ključ nije dopušten u pregledniku.')
  }
}
