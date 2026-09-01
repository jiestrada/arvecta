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
      website:(data.get('website')||'').toString().trim()
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
