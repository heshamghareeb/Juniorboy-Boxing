import { DateTime } from 'luxon';
import { getLocale } from './i18n/locale-state';
import { en } from './i18n/dictionaries/en';
import { ar } from './i18n/dictionaries/ar';
export const zone = 'America/Los_Angeles';
function dict() { return getLocale() === 'ar' ? ar : en; }
export function asDate(value: any): Date { return value?.toDate ? value.toDate() : new Date(value); }
export const dateLabel = (value: any) => DateTime.fromJSDate(asDate(value)).setZone(zone).setLocale(getLocale()==='ar'?'ar':'en').toFormat('ccc, LLL d');
export const timeLabel = (value: any) => DateTime.fromJSDate(asDate(value)).setZone(zone).setLocale(getLocale()==='ar'?'ar':'en').toFormat('h:mm a');
export const money = (amount: number) => new Intl.NumberFormat(getLocale()==='ar'?'ar':'en-US', {style:'currency',currency:'USD'}).format(amount / 100);
export function errorMessage(error: unknown): string {
  const e = error as { code?: string; message?: string; details?: {message?:string}|string };
  const code = (e?.code||'').replace(/^functions\//,'');
  const d = dict();
  if (['auth/invalid-credential','auth/wrong-password','auth/user-not-found'].includes(e?.code || '')) return d['errors.checkCredentials'];
  if (e?.code === 'auth/email-already-in-use') return d['errors.emailInUse'];
  if (code === 'unauthenticated') return d['errors.signInToContinue'];
  if (code === 'permission-denied') return d['errors.permissionDenied'];
  if (code === 'failed-precondition') return (typeof e?.details==='object'?e.details?.message:undefined)||(/^internal(?:\s*\[\d+\])?$/i.test(e?.message||'')?'':e?.message)||d['errors.actionNotAvailable'];
  if (code === 'internal' || /\binternal\s*\[\d+\]/i.test(e?.message||'')) return d['errors.somethingWrong'];
  if (['unavailable','deadline-exceeded','network-request-failed','auth/network-request-failed'].includes(code)) return d['errors.connectionUnavailable'];
  return e?.message?.replace(/^Firebase:\s*/,'').replace(/\s*\(auth\/[^)]+\)\.?$/,'') || d['errors.unableToComplete'];
}
export function downloadCSV(csv: string, filename: string) { const url = URL.createObjectURL(new Blob(['\ufeff',csv], {type:'text/csv;charset=utf-8;'})); const a = document.createElement('a'); a.href = url; a.download = filename; a.click(); URL.revokeObjectURL(url); }
export function isProfileComplete(profile: { childName?: string; childAge?: number; phone?: string; address?: string } | null): boolean {
  return !!profile && !!profile.childName?.trim() && !!profile.childAge && profile.childAge > 0 && !!profile.phone?.trim() && !!profile.address?.trim();
}
export function composeAddress(data: {houseNumber?:string; streetName?:string; city?:string; country?:string}): string {
  return [[data.houseNumber,data.streetName].filter(Boolean).join(' '), data.city, data.country].filter(Boolean).join(', ').trim();
}
// Never surface the payment processor's name in the UI — just how the card was charged.
export function paymentMethodLabel(method?: string): string {
  const d = dict();
  if (method === 'stripe') return d['common.paymentMethod.card'];
  if (method === 'manual') return d['common.paymentMethod.manual'];
  if (method === 'cash') return d['common.paymentMethod.cash'];
  return method || '—';
}
