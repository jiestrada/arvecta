const menuButton=document.querySelector('[data-menu]');
const mobileNav=document.querySelector('[data-mobile-nav]');
if(menuButton&&mobileNav){
  menuButton.addEventListener('click',()=>{
    const open=mobileNav.classList.toggle('open');
    menuButton.setAttribute('aria-expanded',String(open));
  });
}

const revealItems=document.querySelectorAll('.reveal');
if('IntersectionObserver'in window){
  const observer=new IntersectionObserver(entries=>{
    entries.forEach(entry=>{
      if(entry.isIntersecting){
        entry.target.classList.add('in');
        observer.unobserve(entry.target);
      }
    });
  },{threshold:.12});
  revealItems.forEach(item=>observer.observe(item));
}else{
  revealItems.forEach(item=>item.classList.add('in'));
}

const year=document.querySelector('[data-year]');
if(year)year.textContent=new Date().getFullYear();
