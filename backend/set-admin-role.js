const admin = require('firebase-admin');
const serviceAccount = require('./service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

// Update to match your test user email
const userEmail = 'testuser@dropcity.com';

async function setAdminRole() {
  try {
    console.log(`\n🔍 Finding user: ${userEmail}`);
    
    // Get user by email
    const user = await admin.auth().getUserByEmail(userEmail);
    console.log(`✓ Found user: ${user.uid}`);

    // Set custom claim for admin role
    await admin.auth().setCustomUserClaims(user.uid, { role: 'admin' });
    console.log(`✓ Admin role assigned!`);

    console.log(`\n📝 Next steps:`);
    console.log(`1. Run: node get-token.js`);
    console.log(`2. Get the new token (must refresh to include role claim)`);
    console.log(`3. Use that token in Postman`);
    console.log(`\n`);
    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error.message);
    console.error('\n💡 Tips:');
    console.error('   - Check that user email is correct');
    console.error('   - Check service-account.json exists');
    console.error('   - Verify user exists in Firebase Console');
    process.exit(1);
  }
}

setAdminRole();
