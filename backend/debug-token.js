const admin = require('firebase-admin');
const https = require('https');
const serviceAccount = require('./service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const webApiKey = 'AIzaSyCTeaqyq_hye5kaF34hXOs0dj8vKdhiuOM';
const userEmail = 'testuser@dropcity.com';
const userPassword = 'Cali8294!!!';

async function debugToken() {
  try {
    console.log('\n🔍 Step 1: Getting current token...');

    // Get current token
    const postData = JSON.stringify({
      email: userEmail,
      password: userPassword,
      returnSecureToken: true
    });

    const options = {
      hostname: 'identitytoolkit.googleapis.com',
      port: 443,
      path: `/v1/accounts:signInWithPassword?key=${webApiKey}`,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': postData.length
      }
    };

    const token = await new Promise((resolve, reject) => {
      const req = https.request(options, (res) => {
        let data = '';
        res.on('data', chunk => data += chunk);
        res.on('end', () => {
          try {
            const json = JSON.parse(data);
            if (json.error) {
              reject(new Error(json.error.message));
            } else {
              resolve(json.idToken);
            }
          } catch (e) {
            reject(e);
          }
        });
      });

      req.on('error', reject);
      req.write(postData);
      req.end();
    });

    // Decode token to see what's inside
    const parts = token.split('.');
    const decoded = JSON.parse(Buffer.from(parts[1], 'base64').toString('utf8'));
    
    console.log('\n📋 Current token claims:');
    console.log(JSON.stringify(decoded, null, 2));
    
    console.log('\n🔑 Looking for role in:');
    console.log('  - role:', decoded.role || 'NOT FOUND');
    console.log('  - roles:', decoded.roles || 'NOT FOUND');
    console.log('  - claims:', decoded.claims || 'NOT FOUND');
    console.log('  - custom_claims:', decoded.custom_claims || 'NOT FOUND');

    console.log('\n✅ Now setting admin role via custom claims...');
    
    const user = await admin.auth().getUserByEmail(userEmail);
    console.log(`   User UID: ${user.uid}`);
    
    await admin.auth().setCustomUserClaims(user.uid, { role: 'admin' });
    console.log('✓ Custom claim set in Firebase');

    console.log('\n⏳ Waiting 3 seconds for sync...');
    await new Promise(resolve => setTimeout(resolve, 3000));

    console.log('\n🔍 Step 2: Getting new token after role set...');

    const newToken = await new Promise((resolve, reject) => {
      const req = https.request(options, (res) => {
        let data = '';
        res.on('data', chunk => data += chunk);
        res.on('end', () => {
          try {
            const json = JSON.parse(data);
            if (json.error) {
              reject(new Error(json.error.message));
            } else {
              resolve(json.idToken);
            }
          } catch (e) {
            reject(e);
          }
        });
      });

      req.on('error', reject);
      req.write(postData);
      req.end();
    });

    const newParts = newToken.split('.');
    const newDecoded = JSON.parse(Buffer.from(newParts[1], 'base64').toString('utf8'));

    console.log('\n📋 New token claims:');
    console.log(JSON.stringify(newDecoded, null, 2));
    
    console.log('\n✅ NEW token has role?');
    console.log('  - role:', newDecoded.role || '❌ MISSING');
    console.log('  - custom_claims:', newDecoded.custom_claims || '❌ MISSING');

    if (newDecoded.role || (newDecoded.custom_claims && newDecoded.custom_claims.role)) {
      console.log('\n🎉 SUCCESS! Use this token:');
      console.log('\n' + newToken);
    } else {
      console.log('\n⚠️  Role not in token. Trying alternative approach...');
      console.log('   Setting role in Supabase instead...');
    }

    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

debugToken();
