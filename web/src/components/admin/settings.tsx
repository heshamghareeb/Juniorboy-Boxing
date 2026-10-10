'use client';

import { FormEvent, useState } from 'react';
import Link from 'next/link';
import { doc, setDoc, serverTimestamp, orderBy, limit } from 'firebase/firestore';
import { ref, uploadBytes, getDownloadURL } from 'firebase/storage';
import { db, storage, call } from '@/lib/firebase';
import { useDocument, useRows } from '@/lib/hooks';
import { gym } from '@/lib/types';
import { errorMessage, dateLabel } from '@/lib/utils';
import { Button, Notice, PageHeading, Icon } from '../ui';
import { useAuth } from '../providers';
import { isSuperAdmin } from '@/lib/permissions';
import { useLocale } from '@/lib/i18n/context';
import type { en as EnDict } from '@/lib/i18n/dictionaries/en';

export function AdminSettings() {
  const { profile } = useAuth();
  const { t } = useLocale();
  const canEdit = isSuperAdmin(profile as any);
  const saved = useDocument('gymSettings/config');
  const settings = saved || gym;
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [message, setMessage] = useState('');
  const [heroImageUrl, setHeroImageUrl] = useState<string>(
    (saved as Record<string, string> | null)?.heroImageUrl || ''
  );

  async function uploadHero(file: File | undefined) {
    if (!file || !canEdit) return;
    if (file.size >= 5 * 1024 * 1024 || !['image/jpeg', 'image/png', 'image/webp'].includes(file.type)) {
      setError(t('admin.settings.imageError'));
      return;
    }
    setBusy(true);
    setError('');
    try {
      const target = ref(storage, 'gym/homeHero');
      await uploadBytes(target, file, { contentType: file.type });
      const url = await getDownloadURL(target);
      setHeroImageUrl(url);
      await setDoc(
        doc(db, 'gymSettings', 'config'),
        { heroImageUrl: url, updatedAt: serverTimestamp() },
        { merge: true }
      );
      setMessage(t('admin.settings.heroUpdated'));
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setBusy(false);
    }
  }

  async function submit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    if (!canEdit) return;
    const f = Object.fromEntries(new FormData(e.currentTarget)) as Record<string, string>;
    setBusy(true);
    setError('');
    setMessage('');

    try {
      const hours = Object.fromEntries(
        ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'].map((day) => [
          day,
          f[day] || '',
        ])
      );
      const address = (f.address || '').trim();

      await setDoc(
        doc(db, 'gymSettings', 'config'),
        {
          gymName: f.gymName || '',
          address,
          zipCode: f.zipCode || '',
          phone: f.phone || '',
          email: f.email || '',
          coachName: f.coachName || '',
          aboutText: f.aboutText || '',
          cancellationPolicyHours: Number(f.cancellationPolicyHours),
          operatingHours: hours,
          socialLinks: {
            instagram: f.instagram || '',
            facebook: f.facebook || '',
            tiktok: f.tiktok || '',
            youtube: f.youtube || '',
          },
          classRemindersEnabled: f.classRemindersEnabled === 'on',
          membershipAlertsEnabled: f.membershipAlertsEnabled === 'on',
          updatedAt: serverTimestamp(),
        },
        { merge: true }
      );
      setMessage(t('admin.settings.saved'));
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <>
      <PageHeading title={t('admin.settings.title')} eyebrow={t('admin.settings.eyebrow')} />

      {/* "More" list of links to hidden administration pages so nothing is unreachable */}
      <div className="card stack" style={{ marginBottom: 20 }}>
        <h3 style={{ margin: 0 }}>{t('admin.settings.moreAdmin.title')}</h3>
        <p className="muted" style={{ fontSize: 13, margin: 0 }}>
          {t('admin.settings.moreAdmin.subtitle')}
        </p>
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fill, minmax(170px, 1fr))',
            gap: 10,
            marginTop: 6,
          }}
        >
          <Link href="/admin/members" className="button secondary small">
            <Icon name="group" size={16} /> {t('admin.settings.links.members')}
          </Link>
          <Link href="/admin/payments" className="button secondary small">
            <Icon name="credit_card" size={16} /> {t('admin.settings.links.payments')}
          </Link>
          <Link href="/admin/notifications" className="button secondary small">
            <Icon name="notifications" size={16} /> {t('admin.settings.links.announcements')}
          </Link>
          <Link href="/admin/waiver" className="button secondary small">
            <Icon name="assignment_turned_in" size={16} /> {t('admin.settings.links.waiver')}
          </Link>
          <Link href="/admin/legal" className="button secondary small">
            <Icon name="gavel" size={16} /> {t('admin.settings.links.legalPages')}
          </Link>
          {canEdit && (
            <Link href="/admin/staff" className="button secondary small">
              <Icon name="admin_panel_settings" size={16} /> {t('admin.settings.links.staff')}
            </Link>
          )}
        </div>
      </div>

      <div className="card stack" style={{ marginBottom: 20 }}>
        <h3 style={{ margin: 0 }}>{t('admin.settings.heroImage.title')}</h3>
        <p className="muted" style={{ fontSize: 12, margin: 0 }}>
          {t('admin.settings.heroImage.description')}
        </p>
        <label className="photo-add" style={{ width: 140, height: 140, position: 'relative', overflow: 'hidden' }}>
          {heroImageUrl ? (
            <img src={heroImageUrl} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
          ) : busy ? (
            '…'
          ) : (
            '+'
          )}
          <input
            type="file"
            accept="image/jpeg,image/png,image/webp"
            disabled={busy || !canEdit}
            style={{ display: 'none' }}
            onChange={(e) => uploadHero(e.target.files?.[0])}
          />
        </label>
      </div>

      <form className="card stack" key={saved ? 'loaded' : 'default'} onSubmit={submit}>
        <div className="field-grid">
          {[
            ['gymName', 'admin.settings.field.gymName', 'text'],
            ['phone', 'common.phone', 'tel'],
            ['email', 'common.email', 'email'],
            ['coachName', 'admin.settings.field.coach', 'text'],
          ].map(([name, labelKey, type]) => (
            <label className="field" key={name}>
              {t(labelKey as keyof typeof EnDict)}
              <input
                name={name}
                type={type}
                defaultValue={(settings[name as keyof typeof settings] as string) || ''}
                required={!['phone', 'email'].includes(name)}
              />
            </label>
          ))}
          <label className="field">
            {t('admin.settings.field.cancellationPolicy')}
            <input
              name="cancellationPolicyHours"
              type="number"
              min="0"
              max="168"
              defaultValue={settings.cancellationPolicyHours ?? 24}
              required
            />
          </label>
        </div>

        <div className="field-grid">
          <label className="field">
            {t('admin.settings.field.address')}
            <input
              name="address"
              defaultValue={(settings.address as string) || ''}
              placeholder="3200 Naglee Rd, Tracy, CA 95304"
              required
            />
          </label>
          <label className="field">
            {t('admin.settings.field.zipCode')}
            <input
              name="zipCode"
              maxLength={20}
              autoComplete="postal-code"
              defaultValue={(settings as Record<string, string>).zipCode || ''}
            />
          </label>
        </div>

        <label className="field">
          {t('admin.settings.field.aboutText')}
          <textarea name="aboutText" defaultValue={settings.aboutText || ''} />
        </label>

        <h3>{t('admin.settings.hours.title')}</h3>
        <p className="muted" style={{ fontSize: 13, margin: '0 0 8px' }}>
          {t('admin.settings.hours.description')}
        </p>
        <div className="field-grid">
          {(['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'] as const).map((day) => (
            <label className="field" key={day}>
              {t(`common.days.${day}` as keyof typeof EnDict)}
              <input
                name={day}
                defaultValue={(settings.operatingHours as Record<string, string>)?.[day] || ''}
                placeholder={t('admin.settings.hours.placeholder')}
              />
            </label>
          ))}
        </div>


        <h3>{t('admin.settings.social.title')}</h3>
        <p className="muted" style={{ fontSize: 13, margin: '0 0 8px' }}>
          {t('admin.settings.social.description')}
        </p>
        <div className="field-grid">
          {['instagram', 'facebook', 'tiktok', 'youtube'].map((name) => (
            <label className="field" key={name} style={{ textTransform: 'capitalize' }}>
              {name}
              <input
                name={name}
                type="url"
                placeholder={`https://${name}.com/...`}
                defaultValue={(settings.socialLinks as Record<string, string>)?.[name] || ''}
              />
            </label>
          ))}
        </div>

        <label className="check-field">
          <input
            name="classRemindersEnabled"
            type="checkbox"
            defaultChecked={saved?.classRemindersEnabled !== false}
          />
          {t('admin.settings.remindersCheckbox')}
        </label>
        <label className="check-field">
          <input
            name="membershipAlertsEnabled"
            type="checkbox"
            defaultChecked={saved?.membershipAlertsEnabled !== false}
          />
          {t('admin.settings.membershipAlertsCheckbox')}
        </label>

        {error && <Notice error>{error}</Notice>}
        {message && <Notice>{message}</Notice>}
        {canEdit && <Button busy={busy}>{t('admin.settings.saveButton')}</Button>}
      </form>
      <p className="muted" style={{ marginTop: 24 }}>
        {t('admin.settings.manageAdminHint')}
      </p>
    </>
  );
}

