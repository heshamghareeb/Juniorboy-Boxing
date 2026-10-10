'use client';
import { ButtonHTMLAttributes, CSSProperties, MouseEventHandler, ReactNode, useEffect, useRef } from 'react';
import Link from 'next/link';
import { useAuth } from './providers';
export function Icon({name,size=20,outlined=true,className='',style,onClick}:{name:string;size?:number;outlined?:boolean;className?:string;style?:CSSProperties;onClick?:MouseEventHandler<HTMLSpanElement>}) {
  return <span aria-hidden="true" translate="no" onClick={onClick} className={`notranslate ${outlined?'material-icons-outlined':'material-icons'}${className?' '+className:''}`} style={{fontSize:size,...style}}>{name}</span>;
}
const socialPaths: Record<string,string> = {
  instagram:'M12 2c2.717 0 3.056.01 4.122.06 1.065.05 1.79.217 2.428.465a4.9 4.9 0 0 1 1.772 1.153 4.9 4.9 0 0 1 1.153 1.772c.248.637.415 1.363.465 2.428.047 1.066.06 1.405.06 4.122s-.01 3.056-.06 4.122c-.05 1.065-.217 1.79-.465 2.428a4.9 4.9 0 0 1-1.153 1.772 4.9 4.9 0 0 1-1.772 1.153c-.637.248-1.363.415-2.428.465-1.066.047-1.405.06-4.122.06s-3.056-.01-4.122-.06c-1.065-.05-1.79-.217-2.428-.465a4.9 4.9 0 0 1-1.772-1.153 4.9 4.9 0 0 1-1.153-1.772c-.248-.637-.415-1.363-.465-2.428C2.013 15.056 2 14.717 2 12s.01-3.056.06-4.122c.05-1.065.217-1.79.465-2.428A4.9 4.9 0 0 1 3.678 3.678 4.9 4.9 0 0 1 5.45 2.525c.637-.248 1.363-.415 2.428-.465C8.944 2.013 9.283 2 12 2zm0 1.802c-2.67 0-2.986.01-4.04.058-.976.045-1.505.207-1.857.344-.467.182-.8.399-1.15.748-.35.35-.566.683-.748 1.15-.137.352-.3.881-.344 1.857-.048 1.054-.058 1.37-.058 4.04s.01 2.986.058 4.04c.045.976.207 1.505.344 1.857.182.467.399.8.748 1.15.35.35.683.566 1.15.748.352.137.881.3 1.857.344 1.054.048 1.37.058 4.04.058s2.986-.01 4.04-.058c.976-.045 1.505-.207 1.857-.344.467-.182.8-.399 1.15-.748.35-.35.566-.683.748-1.15.137-.352.3-.881.344-1.857.048-1.054.058-1.37.058-4.04s-.01-2.986-.058-4.04c-.045-.976-.207-1.505-.344-1.857a3.1 3.1 0 0 0-.748-1.15 3.1 3.1 0 0 0-1.15-.748c-.352-.137-.881-.3-1.857-.344-1.054-.048-1.37-.058-4.04-.058zm0 3.063a5.135 5.135 0 1 1 0 10.27 5.135 5.135 0 0 1 0-10.27zm0 1.802a3.333 3.333 0 1 0 0 6.666 3.333 3.333 0 0 0 0-6.666zm5.338-3.205a1.2 1.2 0 1 1 0 2.4 1.2 1.2 0 0 1 0-2.4z',
  facebook:'M22 12.06C22 6.505 17.523 2 12 2S2 6.505 2 12.06c0 5.02 3.657 9.184 8.438 9.94v-7.03H7.898v-2.91h2.54V9.845c0-2.507 1.492-3.89 3.777-3.89 1.095 0 2.24.195 2.24.195v2.46h-1.26c-1.243 0-1.63.772-1.63 1.562v1.878h2.773l-.443 2.91h-2.33V22c4.78-.756 8.435-4.92 8.435-9.94z',
  tiktok:'M16.5 2h-3.03v13.74a3.07 3.07 0 1 1-2.17-2.93v-3.1a6.17 6.17 0 1 0 5.2 6.1V8.58a7.6 7.6 0 0 0 4.5 1.45V6.99a4.6 4.6 0 0 1-4.5-4.6V2z',
  youtube:'M23.5 6.2a3.02 3.02 0 0 0-2.12-2.14C19.5 3.5 12 3.5 12 3.5s-7.5 0-9.38.56A3.02 3.02 0 0 0 .5 6.2 31.6 31.6 0 0 0 0 12a31.6 31.6 0 0 0 .5 5.8 3.02 3.02 0 0 0 2.12 2.14C4.5 20.5 12 20.5 12 20.5s7.5 0 9.38-.56a3.02 3.02 0 0 0 2.12-2.14A31.6 31.6 0 0 0 24 12a31.6 31.6 0 0 0-.5-5.8zM9.6 15.6V8.4l6.3 3.6-6.3 3.6z',
  whatsapp:'M.057 24l1.687-6.163c-1.041-1.804-1.588-3.849-1.587-5.946.003-6.556 5.338-11.891 11.893-11.891 3.181.001 6.167 1.24 8.413 3.488 2.245 2.248 3.481 5.236 3.48 8.414-.003 6.557-5.338 11.892-11.893 11.892-1.99-.001-3.951-.5-5.688-1.448L.057 24zm6.597-3.807c1.676.995 3.276 1.591 5.392 1.592 5.448 0 9.886-4.434 9.889-9.885.002-5.462-4.415-9.89-9.881-9.892-5.452 0-9.887 4.434-9.889 9.884-.001 2.225.651 3.891 1.746 5.634l-.999 3.648 3.742-.981zm11.387-5.464c-.074-.124-.272-.198-.57-.347-.297-.149-1.758-.868-2.031-.967-.272-.099-.47-.148-.669.149-.198.297-.768.967-.941 1.165-.173.198-.347.223-.644.074-1.746-.874-2.887-1.56-4.034-3.539-.305-.527.305-.489.873-1.624.099-.198.05-.371-.05-.52-.099-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.009-.372-.011-.57-.011-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.057 3.148 5.003 4.287 2.946 1.14 2.946.76 3.985.64 1.039-.12 2.374-.973 2.722-1.91.347-.936.347-1.738.247-1.91z',
};
export function SocialIcon({name,size=20}:{name:'instagram'|'facebook'|'tiktok'|'youtube'|'whatsapp';size?:number}) {
  return <svg viewBox="0 0 24 24" width={size} height={size} fill="currentColor" aria-hidden="true"><path d={socialPaths[name]}/></svg>;
}
export function Button({children,busy,...props}:ButtonHTMLAttributes<HTMLButtonElement>&{busy?:boolean}) { return <button {...props} className={`button ${props.className||''}`} disabled={busy||props.disabled}>{busy?<Icon name="autorenew" className="spin" size={18}/>:null}{children}</button>; }
export function ActionLink({href,children,secondary=false}:{href:string;children:ReactNode;secondary?:boolean}) { return <Link className={`button ${secondary?'secondary':''}`} href={href}>{children}<Icon name="arrow_forward" size={17}/></Link>; }
/** A signup-CTA that switches copy/destination once we know the visitor's auth state, with a same-size skeleton while that's still loading (avoids flicker/layout shift). */
export function AuthCTA({signedOut,signedIn,secondary=false}:{signedOut:{label:string;href:string};signedIn:{label:string;href:string};secondary?:boolean}) {
  const {user,loading} = useAuth();
  if (loading) return <span className={`button skel-btn${secondary?' secondary':''}`} aria-hidden="true"/>;
  const target = user ? signedIn : signedOut;
  return <ActionLink href={target.href} secondary={secondary}>{target.label}</ActionLink>;
}
export function Notice({children,error=false}:{children:ReactNode;error?:boolean}) { return <div role={error?'alert':'status'} className={`notice ${error?'error':''}`}>{children}</div>; }
export function Loading() {return <div aria-label="Loading" className="loading"><Icon name="autorenew" className="spin"/> Loading…</div>;}
export function Empty({children}:{children:ReactNode}) {return <div className="empty">{children}</div>;}
export function Modal({title,onClose,children}:{title:string;onClose:()=>void;children:ReactNode}) {
  const ref=useRef<HTMLDialogElement>(null);
  useEffect(()=>{ref.current?.showModal(); const prior=document.body.style.overflow;document.body.style.overflow='hidden';return()=>{document.body.style.overflow=prior;};},[]);
  return <dialog ref={ref} className="modal" onCancel={onClose} onClick={e=>{if(e.target===ref.current) onClose();}}><div className="modal-head"><h2>{title}</h2><button className="icon-button" aria-label="Close dialog" onClick={onClose}><Icon name="close"/></button></div>{children}</dialog>;
}
export function PageHeading({eyebrow,title,children}:{eyebrow?:string;title:string;children?:ReactNode}) {return <div className="page-heading">{eyebrow&&<p className="eyebrow">{eyebrow}</p>}<h1>{title}</h1>{children&&<p className="lede">{children}</p>}</div>;}
