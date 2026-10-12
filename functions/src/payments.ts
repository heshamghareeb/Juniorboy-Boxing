import Stripe from 'stripe';
import { FieldPath, Timestamp } from 'firebase-admin/firestore';
import { defineSecret } from 'firebase-functions/params';
import { HttpsError, onCall, onRequest } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions';
import { z } from 'zod';
import { audit, callable, db, emulator, enforceAppCheck, id, notify, now, rateLimit, requireAuth, requireRegistered, requireMember } from './platform';
import type { TrainingType } from './domain';

const STRIPE_SECRET_KEY = defineSecret('STRIPE_SECRET_KEY');
const STRIPE_WEBHOOK_SECRET = defineSecret('STRIPE_WEBHOOK_SECRET');
const stripe = () => new Stripe(STRIPE_SECRET_KEY.value());
const purchaseSchema = z.object({ planId: id, requestId: z.string().uuid() });
const productPurchaseSchema = z.object({ productId: id, requestId: z.string().uuid(), size: z.string().max(20).optional() });
const joinSessionSchema = z.object({ sessionId: id, requestId: z.string().uuid(), timeSlot: z.string().max(100).optional() });

async function createOrRetrieveIntent(ref: FirebaseFirestore.DocumentReference, order: FirebaseFirestore.DocumentData, metadata: Record<string, string>, receiptEmail?: string) {
  const api = stripe();
  const intent = order.stripePaymentIntentId ? await api.paymentIntents.retrieve(order.stripePaymentIntentId) : await api.paymentIntents.create({ amount: order.amount, currency: 'usd', automatic_payment_methods: { enabled: true }, receipt_email: receiptEmail || undefined, metadata }, { idempotencyKey: ref.id });
  await ref.update({ stripePaymentIntentId: intent.id, updatedAt: now() });
  return intent;
}

export const createPaymentIntent = onCall({ secrets: [STRIPE_SECRET_KEY], enforceAppCheck, maxInstances: 20 }, async request => {
  const uid = requireRegistered(request);
  const user = await requireMember(uid);
  if (!user.phone?.trim()) throw new HttpsError('failed-precondition', 'Complete your phone number in Profile Settings before purchasing.');
  await rateLimit(uid, 'payment', 8);
  const input = purchaseSchema.safeParse(request.data);
  if (!input.success) throw new HttpsError('invalid-argument', 'A plan and unique request ID are required.');
  const { planId, requestId } = input.data;
  const ref = db.doc(`payments/${uid}_${requestId}`);
  const order = await db.runTransaction(async tx => {
    const [old, planSnap] = await Promise.all([tx.get(ref), tx.get(db.doc(`membershipPlans/${planId}`))]);
    if (old.exists) {
      if (old.data()!.membershipPlanId !== planId) throw new HttpsError('already-exists', 'Use a new checkout request when changing plans.');
      if (!old.data()!.stripePaymentIntentId && Date.now() - old.data()!.createdAt.toMillis() > 23 * 3_600_000) throw new HttpsError('failed-precondition', 'Checkout expired. Start a new checkout.', { reason: 'checkout-expired' });
      return old.data()!;
    }
    const plan = planSnap.data();
    if (!plan?.isActive || !Number.isInteger(plan.price) || plan.price <= 0) throw new HttpsError('failed-precondition', 'Plan is not available.');
    const credits = plan.sessionCount ?? plan.creditsPerPurchase;
    if (!Number.isInteger(credits) || credits <= 0) throw new HttpsError('failed-precondition', 'This plan requires a credit configuration.');
    const trainingType: TrainingType = plan.trainingType || 'private';
    const discountPercent = plan.discountActive && typeof plan.discountPercent === 'number' && plan.discountPercent > 0 && plan.discountPercent <= 100 ? plan.discountPercent : 0;
    const amount = discountPercent > 0 ? Math.round(plan.price * (1 - discountPercent / 100)) : plan.price;
    const data = { userId: uid, membershipPlanId: planId, trainingType, amount, credits, currency: 'usd', status: 'pending', paymentMethod: 'stripe', stripePaymentIntentId: null, receiptUrl: null, createdAt: now(), updatedAt: now() };
    tx.create(ref, data);
    return data;
  });
  if (['completed', 'refunded', 'refund_pending'].includes(order.status)) return { paymentId: ref.id, status: order.status };
  const intent = await createOrRetrieveIntent(ref, order, { paymentId: ref.id, userId: uid, planId }, user.email);
  return { paymentId: ref.id, clientSecret: intent.client_secret, status: intent.status };
});
export const purchaseMembership = createPaymentIntent;

