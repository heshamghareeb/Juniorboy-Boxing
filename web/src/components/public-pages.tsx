'use client';
import { FormEvent, useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import { where } from 'firebase/firestore';
import { motion, useReducedMotion } from 'framer-motion';
import { useDocument, useRows } from '@/lib/hooks';
import { gym } from '@/lib/types';
import { call } from '@/lib/firebase';
import { errorMessage, money } from '@/lib/utils';
import { ActionLink, AuthCTA, Button, Empty, Icon, Loading, Notice, PageHeading } from './ui';
import { IntroSplash, PunchTitle } from './fx';
import { HomeShopSection } from './featured-products';
import { KidsGallery } from '@/components/kids-gallery';
import './home-extras.css';
import './sessions-public.css';
function HomeHeroSocial({settings}:{settings:any}){
  const address=String(settings?.address||'').trim();
  const social=((settings?.socialLinks||{})as Record<string,string>);
  function clean(u?:string){
    if(!u)return'';
    const s=String(u).trim();
    if(/^https?:\/\//i.test(s))return s;
    if(/^[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,5}(:[0-9]{1,5})?(\/.*)?$/i.test(s))return`https://${s}`;
    return'';
  }
  const mapsUrl=address?`https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(address)}`:'';
  const items=[
    {name:'facebook',label:'Facebook',url:clean(social.facebook||settings?.facebook),icon:<svg viewBox="0 0 24 24" width={20} height={20} fill="currentColor" aria-hidden="true"><path d="M22 12.06C22 6.505 17.523 2 12 2S2 6.505 2 12.06c0 5.02 3.657 9.184 8.438 9.94v-7.03H7.898v-2.91h2.54V9.845c0-2.507 1.492-3.89 3.777-3.89 1.095 0 2.24.195 2.24.195v2.46h-1.26c-1.243 0-1.63.772-1.63 1.562v1.878h2.773l-.443 2.91h-2.33V22c4.78-.756 8.435-4.92 8.435-9.94z"/></svg>},
    {name:'instagram',label:'Instagram',url:clean(social.instagram||settings?.instagram),icon:<svg viewBox="0 0 24 24" width={20} height={20} fill="currentColor" aria-hidden="true"><path d="M12 2c2.717 0 3.056.01 4.122.06 1.065.05 1.79.217 2.428.465a4.9 4.9 0 0 1 1.772 1.153 4.9 4.9 0 0 1 1.153 1.772c.248.637.415 1.363.465 2.428.047 1.066.06 1.405.06 4.122s-.01 3.056-.06 4.122c-.05 1.065-.217 1.79-.465 2.428a4.9 4.9 0 0 1-1.153 1.772 4.9 4.9 0 0 1-1.772 1.153c-.637.248-1.363.415-2.428.465-1.066.047-1.405.06-4.122.06s-3.056-.01-4.122-.06c-1.065-.05-1.79-.217-2.428-.465a4.9 4.9 0 0 1-1.772-1.153 4.9 4.9 0 0 1-1.772 1.153c-.248-.637-.415-1.363-.465-2.428C2.013 15.056 2 14.717 2 12s.01-3.056.06-4.122c.05-1.065.217-1.79.465-2.428A4.9 4.9 0 0 1 3.678 3.678 4.9 4.9 0 0 1 5.45 2.525c.637-.248 1.363-.415 2.428-.465C8.944 2.013 9.283 2 12 2zm0 1.802c-2.67 0-2.986.01-4.04.058-.976.045-1.505.207-1.857.344-.467.182-.8.399-1.15.748-.35.35-.566.683-.748 1.15-.137.352-.3.881-.344 1.857-.048 1.054-.058 1.37-.058 4.04s.01 2.986.058 4.04c.045.976.207 1.505.344 1.857.182.467.399.8.748 1.15.35.35.683.566 1.15.748.352.137.881.3 1.857.344 1.054.048 1.37.058 4.04.058s2.986-.01 4.04-.058c.976-.045 1.505-.207 1.857-.344.467-.182.8-.399 1.15-.748.35-.35.566-.683.748-1.15.137-.352.3-.881.344-1.857.048-1.054.058-1.37.058-4.04s-.01-2.986-.058-4.04c-.045-.976-.207-1.505-.344-1.857a3.1 3.1 0 0 0-.748-1.15 3.1 3.1 0 0 0-1.15-.748c-.352-.137-.881-.3-1.857-.344-1.054-.048-1.37-.058-4.04-.058zm0 3.063a5.135 5.135 0 1 1 0 10.27 5.135 5.135 0 0 1 0-10.27zm0 1.802a3.333 3.333 0 1 0 0 6.666 3.333 3.333 0 0 0 0-6.666zm5.338-3.205a1.2 1.2 0 1 1 0 2.4 1.2 1.2 0 0 1 0-2.4z"/></svg>},
    {name:'maps',label:'Google Maps',url:clean(mapsUrl),icon:<svg viewBox="0 0 24 24" width={20} height={20} fill="currentColor" aria-hidden="true"><path fillRule="evenodd" clipRule="evenodd" d="M12 0C7.31 0 3.5 3.81 3.5 8.5c0 5.89 7.44 14.67 7.76 15.05a1 1 0 0 0 1.48 0c.32-.38 7.76-9.16 7.76-15.05C20.5 3.81 16.69 0 12 0zm0 13a4.5 4.5 0 1 1 0-9 4.5 4.5 0 0 1 0 9z"/></svg>},
    {name:'youtube',label:'YouTube',url:clean(social.youtube||settings?.youtube),icon:<svg viewBox="0 0 24 24" width={20} height={20} fill="currentColor" aria-hidden="true"><path d="M23.5 6.2a3.02 3.02 0 0 0-2.12-2.14C19.5 3.5 12 3.5 12 3.5s-7.5 0-9.38.56A3.02 3.02 0 0 0 .5 6.2 31.6 31.6 0 0 0 0 12a31.6 31.6 0 0 0 .5 5.8 3.02 3.02 0 0 0 2.12 2.14C4.5 20.5 12 20.5 12 20.5s7.5 0 9.38-.56a3.02 3.02 0 0 0 2.12-2.14A31.6 31.6 0 0 0 24 12a31.6 31.6 0 0 0-.5-5.8zM9.6 15.6V8.4l6.3 3.6-6.3 3.6z"/></svg>},
    {name:'tiktok',label:'TikTok',url:clean(social.tiktok||settings?.tiktok),icon:<svg viewBox="0 0 24 24" width={20} height={20} fill="currentColor" aria-hidden="true"><path d="M16.5 2h-3.03v13.74a3.07 3.07 0 1 1-2.17-2.93v-3.1a6.17 6.17 0 1 0 5.2 6.1V8.58a7.6 7.6 0 0 0 4.5 1.45V6.99a4.6 4.6 0 0 1-4.5-4.6V2z"/></svg>},
  ].filter(i=>Boolean(i.url));
  if(!items.length)return null;
  return <div className="home-social-strip"><div className="home-social-row">{items.map(item=><a key={item.name} href={item.url} target="_blank" rel="noreferrer" aria-label={item.label} className="home-social-link">{item.icon}</a>)}</div></div>;
}
export function HomePage(){const reduced=useReducedMotion(),settings=useDocument('gymSettings/config')||gym;return <><IntroSplash/><section className="hero"><motion.div className="hero-copy" initial={reduced?false:{opacity:0,y:20}} animate={{opacity:1,y:0}} transition={{duration:.6}}><p className="eyebrow">Junior Boy Boxing</p><PunchTitle/><p className="lede">More confidence. More focus. A stronger tomorrow. Boxing for kids and teens, with Coach Sharif in your corner.</p><div className="hero-actions"><ActionLink href="/offers">Book now</ActionLink></div><div className="hero-stamp"><Icon name="bolt" size={14}/>Discipline builds champions</div></motion.div><div className="hero-photo"><img src={(settings as Record<string,string>).heroImageUrl||'/assets/images/backgrounds/bg_home_hero_logo.jpg'} alt="Junior Boy Boxing"/><div className="hero-caption"><span>STRONGER KIDS.<br/>BRIGHTER FUTURES.</span></div></div></section><HomeHeroSocial settings={settings}/><HomeSessions/><HomeShopSection/><KidsGallery/><VisitUs/></>;}
export function HomeSessions(){const {rows,loading,error}=useRows('sessions');const now=new Date(new Date().toDateString());const upcoming=rows.filter(r=>{const end=r.endDate?.toDate?r.endDate.toDate():new Date(r.endDate);return end>=now;}).sort((a,b)=>(a.startDate?.seconds||0)-(b.startDate?.seconds||0));const trackRef=useRef<HTMLDivElement>(null);function scroll(dir:number){const el=trackRef.current;if(!el)return;const card=el.querySelector('.parent-offer-card') as HTMLElement|null;const amount=(card?.offsetWidth||340)+24;el.scrollBy({left:dir*amount,behavior:'smooth'});}return <section className="section"><div className="container"><div className="section-heading"><div><p className="eyebrow">Upcoming training</p><h2>Sessions</h2></div><Link href="/offers" className="section-link">See all sessions</Link></div>{error&&<Notice error>{error}</Notice>}{loading?<Loading/>:upcoming.length?<><div className="home-sessions-track" ref={trackRef}>{upcoming.map(s=><article className="card parent-offer-card" key={s.id}>{s.images?.[0]&&<img className="parent-offer-cover" src={s.images[0]} alt={s.title||''} loading="lazy"/>}<h3 className="parent-offer-title" title={s.title}>{s.title}</h3><p className="parent-offer-desc" title={s.description}>{s.description}</p><div className="parent-offer-footer"><div className="parent-offer-footer-row"><strong>${Number(s.price||0).toFixed(2)}</strong><span className="muted">{(s.joinedUserIds||[]).length} / {s.maxParticipants} joined</span></div><ActionLink href={`/offers/detail?id=${encodeURIComponent(s.id)}`}>View details</ActionLink></div></article>)}</div>{upcoming.length>1&&<div className="home-carousel-arrows"><button type="button" aria-label="Previous sessions" className="icon-button home-carousel-arrow" onClick={()=>scroll(-1)}><Icon name="chevron_left"/></button><button type="button" aria-label="Next sessions" className="icon-button home-carousel-arrow" onClick={()=>scroll(1)}><Icon name="chevron_right"/></button></div>}</>:<Empty>No upcoming sessions are available right now.</Empty>}</div></section>;}
function VisitUs(){const settings=useDocument('gymSettings/config')||gym,address=String(settings.address||'').trim();if(!address)return null;return <section id="visit-us" className="section visit-us"><div className="container"><div className="section-heading"><div><p className="eyebrow">Come by the gym</p><h2>Visit us</h2></div></div><div className="visit-wrap"><iframe title="Junior Boy Boxing location on Google Maps" src={`https://www.google.com/maps?q=${encodeURIComponent(address)}&output=embed`} loading="lazy" referrerPolicy="no-referrer-when-downgrade"/><a href={`https://www.google.com/maps/dir/?api=1&destination=${encodeURIComponent(address)}`} target="_blank" rel="noreferrer" className="visit-address">{address}</a></div></div></section>;}
export function Programs(){
  const {rows}=useRows('classes',[where('isActive','==',true)]);
  const [index,setIndex]=useState(0);
  const trackRef=useRef<HTMLDivElement>(null);
  const scrollTimer=useRef<ReturnType<typeof setTimeout>>();
  useEffect(()=>{
    if (rows.length<2) return;
    const id=setInterval(()=>setIndex(i=>(i+1)%rows.length),5000);
    return ()=>clearInterval(id);
  },[rows.length]);
  useEffect(()=>{
    const el=trackRef.current; if (!el) return;
    el.scrollTo({left:index*el.clientWidth, behavior:'smooth'});
  },[index]);
  if (!rows.length) return null;
  return <div className="featured-carousel">
    <div ref={trackRef} className="featured-track" onScroll={e=>{
      const el=e.currentTarget;
      clearTimeout(scrollTimer.current);
      scrollTimer.current=setTimeout(()=>{
        const i=Math.round(el.scrollLeft/(el.clientWidth||1));
        setIndex(current=>i!==current?i:current);
      },150);
    }}>
      {rows.map(p=>{
        const hasDiscount=p.discountActive===true&&p.discountPercent>0&&p.price>0;
        const saleCents=hasDiscount?Math.round(p.price*(1-p.discountPercent/100)):p.price;
        return <a key={p.id} href={`/schedule?program=${p.id}`} className="featured-slide">
          {p.imageUrl&&<img src={p.imageUrl} alt=""/>}
          <div>
            {p.category&&<span className="featured-eyebrow">{p.category}</span>}
            <h3 style={{margin:0,fontSize:20}}>{p.className}</h3>
            {hasDiscount?<p style={{margin:'6px 0 0'}}><span className="price-was" style={{marginLeft:0,marginRight:8}}>{p.priceLabel}</span><strong style={{color:'var(--green)'}}>{money(saleCents)}</strong></p>:p.priceLabel&&<p className="muted" style={{margin:'6px 0 0',fontSize:13}}>{p.priceLabel}</p>}
          </div>
        </a>;
      })}
    </div>
    {rows.length>1&&<div className="featured-dots">{rows.map((p,i)=><button key={p.id} aria-label={`Go to slide ${i+1}`} className={i===index?'active':''} onClick={()=>setIndex(i)}/>)}</div>}
  </div>;
}
export function CTA(){return <section className="cta-band"><div className="container"><div><p style={{fontSize:11,letterSpacing:2,marginBottom:12}}>YOUR FIRST ROUND STARTS HERE</p><h2>Ready to train?</h2></div><AuthCTA signedOut={{label:'Join Junior Boy Boxing',href:'/signup'}} signedIn={{label:'Book a Class',href:'/schedule'}}/></div></section>;}
export function AboutPage(){const settings=useDocument('gymSettings/config')||gym;return <><div className="container page-wrap"><PageHeading eyebrow="Meet your corner" title="More than boxing.">A stronger future starts with the habits we build today.</PageHeading><div className="two-col"><img className="about-photo" src="/assets/images/photos/photo_kid_boxing.png" alt="Junior boxing training"/><div><p className="eyebrow">{settings.coachName}</p><h2>Train with purpose.</h2><p className="lede">{settings.aboutText}</p><p className="muted">We teach young athletes to listen, practise and improve in a focused training environment.</p><ActionLink href="/contact" secondary>Contact Coach Sharif</ActionLink></div></div><div className="section"><Programs/></div></div><CTA/></>;}
export function ContactPage(){const [busy,setBusy]=useState(false),[message,setMessage]=useState(''),[error,setError]=useState(''),settings=useDocument('gymSettings/config')||gym;const phoneDigits=String(settings.phone||'').replace(/[^0-9]/g,'');async function submit(e:FormEvent<HTMLFormElement>){e.preventDefault();const form=e.currentTarget,data=Object.fromEntries(new FormData(form));setBusy(true);setError('');try{await call('contactGym',data);setMessage('Your message has been sent. The gym will be in touch.');form.reset();}catch(e){setError(errorMessage(e));}finally{setBusy(false);}}return <div className="container page-wrap"><PageHeading eyebrow="We’re in your corner" title="Let’s talk training.">Questions about classes, ages or getting started? Send Coach Sharif a message.</PageHeading><div className="two-col" style={{alignItems:'start'}}><form className="card stack" onSubmit={submit}><label className="field">Your name<input name="name" required minLength={2} maxLength={100} autoComplete="name"/></label><label className="field">Email<input name="email" type="email" required autoComplete="email"/></label><label className="field">Message<textarea name="message" required minLength={10} maxLength={4000}/></label><label className="hidden-trap" aria-hidden="true">Website<input name="website" tabIndex={-1} autoComplete="off"/></label>{error&&<Notice error>{error}</Notice>}{message&&<Notice>{message}</Notice>}<Button busy={busy}>Send Message →</Button></form><div>{settings.email&&<p><a href={`mailto:${settings.email}`}>{settings.email}</a></p>}{phoneDigits&&<p><a href={`https://wa.me/${phoneDigits}`} target="_blank" rel="noreferrer">WhatsApp: {settings.phone}</a></p>}{phoneDigits&&<p><a href={`tel:${settings.phone}`}>Call: {settings.phone}</a></p>}<h3 style={{marginTop:24}}>Operating hours</h3>{Object.entries(settings.operatingHours||{}).length?Object.entries(settings.operatingHours||{}).map(([day,time])=><p className="row spread" key={day}><span>{day}</span><span className="muted">{String(time)}</span></p>):<p className="muted">Contact the gym to confirm training hours.</p>}</div></div></div>;}
