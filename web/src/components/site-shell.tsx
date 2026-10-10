'use client';
import { ReactNode, useEffect, useState } from 'react';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useAuth } from './providers';
import { useDocument } from '@/lib/hooks';
import { gym } from '@/lib/types';
import { isProfileComplete } from '@/lib/utils';
import { isStaff } from '@/lib/permissions';
import { useLocale } from '@/lib/i18n/context';
import type { en as EnDict } from '@/lib/i18n/dictionaries/en';
import { LocaleToggle } from './locale-toggle';
import { Icon, SocialIcon } from './ui';
const PROFILE_GATE_EXEMPT = ['/complete-profile','/signin','/signup','/waiver','/privacy','/terms','/contact','/about','/blog','/reviews','/store','/'];
function ThemeToggle(){
  const [dark,setDark]=useState(false),{t}=useLocale();
  useEffect(()=>{setDark(document.documentElement.getAttribute('data-theme')==='dark'||(!document.documentElement.hasAttribute('data-theme')&&matchMedia('(prefers-color-scheme: dark)').matches));},[]);
  function toggle(){const next=!dark;setDark(next);document.documentElement.setAttribute('data-theme',next?'dark':'light');try{localStorage.setItem('jbb-theme',next?'dark':'light');}catch{}}
  return <button type="button" className="icon-button" aria-label={dark?t('common.useLightTheme'):t('common.useDarkTheme')} onClick={toggle}><Icon name={dark?'light_mode':'dark_mode'}/></button>;
}
export function SocialLinks({links}:{links:Record<string,string>}){return <div className="footer-social">{(['instagram','facebook','tiktok'] as const).filter(name=>/^https:\/\//.test(links?.[name]||'')).map(name=><a key={name} href={links[name]} target="_blank" rel="noreferrer" aria-label={name} className="social-icon-btn"><SocialIcon name={name}/></a>)}</div>;}
function FooterContact({settings}:{settings:any}){
  const {t}=useLocale();
  const email=String(settings?.email||'').trim();
  const phone=String(settings?.phone||'').trim();
  const phoneDigits=phone.replace(/[^0-9]/g,'');
  const hours=Object.entries(settings?.operatingHours||{}) as [string,string][];
  if(!email&&!phoneDigits&&!hours.length)return null;
  return <div className="footer-contact">
    <div>
      <p className="eyebrow">{t('nav.footerContact.title')}</p>
      <div className="footer-contact-row">
        {email&&<a href={`mailto:${email}`} aria-label={t('nav.footerContact.emailAria')} className="footer-contact-link"><Icon name="mail" size={18}/><span>{email}</span></a>}
        {phoneDigits&&<a href={`https://wa.me/${phoneDigits}`} target="_blank" rel="noreferrer" aria-label={t('nav.footerContact.whatsappAria')} className="footer-contact-link"><SocialIcon name="whatsapp" size={18}/><span>{phone}</span></a>}
        {phoneDigits&&<a href={`tel:${phone}`} aria-label={t('nav.footerContact.callAria')} className="footer-contact-link"><Icon name="call" size={18}/><span>{phone}</span></a>}
      </div>
    </div>
    {hours.length>0&&<div className="footer-hours">
      <p className="eyebrow">{t('nav.footerHours.title')}</p>
      {hours.map(([day,time])=><p className="row spread" key={day}><span>{t(`common.days.${day}` as keyof typeof EnDict)}</span><span className="muted">{String(time)}</span></p>)}
    </div>}
  </div>;
}
export function SiteShell({children}:{children:ReactNode}){
  const path=usePathname(),router=useRouter(),{user,profile,loading}=useAuth(),settings=useDocument('gymSettings/config')||gym,{t}=useLocale();
  useEffect(()=>{if(!loading&&user&&profile&&!isProfileComplete(profile as any)&&!PROFILE_GATE_EXEMPT.includes(path)&&!['/offers','/store/'].some(prefix=>path.startsWith(prefix)))router.replace('/complete-profile');},[loading,user,profile,path,router]);
  if(path.startsWith('/admin'))return <>{children}</>;
  const links=[[t('nav.sessions'),'/offers'],[t('nav.shop'),'/store'],[t('nav.account'),user?'/dashboard':'/signin']];
  return <><header className="site-header"><Link className="wordmark" href="/" aria-label={t('nav.homeAriaLabel')}>JUNIOR BOY <em>BOXING</em></Link><nav className="site-nav" aria-label={t('nav.ariaLabel')}>{links.map(([label,href])=><Link aria-current={path===href?'page':undefined} href={href} key={label}>{label}</Link>)}{isStaff(profile)&&<Link href="/admin" className="row" style={{gap:4,alignItems:'center'}}><Icon name="admin_panel_settings" size={18}/>{t('nav.adminDashboard')}</Link>}</nav><ThemeToggle/><LocaleToggle/></header><main id="main">{children}</main><footer className="site-footer"><div className="footer-top"><Link className="wordmark" href="/">JUNIOR BOY <em>BOXING</em></Link><SocialLinks links={settings.socialLinks||{}}/></div><FooterContact settings={settings}/><div className="footer-bottom"><span>{t('nav.footerCopyright',{year:new Date().getFullYear()})}</span><div><Link href="/privacy">{t('nav.privacy')}</Link><Link href="/terms">{t('nav.terms')}</Link><Link href="/waiver">{t('nav.waiver')}</Link></div></div></footer></>;
}
