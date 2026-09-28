/**
 * SmartBill Users Admin - Integration Test Suite
 */

const BASE_URL = 'http://127.0.0.1:8787';

async function request(action, payload = {}) {
  const res = await fetch(`${BASE_URL}/api`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ action, ...payload })
  });
  return await res.json();
}

async function runTests() {
  console.log('🧪 Starting SmartBill Integration Tests...\n');
  let passed = 0;
  let total = 0;

  function assert(desc, condition) {
    total++;
    if (condition) {
      console.log(`✅ [PASS] ${desc}`);
      passed++;
    } else {
      console.error(`❌ [FAIL] ${desc}`);
    }
  }

  try {
    // 1. Ping / Health check
    const pingRes = await fetch(`${BASE_URL}/ping`);
    const pingJson = await pingRes.json();
    assert('Health Check /ping returns success', pingJson.success === true);

    // 2. Static Assets (GET /)
    const indexRes = await fetch(`${BASE_URL}/`);
    const indexText = await indexRes.text();
    assert('Frontend Static Asset / returns HTML', indexText.includes('SmartBill Users Admin'));

    // 3. Admin Login (Verify PIN 999999)
    const adminLogin = await request('verifyPin', { pin: '999999' });
    assert('Admin Login verifyPin(999999) succeeds', adminLogin.success === true && adminLogin.role === 'ADMIN');
    assert('Admin Login returns seeded users list', Array.isArray(adminLogin.usersList) && adminLogin.usersList.length >= 4);

    // 4. Pending User Verification (Verify PIN 123456)
    const userPinRes = await request('verifyPin', { pin: '123456' });
    assert('User verifyPin(123456) identifies pending user', userPinRes.success === true && userPinRes.role === 'USER' && userPinRes.isPending === true);
    assert('User verifyPin returns pcLimit and requesterName/requestName', 
      userPinRes.data.pcLimit === 5000 && 
      userPinRes.data.requesterName === 'สมชาย ใจดี' &&
      userPinRes.data.requestName === 'สมชาย ใจดี');

    // 5. Invalid PIN Rejection
    const invalidPinRes = await request('verifyPin', { pin: '000000' });
    assert('Invalid PIN rejected', invalidPinRes.success === false && invalidPinRes.message === 'รหัสไม่ถูกต้อง');

    // 6. Query Approvers by Tag (คุมวงเงินสด)
    const controlApprovers = await request('getApprovers', { tag: 'คุมวงเงินสด' });
    assert('getApprovers("คุมวงเงินสด") returns active holders', controlApprovers.success === true && controlApprovers.data.length >= 1);
    const hasHolder = controlApprovers.data.some(u => (u.requester_name || u.users_name).includes('สุภาพร บุญมา'));
    assert('Found active Petty Cash Controller "สุภาพร บุญมา" with requester_name', hasHolder);

    // 7. Query Approvers by Tag (อนุมัติวงเงินสด)
    const paymentApprovers = await request('getApprovers', { tag: 'อนุมัติวงเงินสด' });
    assert('getApprovers("อนุมัติวงเงินสด") returns active approvers', paymentApprovers.success === true && paymentApprovers.data.length >= 1);
    const hasApprover = paymentApprovers.data.some(u => (u.requester_name || u.users_name).includes('มนตรี เกียรติสกุล'));
    assert('Found active Approver "มนตรี เกียรติสกุล" with requester_name', hasApprover);

    // 8. Create New User (Testing requester_name field support)
    const testUserName = 'ทดสอบ สมาชิกใหม่ ' + Date.now().toString().slice(-4);
    const createRes = await request('createUser', {
      requester_name: testUserName,
      emp_no: '99001',
      pc_limit: 8000,
      pettycash_control: 'YES',
      can_approve: false
    });
    assert('createUser succeeds and returns requester_name & aliases', 
      createRes.success === true && 
      createRes.data.pin && 
      createRes.data.pin.length === 6 &&
      createRes.data.requester_name === testUserName &&
      createRes.data.users_name === testUserName);
    const createdPin = createRes.data.pin;
    const createdUserId = createRes.data.users_id;

    // 9. Rejection on duplicate name
    const duplicateRes = await request('createUser', {
      Request_Name: testUserName,
      emp_no: '99002'
    });
    assert('Duplicate user name is rejected', duplicateRes.success === false);

    // 10. Register User with LINE UID (Binding flow)
    const testLineUid = 'U' + Math.random().toString(16).substring(2, 10).padStart(32, '0');
    const registerRes = await request('registerUser', {
      pin: createdPin,
      lineUid: testLineUid,
      displayName: 'TestLineUser',
      pictureUrl: 'https://example.com/avatar.png'
    });
    assert('registerUser binds LINE UID and returns requesterName', 
      registerRes.success === true && 
      registerRes.data.lineUid === testLineUid &&
      registerRes.data.requesterName === testUserName);

    // Verify user is now active in listUsers
    const listRes = await request('listUsers', { adminPin: '999999' });
    const verifiedUser = listRes.data.find(u => u.users_id === createdUserId);
    assert('User appears as REGISTERED in listUsers with requester_name', 
      verifiedUser && 
      verifiedUser.active === 'Y' && 
      verifiedUser.status === 'REGISTERED' &&
      verifiedUser.requester_name === testUserName);

    // 11. Update User
    const updateRes = await request('updateUser', {
      users_id: createdUserId,
      Request_Name: testUserName + ' (Updated)',
      emp_no: '99001-A',
      pc_limit: 12000,
      pettycash_control: 'NO',
      can_approve: true
    });
    assert('updateUser succeeds', updateRes.success === true);

    // 12. Delete User
    const deleteRes = await request('deleteUser', {
      users_id: createdUserId,
      adminPin: '999999'
    });
    assert('deleteUser succeeds', deleteRes.success === true);

    // Verify deleted
    const finalList = await request('listUsers', { adminPin: '999999' });
    const notFound = !finalList.data.some(u => u.users_id === createdUserId);
    assert('Deleted user is removed from database', notFound);

  } catch (err) {
    console.error('Test execution error:', err);
  }

  console.log(`\n========================================`);
  console.log(`Test Results: ${passed} / ${total} passed (${Math.round((passed / total) * 100)}%)`);
  console.log(`========================================\n`);

  process.exit(passed === total ? 0 : 1);
}

runTests();
