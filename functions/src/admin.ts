import { createHash } from 'node:crypto';
import { DateTime } from 'luxon';
import { Timestamp } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { z } from 'zod';
import { callable, db, emulator, enforceAppCheck, notify, now, rateLimit, zone, audit, id } from './platform';
import { csvCell } from './domain';

export const getDashboardStats = callable(z.object({}), 'dashboard', async () => {
  const today = DateTime.now().setZone(zone).startOf('day');
  const month = today.startOf('month');
  const from = today.minus({ days: 29 });
  const [members, todayBookings, plans, monthPayments, recentPayments, bookings] = await Promise.all([
    db.collection('users').where('role', '==', 'member').count().get(),
    db.collection('bookings').where('date', '>=', Timestamp.fromMillis(today.toMillis())).where('date', '<', Timestamp.fromMillis(today.plus({ days: 1 }).toMillis())).get(),
    db.collection('membershipPlans').where('isActive', '==', true).count().get(),
    db.collection('payments').where('status', '==', 'completed').where('createdAt', '>=', Timestamp.fromMillis(month.toMillis())).get(),
    db.collection('payments').where('status', '==', 'completed').where('createdAt', '>=', Timestamp.fromMillis(from.toMillis())).get(),
    db.collection('bookings').where('date', '>=', Timestamp.fromMillis(from.toMillis())).where('date', '<', Timestamp.fromMillis(today.plus({ days: 1 }).toMillis())).get(),
  ]);
  const revenue: Record<string, number> = {};
  for (let i = 0; i < 30; i++) revenue[from.plus({ days: i }).toISODate()!] = 0;
  recentPayments.docs.forEach(p => { const d = DateTime.fromJSDate(p.data().createdAt.toDate()).setZone(zone).toISODate()!; revenue[d] = (revenue[d] ?? 0) + p.data().amount; });
  const popular: Record<string, number> = {};
  bookings.docs.filter(b => b.data().status !== 'cancelled').forEach(b => { const name = b.data().className; popular[name] = (popular[name] ?? 0) + 1; });
  return { totalMembers: members.data().count, bookingsToday: todayBookings.docs.filter(b => b.data().status !== 'cancelled').length, activePlans: plans.data().count, revenueThisMonth: monthPayments.docs.reduce((sum, p) => sum + p.data().amount, 0), revenue: Object.entries(revenue).map(([date, amount]) => ({ date, amount })), popularClasses: Object.entries(popular).map(([name, count]) => ({ name, count })) };
}, true);

export const exportBookingsCSV = callable(z.object({ from: z.string().datetime(), to: z.string().datetime(), collection: z.enum(['bookings', 'payments']).default('bookings') }), 'export', async input => {
  const from = new Date(input.from), to = new Date(input.to);
  if (to <= from || +to - +from > 366 * 86_400_000) throw new HttpsError('invalid-argument', 'Choose a range of up to one year.');
  const field = input.collection === 'bookings' ? 'date' : 'createdAt';
  const rows = await db.collection(input.collection).where(field, '>=', from).where(field, '<', to).orderBy(field).limit(10001).get();
  if (rows.size > 10000) throw new HttpsError('resource-exhausted', 'Narrow the export date range.');
  const columns = input.collection === 'bookings' ? ['id', 'userId', 'className', 'date', 'startTime', 'endTime', 'status'] : ['id', 'userId', 'membershipPlanId', 'amount', 'currency', 'status', 'paymentMethod', 'createdAt'];
  const csv = [columns.map(csvCell).join(','), ...rows.docs.map(row => columns.map(key => { const value = key === 'id' ? row.id : row.data()[key]; return csvCell(value instanceof Timestamp ? value.toDate().toISOString() : value); }).join(','))].join('\r\n');
  return { csv, filename: `${input.collection}-${from.toISOString().slice(0, 10)}.csv` };
}, true);

export const contactGym = onCall({ enforceAppCheck, maxInstances: 5 }, async request => {
  const input = z.object({ name: z.string().min(2).max(100), email: z.email().max(254), message: z.string().min(10).max(4000), website: z.string().max(0).default('') }).safeParse(request.data);
  if (!input.success) throw new HttpsError('invalid-argument', 'Check your name, email and message.');
  const ipHash = createHash('sha256').update(request.rawRequest.ip || 'unknown').digest('hex');
  await rateLimit(ipHash, 'contact', 3);
  const admins = await db.collection('users').where('role', '==', 'admin').where('isActive', '==', true).get();
  const ref = db.collection('contactMessages').doc();
  await db.runTransaction(async tx => {
    tx.create(ref, { ...input.data, createdAt: now(), status: 'new' });
    for (const admin of admins.docs) notify(tx, `contact_${ref.id}_${admin.id}`, admin.id, `Website enquiry from ${input.data.name}`, `Reply to: ${input.data.email}\n\n${input.data.message}`, 'contact');
  });
  return { success: true };
});

