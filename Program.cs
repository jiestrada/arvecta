using System.Net;
using System.Threading.RateLimiting;
using MailKit.Net.Smtp;
using MailKit.Security;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.AspNetCore.StaticFiles;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Options;
using MimeKit;

var builder = WebApplication.CreateBuilder(args);

builder.Configuration.AddJsonFile("appsettings.Local.json", optional: true, reloadOnChange: true);

builder.Services.Configure<EmailSettings>(builder.Configuration.GetSection("EmailSettings"));
builder.Services.AddSingleton<ContactEmailSender>();
builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    options.KnownProxies.Add(IPAddress.Loopback);
    options.KnownProxies.Add(IPAddress.IPv6Loopback);
});
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.AddPolicy("contact", httpContext =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: httpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 5,
                Window = TimeSpan.FromMinutes(10),
                QueueLimit = 0,
                AutoReplenishment = true
            }));
});

var app = builder.Build();

app.UseForwardedHeaders();

if (!app.Environment.IsDevelopment())
    app.UseHsts();

app.Use(async (context, next) =>
{
    context.Response.Headers["X-Content-Type-Options"] = "nosniff";
    context.Response.Headers["X-Frame-Options"] = "DENY";
    context.Response.Headers["Referrer-Policy"] = "strict-origin-when-cross-origin";
    context.Response.Headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=(), payment=()";
    await next();
});

app.UseRateLimiter();
app.UseHttpsRedirection();

var rootProvider = new PhysicalFileProvider(app.Environment.ContentRootPath);
var contentTypes = new FileExtensionContentTypeProvider();
contentTypes.Mappings.Clear();
contentTypes.Mappings[".html"] = "text/html; charset=utf-8";
contentTypes.Mappings[".css"] = "text/css; charset=utf-8";
contentTypes.Mappings[".js"] = "application/javascript; charset=utf-8";
contentTypes.Mappings[".png"] = "image/png";
contentTypes.Mappings[".svg"] = "image/svg+xml";
contentTypes.Mappings[".ico"] = "image/x-icon";
contentTypes.Mappings[".webmanifest"] = "application/manifest+json";
contentTypes.Mappings[".txt"] = "text/plain; charset=utf-8";
contentTypes.Mappings[".xml"] = "application/xml; charset=utf-8";
contentTypes.Mappings[".webp"] = "image/webp";
contentTypes.Mappings[".jpg"] = "image/jpeg";
contentTypes.Mappings[".jpeg"] = "image/jpeg";

// Serve the corporate homepage explicitly. Do not depend on DefaultFiles for the
// repository-root static-site layout used by ARVECTA's published artifact.
app.Use(async (context, next) =>
{
    if (context.Request.Path == "/" &&
        (HttpMethods.IsGet(context.Request.Method) || HttpMethods.IsHead(context.Request.Method)))
    {
        var indexPath = Path.Combine(app.Environment.ContentRootPath, "index.html");
        if (!File.Exists(indexPath))
        {
            app.Logger.LogError("ARVECTA homepage missing at {IndexPath}", indexPath);
            context.Response.StatusCode = StatusCodes.Status500InternalServerError;
            await context.Response.WriteAsync("ARVECTA homepage is unavailable.");
            return;
        }

        context.Response.StatusCode = StatusCodes.Status200OK;
        context.Response.ContentType = "text/html; charset=utf-8";
        context.Response.Headers.CacheControl = "no-cache";
        if (!HttpMethods.IsHead(context.Request.Method))
            await context.Response.SendFileAsync(indexPath);
        return;
    }

    await next();
});

app.UseStaticFiles(new StaticFileOptions
{
    FileProvider = rootProvider,
    ContentTypeProvider = contentTypes,
    ServeUnknownFileTypes = false,
    OnPrepareResponse = context =>
    {
        var path = context.File.Name;
        if (path.EndsWith(".html", StringComparison.OrdinalIgnoreCase))
            context.Context.Response.Headers.CacheControl = "no-cache";
        else
            context.Context.Response.Headers.CacheControl = "public,max-age=86400";
    }
});