export const createProductPaymentIntent = onCall({ secrets: [STRIPE_SECRET_KEY], enforceAppCheck, maxInstances: 20 }, async request => {
  const uid = requireRegistered(request);
  await requireMember(uid);
  await rateLimit(uid, 'payment', 8);
  const input = productPurchaseSchema.safeParse(request.data);
  if (!input.success) throw new HttpsError('invalid-argument', 'A product and unique request ID are required.');
  const { productId, requestId, size } = input.data;
  const ref = db.doc(`payments/${uid}_${requestId}`);
  const order = await db.runTransaction(async tx => {
    const [old, productSnap] = await Promise.all([tx.get(ref), tx.get(db.doc(`products/${productId}`))]);
    if (old.exists) {
      if (old.data()!.productId !== productId) throw new HttpsError('already-exists', 'Use a new checkout request when changing products.');
      if (!old.data()!.stripePaymentIntentId && Date.now() - old.data()!.createdAt.toMillis() > 23 * 3_600_000) throw new HttpsError('failed-precondition', 'Checkout expired. Start a new checkout.', { reason: 'checkout-expired' });
      return old.data()!;
    }
    const product = productSnap.data();
    if (!product?.isActive || !Number.isInteger(product.price) || product.price <= 0) throw new HttpsError('failed-precondition', 'Product is not available.');
    const availableSizes: string[] = Array.isArray(product.sizes) ? product.sizes : [];
    if (availableSizes.length > 0 && (!size || !availableSizes.includes(size))) throw new HttpsError('invalid-argument', 'Choose an available size before purchasing.');
    const discountPercent = product.discountActive && typeof product.discountPercent === 'number' && product.discountPercent > 0 && product.discountPercent <= 100 ? product.discountPercent : 0;
    const amount = discountPercent > 0 ? Math.round(product.price * (1 - discountPercent / 100)) : product.price;
    const data = { userId: uid, productId, productName: product.name as string, size: availableSizes.length > 0 ? size : null, amount, currency: 'usd', status: 'pending', paymentMethod: 'stripe', stripePaymentIntentId: null, receiptUrl: null, createdAt: now(), updatedAt: now() };
    tx.create(ref, data);
    return data;
  });
  if (['completed', 'refunded', 'refund_pending'].includes(order.status)) return { paymentId: ref.id, status: order.status };
  const intent = await createOrRetrieveIntent(ref, order, { paymentId: ref.id, userId: uid, productId });
  return { paymentId: ref.id, clientSecret: intent.client_secret, status: intent.status };
});

