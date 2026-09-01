# ARVECTA Technologies

Sitio corporativo y sistema de marca de **ARVECTA TECHNOLOGIES, S.A.S.**

> **Construir. Integrar. Evolucionar.**

ARVECTA diseña software, integra sistemas y estructura datos para organizaciones que necesitan más control, trazabilidad y capacidad de ejecución.

## Stack

- HTML/CSS/JavaScript para la experiencia web.
- ASP.NET Core 8 como host y API mínima.
- MailKit para envío SMTP del formulario de contacto.
- Rate limiting por IP y honeypot básico contra spam.

## Ejecutar localmente

Para probar **todo el sitio, incluido el envío real del formulario**, usa .NET:

```bash
git clone https://github.com/jiestrada/arvecta.git
cd arvecta
dotnet restore
dotnet run --urls http://localhost:8080
```

Abre:

```text
http://localhost:8080
```

Si ya tienes el repositorio:

```bash
cd ~/Devs/arvecta
git pull origin main
dotnet restore
dotnet run --urls http://localhost:8080
```

> `python3 -m http.server 8080` sigue sirviendo para revisar únicamente la parte visual, pero **no ejecuta `/api/contact`** y por tanto el formulario no enviará correos.

## Configurar correo

El proyecto reutiliza temporalmente la infraestructura SMTP de AI Regula Solutions mediante la sección `EmailSettings`.

`appsettings.json` contiene sólo parámetros no secretos y deja usuario/password vacíos. **No pongas credenciales reales en ese archivo.**

Crea un archivo local a partir del ejemplo:

```bash
cp appsettings.Local.example.json appsettings.Local.json
```

Después edita `appsettings.Local.json`:

```json
{
  "EmailSettings": {
    "SmtpUser": "TU_USUARIO_SMTP",
    "SmtpPassword": "TU_PASSWORD_SMTP"
  }
}
```

`appsettings.Local.json` está incluido en `.gitignore` y no debe subirse al repositorio.

También puedes sobrescribir cualquier valor mediante variables de entorno, por ejemplo:

```bash
export EmailSettings__SmtpUser="usuario"
export EmailSettings__SmtpPassword="password"
```

### Configuración actual no secreta

- SMTP: infraestructura temporal de AI Regula Solutions.
- Remitente temporal: `info@airegulasolutions.com`.
- Destino: `contacto@arvecta.mx`.
- `Reply-To`: se establece automáticamente al correo que captura el prospecto, para que puedas responderle directamente.

## Formulario de contacto

`POST /api/contact`

El endpoint:

- valida nombre, correo y mensaje;
- limita solicitudes por IP;
- incorpora un honeypot básico;
- escapa contenido antes de construir el HTML del correo;
- envía el mensaje a `contacto@arvecta.mx`;
- devuelve confirmación JSON al frontend;
- no almacena los datos en una base de datos.

Health check:

```text
GET /health/live
```

## Arquitectura

```text
/
├── Arvecta.Web.csproj
├── Program.cs
├── appsettings.json
├── appsettings.Local.example.json
├── index.html
├── servicios.html
├── sectores.html
├── empresa.html
├── contacto.html
├── 404.html
├── assets/
│   ├── css/site-v3.css
│   ├── css/site-v4.css
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
