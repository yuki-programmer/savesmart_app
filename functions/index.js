const admin = require('firebase-admin');
const functions = require('firebase-functions');
const { google } = require('googleapis');

admin.initializeApp();
const config = functions.config();

const APPLE_VERIFY_PRODUCTION =
  'https://buy.itunes.apple.com/verifyReceipt';
const APPLE_VERIFY_SANDBOX =
  'https://sandbox.itunes.apple.com/verifyReceipt';

function jsonError(res, status, message) {
  res.status(status).json({ active: false, error: message });
}

function allowCors(res) {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
}

async function verifyFirebaseAuth(req) {
  const auth = req.get('Authorization') || '';
  if (!auth.startsWith('Bearer ')) return null;
  const token = auth.substring('Bearer '.length).trim();
  if (!token) return null;
  return await admin.auth().verifyIdToken(token);
}

async function recomputePairPlusState(pairId) {
  const db = admin.firestore();
  const pairRef = db.collection('pairs').doc(pairId);
  const pairSnap = await pairRef.get();
  if (!pairSnap.exists) return;

  const pairData = pairSnap.data() || {};
  const memberUids = pairData.memberUids || [];
  if (!memberUids.length) {
    if (pairData.plusActive !== false || pairData.plusOwnerUid != null) {
      await pairRef.update({
        plusActive: false,
        plusOwnerUid: null,
        plusGraceUntil: null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    return;
  }

  const memberDocs = await db
    .collection('users')
    .where(admin.firestore.FieldPath.documentId(), 'in', memberUids)
    .get();

  let plusOwnerUid = null;
  let plusActive = false;
  memberDocs.forEach((doc) => {
    const data = doc.data() || {};
    if (data.isPlus === true) {
      plusActive = true;
      if (!plusOwnerUid) {
        plusOwnerUid = doc.id;
      }
    }
  });

  if (
    pairData.plusActive === plusActive &&
    pairData.plusOwnerUid === plusOwnerUid
  ) {
    return;
  }

  await pairRef.update({
    plusActive,
    plusOwnerUid,
    plusGraceUntil: null,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

async function syncUserEntitlement(uid, isPlus) {
  const db = admin.firestore();
  const userRef = db.collection('users').doc(uid);
  await userRef.set(
    {
      isPlus,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  const userSnap = await userRef.get();
  const pairId = userSnap.data() && userSnap.data().pairId;
  if (!pairId) return;

  await recomputePairPlusState(pairId);
}

exports.syncPairPlusState = functions.firestore
  .document('pairs/{pairId}')
  .onWrite(async (change, context) => {
    if (!change.after.exists) return;
    await recomputePairPlusState(context.params.pairId);
  });

async function verifyAppleReceipt({
  receiptData,
  productId,
  sharedSecret,
}) {
  const payload = {
    'receipt-data': receiptData,
    password: sharedSecret,
    'exclude-old-transactions': true,
  };

  const response = await fetch(APPLE_VERIFY_PRODUCTION, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
  const result = await response.json();

  if (result.status === 21007) {
    const sandboxResp = await fetch(APPLE_VERIFY_SANDBOX, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });
    return sandboxResp.json();
  }

  return result;
}

function resolveAppleEntitlement(data, productId) {
  const now = Date.now();
  const list =
    data.latest_receipt_info ||
    (data.receipt && data.receipt.in_app) ||
    [];

  const filtered = productId
    ? list.filter((item) => item.product_id === productId)
    : list;

  if (!filtered.length) {
    return { active: false, expiresAt: null, productId: null };
  }

  const latest = filtered.reduce((a, b) => {
    const aMs = Number(a.expires_date_ms || a.purchase_date_ms || 0);
    const bMs = Number(b.expires_date_ms || b.purchase_date_ms || 0);
    return bMs > aMs ? b : a;
  });

  const expiresMs = Number(latest.expires_date_ms || 0);
  const canceledMs = Number(latest.cancellation_date_ms || 0);
  const active = expiresMs > now && canceledMs === 0;

  return {
    active,
    expiresAt: expiresMs ? new Date(expiresMs).toISOString() : null,
    productId: latest.product_id || productId || null,
  };
}

async function verifyGooglePlay({
  purchaseToken,
  productId,
  packageName,
  serviceAccountJson,
}) {
  const auth = new google.auth.GoogleAuth({
    credentials: JSON.parse(serviceAccountJson),
    scopes: ['https://www.googleapis.com/auth/androidpublisher'],
  });

  const client = await auth.getClient();
  const androidPublisher = google.androidpublisher({
    version: 'v3',
    auth: client,
  });

  const result = await androidPublisher.purchases.subscriptions.get({
    packageName,
    subscriptionId: productId,
    token: purchaseToken,
  });

  return result.data;
}

exports.verifyPurchase = functions.https.onRequest(async (req, res) => {
  allowCors(res);

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    jsonError(res, 405, 'Method Not Allowed');
    return;
  }

  try {
    const decoded = await verifyFirebaseAuth(req);
    if (!decoded) {
      jsonError(res, 401, 'Auth token required');
      return;
    }

    const {
      platform,
      productId,
      verificationData,
      verificationSource,
    } = req.body || {};

    if (!platform || !productId || !verificationData) {
      jsonError(res, 400, 'Missing required fields');
      return;
    }

    if (platform === 'ios') {
      const sharedSecret =
        (config.appstore && config.appstore.shared_secret) ||
        process.env.APPLE_SHARED_SECRET;
      if (!sharedSecret) {
        jsonError(res, 500, 'APPLE_SHARED_SECRET not configured');
        return;
      }

      const result = await verifyAppleReceipt({
        receiptData: verificationData,
        productId,
        sharedSecret,
      });

      if (result.status !== 0) {
        res.status(200).json({
          active: false,
          status: String(result.status),
        });
        return;
      }

      const entitlement = resolveAppleEntitlement(result, productId);
      await syncUserEntitlement(decoded.uid, entitlement.active);

      res.status(200).json({
        active: entitlement.active,
        expiresAt: entitlement.expiresAt,
        productId: entitlement.productId,
        status: 'active',
        verificationSource,
      });
      return;
    }

    if (platform === 'android') {
      const packageName =
        (config.android && config.android.package_name) ||
        process.env.ANDROID_PACKAGE_NAME;
      const serviceAccountJson =
        (config.google && config.google.service_account_json) ||
        process.env.GOOGLE_SERVICE_ACCOUNT_JSON;
      if (!packageName || !serviceAccountJson) {
        jsonError(res, 500, 'Android verification not configured');
        return;
      }

      const result = await verifyGooglePlay({
        purchaseToken: verificationData,
        productId,
        packageName,
        serviceAccountJson,
      });

      const expiryMs = Number(result.expiryTimeMillis || 0);
      const active = expiryMs > Date.now();

      await syncUserEntitlement(decoded.uid, active);

      res.status(200).json({
        active,
        expiresAt: expiryMs ? new Date(expiryMs).toISOString() : null,
        productId,
        status: active ? 'active' : 'expired',
      });
      return;
    }

    jsonError(res, 400, 'Unsupported platform');
  } catch (e) {
    functions.logger.error('verifyPurchase failed', e);
    jsonError(res, 500, 'Internal error');
  }
});