export const joinSession = onCall({ secrets: [STRIPE_SECRET_KEY], enforceAppCheck, maxInstances: 20 }, async request => {
  const uid = requireRegistered(request);
  const user = await requireMember(uid);
  if (user.role === 'admin' || user.role === 'superAdmin') throw new HttpsError('permission-denied', 'Admin accounts cannot join sessions.');
  if (!user.phone?.trim()) throw new HttpsError('failed-precondition', 'Complete your phone number in Profile Settings before purchasing.');
  await rateLimit(uid, 'payment', 8);
  const input = joinSessionSchema.safeParse(request.data);
  if (!input.success) throw new HttpsError('invalid-argument', 'A session and unique request ID are required.');
  const { sessionId, requestId, timeSlot } = input.data;
  const ref = db.doc(`payments/${uid}_${requestId}`);
  const order = await db.runTransaction(async tx => {
    const [old, sessionSnap] = await Promise.all([tx.get(ref), tx.get(db.doc(`sessions/${sessionId}`))]);
    if (old.exists) {
      if (old.data()!.sessionId !== sessionId) throw new HttpsError('already-exists', 'Use a new checkout request when changing sessions.');
      if (!old.data()!.stripePaymentIntentId && Date.now() - old.data()!.createdAt.toMillis() > 23 * 3_600_000) throw new HttpsError('failed-precondition', 'Checkout expired. Start a new checkout.', { reason: 'checkout-expired' });
      return old.data()!;
    }
    const session = sessionSnap.data();
    if (!session) throw new HttpsError('not-found', 'Session not found.');
    const joined: string[] = Array.isArray(session.joinedUserIds) ? session.joinedUserIds : [];
    if (joined.includes(uid)) throw new HttpsError('already-exists', "You've already joined this session.");
    if (joined.length >= (session.maxParticipants ?? 0)) throw new HttpsError('resource-exhausted', 'This session is full.');
    if (timeSlot && Array.isArray(session.timeSlots)) {
      const matchSlot = session.timeSlots.find((s: any) => `${s.startTime}–${s.endTime}` === timeSlot || `${s.startTime}-${s.endTime}` === timeSlot);
      if (matchSlot) {
        const slotJoined: string[] = Array.isArray(matchSlot.joinedUserIds) ? matchSlot.joinedUserIds : [];
        if (slotJoined.includes(uid)) throw new HttpsError('already-exists', "You've already joined this time slot.");
        const slotMax = typeof matchSlot.maxParticipants === 'number' && matchSlot.maxParticipants > 0 ? matchSlot.maxParticipants : (session.maxParticipants ?? 0);
        if (slotMax > 0 && slotJoined.length >= slotMax) throw new HttpsError('resource-exhausted', `This time slot (${timeSlot}) is full.`);
      }
    }
    if (typeof session.price !== 'number' || !Number.isFinite(session.price) || session.price <= 0) throw new HttpsError('failed-precondition', 'Session is not available for purchase.');
    const amount = Math.round(session.price * 100);
    const data = { userId: uid, sessionId, sessionTitle: session.title as string, timeSlot: timeSlot || null, amount, currency: 'usd', status: 'pending', paymentMethod: 'stripe', stripePaymentIntentId: null, receiptUrl: null, createdAt: now(), updatedAt: now() };
    tx.create(ref, data);
    return data;
  });
  if (['completed', 'refunded', 'refund_pending'].includes(order.status)) return { paymentId: ref.id, status: order.status };
  const intent = await createOrRetrieveIntent(ref, order, { paymentId: ref.id, userId: uid, sessionId, ...(timeSlot ? { timeSlot } : {}) }, user.email);
  return { paymentId: ref.id, clientSecret: intent.client_secret, status: intent.status };
});

export async function applySuccessfulPayment(paymentId: string, intent: { id: string; amount: number; currency: string }, receiptUrl: string | null = null) {
  await db.runTransaction(async tx => {
    const ref = db.doc(`payments/${paymentId}`);
    const p = await tx.get(ref), payment = p.data();
    if (!payment) throw new Error('Unknown payment order');
    if (['completed', 'refunded', 'refund_pending'].includes(payment.status)) return;
    if (payment.amount !== intent.amount || payment.currency !== intent.currency || (payment.stripePaymentIntentId && payment.stripePaymentIntentId !== intent.id)) throw new Error('Payment verification mismatch');
    const user = await tx.get(db.doc(`users/${payment.userId}`));
    const isProduct = !!payment.productId;
    const isSession = !!payment.sessionId;
    const sessionRef = isSession ? db.doc(`sessions/${payment.sessionId}`) : null;
    const sessionSnap = sessionRef ? await tx.get(sessionRef) : null;
    tx.update(ref, { status: 'completed', stripePaymentIntentId: intent.id, receiptUrl, updatedAt: now(), paidAt: now(), fulfillmentStatus: !user.exists ? 'account_deleted' : isProduct ? 'ready_for_pickup' : 'fulfilled' });
    if (!user.exists) return;
    if (isProduct) {
      const label = payment.size ? `${payment.productName} (size ${payment.size})` : payment.productName;
      notify(tx, `payment_${paymentId}`, payment.userId, 'Order confirmed', `Your order for ${label} is ready to pick up at the gym.`, 'product_purchased', { paymentId });
    } else if (isSession) {
      if (sessionRef && sessionSnap?.exists) {
        const session = sessionSnap.data()!;
        const joined: string[] = Array.isArray(session.joinedUserIds) ? session.joinedUserIds : [];
        const timeSlot = payment.timeSlot as string | null | undefined;
        let updatedTimeSlots = session.timeSlots;
        if (timeSlot && Array.isArray(session.timeSlots)) {
          updatedTimeSlots = session.timeSlots.map((s: any) => {
            const l1 = `${s.startTime}–${s.endTime}`, l2 = `${s.startTime}-${s.endTime}`;
            if (l1 === timeSlot || l2 === timeSlot) {
              const sJoined: string[] = Array.isArray(s.joinedUserIds) ? s.joinedUserIds : [];
              if (!sJoined.includes(payment.userId)) return { ...s, joinedUserIds: [...sJoined, payment.userId] };
            }
            return s;
          });
        }
        const updates: Record<string, any> = { updatedAt: now() };
        if (!joined.includes(payment.userId) && joined.length < (session.maxParticipants ?? 0)) {
          updates.joinedUserIds = [...joined, payment.userId];
        }
        if (updatedTimeSlots) {
          updates.timeSlots = updatedTimeSlots;
        }
        tx.update(sessionRef, updates);
      }
      notify(tx, `payment_${paymentId}`, payment.userId, "You're in!", `You've joined ${payment.sessionTitle || 'the session'}.`, 'session_joined', { paymentId, sessionId: payment.sessionId });
    } else {
      const trainingType: TrainingType = payment.trainingType || 'private';
      const remainingField = `${trainingType}SessionsRemaining`;
      tx.update(user.ref, {
        membershipPlanId: payment.membershipPlanId,
        [remainingField]: (user.data()![remainingField] ?? 0) + payment.credits,
        sessionsRemaining: user.data()!.sessionsRemaining + payment.credits,
        updatedAt: now(),
      });
      notify(tx, `payment_${paymentId}`, payment.userId, 'Membership purchased', `${payment.credits} session credits have been added to your account.`, 'membership_purchased', { paymentId });
    }
  });
}

