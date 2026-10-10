export type Locale = 'en' | 'ar';
let currentLocale: Locale = 'en';
export function getLocale(): Locale { return currentLocale; }
export function setCurrentLocale(locale: Locale) { currentLocale = locale; }
