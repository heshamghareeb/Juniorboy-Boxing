import type { Metadata } from 'next';
import { Providers } from '@/components/providers';
import { SiteShell } from '@/components/site-shell';
import { LocaleProvider } from '@/lib/i18n/context';
import './globals.css';
const url=process.env.NEXT_PUBLIC_SITE_URL||'http://localhost:3000';
export const metadata: Metadata={metadataBase:new URL(url),title:{default:'Junior Boy Boxing',template:'%s | Junior Boy Boxing'},description:'Boxing classes for kids and teens. Train with Coach Sharif. Build confidence, discipline and strength.',openGraph:{title:'Junior Boy Boxing',description:'Discipline builds champions. Boxing classes for kids and teens.',images:['/assets/images/backgrounds/bg_home_header.png'],type:'website'},robots:{index:true,follow:true},other:{google:'notranslate'}};
const THEME_SCRIPT = `try{var theme=localStorage.getItem('jbb-theme');if(theme==='dark'||theme==='light')document.documentElement.setAttribute('data-theme',theme);}catch(e){}`;
const LOCALE_SCRIPT = `try{var loc=localStorage.getItem('jbb-locale')==='ar'?'ar':'en';document.documentElement.lang=loc;document.documentElement.dir=loc==='ar'?'rtl':'ltr';}catch(e){}`;
// translate="no" + the notranslate class/meta above ask the browser not to auto-translate this
// page — browser translation rewrites text nodes behind React's back and collides with React's
// own DOM updates (e.g. while uploading a photo), throwing insertBefore/removeChild errors that
// look like app bugs but aren't. Our own i18n system (src/lib/i18n) is what makes it safe to
// keep the browser's own translate feature switched off.
export default function RootLayout({children}:{children:React.ReactNode}) {return <html lang="en" translate="no" className="notranslate"><body><script dangerouslySetInnerHTML={{__html:THEME_SCRIPT}}/><script dangerouslySetInnerHTML={{__html:LOCALE_SCRIPT}}/><a href="#main" className="skip-link">Skip to content</a><LocaleProvider><Providers><SiteShell>{children}</SiteShell></Providers></LocaleProvider></body></html>;}