export const handleStripeWebhook = onRequest({ secrets: [STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET], timeoutSeconds: 60 }, async (request, response) => {
  if (request.method !== 'POST') { response.status(405).send('Method not allowed'); return; }
  let event: Stripe.Event;
  try { event = stripe().webhooks.constructEvent(request.rawBody, request.headers['stripe-signature'] as string, STRIPE_WEBHOOK_SECRET.value()); }
  catch { response.status(400).send('Invalid signature'); return; }
  try {
    if (event.type === 'payment_intent.succeeded') {
      const intent = event.data.object;
      if (intent.metadata.paymentId) {
        const charge = intent.latest_charge ? await stripe().charges.retrieve(typeof intent.latest_charge === 'string' ? intent.latest_charge : intent.latest_charge.id) : null;
        await applySuccessfulPayment(intent.metadata.paymentId, intent, charge?.receipt_url ?? null);
      }
    } else if (event.type === 'payment_intent.payment_failed' || event.type === 'payment_intent.canceled') {
      const intent = event.data.object;
      if (intent.metadata.paymentId) await db.runTransaction(async tx => {
        const ref = db.doc(`payments/${intent.metadata.paymentId}`), old = await tx.get(ref);
        if (old.exists && ['pending', 'failed'].includes(old.data()!.status)) tx.update(ref, { status: 'failed', updatedAt: now() });
      });
    } else if (event.type === 'refund.updated' || event.type === 'refund.created' || event.type === 'refund.failed') {
      await settleRefund(event.data.object);
    }
    response.status(200).json({ received: true });
  } catch (error) {
    logger.error('Stripe event failed', { eventId: event.id, error: String(error) });
    response.status(500).send('Retry required');
  }
});

