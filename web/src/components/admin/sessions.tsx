'use client';
import { FormEvent, useState } from 'react';
import { Timestamp, doc, setDoc, deleteDoc, serverTimestamp } from 'firebase/firestore';
import { ref, uploadBytes, getDownloadURL } from 'firebase/storage';
import { db, storage } from '@/lib/firebase';
import { useRows } from '@/lib/hooks';
import { useMemberProfiles } from '@/lib/member-cache';
import { Row, SessionTimeSlot } from '@/lib/types';
import { errorMessage } from '@/lib/utils';
import { Button, Notice, PageHeading, Modal, Loading } from '../ui';
import { MemberCell } from './member-cell';

const types = [
  ['individual', 'Individual'],
  ['duo', 'Duo'],
  ['team', 'Team'],
] as const;

function toDateInput(value: any): string {
  const d = value?.toDate ? value.toDate() : value ? new Date(value) : null;
  return d ? d.toISOString().slice(0, 10) : '';
}

function dateRangeLabel(row: Row): string {
  const fmt = (v: any) => {
    const d = v?.toDate ? v.toDate() : new Date(v);
    return d.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
  };
  if (!row.startDate || !row.endDate) return '';
  const start = fmt(row.startDate), end = fmt(row.endDate);
  return start === end ? start : `${start} – ${end}`;
}

function formatSessionTimes(row: Row): string {
  const slots: SessionTimeSlot[] = Array.isArray(row.timeSlots) && row.timeSlots.length > 0
    ? row.timeSlots
    : (row.startTime && row.endTime ? [{ startTime: row.startTime, endTime: row.endTime }] : []);
  if (slots.length === 0) return '';
  return slots.map((s) => s.maxParticipants ? `${s.startTime}–${s.endTime} (${(s.joinedUserIds || []).length}/${s.maxParticipants})` : `${s.startTime}–${s.endTime}`).join(', ');
}

export function AdminSessions() {
  const { rows, loading, error } = useRows('sessions');
  const [selected, setSelected] = useState<Row | null>(null);
  const sorted = [...rows].sort((a, b) => (a.startDate?.seconds || 0) - (b.startDate?.seconds || 0));

  return (
    <>
      <PageHeading title="Sessions." eyebrow="Create and manage bookable sessions — shown on the app and the website" />
      <div className="admin-toolbar">
        <Button onClick={() => setSelected({ id: '' })}>Create Session</Button>
      </div>
      {error && <Notice error>{error}</Notice>}
      {loading ? (
        <Loading />
      ) : sorted.length === 0 ? (
        <p className="muted">No sessions yet. Create one to feature it on the app and the website.</p>
      ) : (
        <div className="stack">
          {sorted.map((s) => (
            <article className="card row spread" key={s.id} onClick={() => setSelected(s)} style={{ cursor: 'pointer' }}>
              <div className="row">
                {s.images?.[0] && (
                  <img src={s.images[0]} alt="" style={{ width: 56, height: 56, objectFit: 'cover', borderRadius: 8 }} />
                )}
                <div>
                  <h3 style={{ margin: 0 }}>{s.title}</h3>
                  <p className="muted" style={{ margin: 0 }}>
                    {[dateRangeLabel(s), formatSessionTimes(s), `${(s.joinedUserIds || []).length}/${s.maxParticipants} joined`].filter(Boolean).join(' · ')}
                  </p>
                </div>
              </div>
            </article>
          ))}
        </div>
      )}
      {selected && <SessionEditor row={selected} onClose={() => setSelected(null)} />}
    </>
  );
}

