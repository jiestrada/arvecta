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

const year=document.querySelectorAll('[data-year]');
year.forEach(el=>el.textContent=new Date().getFullYear());

const form=document.querySelector('[data-contact-form]');
if(form){
  form.addEventListener('submit',event=>{
    event.preventDefault();
    const data=new FormData(form);
    const name=data.get('name')||'';
    const company=data.get('company')||'';
    const email=data.get('email')||'';
    const type=data.get('type')||'';
    const message=data.get('message')||'';
    const subject=encodeURIComponent(`Proyecto ARVECTA — ${company||name||'Nuevo contacto'}`);
    const body=encodeURIComponent(`Nombre: ${name}\nEmpresa: ${company}\nCorreo: ${email}\nTipo de necesidad: ${type}\n\nQué necesitamos resolver:\n${message}`);
    window.location.href=`mailto:contacto@arvecta.mx?subject=${subject}&body=${body}`;
  });
}