export const adminEnrollMember = callable(
  z.object({
    sessionId: id,
    userId: id,
    timeSlot: z.string().max(100).optional(),
  }),
  'adminEnrollMember',
  async ({ sessionId, userId, timeSlot }, uid) => {
    console.log(`👉 [ADMIN_ENROLL 1] Started by admin=${uid} for member=${userId} in session=${sessionId}`);
    const bookingRef = db.doc(`bookings/${userId}_${sessionId}`);
    await db.runTransaction(async tx => {
      console.log('👉 [ADMIN_ENROLL 2] Reading session, user, and booking docs (all reads first)...');
      const [sessionSnap, userSnap, bookingSnap] = await Promise.all([
        tx.get(db.doc(`sessions/${sessionId}`)),
        tx.get(db.doc(`users/${userId}`)),
        tx.get(bookingRef),
      ]);
      if (!sessionSnap.exists) throw new HttpsError('not-found', 'Session not found.');
      if (!userSnap.exists) throw new HttpsError('not-found', 'Member not found.');
      const session = sessionSnap.data()!;
      const user = userSnap.data()!;
      if (!user.isActive) throw new HttpsError('failed-precondition', 'Member account is inactive.');

      console.log('👉 [ADMIN_ENROLL 3] Preparing session updates...');
      const joined: string[] = Array.isArray(session.joinedUserIds) ? [...session.joinedUserIds] : [];
      if (!joined.includes(userId)) {
        joined.push(userId);
      }

      let updatedTimeSlots = session.timeSlots;
      if (timeSlot && Array.isArray(session.timeSlots)) {
        updatedTimeSlots = session.timeSlots.map((s: any) => {
          const l1 = `${s.startTime}–${s.endTime}`, l2 = `${s.startTime}-${s.endTime}`;
          if (l1 === timeSlot || l2 === timeSlot || s.startTime === timeSlot) {
            const sJoined: string[] = Array.isArray(s.joinedUserIds) ? [...s.joinedUserIds] : [];
            if (!sJoined.includes(userId)) {
              return { ...s, joinedUserIds: [...sJoined, userId] };
            }
          }
          return s;
        });
      }

      console.log('👉 [ADMIN_ENROLL 4] Writing session updates and booking record...');
      tx.update(sessionSnap.ref, {
        joinedUserIds: joined,
        ...(updatedTimeSlots ? { timeSlots: updatedTimeSlots } : {}),
        updatedAt: now(),
      });

      const revision = (bookingSnap.data()?.revision ?? 0) + 1;

      tx.set(bookingRef, {
        userId,
        sessionId,
        scheduleId: sessionId,
        className: session.title || 'Training Session',
        category: session.category || 'boxing',
        trainingType: session.type || 'team',
        date: session.startDate || now(),
        endAt: session.endDate || session.startDate || now(),
        startTime: session.startTime || '',
        endTime: session.endTime || '',
        ...(timeSlot ? { timeSlot } : {}),
        status: 'confirmed',
        notes: 'Enrolled directly by admin (Walk-in)',
        bookedAt: now(),
        cancelledAt: null,
        cancelReason: null,
        revision,
      }, { merge: true });

      notify(
        tx,
        `admin_enroll_${sessionId}_${userId}_${revision}`,
        userId,
        "You're Enrolled!",
        `You have been enrolled in "${session.title || 'Session'}" by the gym admin.`,
        'session_enrolled',
        { sessionId, bookingId: bookingRef.id }
      );

      audit(tx, uid, 'adminEnrollMember', sessionId, { userId, timeSlot });
    });

    console.log('👉 [ADMIN_ENROLL 5] Successfully completed!');
    return { success: true };
  },
  true
);

