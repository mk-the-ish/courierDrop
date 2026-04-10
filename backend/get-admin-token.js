const admin = require('firebase-admin');
const https = require('https');
const serviceAccount = require('./service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const webApiKey = 'AIzaSyCTeaqyq_hye5kaF34hXOs0dj8vKdhiuOM';
const userEmail = 'testuser@dropcity.com';
const userPassword = 'Cali8294!!!';

async function getAdminToken() {
  try {
    console.log('\n📋 Step 1: Setting admin role...');
    
    // Get user by email and set admin role
    const user = await admin.auth().getUserByEmail(userEmail);
    await admin.auth().setCustomUserClaims(user.uid, { role: 'admin' });
    console.log(`✓ Admin role set for ${userEmail}`);

    // Wait a moment for Firebase to process
    console.log('\n⏳ Waiting for Firebase to sync (2 seconds)...');
    await new Promise(resolve => setTimeout(resolve, 2000));

    console.log('\n📋 Step 2: Getting fresh token with admin role...');

    // Now get a fresh ID token that includes the role claim
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

    return new Promise((resolve, reject) => {
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
  } catch (error) {
    console.error('❌ Error:', error.message);
    console.error('\n💡 Troubleshooting:');
    console.error('   - Verify service-account.json exists in backend directory');
    console.error('   - Check user email is correct: ' + userEmail);
    console.error('   - Check user exists in Firebase Console');
    console.error('   - Try refreshing Firebase Console if role was just set');
    process.exit(1);
  }
}

getAdminToken().then(token => {
  console.log('\n✓ Token generated with ADMIN role!');
  console.log('\n🔑 Copy this entire token:');
  console.log('\n' + token);
  console.log('\n\n📋 How to use in Postman:');
  console.log('1. Open any request (e.g., GET /admin/alerts/rules)');
  console.log('2. Click "Headers" tab');
  console.log('3. Add new header:');
  console.log('   Key: Authorization');
  console.log('   Value: Bearer [paste-token-above]');
  console.log('\n4. Click "Send" - it should work now!');
  console.log('\n');
  process.exit(0);
}).catch(error => {
  console.error(error.message);
  process.exit(1);
});