app.MapGet("/health/live", () => Results.Ok(new { status = "ok", service = "arvecta-web" }));
app.MapGet("/health/ready", (IOptions<EmailSettings> options) =>
{
    var settings = options.Value;
    var ready = !string.IsNullOrWhiteSpace(settings.SmtpHost) &&
                !string.IsNullOrWhiteSpace(settings.SmtpUser) &&
                !string.IsNullOrWhiteSpace(settings.SmtpPassword) &&
                !string.IsNullOrWhiteSpace(settings.FromEmail) &&
                !string.IsNullOrWhiteSpace(settings.ToEmail);

    return ready
        ? Results.Ok(new { status = "ready", service = "arvecta-web", email = "configured" })
        : Results.Json(new { status = "not-ready", service = "arvecta-web", email = "not-configured" }, statusCode: StatusCodes.Status503ServiceUnavailable);
});

app.MapPost("/api/contact", async (ContactRequest request, HttpContext context, ContactEmailSender sender, CancellationToken cancellationToken) =>
{
    if (!string.IsNullOrWhiteSpace(request.Website))
        return Results.Ok(new { ok = true });

    var name = request.Name?.Trim() ?? string.Empty;
    var company = request.Company?.Trim() ?? string.Empty;
    var email = request.Email?.Trim() ?? string.Empty;
    var type = request.Type?.Trim() ?? string.Empty;
    var message = request.Message?.Trim() ?? string.Empty;

    if (name.Length is < 2 or > 120)
        return Results.BadRequest(new { ok = false, error = "Escribe un nombre válido." });
    if (company.Length > 160)
        return Results.BadRequest(new { ok = false, error = "El nombre de la empresa es demasiado largo." });
    if (type.Length > 120)
        return Results.BadRequest(new { ok = false, error = "La necesidad seleccionada no es válida." });
    if (message.Length is < 20 or > 5000)
        return Results.BadRequest(new { ok = false, error = "Describe el problema con al menos 20 caracteres y un máximo de 5,000." });

    try
    {
        var address = new System.Net.Mail.MailAddress(email);
        if (!string.Equals(address.Address, email, StringComparison.OrdinalIgnoreCase))
            return Results.BadRequest(new { ok = false, error = "Escribe un correo válido." });
    }
    catch
    {
        return Results.BadRequest(new { ok = false, error = "Escribe un correo válido." });
    }

    var result = await sender.SendContactAsync(new ContactMessage(name, company, email, type, message), cancellationToken);
    if (!result.Success)
    {
        app.Logger.LogError("Contact email failed: {Reason}", result.Error);
        return Results.Json(new { ok = false, error = "No pudimos enviar el mensaje en este momento. Intenta de nuevo o escribe a contacto@arvecta.mx." }, statusCode: StatusCodes.Status503ServiceUnavailable);
    }

    app.Logger.LogInformation("Contact message sent for {Company} from {Email} via {RemoteIp}", company, email, context.Connection.RemoteIpAddress);
    return Results.Ok(new { ok = true, message = "Mensaje enviado. Gracias por contactar a ARVECTA." });
}).RequireRateLimiting("contact");

app.MapFallback(async context =>
{
    context.Response.StatusCode = StatusCodes.Status404NotFound;
    context.Response.ContentType = "text/html; charset=utf-8";
    await context.Response.SendFileAsync(Path.Combine(app.Environment.ContentRootPath, "404.html"));
});

app.Logger.LogInformation("ARVECTA web starting in {Environment}", app.Environment.EnvironmentName);
app.Run();

public sealed record ContactRequest(string? Name, string? Company, string? Email, string? Type, string? Message, string? Website);
public sealed record ContactMessage(string Name, string Company, string Email, string Type, string Message);
public sealed record SendResult(bool Success, string? Error = null);

public sealed class EmailSettings
{
    public string SmtpHost { get; set; } = string.Empty;
    public int SmtpPort { get; set; } = 465;
    public string Security { get; set; } = "SslOnConnect";
    public string SmtpUser { get; set; } = string.Empty;
    public string SmtpPassword { get; set; } = string.Empty;
    public string FromName { get; set; } = "ARVECTA Technologies";
    public string FromEmail { get; set; } = string.Empty;
    public string ToEmail { get; set; } = "contacto@arvecta.mx";
    public string? BccEmail { get; set; }
}

public sealed class ContactEmailSender(IOptions<EmailSettings> options, ILogger<ContactEmailSender> logger)
{
    private readonly EmailSettings _settings = options.Value;

