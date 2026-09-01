# Deployment — ARVECTA site v3

El sitio es estático y no requiere build.

## Ver localmente

```bash
python3 -m http.server 8080
```

## Páginas

- `/`
- `/servicios.html`
- `/sectores.html`
- `/empresa.html`
- `/contacto.html`
- `/404.html`

## Opciones de publicación

1. Cloudflare Pages.
2. GitHub Pages.
3. Netlify.
4. Nginx en servidor propio.

## Checklist antes de producción

- [ ] Configurar `arvecta.mx` y HTTPS.
- [ ] Revisar responsive en desktop, tablet y móvil.
- [ ] Ejecutar Lighthouse y corregir problemas críticos de accesibilidad/performance.
- [ ] Activar analítica sólo cuando se defina la política de privacidad/cookies aplicable.
- [ ] Dar de alta Google Search Console y enviar `sitemap.xml`.
- [ ] Mantener `robots.txt` y canonical de cada página.
- [ ] Validar aviso de privacidad antes de sustituir el flujo `mailto:` por un formulario que almacene o procese datos en backend.
- [ ] Mantener el formulario actual sin almacenamiento mientras no exista ese aviso/endpoint.
- [ ] Publicar casos de estudio únicamente con autorización del cliente.
- [ ] Revisar datos corporativos del footer cuando RFC y demás datos operativos estén finalizados.

## Marca

La web debe usar los masters PNG aprobados de `brand/`. Los SVG históricos no sustituyen al master visual aprobado.