export const adminRemoveMember = callable(
  z.object({
    sessionId: id,
    userId: id,
    reason: z.string().max(500).optional(),
  }),
  'adminRemoveMember',
  async ({ sessionId, userId, reason }, uid) => {
    console.log(`👉 [ADMIN_REMOVE 1] Started by admin=${uid} for member=${userId} in session=${sessionId}`);
    const bookingRef = db.doc(`bookings/${userId}_${sessionId}`);
    await db.runTransaction(async tx => {
      console.log('👉 [ADMIN_REMOVE 2] Reading session and booking docs (all reads first)...');
      const [sessionSnap, bookingSnap] = await Promise.all([
        tx.get(db.doc(`sessions/${sessionId}`)),
        tx.get(bookingRef),
      ]);
      if (!sessionSnap.exists) throw new HttpsError('not-found', 'Session not found.');
      const session = sessionSnap.data()!;

      console.log('👉 [ADMIN_REMOVE 3] Filtering out member from joinedUserIds and timeSlots...');
      const joined: string[] = (session.joinedUserIds || []).filter((u: string) => u !== userId);

      let updatedTimeSlots = session.timeSlots;
      if (Array.isArray(session.timeSlots)) {
        updatedTimeSlots = session.timeSlots.map((s: any) => {
          const sJoined: string[] = (s.joinedUserIds || []).filter((u: string) => u !== userId);
          return { ...s, joinedUserIds: sJoined };
        });
      }

      console.log('👉 [ADMIN_REMOVE 4] Executing atomic writes...');
      tx.update(sessionSnap.ref, {
        joinedUserIds: joined,
        ...(updatedTimeSlots ? { timeSlots: updatedTimeSlots } : {}),
        updatedAt: now(),
      });

      if (bookingSnap.exists && bookingSnap.data()?.status === 'confirmed') {
        const rev = (bookingSnap.data()?.revision ?? 0) + 1;
        tx.update(bookingRef, {
          status: 'cancelled',
          cancelledAt: now(),
          cancelReason: reason || 'Removed from session by gym admin',
          cancelledBy: uid,
          revision: rev,
        });
      }

      notify(
        tx,
        `admin_remove_${sessionId}_${userId}_${Date.now()}`,
        userId,
        'Session Enrollment Cancelled',
        `You were removed from "${session.title || 'Session'}" by gym admin.`,
        'booking_cancelled',
        { sessionId, reason: reason || '' }
      );

      audit(tx, uid, 'adminRemoveMember', sessionId, { userId, reason });
    });

    console.log('👉 [ADMIN_REMOVE 5] Successfully completed!');
    return { success: true };
  },
  true
);

export const adminAdjustCredits = callable(
  z.object({
    userId: id,
    groupDelta: z.number().int().default(0),
    duoDelta: z.number().int().default(0),
    privateDelta: z.number().int().default(0),
    reason: z.string().max(500).optional(),
  }),
  'adminAdjustCredits',
  async ({ userId, groupDelta, duoDelta, privateDelta, reason }, uid) => {
    const totalDelta = groupDelta + duoDelta + privateDelta;
    await db.runTransaction(async tx => {
      const userSnap = await tx.get(db.doc(`users/${userId}`));
      if (!userSnap.exists) throw new HttpsError('not-found', 'Member not found.');
      const u = userSnap.data()!;

      const newGroup = Math.max(0, (u.groupSessionsRemaining ?? 0) + groupDelta);
      const newDuo = Math.max(0, (u.duoSessionsRemaining ?? 0) + duoDelta);
      const newPrivate = Math.max(0, (u.privateSessionsRemaining ?? 0) + privateDelta);
      const newTotal = Math.max(0, (u.sessionsRemaining ?? 0) + totalDelta);

      tx.update(userSnap.ref, {
        groupSessionsRemaining: newGroup,
        duoSessionsRemaining: newDuo,
        privateSessionsRemaining: newPrivate,
        sessionsRemaining: newTotal,
        updatedAt: now(),
      });

      if (totalDelta !== 0) {
        const sign = totalDelta > 0 ? `+${totalDelta}` : `${totalDelta}`;
        const paymentRef = db.collection('payments').doc();
        tx.create(paymentRef, {
          userId,
          productName: `Credit Adjustment (${sign})`,
          amount: 0,
          currency: 'usd',
          credits: totalDelta,
          paymentMethod: 'Admin Adjustment',
          status: 'completed',
          note: reason || 'Adjusted by admin',
          createdAt: now(),
          updatedAt: now(),
          paidAt: now(),
        });

        notify(
          tx,
          `credit_adj_${paymentRef.id}`,
          userId,
          'Credits Adjusted',
          `Your session credits were updated by admin (${sign} credits).`,
          'credit_adjustment'
        );
      }

      audit(tx, uid, 'adminAdjustCredits', userId, { groupDelta, duoDelta, privateDelta, reason });
    });

    return { success: true };
  },
  true
);

