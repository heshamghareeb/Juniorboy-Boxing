'use client';

import { useEffect, useState } from 'react';
import { where } from 'firebase/firestore';
import { call } from '@/lib/firebase';
import { formatMemberName, searchMemberUids, useMemberProfiles } from '@/lib/member-cache';
import { Row } from '@/lib/types';
import { dateLabel, timeLabel, asDate, errorMessage, downloadCSV } from '@/lib/utils';
import { Button, Notice, PageHeading, Loading, Empty, Modal } from '../ui';
import { Status } from './data';
import { useRows } from '@/lib/hooks';
import { MemberCell } from './member-cell';
import { MemberEditor } from './members';

export function AdminBookings() {
  return <ClassAdminBookings />;
}

function ClassAdminBookings() {
  const [status, setStatus] = useState('');
  const [member, setMember] = useState('');
  const [resolvedUid, setResolvedUid] = useState('');
  const [error, setError] = useState('');
  const [busy, setBusy] = useState('');
  const [exporting, setExporting] = useState(false);
  const [selectedMember, setSelectedMember] = useState<Row | null>(null);

  useEffect(() => {
    const trimmed = member.trim();
    if (!trimmed) {
      setResolvedUid('');
      return;
    }
    let active = true;
    if (!trimmed.includes('@') && !trimmed.includes(' ') && trimmed.length >= 20) {
      setResolvedUid(trimmed);
      return;
    }
    const timer = setTimeout(async () => {
      const uids = await searchMemberUids(trimmed);
      if (active) {
        setResolvedUid(uids[0] || '');
      }
    }, 300);
    return () => {
      active = false;
      clearTimeout(timer);
    };
  }, [member]);

  const targetUid = resolvedUid || (member.trim().length >= 20 ? member.trim() : '');
  const bookingsData = useRows(
    'bookings',
    [
      ...(status ? [where('status', '==', status)] : []),
      ...(targetUid ? [where('userId', '==', targetUid)] : []),
    ],
    `${status}:${targetUid}`
  );

  const paymentsData = useRows('payments', [where('status', '==', 'completed')]);
  const usersWithCredits = useRows('users', [where('sessionsRemaining', '>', 0)]);

  // Format booking rows
  const bookingRows: Row[] = bookingsData.rows.map((b) => ({
    id: b.id,
    userId: b.userId,
    className: b.className || 'Boxing Session',
    date: b.date,
    endAt: b.endAt,
    status: b.status,
    isClassBooking: true,
    raw: b,
  }));

  // Format completed session purchases
  const paymentRows: Row[] = paymentsData.rows
    .filter((p: Row) => {
      if (p.productId && p.orderType === 'product') return false;
      return Boolean(p.sessionId || p.credits || p.membershipPlanId || p.sessionTitle);
    })
    .map((p: Row) => {
      let title = p.sessionTitle as string | undefined;
      if (!title) {
        if (p.credits) title = `${p.credits} Sessions Package`;
        else if (p.productName) title = p.productName as string;
        else title = 'Session Purchase';
      }
      return {
        id: p.id,
        userId: p.userId,
        className: title,
        date: p.createdAt,
        status: 'confirmed',
        isSessionPurchase: true,
        raw: p,
      };
    });

  // Format members with active session credits who don't already have a booking
  const creditRows: Row[] = usersWithCredits.rows
    .filter((u: Row) => {
      const hasBooking = bookingRows.some((b) => b.userId === u.id);
      const hasPayment = paymentRows.some((p) => p.userId === u.id);
      return !hasBooking && !hasPayment;
    })
    .map((u: Row) => ({
      id: `credit_${u.id}`,
      userId: u.id,
      className: `${u.sessionsRemaining} Sessions Purchased`,
      date: u.updatedAt || u.memberSince || new Date(),
      status: 'confirmed',
      isCreditOnly: true,
      raw: u,
    }));

  const allCombined = [...bookingRows, ...paymentRows, ...creditRows];

  const allUids = Array.from(new Set(allCombined.map((b) => b.userId as string).filter(Boolean)));
  const profiles = useMemberProfiles(allUids);

  const displayRows = allCombined.filter((b) => {
    if (status && b.status !== status) return false;
    const filter = member.trim().toLowerCase();
    if (!filter) return true;
    if (targetUid && b.userId === targetUid) return true;
    const p = profiles[b.userId];
    const name = p ? formatMemberName(p.fullName, p.lastName, p.childName).toLowerCase() : '';
    const email = (p?.email || '').toLowerCase();
    return (
      (b.userId || '').toLowerCase().includes(filter) ||
      name.includes(filter) ||
      email.includes(filter) ||
      (b.className || '').toLowerCase().includes(filter)
    );
  });

  async function action(name: string, row: Row, extra = {}) {
    setBusy(row.id);
    setError('');
    try {
      await call(name, { bookingId: row.id, ...extra });
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setBusy('');
    }
  }

  return (
    <>
      <PageHeading title="Bookings." />
      <div className="admin-toolbar">
        <input
          className="search-input"
          aria-label="Filter by member name, email, or ID"
          placeholder="Filter by name, email or ID"
          value={member}
          onChange={(e) => setMember(e.target.value)}
        />
        <select
          className="search-input"
          aria-label="Filter by status"
          value={status}
          onChange={(e) => setStatus(e.target.value)}
          style={{
            width: 'auto',
            minWidth: 160,
            cursor: 'pointer',
            padding: '10px 16px',
            borderRadius: 8,
            border: '1px solid var(--line)',
            background: 'var(--surface)',
            color: 'var(--text)',
            minHeight: 46,
          }}
        >
          <option value="">All statuses</option>
          <option value="confirmed">Confirmed</option>
          <option value="completed">Completed</option>
          <option value="cancelled">Cancelled</option>
          <option value="no-show">No-show</option>
        </select>
        <Button className="secondary" onClick={() => setExporting(true)}>
          Export CSV
        </Button>
      </div>

      {(error || bookingsData.error) && <Notice error>{error || bookingsData.error}</Notice>}

      {bookingsData.loading ? (
        <Loading />
      ) : displayRows.length ? (
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Member</th>
                <th>Class</th>
                <th>Session</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {displayRows.map((b) => (
                <tr key={b.id}>
                  <td>
                    <MemberCell uid={b.userId} profile={profiles[b.userId]} />
                  </td>
                  <td>{b.className}</td>
                  <td>
                    {dateLabel(b.date)}
                    {b.isClassBooking && (
                      <>
                        <br />
                        <span className="muted">{timeLabel(b.date)} PT</span>
                      </>
                    )}
                    {!b.isClassBooking && (
                      <>
                        <br />
                        <span className="muted">
                          {b.isSessionPurchase ? 'Purchased Session' : 'Active Balance'}
                        </span>
                      </>
                    )}
                  </td>
                  <td>
                    <Status row={b} />
                  </td>
                  <td>
                    <div className="row">
                      {b.isClassBooking && b.status === 'confirmed' && (
                        <>
                          {asDate(b.endAt) <= new Date() && (
                            <>
                              <Button
                                className="small"
                                disabled={busy === b.id}
                                onClick={() =>
                                  action('markBookingCompleted', b, { status: 'completed' })
                                }
                              >
                                Present
                              </Button>
                              <Button
                                className="secondary small"
                                disabled={busy === b.id}
                                onClick={() =>
                                  action('markBookingCompleted', b, { status: 'no-show' })
                                }
                              >
                                No-show
                              </Button>
                            </>
                          )}
                          <Button
                            className="text small"
                            disabled={busy === b.id}
                            onClick={() => {
                              const reason = window.prompt('Cancellation reason');
                              if (reason) action('cancelBooking', b, { reason });
                            }}
                          >
                            Cancel
                          </Button>
                        </>
                      )}
                      {!b.isClassBooking && (
                        <Button
                          className="secondary small"
                          onClick={() =>
                            setSelectedMember(
                              profiles[b.userId]
                                ? { id: b.userId, ...profiles[b.userId] }
                                : { id: b.userId }
                            )
                          }
                        >
                          View Member
                        </Button>
                      )}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ) : (
        <Empty>No matching bookings.</Empty>
      )}

      {exporting && <ExportDialog collection="bookings" onClose={() => setExporting(false)} />}
      {selectedMember && (
        <MemberEditor member={selectedMember} onClose={() => setSelectedMember(null)} />
      )}
    </>
  );
}

export function ExportDialog({
  collection,
  onClose,
}: {
  collection: 'bookings' | 'payments';
  onClose: () => void;
}) {
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  return (
    <Modal title="Export CSV" onClose={onClose}>
      <form
        className="stack"
        onSubmit={async (e) => {
          e.preventDefault();
          const f = new FormData(e.currentTarget);
          setBusy(true);
          try {
            const result = await call<{ csv: string; filename: string }>('exportBookingsCSV', {
              collection,
              from: new Date(String(f.get('from'))).toISOString(),
              to: new Date(+new Date(String(f.get('to'))) + 86400000).toISOString(),
            });
            downloadCSV(result.csv, result.filename);
            onClose();
          } catch (e) {
            setError(errorMessage(e));
          } finally {
            setBusy(false);
          }
        }}
      >
        <label className="field">
          From
          <input name="from" type="date" required />
        </label>
        <label className="field">
          Through
          <input name="to" type="date" required />
        </label>
        {error && <Notice error>{error}</Notice>}
        <Button busy={busy}>Download CSV</Button>
      </form>
    </Modal>
  );
}
