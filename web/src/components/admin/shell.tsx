'use client';
import { ReactNode } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useAuth } from '../providers';
import { Icon, Loading, Notice, ActionLink } from '../ui';
import { LocaleToggle } from '../locale-toggle';
import { UserProfile } from '@/lib/types';
import { adminAccess, nav } from './nav';

export function isNavActive(currentPath: string, itemHref: string): boolean {
  const normCurrent = (currentPath || '').replace(/\.html$/, '').replace(/\/$/, '') || '/admin';
  const normHref = (itemHref || '').replace(/\.html$/, '').replace(/\/$/, '') || '/admin';
  if (normHref === '/admin') {
    return normCurrent === '/admin';
  }
  return normCurrent === normHref || normCurrent.startsWith(normHref + '/');
}

export function AdminShell({children}:{children:ReactNode}){
  const {profile:row,user,loading}=useAuth(),path=usePathname()||'',profile=row as UserProfile|null;
  if(loading)return <Loading/>;
  if(!user)return <div className="container section"><Notice>Sign in with an administrator account.</Notice><ActionLink href="/signin?next=/admin">Sign In</ActionLink></div>;
  const access=adminAccess(profile,path);
  if(!access.item&&!access.allowed)return <div className="container section"><Notice error>{access.notice}</Notice><ActionLink href="/dashboard">Member Dashboard</ActionLink></div>;
  return (
    <div className="admin-shell">
      <aside className="admin-sidebar">
        <div className="row spread" style={{alignItems:'center'}}>
          <Link className="wordmark" href="/">JUNIOR BOY <em>BOXING</em></Link>
          <LocaleToggle/>
        </div>
        <p className="eyebrow" style={{marginTop:10}}>Coach’s corner</p>
        <nav aria-label="Admin navigation">
          {nav.filter(item=>item.visible(profile)).map(item=>(
            <Link
              key={item.href}
              href={item.href}
              className={isNavActive(path, item.href) ? 'active' : ''}
            >
              <Icon name={item.icon} size={18}/>{item.title}
            </Link>
          ))}
        </nav>
        <Link href="/dashboard" className="row muted" style={{fontSize:12}}>
          <Icon name="arrow_back" size={14}/>Member portal
        </Link>
      </aside>
      <main id="main" className="admin-main">
        {access.allowed ? children : <Notice error>{access.notice}</Notice>}
      </main>
    </div>
  );
}

