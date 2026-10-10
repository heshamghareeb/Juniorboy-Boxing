'use client';
import { useLocale } from '@/lib/i18n/context';
export function LocaleToggle() {
  const { locale, setLocale, t } = useLocale();
  const next = locale === 'ar' ? 'en' : 'ar';
  return <button type="button" className="icon-button" aria-label={locale === 'ar' ? t('common.switchToEnglish') : t('common.switchToArabic')} onClick={() => setLocale(next)}>{locale === 'ar' ? 'EN' : 'AR'}</button>;
}
