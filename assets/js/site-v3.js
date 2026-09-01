const GA_MEASUREMENT_ID='G-DVKX7DGK9T';
const CONSENT_KEY='arvecta_cookie_consent';
let analyticsLoaded=false;

const readConsent=()=>{
  try{
    const raw=localStorage.getItem(CONSENT_KEY);
    if(!raw)return null;
    const parsed=JSON.parse(raw);
    return parsed&&['granted','denied'].includes(parsed.analytics)?parsed:null;
  }catch{return null;}
};

const writeConsent=analytics=>{
  const value={analytics,updatedAt:new Date().toISOString(),version:1};
  localStorage.setItem(CONSENT_KEY,JSON.stringify(value));
  return value;
};

const clearAnalyticsCookies=()=>{
  document.cookie.split(';').map(v=>v.trim().split('=')[0]).filter(name=>name==='_ga'||name.startsWith('_ga_')).forEach(name=>{
    document.cookie=`${name}=; Max-Age=0; path=/; SameSite=Lax`;
    document.cookie=`${name}=; Max-Age=0; path=/; domain=.arvecta.mx; SameSite=Lax`;
  });
};

const loadAnalytics=()=>{
  if(analyticsLoaded)return;
  analyticsLoaded=true;
  window.dataLayer=window.dataLayer||[];
  window.gtag=window.gtag||function(){window.dataLayer.push(arguments)};
  window.gtag('consent','default',{
    analytics_storage:'granted',
    ad_storage:'denied',
    ad_user_data:'denied',
    ad_personalization:'denied'
  });
  window.gtag('js',new Date());
  window.gtag('config',GA_MEASUREMENT_ID);
  if(!document.querySelector(`script[src*="${GA_MEASUREMENT_ID}"]`)){
    const googleTag=document.createElement('script');
    googleTag.async=true;
    googleTag.src=`https://www.googletagmanager.com/gtag/js?id=${GA_MEASUREMENT_ID}`;
    document.head.appendChild(googleTag);
  }
};

const trackAnalyticsEvent=(name,parameters={})=>{
  if(readConsent()?.analytics!=='granted')return;
  loadAnalytics();
  window.gtag?.('event',name,parameters);
};

const removeConsentBanner=()=>document.querySelector('[data-consent-banner]')?.remove();

const setAnalyticsConsent=choice=>{
  const previous=readConsent()?.analytics;
  writeConsent(choice);
  removeConsentBanner();
  if(choice==='granted'){
    if(window.gtag)window.gtag('consent','update',{analytics_storage:'granted',ad_storage:'denied',ad_user_data:'denied',ad_personalization:'denied'});
    loadAnalytics();
  }else{
    if(window.gtag)window.gtag('consent','update',{analytics_storage:'denied',ad_storage:'denied',ad_user_data:'denied',ad_personalization:'denied'});
    clearAnalyticsCookies();
    if(previous==='granted')window.location.reload();
  }
};

const showConsentBanner=()=>{
  removeConsentBanner();
  const banner=document.createElement('section');
  banner.className='cookie-banner';
  banner.dataset.consentBanner='';
  banner.setAttribute('role','dialog');
  banner.setAttribute('aria-label','Preferencias de privacidad');
  banner.innerHTML=`<div class="cookie-banner-inner"><div class="cookie-copy"><strong>Privacidad y analítica</strong><p>Usamos tecnologías necesarias para operar el sitio. Google Analytics sólo se carga si autorizas analítica. Puedes cambiar tu elección después.</p><a href="cookies.html">Política de Cookies</a> · <a href="aviso-privacidad.html">Aviso de Privacidad</a></div><div class="cookie-actions"><button class="btn btn-primary" type="button" data-consent-accept>Aceptar analítica</button><button class="btn cookie-btn-secondary" type="button" data-consent-reject>Sólo necesarias</button></div></div>`;
  document.body.appendChild(banner);
  banner.querySelector('[data-consent-accept]')?.addEventListener('click',()=>setAnalyticsConsent('granted'));
  banner.querySelector('[data-consent-reject]')?.addEventListener('click',()=>setAnalyticsConsent('denied'));
};

