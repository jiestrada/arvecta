# ARVECTA Technologies

Sitio corporativo y sistema de marca de **ARVECTA TECHNOLOGIES, S.A.S.**

> **Construir. Integrar. Evolucionar.**

ARVECTA diseña software, integra sistemas y estructura datos para organizaciones que necesitan más control, trazabilidad y capacidad de ejecución.

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

## Sitio corporativo v3

La tercera dirección mantiene el lenguaje de ingeniería de sistemas, pero corrige los puntos que todavía hacían ver la web como una landing de consultoría:

- copy centrado en el comprador, no en discusiones internas de ARVECTA;
- Sora para titulares, Inter para lectura e IBM Plex Mono para lenguaje técnico;
- navegación hacia páginas corporativas reales;
- hero técnico y mapa de sistemas propio;
- tres capacidades principales;
- metodología formal: Diagnóstico y arquitectura → Implementación controlada → Operación y evolución;
- disciplina de ejecución como argumento de confianza;
- sectorización sin encerrar la marca;
- activos propios presentados de forma compacta;
- footer institucional y página de contacto estructurada;
- accesibilidad básica y responsive.

## Arquitectura

```text
/
├── index.html
├── servicios.html
├── sectores.html
├── empresa.html
├── contacto.html
├── 404.html
├── assets/
│   ├── css/site-v3.css
│   ├── css/contact-page.css
│   └── js/site-v3.js
└── brand/
    ├── arvecta-logo.png
    ├── arvecta-logo-white.png
    ├── arvecta-symbol.png
    ├── arvecta-symbol-white.png
    ├── arvecta-system-field-v2.svg
    └── BRAND-GUIDELINES.md
```

## Branding

Masters PNG aprobados:

- `brand/arvecta-logo.png`
- `brand/arvecta-logo-white.png`
- `brand/arvecta-symbol.png`
- `brand/arvecta-symbol-white.png`

Los SVG históricos permanecen como referencia, pero no deben considerarse masters definitivos si no reproducen fielmente el arte aprobado.

## Dominio

- Web: `https://arvecta.mx`
- Correo: `contacto@arvecta.mx`

## Principio comercial

La web responde en este orden:

1. qué fricción operativa existe;
2. qué resultado debe conseguirse;
3. qué capacidad aplica ARVECTA;
4. cómo se reduce riesgo de ejecución;
5. cuál es el siguiente paso.

## Derechos

Código, branding, copy y activos visuales son propiedad de ARVECTA Technologies salvo indicación contraria.