    public async Task<SendResult> SendContactAsync(ContactMessage contact, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(_settings.SmtpHost) ||
            string.IsNullOrWhiteSpace(_settings.SmtpUser) ||
            string.IsNullOrWhiteSpace(_settings.SmtpPassword) ||
            string.IsNullOrWhiteSpace(_settings.FromEmail) ||
            string.IsNullOrWhiteSpace(_settings.ToEmail))
        {
            return new SendResult(false, "EmailSettings is incomplete.");
        }

        try
        {
            var safeName = WebUtility.HtmlEncode(contact.Name);
            var safeCompany = WebUtility.HtmlEncode(contact.Company);
            var safeEmail = WebUtility.HtmlEncode(contact.Email);
            var safeType = WebUtility.HtmlEncode(contact.Type);
            var safeMessage = WebUtility.HtmlEncode(contact.Message).Replace("\n", "<br>");

            var email = new MimeMessage();
            email.From.Add(new MailboxAddress(_settings.FromName, _settings.FromEmail));
            email.To.Add(MailboxAddress.Parse(_settings.ToEmail));
            if (!string.IsNullOrWhiteSpace(_settings.BccEmail))
                email.Bcc.Add(MailboxAddress.Parse(_settings.BccEmail));
            email.ReplyTo.Add(new MailboxAddress(contact.Name, contact.Email));
            email.Subject = $"Nuevo contacto ARVECTA — {(string.IsNullOrWhiteSpace(contact.Company) ? contact.Name : contact.Company)}";

            var bodyBuilder = new BodyBuilder
            {
                TextBody = $"Nombre: {contact.Name}\nEmpresa: {contact.Company}\nCorreo: {contact.Email}\nNecesidad: {contact.Type}\n\nMensaje:\n{contact.Message}",
                HtmlBody = $"""
                    <div style="font-family:Arial,sans-serif;color:#0b1f33;line-height:1.55">
                      <h2 style="margin:0 0 18px">Nuevo contacto desde arvecta.mx</h2>
                      <table style="border-collapse:collapse;width:100%;max-width:680px">
                        <tr><td style="padding:8px 12px;background:#f4f7fa;font-weight:700">Nombre</td><td style="padding:8px 12px">{safeName}</td></tr>
                        <tr><td style="padding:8px 12px;background:#f4f7fa;font-weight:700">Empresa</td><td style="padding:8px 12px">{safeCompany}</td></tr>
                        <tr><td style="padding:8px 12px;background:#f4f7fa;font-weight:700">Correo</td><td style="padding:8px 12px">{safeEmail}</td></tr>
                        <tr><td style="padding:8px 12px;background:#f4f7fa;font-weight:700">Necesidad</td><td style="padding:8px 12px">{safeType}</td></tr>
                      </table>
                      <h3 style="margin:24px 0 8px">Qué necesita resolver</h3>
                      <div style="padding:16px;background:#f4f7fa;border-left:3px solid #3568f0;max-width:648px">{safeMessage}</div>
                      <p style="margin-top:22px;color:#58708a">Responde directamente a este correo para contestar al prospecto.</p>
                    </div>
                    """
            };
            email.Body = bodyBuilder.ToMessageBody();

            using var client = new SmtpClient();
            await client.ConnectAsync(_settings.SmtpHost, _settings.SmtpPort, ParseSecurity(_settings.Security), cancellationToken);
            await client.AuthenticateAsync(_settings.SmtpUser, _settings.SmtpPassword, cancellationToken);
            await client.SendAsync(email, cancellationToken);
            await client.DisconnectAsync(true, cancellationToken);

            return new SendResult(true);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "SMTP error while sending ARVECTA contact message.");
            return new SendResult(false, ex.Message);
        }
    }

    private static SecureSocketOptions ParseSecurity(string? value) =>
        value?.Trim().ToLowerInvariant() switch
        {
            "none" => SecureSocketOptions.None,
            "starttls" => SecureSocketOptions.StartTls,
            "starttlswhenavailable" => SecureSocketOptions.StartTlsWhenAvailable,
            "sslonconnect" => SecureSocketOptions.SslOnConnect,
            _ => SecureSocketOptions.Auto
        };
}
