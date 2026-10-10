'use client';
import { createContext, useContext, useEffect, useState, ReactNode } from 'react';
import { Locale, setCurrentLocale } from './locale-state';
import { en } from './dictionaries/en';
import { ar } from './dictionaries/ar';

const dictionaries: Record<Locale, Record<string, string>> = { en, ar };

type TranslateFn = (key: keyof typeof en, vars?: Record<string, string | number>) => string;

function interpolate(template: string, vars?: Record<string, string | number>): string {
  if (!vars) return template;
  return template.replace(/\{(\w+)\}/g, (match, name) => (name in vars ? String(vars[name]) : match));
}

const LocaleContext = createContext<{ locale: Locale; setLocale: (next: Locale) => void; t: TranslateFn; dir: 'ltr' | 'rtl' }>({
  locale: 'en',
  setLocale: () => {},
  t: (key, vars) => interpolate(en[key], vars),
  dir: 'ltr',
});

export function LocaleProvider({ children }: { children: ReactNode }) {
  const [locale, setLocaleState] = useState<Locale>('en');

  useEffect(() => {
    const detected: Locale = document.documentElement.lang === 'ar' ? 'ar' : 'en';
    setLocaleState(detected);
    setCurrentLocale(detected);
  }, []);

  function setLocale(next: Locale) {
    setLocaleState(next);
    setCurrentLocale(next);
    try { localStorage.setItem('jbb-locale', next); } catch {}
    document.documentElement.lang = next;
    document.documentElement.dir = next === 'ar' ? 'rtl' : 'ltr';
  }

  function t(key: keyof typeof en, vars?: Record<string, string | number>): string {
    const template = dictionaries[locale][key as string] ?? en[key];
    return interpolate(template, vars);
  }

  return <LocaleContext.Provider value={{ locale, setLocale, t, dir: locale === 'ar' ? 'rtl' : 'ltr' }}>{children}</LocaleContext.Provider>;
}

export const useLocale = () => useContext(LocaleContext);
export const useT = () => useLocale().t;
