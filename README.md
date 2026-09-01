# ARVECTA Technologies

Sitio corporativo y sistema de marca de **ARVECTA TECHNOLOGIES, S.A.S.**

> **Construir. Integrar. Evolucionar.**

ARVECTA diseña software, integra sistemas y estructura datos para organizaciones que necesitan más control, trazabilidad y capacidad de escalar.

## Ver localmente

```bash
git clone https://github.com/jiestrada/arvecta.git
cd arvecta
python3 -m http.server 8080
```

Abre `http://localhost:8080`.

Si ya tienes el repositorio local:

```bash
cd ~/Devs/arvecta
git pull origin main
python3 -m http.server 8080
```

## Sitio corporativo v2

La segunda dirección visual elimina el patrón genérico de landing SaaS y adopta una identidad más cercana a **ingeniería de sistemas y arquitectura tecnológica**:

- hero oscuro y técnico;
- narrativa orientada a problemas operativos;
- menos cards repetidas;
- tres capacidades principales;
- sistema visual basado en retículas, vectores y mapas de sistemas;
- metodología comercial Discovery → Build → Operate;
- credibilidad basada en ejecución, no en claims inventados.

Archivos principales:

- `index.html` — sitio corporativo.
- `assets/css/site-v2.css` — sistema visual web.
- `assets/js/site-v2.js` — menú y animaciones.
- `brand/arvecta-system-field.svg` — visual técnico propio de ARVECTA.
- `brand/BRAND-GUIDELINES.md` — manual de identidad actualizado.

## Logotipo

La web intenta cargar primero los masters PNG aprobados:

- `brand/arvecta-logo.png`
- `brand/arvecta-logo-white.png`

Si todavía no existen en el repositorio, el HTML usa los SVG históricos como fallback temporal. Los SVG anteriores **no deben considerarse el master definitivo** si no reproducen fielmente el logo aprobado.

## Brand system

- `brand/arvecta-symbol.svg` — isotipo actual para favicon/UI.
- `brand/arvecta-brand-board.svg` — lámina visual inicial.
- `brand/tokens.css` y `brand/tokens.json` — design tokens.
- `brand/BRAND-GUIDELINES.md` — reglas de marca y web.

## Dominio

- Web: `https://arvecta.mx`
- Correo: `contacto@arvecta.mx`

## Enfoque comercial

La web responde en este orden:

1. qué fricción operativa resuelve ARVECTA;
2. qué capacidades utiliza;
3. cómo reduce riesgo de ejecución;
4. cómo iniciar con un alcance controlado;
5. cómo convertir la conversación en proyecto.

## Derechos

Código, branding, copy y activos visuales son propiedad de ARVECTA Technologies salvo indicación contraria.
