const { createClient } = require("@supabase/supabase-js");
const config = require("./config");

let client;

function getSupabase() {
  if (!client) {
    if (!config.supabaseUrl || !config.supabaseServiceRoleKey) {
      console.error(
        "Supabase configuration missing. Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in .env"
      );
      return null;
    }
    
    client = createClient(config.supabaseUrl, config.supabaseServiceRoleKey, {
      auth: { persistSession: false }
    });
  }
  return client;
}

module.exports = {
  getSupabase
};