export const adminAssignPlan = callable(
  z.object({
    userId: id,
    planId: id,
    paymentMethod: z.string().max(50).default('Cash'),
    customCredits: z.number().int().min(0).max(1000).optional(),
    note: z.string().max(500).optional(),
  }),
  'adminAssignPlan',
  async ({ userId, planId, paymentMethod, customCredits, note }, uid) => {
    await db.runTransaction(async tx => {
      const [userSnap, planSnap] = await Promise.all([
        tx.get(db.doc(`users/${userId}`)),
        tx.get(db.doc(`membershipPlans/${planId}`)),
      ]);
      if (!userSnap.exists) throw new HttpsError('not-found', 'Member not found.');
      if (!planSnap.exists) throw new HttpsError('not-found', 'Membership plan not found.');
      const user = userSnap.data()!;
      const plan = planSnap.data()!;

      const sessionCount = customCredits ?? plan.sessionCount ?? plan.creditsPerPurchase ?? 0;
      const trainingType = ((plan.trainingType || plan.category || 'group') as string).toLowerCase();

      let groupInc = 0;
      let duoInc = 0;
      let privateInc = 0;

      if (trainingType.includes('group') || trainingType.includes('team')) {
        groupInc = sessionCount;
      } else if (trainingType.includes('duo')) {
        duoInc = sessionCount;
      } else if (trainingType.includes('private') || trainingType.includes('individual')) {
        privateInc = sessionCount;
      } else {
        groupInc = sessionCount;
      }

      const userUpdates: Record<string, any> = {
        membershipPlanId: planId,
        membershipPlanName: plan.name || '',
        isActive: true,
        updatedAt: now(),
      };
      if (plan.category) userUpdates.membershipPlanCategory = plan.category;
      if (groupInc > 0) userUpdates.groupSessionsRemaining = (user.groupSessionsRemaining ?? 0) + groupInc;
      if (duoInc > 0) userUpdates.duoSessionsRemaining = (user.duoSessionsRemaining ?? 0) + duoInc;
      if (privateInc > 0) userUpdates.privateSessionsRemaining = (user.privateSessionsRemaining ?? 0) + privateInc;
      if (sessionCount > 0) userUpdates.sessionsRemaining = (user.sessionsRemaining ?? 0) + sessionCount;

      tx.update(userSnap.ref, userUpdates);

      const paymentRef = db.collection('payments').doc();
      const isFree = paymentMethod.toLowerCase().includes('free') || paymentMethod.toLowerCase().includes('comp');
      const amount = isFree ? 0 : (plan.price ?? 0);

      tx.create(paymentRef, {
        userId,
        membershipPlanId: planId,
        productName: plan.name || 'Membership Plan',
        amount,
        currency: 'usd',
        credits: sessionCount,
        trainingType: plan.trainingType || 'group',
        paymentMethod,
        status: 'completed',
        note: note || `Assigned by admin (${paymentMethod})`,
        createdAt: now(),
        updatedAt: now(),
        paidAt: now(),
      });

      notify(
        tx,
        `plan_assign_${paymentRef.id}`,
        userId,
        'Plan Assigned',
        `${plan.name || 'Membership Plan'} (${sessionCount} credits) was assigned to your account.`,
        'membership_purchased'
      );

      audit(tx, uid, 'adminAssignPlan', planId, { userId, paymentMethod, sessionCount });
    });

    return { success: true };
  },
  true
);

export const cancelPendingPayment = callable(
  z.object({ paymentId: id }),
  'cancelPendingPayment',
  async ({ paymentId }, uid) => {
    const ref = db.doc(`payments/${paymentId}`);
    await db.runTransaction(async tx => {
      const snap = await tx.get(ref);
      if (!snap.exists) return;
      const data = snap.data()!;
      if (data.userId !== uid) throw new HttpsError('permission-denied', 'This order belongs to another user.');
      if (data.status !== 'pending') throw new HttpsError('failed-precondition', 'Only pending orders can be cancelled.');
      tx.delete(ref);
      audit(tx, uid, 'cancelPendingPayment', paymentId);
    });
    return { success: true };
  },
  false
);