document.querySelectorAll('[data-cookie-settings]').forEach(button=>button.addEventListener('click',showConsentBanner));
const initialConsent=readConsent();
if(initialConsent?.analytics==='granted')loadAnalytics();
else if(!initialConsent)showConsentBanner();

const header=document.querySelector('.site-header');
const menuButton=document.querySelector('[data-menu]');
const mobileNav=document.querySelector('[data-mobile-nav]');

const syncHeader=()=>{if(header)header.classList.toggle('scrolled',window.scrollY>18)};
syncHeader();
window.addEventListener('scroll',syncHeader,{passive:true});

if(menuButton&&mobileNav){
  menuButton.addEventListener('click',()=>{
    const open=mobileNav.classList.toggle('open');
    menuButton.setAttribute('aria-expanded',String(open));
  });
  mobileNav.querySelectorAll('a').forEach(link=>link.addEventListener('click',()=>{
    mobileNav.classList.remove('open');
    menuButton.setAttribute('aria-expanded','false');
  }));
}

const revealItems=document.querySelectorAll('.reveal');
if('IntersectionObserver'in window&&!window.matchMedia('(prefers-reduced-motion: reduce)').matches){
  const observer=new IntersectionObserver(entries=>{
    entries.forEach(entry=>{
      if(entry.isIntersecting){
        entry.target.classList.add('in');
        observer.unobserve(entry.target);
      }
    });
  },{threshold:.11});
  revealItems.forEach(item=>observer.observe(item));
}else{
  revealItems.forEach(item=>item.classList.add('in'));
}

document.querySelectorAll('[data-year]').forEach(el=>el.textContent=new Date().getFullYear());

const form=document.querySelector('[data-contact-form]');
if(form){
  const submitButton=form.querySelector('button[type="submit"]');
  const status=form.querySelector('[data-form-status]');
  const originalButtonText=submitButton?.textContent||'Enviar mensaje';

  const setStatus=(message,type='')=>{
    if(!status)return;
    status.textContent=message;
    status.className=`form-status${type?` ${type}`:''}`;
    status.hidden=!message;
  };

  form.addEventListener('submit',async event=>{
    event.preventDefault();
    if(!form.reportValidity())return;

    const data=new FormData(form);
    const payload={
      name:(data.get('name')||'').toString().trim(),
      company:(data.get('company')||'').toString().trim(),
      email:(data.get('email')||'').toString().trim(),
      type:(data.get('type')||'').toString().trim(),
      message:(data.get('message')||'').toString().trim(),
      website:(data.get('website')||'').toString().trim(),
      privacyNoticeAccepted:Boolean(data.get('privacyNoticeAccepted'))
    };

    submitButton.disabled=true;
    submitButton.textContent='Enviando…';
    setStatus('Enviando tu mensaje a ARVECTA…','pending');

    try{
      const response=await fetch('/api/contact',{
        method:'POST',
        headers:{'Content-Type':'application/json','Accept':'application/json'},
        body:JSON.stringify(payload)
      });
      const result=await response.json().catch(()=>({}));

      if(!response.ok||!result.ok){
        throw new Error(result.error||'No pudimos enviar el mensaje en este momento.');
      }

      trackAnalyticsEvent('generate_lead',{
        event_category:'contact',
        event_label:payload.type||'unspecified'
      });

      form.reset();
      setStatus(result.message||'Mensaje enviado. Gracias por contactar a ARVECTA.','success');
      submitButton.textContent='Mensaje enviado';
      setTimeout(()=>{submitButton.textContent=originalButtonText;},3500);
    }catch(error){
      setStatus(`${error.message||'No pudimos enviar el mensaje.'} También puedes escribir directamente a contacto@arvecta.mx.`,'error');
      submitButton.textContent=originalButtonText;
    }finally{
      submitButton.disabled=false;
    }
  });
}
