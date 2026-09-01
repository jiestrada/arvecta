# Deployment

El sitio es estático y no requiere build.

## Ver localmente
```bash
python3 -m http.server 8080
```

## Opciones de publicación
1. Cloudflare Pages.
2. GitHub Pages.
3. Netlify.
4. Nginx en servidor propio.

## Checklist antes de producción
- Configurar `arvecta.mx` y HTTPS.
- Activar analítica y Search Console.
- Mantener `sitemap.xml` y `robots.txt`.
- Reemplazar el CTA `mailto:` por un endpoint real cuando exista backend.
- Añadir aviso de privacidad antes de captar datos mediante formulario.
- Publicar casos de estudio únicamente cuando exista autorización del cliente.