function SessionEditor({ row, onClose }: { row: Row; onClose: () => void }) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [imageUrl, setImageUrl] = useState<string>(row.images?.[0] || '');
  const joinedUserIds: string[] = row.joinedUserIds || [];
  const profiles = useMemberProfiles(joinedUserIds);

  const [timeSlots, setTimeSlots] = useState<SessionTimeSlot[]>(() => {
    if (Array.isArray(row.timeSlots) && row.timeSlots.length > 0) {
      return row.timeSlots.map((s: any) => ({
        startTime: s.startTime || '',
        endTime: s.endTime || '',
        maxParticipants: Number(s.maxParticipants) || Number(row.maxParticipants) || 1,
        joinedUserIds: Array.isArray(s.joinedUserIds) ? s.joinedUserIds : [],
      }));
    }
    if (row.startTime || row.endTime) {
      return [{
        startTime: row.startTime || '',
        endTime: row.endTime || '',
        maxParticipants: Number(row.maxParticipants) || 1,
        joinedUserIds: Array.isArray(row.joinedUserIds) ? row.joinedUserIds : [],
      }];
    }
    return [{ startTime: '', endTime: '', maxParticipants: Number(row.maxParticipants) || 5, joinedUserIds: [] }];
  });

  function updateSlot(index: number, field: keyof SessionTimeSlot, value: any) {
    setTimeSlots((prev) => prev.map((slot, i) => (i === index ? { ...slot, [field]: value } : slot)));
  }

  function addSlot() {
    setTimeSlots((prev) => [...prev, { startTime: '', endTime: '', maxParticipants: 5, joinedUserIds: [] }]);
  }

  function removeSlot(index: number) {
    setTimeSlots((prev) => {
      if (prev.length <= 1) return prev;
      return prev.filter((_, i) => i !== index);
    });
  }

  async function uploadImage(file: File | undefined) {
    if (!file) return;
    if (file.size >= 5 * 1024 * 1024 || !['image/jpeg', 'image/png', 'image/webp'].includes(file.type)) {
      setError('Choose a JPG, PNG or WebP smaller than 5 MB.');
      return;
    }
    setBusy(true);
    setError('');
    try {
      const id = row.id || (row.id = crypto.randomUUID());
      const target = ref(storage, `gym/sessions/${id}`);
      await uploadBytes(target, file, { contentType: file.type });
      setImageUrl(await getDownloadURL(target));
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setBusy(false);
    }
  }

  async function save(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const f = Object.fromEntries(new FormData(e.currentTarget)) as Record<string, string>;

    const validSlots = timeSlots.map((s) => ({
      startTime: s.startTime.trim(),
      endTime: s.endTime.trim(),
      maxParticipants: Math.max(1, Number(s.maxParticipants) || 1),
      joinedUserIds: s.joinedUserIds || [],
    }));

    if (validSlots.length === 0 || validSlots.some((s) => !s.startTime || !s.endTime)) {
      setError('Please provide both Start Time and End Time for each timing slot.');
      return;
    }

    for (let i = 0; i < validSlots.length; i++) {
      const { startTime, endTime } = validSlots[i];
      if (startTime >= endTime) {
        setError(`Time slot ${i + 1}: End time must be after start time (${startTime} – ${endTime}).`);
        return;
      }
    }

    setBusy(true);
    setError('');
    try {
      await setDoc(
        doc(db, 'sessions', row.id || crypto.randomUUID()),
        {
          title: f.title,
          description: f.description,
          images: imageUrl ? [imageUrl] : [],
          type: f.type,
          price: Number(f.price),
          startDate: Timestamp.fromDate(new Date(f.startDate)),
          endDate: Timestamp.fromDate(new Date(f.endDate)),
          timeSlots: validSlots,
          startTime: validSlots[0]?.startTime || '',
          endTime: validSlots[0]?.endTime || '',
          maxParticipants: Number(f.maxParticipants) || validSlots.reduce((sum, s) => sum + s.maxParticipants, 0),
          joinedUserIds,
          createdAt: row.createdAt || serverTimestamp(),
          updatedAt: serverTimestamp(),
        },
        { merge: true }
      );
      onClose();
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setBusy(false);
    }
  }

  async function remove() {
    if (!row.id || !window.confirm('Delete this session?')) return;
    setBusy(true);
    try {
      await deleteDoc(doc(db, 'sessions', row.id));
      onClose();
    } catch (e) {
      setError(errorMessage(e));
      setBusy(false);
    }
  }

  return (
    <Modal title={row.id ? 'Edit Session' : 'Create Session'} onClose={onClose}>
      <form className="stack" onSubmit={save}>
        <label className="field">
          Photo
          <div className="photo-grid">
            {imageUrl ? (
              <div className="photo-slot">
                <img src={imageUrl} alt="" />
                <button type="button" onClick={() => setImageUrl('')} className="photo-remove" aria-label="Remove photo">✕</button>
              </div>
            ) : (
              <label className="photo-add">
                +
                <input type="file" accept="image/jpeg,image/png,image/webp" disabled={busy} style={{ display: 'none' }} onChange={(e) => uploadImage(e.target.files?.[0])} />
              </label>
            )}
          </div>
        </label>
        <label className="field">Title<input name="title" defaultValue={row.title || ''} required /></label>
        <label className="field">Description<textarea name="description" defaultValue={row.description || ''} rows={3} /></label>
        <div className="field-grid">
          <label className="field">Price in USD<input name="price" type="number" min="0" step="0.01" defaultValue={row.price ?? ''} required /></label>
          <label className="field">
            Type
            <select name="type" defaultValue={row.type || 'individual'}>
              {types.map(([v, label]) => <option key={v} value={v}>{label}</option>)}
            </select>
          </label>
        </div>
        <div className="field-grid">
          <label className="field">Start Date<input name="startDate" type="date" defaultValue={toDateInput(row.startDate)} required /></label>
          <label className="field">End Date<input name="endDate" type="date" defaultValue={toDateInput(row.endDate)} required /></label>
        </div>

        <div className="stack" style={{ gap: 10 }}>
          {timeSlots.map((slot, index) => (
            <div key={index} className="field-grid" style={{ alignItems: 'flex-end', position: 'relative' }}>
              <label className="field" style={{ margin: 0 }}>
                Start Time
                <input
                  type="time"
                  value={slot.startTime}
                  onChange={(e) => updateSlot(index, 'startTime', e.target.value)}
                  required
                />
              </label>
              <div className="row" style={{ alignItems: 'flex-end', gap: 8, margin: 0 }}>
                <label className="field" style={{ flex: 1, margin: 0 }}>
                  End Time
                  <input
                    type="time"
                    value={slot.endTime}
                    onChange={(e) => updateSlot(index, 'endTime', e.target.value)}
                    required
                  />
                </label>
                <label className="field" style={{ width: 85, margin: 0 }}>
                  Spots
                  <input
                    type="number"
                    min="1"
                    value={slot.maxParticipants || 1}
                    onChange={(e) => updateSlot(index, 'maxParticipants', Math.max(1, Number(e.target.value) || 1))}
                    required
                  />
                </label>
                {timeSlots.length > 1 && (
                  <button
                    type="button"
                    onClick={() => removeSlot(index)}
                    aria-label={`Remove time slot ${index + 1}`}
                    style={{
                      background: 'transparent',
                      border: '1px solid var(--border)',
                      borderRadius: 8,
                      color: 'var(--muted)',
                      fontSize: 14,
                      cursor: 'pointer',
                      padding: '0 12px',
                      height: 42,
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                    }}
                    title="Remove time"
                  >
                    ✕
                  </button>
                )}
              </div>
            </div>
          ))}
          <div>
            <button
              type="button"
              onClick={addSlot}
              style={{
                background: 'transparent',
                border: 'none',
                color: 'var(--red, #e53935)',
                fontSize: 13,
                fontWeight: 600,
                cursor: 'pointer',
                padding: '2px 0',
              }}
            >
              + Add another time
            </button>
          </div>
        </div>


        <label className="field">Max Participants<input name="maxParticipants" type="number" min="1" defaultValue={row.maxParticipants ?? ''} required /></label>
        {joinedUserIds.length > 0 && (
          <div className="field">
            Joined ({joinedUserIds.length})
            <div className="stack" style={{ gap: 6, marginTop: 6 }}>
              {joinedUserIds.map((uid) => <MemberCell key={uid} uid={uid} profile={profiles[uid]} />)}
            </div>
          </div>
        )}
        {error && <Notice error>{error}</Notice>}
        <div className="row">
          <Button busy={busy}>Save Session</Button>
          {row.id && <Button type="button" className="secondary" onClick={remove}>Delete</Button>}
        </div>
      </form>
    </Modal>
  );
}