async function settleRefund(refund: Stripe.Refund) {
  const paymentId = refund.metadata?.paymentId;
  if (!paymentId) return;
  await db.runTransaction(async tx => {
    const ref = db.doc(`payments/${paymentId}`), snap = await tx.get(ref), p = snap.data();
    if (!p || p.status !== 'refund_pending') return;
    const user = await tx.get(db.doc(`users/${p.userId}`));
    if (refund.status === 'succeeded') tx.update(ref, { status: 'refunded', stripeRefundId: refund.id, updatedAt: now() });
    else if (refund.status === 'failed' || refund.status === 'canceled') {
      tx.update(ref, { status: 'completed', refundError: refund.failure_reason ?? refund.status, updatedAt: now() });
      if (!p.productId && user.exists) {
        const trainingType: TrainingType = p.trainingType || 'private';
        const remainingField = `${trainingType}SessionsRemaining`;
        tx.update(user.ref, {
          [remainingField]: (user.data()![remainingField] ?? 0) + p.credits,
          sessionsRemaining: user.data()!.sessionsRemaining + p.credits,
          updatedAt: now(),
        });
      }
    }
  });
}
export const createRefund = onCall({ secrets: [STRIPE_SECRET_KEY], enforceAppCheck }, async request => {
  const uid = requireAuth(request); await requireMember(uid, true); await rateLimit(uid, 'refund', 10);
  const input = z.object({ paymentId: id }).safeParse(request.data);
  if (!input.success) throw new HttpsError('invalid-argument', 'Payment ID is required.');
  const ref = db.doc(`payments/${input.data.paymentId}`);
  const p = await db.runTransaction(async tx => {
    const snap = await tx.get(ref), payment = snap.data();
    if (!payment) throw new HttpsError('not-found', 'Payment not found.');
    if (['refunded', 'refund_pending'].includes(payment.status)) return payment;
    if (payment.status !== 'completed' || payment.refundError) throw new HttpsError('failed-precondition', 'Payment is not eligible for an automatic refund.');
    const user = await tx.get(db.doc(`users/${payment.userId}`));
    const isProduct = !!payment.productId;
    const trainingType: TrainingType = payment.trainingType || 'private';
    const remainingField = `${trainingType}SessionsRemaining`, reservedField = `${trainingType}SessionsReserved`;
    if (!isProduct && user.exists && (user.data()![remainingField] ?? 0) - (user.data()![reservedField] ?? 0) < payment.credits) throw new HttpsError('failed-precondition', 'Cancel reservations or resolve used credits before refunding.');
    if (!isProduct && user.exists) tx.update(user.ref, {
      [remainingField]: (user.data()![remainingField] ?? 0) - payment.credits,
      sessionsRemaining: user.data()!.sessionsRemaining - payment.credits,
      updatedAt: now(),
    });
    tx.update(ref, { status: 'refund_pending', updatedAt: now() });
    audit(tx, uid, 'refund', ref.id);
    return payment;
  });
  if (p.status === 'refunded') return { status: 'refunded' };
  if (p.paymentMethod !== 'stripe') { await ref.update({ status: 'refunded', updatedAt: now() }); return { status: 'refunded' }; }
  const refund = await stripe().refunds.create({ payment_intent: p.stripePaymentIntentId, metadata: { paymentId: ref.id } }, { idempotencyKey: `refund_${ref.id}` });
  await settleRefund(refund);
  return { status: refund.status };
});

export const recordManualPayment = callable(z.object({ userId: id, planId: id, requestId: z.string().uuid(), method: z.enum(['cash', 'manual']), note: z.string().max(500).default('') }), 'manualPayment', async (input, uid) => {
  const ref = db.doc(`payments/manual_${input.requestId}`);
  await db.runTransaction(async tx => {
    const [old, plan, user] = await Promise.all([tx.get(ref), tx.get(db.doc(`membershipPlans/${input.planId}`)), tx.get(db.doc(`users/${input.userId}`))]);
    if (old.exists) {
      if (old.data()!.userId !== input.userId || old.data()!.membershipPlanId !== input.planId || old.data()!.paymentMethod !== input.method) throw new HttpsError('already-exists', 'This request was already used for a different payment.');
      return;
    }
    const p = plan.data(), u = user.data(), credits = p?.sessionCount ?? p?.creditsPerPurchase;
    if (!p?.isActive || !u?.isActive || !Number.isInteger(credits) || credits <= 0 || !Number.isInteger(p.price) || p.price <= 0) throw new HttpsError('failed-precondition', 'Select an active member and plan with a valid price.');
    const trainingType: TrainingType = p.trainingType || 'private';
    const remainingField = `${trainingType}SessionsRemaining`;
    tx.create(ref, { userId: input.userId, membershipPlanId: input.planId, trainingType, amount: p.price, currency: 'usd', credits, status: 'completed', paymentMethod: input.method, stripePaymentIntentId: null, receiptUrl: null, note: input.note, createdAt: now(), updatedAt: now(), paidAt: now() });
    tx.update(user.ref, {
      [remainingField]: (u[remainingField] ?? 0) + credits,
      sessionsRemaining: u.sessionsRemaining + credits,
      membershipPlanId: input.planId,
      updatedAt: now(),
    });
    notify(tx, `payment_${ref.id}`, input.userId, 'Payment recorded', `${credits} session credits were added to your account.`, 'membership_purchased');
    audit(tx, uid, 'manualPayment', ref.id);
  });
  return { paymentId: ref.id };
}, true);
// Removes a payment/order record from the admin's history. This does not
// reverse its effects (session credits already granted, or a store order
// already marked fulfilled) — use createRefund first if the purchase
// itself needs to be undone. This is for clearing out mistaken or test
// entries, with an audit trail of who removed what.
export const deletePayment = callable(z.object({ paymentId: id }), 'deletePayment', async (input, uid) => {
  const ref = db.doc(`payments/${input.paymentId}`);
  await db.runTransaction(async tx => {
    const snap = await tx.get(ref);
    if (!snap.exists) return;
    tx.delete(ref);
    audit(tx, uid, 'deletePayment', ref.id, { snapshot: snap.data() });
  });
  return { success: true };
}, true);
export const getPaymentHistory = callable(z.object({ before: z.string().datetime().optional() }), 'paymentHistory', async ({ before }, uid) => {
  let q = db.collection('payments').where('userId', '==', uid).orderBy('createdAt', 'desc').limit(50);
  if (before) q = q.startAfter(new Date(before));
  const page = await q.get();
  return { payments: page.docs.map(d => ({ ...d.data(), id: d.id, createdAt: d.data().createdAt.toDate().toISOString(), updatedAt: d.data().updatedAt.toDate().toISOString() })) };
});