export function AdminNotifications() {
  const [busy, setBusy] = useState(false),
    [error, setError] = useState(''),
    [message, setMessage] = useState(''),
    history = useRows('announcements', [orderBy('createdAt', 'desc'), limit(50)]);
  return (
    <>
      <PageHeading title="Announcements." />
      <form
        className="card stack"
        onSubmit={async (e) => {
          e.preventDefault();
          const form = e.currentTarget,
            f = Object.fromEntries(new FormData(form)) as Record<string, string>;
          setBusy(true);
          try {
            await call('sendAnnouncement', {
              title: f.title,
              body: f.body,
              ...(f.userIds.trim()
                ? { userIds: f.userIds.split(',').map((s) => s.trim()).filter(Boolean) }
                : {}),
            });
            setMessage('Announcement queued for delivery.');
            form.reset();
          } catch (e) {
            setError(errorMessage(e));
          } finally {
            setBusy(false);
          }
        }}
      >
        <label className="field">
          Title
          <input name="title" required maxLength={100} />
        </label>
        <label className="field">
          Message
          <textarea name="body" required maxLength={2000} />
        </label>
        <label className="field">
          Specific member IDs · comma separated, leave empty for all active members
          <input name="userIds" />
        </label>
        {error && <Notice error>{error}</Notice>}
        {message && <Notice>{message}</Notice>}
        <Button busy={busy}>Send Announcement</Button>
      </form>
      <h2 style={{ fontSize: 26, marginTop: 36 }}>Notification history</h2>
      <div className="stack">
        {history.rows.map((n) => (
          <article className="card" key={n.id}>
            <div className="row spread">
              <h3>{n.title}</h3>
              <span className="status">{n.status}</span>
            </div>
            <p className="muted">{n.body}</p>
            <span className="muted" style={{ fontSize: 12 }}>
              {dateLabel(n.createdAt)} · {n.deliveredCount || 0} recipients processed
            </span>
          </article>
        ))}
      </div>
    </>
  );
}
