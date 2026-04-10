const https = require('https');

const webApiKey = 'AIzaSyCTeaqyq_hye5kaF34hXOs0dj8vKdhiuOM';

// Update these credentials
const email = 'testuser@dropcity.com';
const password = 'Cali8294!!!';

function getIdToken() {
  const postData = JSON.stringify({
    email,
    password,
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
}

getIdToken().then(token => {
  console.log('\n✓ ID Token Generated!');
  console.log('\n🔑 Token (copy this):');
  console.log(token);
  console.log('\n📋 In Postman:');
  console.log('1. Click "Authorization" tab');
  console.log('2. Type: Bearer ' + token.substring(0, 30) + '...');
  console.log('3. OR paste full token above');
  console.log('\n');
  process.exit(0);
}).catch(error => {
  console.error('❌ Error:', error.message);
  console.error('\n💡 Make sure this user exists in Firebase:');
  console.error('   Email:', email);
  console.error('   Password:', password);
  console.error('\n📝 If user doesn\'t exist, create it in Firebase Console or uncomment signUp code below');
  process.exit(1);
});