// Members can't read each other's user docs directly (Firestore rules only
// allow a user to read their own profile or an admin to read any), so the
// joined-members list on a session card goes through this function instead,
// which uses the Admin SDK to return just the public display fields.
export const getSessionMembers = onCall({ enforceAppCheck, maxInstances: 20 }, async request => {
  const parsed = z.object({ sessionId: id }).safeParse(request.data);
  if (!parsed.success) throw new HttpsError('invalid-argument', 'Invalid session ID.');
  const { sessionId } = parsed.data;
  const sessionSnap = await db.doc(`sessions/${sessionId}`).get();
  if (!sessionSnap.exists) throw new HttpsError('not-found', 'Session not found.');
  const sessionData = sessionSnap.data();
  const uids: string[] = sessionData?.joinedUserIds || [];
  if (!uids.length) return { members: [] };
  // Map each joined member to the specific time slot they picked (sessions can offer several
  // same-day slots), so the admin/member "Joined Members" view can show who's in which slot.
  const timeSlotByUid = new Map<string, string>();
  if (Array.isArray(sessionData?.timeSlots)) {
    for (const slot of sessionData!.timeSlots) {
      const label = `${slot.startTime}–${slot.endTime}`;
      for (const uid of Array.isArray(slot.joinedUserIds) ? slot.joinedUserIds : []) timeSlotByUid.set(uid, label);
    }
  }
  const members: { uid: string; fullName: string; childName: string; profilePicUrl: string | null; timeSlot: string | null }[] = [];
  for (let i = 0; i < uids.length; i += 30) {
    const chunk = uids.slice(i, i + 30);
    const snap = await db.collection('users').where(FieldPath.documentId(), 'in', chunk).get();
    snap.forEach(d => {
      const data = d.data();
      members.push({ uid: d.id, fullName: data.fullName || 'Member', childName: data.childName || '', profilePicUrl: data.profilePicUrl || data.avatarUrl || null, timeSlot: timeSlotByUid.get(d.id) || null });
    });
  }
  return { members };
});

// Lets an admin schedule a store order for pickup/delivery, so the buyer can
// see when to expect it. The admin looks up the buyer's contact/address
// directly on their profile (users/{uid}) before deciding whether to arrange
// shipping or a gym pickup.
export const setOrderDelivery = callable(z.object({ paymentId: id, estimatedDeliveryDate: z.string().datetime(), note: z.string().max(300).default('') }), 'orderDelivery', async (input, uid) => {
  const ref = db.doc(`payments/${input.paymentId}`);
  await db.runTransaction(async tx => {
    const snap = await tx.get(ref), payment = snap.data();
    if (!payment) throw new HttpsError('not-found', 'Order not found.');
    if (!payment.productId) throw new HttpsError('failed-precondition', 'Only store orders can be scheduled for delivery.');
    if (payment.status !== 'completed') throw new HttpsError('failed-precondition', 'Order must be paid before scheduling delivery.');
    const deliveryDate = Timestamp.fromDate(new Date(input.estimatedDeliveryDate));
    tx.update(ref, { estimatedDeliveryDate: deliveryDate, deliveryNote: input.note, fulfillmentStatus: 'scheduled', updatedAt: now() });
    notify(tx, `delivery_${ref.id}_${deliveryDate.toMillis()}`, payment.userId, 'Delivery scheduled', `Your order for ${payment.productName} is expected around ${new Date(input.estimatedDeliveryDate).toLocaleDateString()}.`, 'product_delivery', { paymentId: ref.id });
    audit(tx, uid, 'setOrderDelivery', ref.id, { estimatedDeliveryDate: input.estimatedDeliveryDate });
  });
  return { success: true };
}, true);
