const { getSupabase } = require('./src/supabase');

const userEmail = 'testuser@dropcity.com';
const userUid = 'HBRDcy3YBUa6a2JcuS6V7WAUgea2'; // From the token

async function setRoleInSupabase() {
  try {
    const supabase = getSupabase();
    if (!supabase) {
      throw new Error('Supabase not configured');
    }

    console.log(`\n📋 Setting admin role in Supabase for: ${userEmail}`);
    console.log(`   UID: ${userUid}`);

    // Check if user record exists in public.users table
    const { data: existingUser, error: checkError } = await supabase
      .from('users')
      .select('id, role')
      .eq('id', userUid)
      .maybeSingle();

    if (checkError && checkError.code !== 'PGRST116') {
      throw checkError;
    }

    if (existingUser) {
      console.log(`   Current role: ${existingUser.role || 'none'}`);
    } else {
      console.log('   (Creating new user record)');
    }

    // Update or insert user with admin role
    const { data, error } = await supabase
      .from('users')
      .upsert({
        id: userUid,
        email: userEmail,
        role: 'admin'
      }, { onConflict: 'id' });

    if (error) {
      throw error;
    }

    console.log('\n✅ Admin role set in Supabase!');
    console.log('\n📋 Next step:');
    console.log('1. Get token: node get-token.js');
    console.log('2. Use in Postman with: Authorization: Bearer [token]');
    console.log('3. The API will now check Supabase for your role');
    console.log('\n');
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error.message);
    
    if (error.message.includes("Could not find the table")) {
      console.error('\n📝 The "users" table doesn\'t exist. Create it with this SQL:');
      console.error(`
CREATE TABLE IF NOT EXISTS public.users (
  id TEXT PRIMARY KEY,
  email TEXT UNIQUE NOT NULL,
  role TEXT DEFAULT 'user',
  created_at TIMESTAMP DEFAULT now(),
  updated_at TIMESTAMP DEFAULT now()
);

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Allow users to read their own data
CREATE POLICY "Users can read own data" ON public.users
  FOR SELECT USING (id = auth.uid()::text);

-- Allow service role to do everything
CREATE POLICY "Service role can do everything" ON public.users
  AS PERMISSIVE FOR ALL USING (true) WITH CHECK (true);
      `);
      console.error('\n1. Go to Supabase Console → SQL Editor');
      console.error('2. Paste the SQL above');
      console.error('3. Run it');
      console.error('4. Then run this script again');
    } else {
      console.error('\n💡 Make sure:');
      console.error('   - Backend is running (npm start)');
      console.error('   - .env file has Supabase credentials');
      console.error('   - "public.users" table exists in Supabase');
    }
    process.exit(1);
  }
}

setRoleInSupabase();
