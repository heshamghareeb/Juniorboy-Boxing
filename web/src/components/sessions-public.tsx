'use client';
import { useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { doc, getDoc } from 'firebase/firestore';
import { call, db } from '@/lib/firebase';
import { useDocument, useRows } from '@/lib/hooks';
import { Row } from '@/lib/types';
import { errorMessage } from '@/lib/utils';
import { useAuth } from './providers';
import { isStaff } from '@/lib/permissions';
import { ActionLink, Button, Empty, Loading, Modal, Notice, PageHeading } from './ui';
import { ParentPayment } from './parent-payment';
import { AuthModal } from './auth-modal';
import './sessions-public.css';

function typeLabel(type?: string): string {
  if (type === 'duo') return 'Duo';
  if (type === 'team') return 'Team';
  return 'Individual';
}

function fmtDate(v: any): string {
  const d = v?.toDate ? v.toDate() : new Date(v);
  return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
}

function dateRange(row: Row): string {
  if (!row.startDate || !row.endDate) return '';
  const start = fmtDate(row.startDate), end = fmtDate(row.endDate);
  return start === end ? start : `${start} – ${end}`;
}

function getSessionTimeSlots(row: Row): Array<{ startTime: string; endTime: string; maxParticipants?: number; joinedUserIds?: string[] }> {
  if (Array.isArray(row.timeSlots) && row.timeSlots.length > 0) {
    return row.timeSlots
      .filter((s: any) => s && s.startTime && s.endTime)
      .map((s: any) => ({
        startTime: s.startTime,
        endTime: s.endTime,
        maxParticipants: Number(s.maxParticipants) || Number(row.maxParticipants) || 0,
        joinedUserIds: Array.isArray(s.joinedUserIds) ? s.joinedUserIds : [],
      }));
  }
  if (row.startTime && row.endTime) {
    return [{
      startTime: row.startTime,
      endTime: row.endTime,
      maxParticipants: Number(row.maxParticipants) || 0,
      joinedUserIds: Array.isArray(row.joinedUserIds) ? row.joinedUserIds : [],
    }];
  }
  return [];
}

function sessionTimesLabel(row: Row): string {
  const slots = getSessionTimeSlots(row);
  if (slots.length === 0) return '';
  return slots.map((s) => `${s.startTime}–${s.endTime}`).join(', ');
}

function isPast(row: Row): boolean {
  const end = row.endDate?.toDate ? row.endDate.toDate() : new Date(row.endDate);
  return end < new Date(new Date().toDateString());
}

export type SessionMember = { uid: string; fullName: string; childName: string; profilePicUrl: string | null; timeSlot?: string | null };

export function useSessionMembers(sessionId: string, joinedUserIds: string[] = []) {
  const [members, setMembers] = useState<SessionMember[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!sessionId || joinedUserIds.length === 0) {
      setMembers([]);
      setLoading(false);
      return;
    }
    let cancelled = false;
    setLoading(true);

    async function fetchFallback() {
      if (cancelled) return;
      try {
        const loaded: SessionMember[] = [];
        for (const uid of joinedUserIds) {
          try {
            const snap = await getDoc(doc(db, 'users', uid));
            if (snap.exists()) {
              const data = snap.data();
              loaded.push({
                uid,
                fullName: data.fullName || 'Member',
                childName: data.childName || '',
                profilePicUrl: data.profilePicUrl || data.avatarUrl || null,
              });
            } else {
              loaded.push({ uid, fullName: 'Member', childName: '', profilePicUrl: null });
            }
          } catch {
            loaded.push({ uid, fullName: 'Member', childName: '', profilePicUrl: null });
          }
        }
        if (!cancelled) setMembers(loaded);
      } catch {
        if (!cancelled) {
          setMembers(joinedUserIds.map((uid) => ({ uid, fullName: 'Member', childName: '', profilePicUrl: null })));
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    }

    call<{ members: SessionMember[] }>('getSessionMembers', { sessionId })
      .then((r) => {
        if (!cancelled) {
          if (r?.members && r.members.length > 0) {
            setMembers(r.members);
            setLoading(false);
          } else {
            fetchFallback();
          }
        }
      })
      .catch(() => {
        if (!cancelled) {
          fetchFallback();
        }
      });

    return () => {
      cancelled = true;
    };
  }, [sessionId, joinedUserIds.join(',')]);

  return { members, loading };
}

export function JoinedAvatars({ members, totalCount, size = 28 }: { members: SessionMember[]; totalCount: number; size?: number }) {
  if (!totalCount) return null;
  const visible = members.filter((m) => m.profilePicUrl).slice(0, 5);
  const overflow = totalCount - visible.length;
  const step = Math.round(size * 0.65);
  const width = visible.length === 0 && overflow > 0 ? size : step * visible.length + (overflow > 0 ? step : 0) + (size - step);
  return (
    <div style={{ position: 'relative', height: size, width, flexShrink: 0 }}>
      {visible.map((m, i) => (
        <img
          key={m.uid || i}
          src={m.profilePicUrl!}
          alt=""
          style={{
            position: 'absolute',
            left: i * step,
            top: 0,
            width: size,
            height: size,
            borderRadius: '50%',
            border: '2px solid var(--bg)',
            objectFit: 'cover',
            boxSizing: 'border-box',
            zIndex: i + 1,
          }}
        />
      ))}
      {overflow > 0 && (
        <div
          style={{
            position: 'absolute',
            left: visible.length * step,
            top: 0,
            width: size,
            height: size,
            borderRadius: '50%',
            border: '2px solid var(--bg)',
            background: 'var(--red, #e50914)',
            color: '#fff',
            fontSize: 11,
            fontWeight: 700,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            boxSizing: 'border-box',
            zIndex: visible.length + 1,
          }}
        >
          +{overflow}
        </div>
      )}
    </div>
  );
}

export function JoinedMembersModal({ session, onClose }: { session: Row; onClose: () => void }) {
  const joinedUserIds: string[] = session.joinedUserIds || [];
  const { members, loading } = useSessionMembers(session.id, joinedUserIds);
  const slots = getSessionTimeSlots(session);
  const [selectedFilterSlot, setSelectedFilterSlot] = useState<number | null>(null);

  const displayedMembers = selectedFilterSlot !== null && slots[selectedFilterSlot]
    ? members.filter((m) => (slots[selectedFilterSlot].joinedUserIds || []).includes(m.uid))
    : members;

  return (
    <Modal title="Joined members" onClose={onClose}>
      <div className="stack">
        <div>
          <h3 style={{ margin: 0 }}>{session.title}</h3>
          <div className="parent-detail-chips" role="list" aria-label="Session details" style={{ marginTop: 8 }}>
            <span className="parent-chip" role="listitem">{typeLabel(session.type)}</span>
            <span className="parent-chip" role="listitem">{dateRange(session)}</span>
            {slots.map((slot, i) => (
              <span key={i} className="parent-chip" role="listitem">
                {slot.startTime}–{slot.endTime}{slot.maxParticipants ? ` (${(slot.joinedUserIds || []).length}/${slot.maxParticipants})` : ''}
              </span>
            ))}
          </div>
          <p className="muted" style={{ fontSize: 13, marginTop: 8 }}>{joinedUserIds.length} / {session.maxParticipants} joined</p>

          {slots.length > 1 && (
            <div className="row" style={{ gap: 6, flexWrap: 'wrap', marginTop: 10 }}>
              <button
                type="button"
                onClick={() => setSelectedFilterSlot(null)}
                className={`parent-chip parent-chip-button ${selectedFilterSlot === null ? 'selected' : ''}`}
                style={{ fontSize: 12, padding: '4px 10px' }}
              >
                All ({joinedUserIds.length})
              </button>
              {slots.map((slot, i) => {
                const sJoined = (slot.joinedUserIds || []).length;
                const isSel = selectedFilterSlot === i;
                return (
                  <button
                    key={i}
                    type="button"
                    onClick={() => setSelectedFilterSlot(i)}
                    className={`parent-chip parent-chip-button ${isSel ? 'selected' : ''}`}
                    style={{ fontSize: 12, padding: '4px 10px' }}
                  >
                    {slot.startTime}–{slot.endTime} ({sJoined}/{slot.maxParticipants || 1})
                  </button>
                );
              })}
            </div>
          )}
        </div>
        {loading ? (
          <Loading />
        ) : joinedUserIds.length === 0 ? (
          <Empty>No one has joined yet.</Empty>
        ) : displayedMembers.length === 0 ? (
          <Empty>{selectedFilterSlot !== null ? 'No members have joined this timing yet.' : 'No member details available.'}</Empty>
        ) : (
          <div className="stack" style={{ gap: 10 }}>
            {displayedMembers.map((m, idx) => {
              const displayName = (m.childName || '').trim() || (m.fullName && m.fullName.trim() !== 'Member' ? m.fullName.trim() : '') || `Member ${idx + 1}`;
              const initial = displayName.charAt(0).toUpperCase() || 'M';
              return (
                <div key={m.uid || idx} className="row" style={{ gap: 10, alignItems: 'center' }}>
                  {m.profilePicUrl ? (
                    <img src={m.profilePicUrl} alt="" style={{ width: 36, height: 36, borderRadius: '50%', objectFit: 'cover' }} />
                  ) : (
                    <div style={{ width: 36, height: 36, borderRadius: '50%', background: 'var(--accent-tint)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 'bold', fontSize: 14 }}>
                      {initial}
                    </div>
                  )}
                  <div style={{ display: 'flex', flexDirection: 'column' }}>
                    <span>{displayName}</span>
                    {slots.length > 1 && m.timeSlot && <span className="muted" style={{ fontSize: 12 }}>{m.timeSlot}</span>}
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </Modal>
  );
}

export function SessionCard({ session }: { session: Row }) {
  const joined = (session.joinedUserIds || []).length;
  const { members } = useSessionMembers(session.id, session.joinedUserIds || []);
  const [showMembers, setShowMembers] = useState(false);
  return (
    <article className="card parent-offer-card" key={session.id}>
      {session.images?.[0] && (
        <img className="parent-offer-cover" src={session.images[0]} alt={session.title || ''} loading="lazy" />
      )}
      <p className="eyebrow parent-offer-eyebrow">
        {[typeLabel(session.type), dateRange(session), sessionTimesLabel(session)].filter(Boolean).join(' · ')}
      </p>
      <h3 className="parent-offer-title" title={session.title}>{session.title}</h3>
      <p className="parent-offer-desc" title={session.description}>{session.description}</p>
      <div className="parent-offer-footer">
        <div className="parent-offer-footer-row">
          <div className="parent-offer-pricing">
            <strong>${Number(session.price || 0).toFixed(2)}</strong>
          </div>
          <button type="button" onClick={() => joined && setShowMembers(true)} className="row" style={{ gap: 6, alignItems: 'center', background: 'transparent', border: 0, padding: 0, cursor: joined ? 'pointer' : 'default' }}>
            <JoinedAvatars members={members} totalCount={joined} />
            <span className="parent-offer-count muted">{joined} / {session.maxParticipants} joined</span>
          </button>
        </div>
        <ActionLink href={`/offers/detail?id=${encodeURIComponent(session.id)}`}>View details</ActionLink>
      </div>
      {showMembers && <JoinedMembersModal session={session} onClose={() => setShowMembers(false)} />}
    </article>
  );
}

export function SessionsPage() {
  const { rows, loading, error } = useRows('sessions');
  const upcoming = rows.filter((r) => !isPast(r));

  return (
    <div className="container page-wrap">
      <PageHeading eyebrow="Training sessions" title="Find your next round.">Book a place in an upcoming session.</PageHeading>
      {error && <Notice error>{error}</Notice>}
      {loading ? (
        <Loading />
      ) : upcoming.length ? (
        <div className="offer-grid parent-offers-grid">
          {upcoming.map((s) => <SessionCard key={s.id} session={s} />)}
        </div>
      ) : (
        <Empty>No upcoming sessions are available right now.</Empty>
      )}
    </div>
  );
}

export function SessionDetailPage({ id }: { id: string }) {
  const session = useDocument(`sessions/${id}`);
  const { user, profile } = useAuth();
  const joinedUserIds: string[] = session?.joinedUserIds || [];
  const joined = !!user && joinedUserIds.includes(user.uid);
  const full = joinedUserIds.length >= (session?.maxParticipants || 0);
  const { members } = useSessionMembers(session?.id || '', joinedUserIds);
  const [showMembers, setShowMembers] = useState(false);
  const staff = isStaff(profile);

  const slots = session ? getSessionTimeSlots(session) : [];
  const [selectedSlotIndex, setSelectedSlotIndex] = useState<number>(0);
  const activeSlotIndex = selectedSlotIndex < slots.length ? selectedSlotIndex : 0;
  const selectedSlot = slots[activeSlotIndex] || slots[0];
  const selectedSlotFull = selectedSlot?.maxParticipants ? (selectedSlot.joinedUserIds || []).length >= selectedSlot.maxParticipants : false;
  const allSlotsFull = slots.length > 0 ? slots.every((s) => s.maxParticipants && (s.joinedUserIds || []).length >= s.maxParticipants) : full;
  const timeParam = selectedSlot ? `&time=${encodeURIComponent(`${selectedSlot.startTime}–${selectedSlot.endTime}`)}` : '';

  return (
    <div className="container page-wrap parent-offer-detail">
      {!session ? (
        <Loading />
      ) : (
        <>
          {session.images?.[0] && <img className="parent-detail-cover" src={session.images[0]} alt={session.title || ''} />}
          <div className="parent-detail-info">
            <PageHeading title={session.title}>{session.description}</PageHeading>
            <div className="parent-detail-chips" role="list" aria-label="Session details">
              <span className="parent-chip" role="listitem">{typeLabel(session.type)}</span>
              <span className="parent-chip" role="listitem">{dateRange(session)}</span>
              <span className="parent-chip" role="listitem">${Number(session.price || 0).toFixed(2)}</span>
            </div>

            {slots.length > 0 && (
              <div style={{ marginTop: 18 }}>
                <div style={{ fontSize: 12, fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.05em', color: 'var(--muted)', marginBottom: 10 }}>
                  {slots.length > 1 ? 'Select Session Timing' : 'Timing'}
                </div>
                <div className="row" style={{ gap: 10, flexWrap: 'wrap', alignItems: 'center' }}>
                  {slots.map((slot, i) => {
                    const isSelected = i === activeSlotIndex;
                    const joinedCount = (slot.joinedUserIds || []).length;
                    const slotMax = slot.maxParticipants || 0;
                    const slotFull = slotMax > 0 && joinedCount >= slotMax;
                    const spotsLeft = slotMax > 0 ? Math.max(0, slotMax - joinedCount) : null;
                    const spotsLabel = slotFull
                      ? ' (Full)'
                      : spotsLeft !== null
                      ? ` (${spotsLeft} left)`
                      : '';
                    return (
                      <button
                        key={i}
                        type="button"
                        onClick={() => !slotFull && setSelectedSlotIndex(i)}
                        className={`parent-chip parent-chip-button ${isSelected ? 'selected' : ''} ${slotFull ? 'disabled' : ''}`}
                        role="listitem"
                        disabled={slotFull}
                        aria-pressed={isSelected}
                        title={slotFull ? 'Time slot is full' : `Choose timing: ${slot.startTime}–${slot.endTime} (${spotsLeft} spots left)`}
                        style={slotFull ? { opacity: 0.5, cursor: 'not-allowed' } : undefined}
                      >
                        {isSelected ? '✓ ' : ''}{slot.startTime}–{slot.endTime}{spotsLabel}
                      </button>
                    );
                  })}
                </div>
              </div>
            )}

            <div style={{ marginTop: 18 }}>
              <button type="button" onClick={() => joinedUserIds.length && setShowMembers(true)} className="row" style={{ gap: 8, alignItems: 'center', background: 'transparent', border: 0, padding: 0, cursor: joinedUserIds.length ? 'pointer' : 'default' }}>
                <JoinedAvatars members={members} totalCount={joinedUserIds.length} />
                <span className="muted">{joinedUserIds.length} / {session.maxParticipants} joined</span>
              </button>
            </div>

            <div style={{ marginTop: 22 }}>
              {!staff && (
                <ActionLink href={joined || selectedSlotFull || allSlotsFull ? '#' : `/offers/book?session=${encodeURIComponent(id)}${timeParam}`}>
                  {joined ? "You're in" : selectedSlotFull ? 'Selected Time Full' : allSlotsFull ? 'Full' : `Join · $${Number(session.price || 0).toFixed(2)}`}
                </ActionLink>
              )}
            </div>
          </div>
          {showMembers && <JoinedMembersModal session={session} onClose={() => setShowMembers(false)} />}
        </>
      )}
    </div>
  );
}


export function SessionJoinPage({ id, initialTime }: { id: string; initialTime?: string }) {
  const router = useRouter();
  const { user, profile, loading: authLoading } = useAuth();
  const staff = isStaff(profile);
  const session = useDocument(`sessions/${id}`);
  const [step, setStep] = useState<'review' | 'payment' | 'result'>('review');
  const [secret, setSecret] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [showAuth, setShowAuth] = useState(false);
  const submittedRef = useRef(false);
  const [submitted, setSubmitted] = useState(false);

  const slots = session ? getSessionTimeSlots(session) : [];
  const [selectedTime, setSelectedTime] = useState<string>(initialTime || '');

  useEffect(() => {
    if (!selectedTime && slots.length > 0) {
      const available = slots.find((s) => !s.maxParticipants || (s.joinedUserIds || []).length < s.maxParticipants) || slots[0];
      setSelectedTime(initialTime || `${available.startTime}–${available.endTime}`);
    }
  }, [slots, initialTime, selectedTime]);

  useEffect(() => {
    const saved = sessionStorage.getItem(`session-join:${id}`);
    if (saved && user) {
      sessionStorage.removeItem(`session-join:${id}`);
    }
  }, [id, user]);

  const joinedUserIds: string[] = session?.joinedUserIds || [];
  const joined = !!user && joinedUserIds.includes(user.uid);
  const full = joinedUserIds.length >= (session?.maxParticipants || 0);

  const currentSlot = slots.find((s) => `${s.startTime}–${s.endTime}` === selectedTime || `${s.startTime}-${s.endTime}` === selectedTime) || slots[0];
  const currentSlotFull = currentSlot?.maxParticipants ? (currentSlot.joinedUserIds || []).length >= currentSlot.maxParticipants : false;
  const allSlotsFull = slots.length > 0 ? slots.every((s) => s.maxParticipants && (s.joinedUserIds || []).length >= s.maxParticipants) : full;

  async function begin() {
    if (!user) {
      sessionStorage.setItem(`session-join:${id}`, '1');
      setShowAuth(true);
      return;
    }
    setBusy(true);
    setError('');
    try {
      const r = await call<{ paymentId: string; clientSecret?: string; status: string }>('joinSession', {
        sessionId: id,
        requestId: crypto.randomUUID(),
        timeSlot: selectedTime || (slots[0] ? `${slots[0].startTime}–${slots[0].endTime}` : undefined),
      });
      if (['completed', 'refunded', 'refund_pending'].includes(r.status)) {
        setStep('result');
      } else if (r.clientSecret) {
        setSecret(r.clientSecret);
        setStep('payment');
      } else {
        setError('Payment is processing. Check back shortly.');
      }
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setBusy(false);
    }
  }

  if (!session) return <div className="container page-wrap"><Loading /></div>;

  return (
    <div className="container page-wrap">
      <PageHeading title={session.title}>{[dateRange(session), selectedTime || sessionTimesLabel(session)].filter(Boolean).join(' · ')}</PageHeading>
      <div className="parent-flow card stack">
        {step === 'review' && (
          <>
            <h2>Confirm your spot</h2>
            {staff ? (
              <Empty>Admin accounts can't join sessions.</Empty>
            ) : joined ? (
              <Notice>You've already joined this session.</Notice>
            ) : allSlotsFull ? (
              <Empty>This session is completely full.</Empty>
            ) : (
              <>
                <p>${Number(session.price || 0).toFixed(2)} · pay securely to confirm your place.</p>
                {slots.length > 1 && (
                  <div style={{ margin: '8px 0 16px 0' }}>
                    <label style={{ fontSize: 13, fontWeight: 600, display: 'block', marginBottom: 8 }}>
                      Choose your session time:
                    </label>
                    <div className="row" style={{ gap: 8, flexWrap: 'wrap' }}>
                      {slots.map((s, idx) => {
                        const label = `${s.startTime}–${s.endTime}`;
                        const isSel = selectedTime ? (selectedTime === label || selectedTime === `${s.startTime}-${s.endTime}`) : idx === 0;
                        const sJoined = (s.joinedUserIds || []).length;
                        const sMax = s.maxParticipants || 0;
                        const sFull = sMax > 0 && sJoined >= sMax;
                        const sLeft = sMax > 0 ? Math.max(0, sMax - sJoined) : null;
                        return (
                          <button
                            key={idx}
                            type="button"
                            disabled={sFull}
                            onClick={() => !sFull && setSelectedTime(label)}
                            className={`parent-chip parent-chip-button ${isSel ? 'selected' : ''} ${sFull ? 'disabled' : ''}`}
                            style={sFull ? { opacity: 0.5, cursor: 'not-allowed' } : undefined}
                            aria-pressed={isSel}
                            title={sFull ? 'Time slot is full' : `${label} (${sLeft} spots left)`}
                          >
                            {isSel ? '✓ ' : ''}{label}{sFull ? ' (Full)' : sLeft !== null ? ` (${sLeft} left)` : ''}
                          </button>
                        );
                      })}
                    </div>
                  </div>
                )}
                {slots.length === 1 && (
                  <p className="muted" style={{ margin: '0 0 14px 0', fontSize: 13 }}>
                    Session Time: <strong>{slots[0].startTime}–{slots[0].endTime}</strong>
                    {slots[0].maxParticipants ? ` · ${(slots[0].joinedUserIds || []).length}/${slots[0].maxParticipants} joined` : ''}
                  </p>
                )}
                {currentSlotFull && (
                  <Notice error>The selected time slot ({selectedTime}) is full. Please choose another timing.</Notice>
                )}
                <Button busy={busy || authLoading} disabled={currentSlotFull || allSlotsFull} onClick={begin}>
                  {currentSlotFull ? 'Selected Time Full' : 'Continue to card payment'}
                </Button>
              </>
            )}
          </>
        )}
        {step === 'payment' && (
          <>
            <h2>Card payment</h2>
            <p>${Number(session.price || 0).toFixed(2)}{selectedTime ? ` · ${selectedTime}` : ''}</p>
            {secret && (
              <ParentPayment
                secret={secret}
                returnPath={`/offers/book?session=${encodeURIComponent(id)}${selectedTime ? `&time=${encodeURIComponent(selectedTime)}` : ''}`}
                onConfirming={() => { submittedRef.current = true; setSubmitted(true); }}
                onFailure={() => { submittedRef.current = false; setSubmitted(false); }}
                onSubmitted={() => setStep('result')}
              />
            )}
            {submitted && <Notice>Payment submitted. Waiting for confirmation.</Notice>}
          </>
        )}
        {step === 'result' && (
          <>
            <h2>{joined ? "You're in!" : 'Payment submitted'}</h2>
            <p className="muted">{joined ? `You've joined ${session.title}${selectedTime ? ` for the ${selectedTime} timing` : ''}.` : 'Confirming your payment — this page will update automatically.'}</p>
            <ActionLink href={`/offers/detail?id=${encodeURIComponent(id)}`}>Back to session</ActionLink>
          </>
        )}
        {error && <Notice error>{error}</Notice>}
      </div>
      {showAuth && (
        <AuthModal
          onClose={() => setShowAuth(false)}
          onSignedIn={() => { setShowAuth(false); }}
        />
      )}
    </div>
  );
}

