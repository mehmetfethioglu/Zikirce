using System.Diagnostics;
using System.Net;
using System.Net.Http.Headers;
using System.Net.Sockets;
using System.Reflection;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using HasibuBranchBridge.Storage;

namespace HasibuBranchBridge.Cloud;

public sealed record OAuthSignInResult(bool Success, string Email, string Message);

/// <summary>
/// Google Cloud OAuth 2.0 PKCE (S256) + Loopback oturum açma ve Refresh Token yenileme istemcisi.
/// </summary>
public sealed class GoogleOAuthPkceClient : IDisposable
{
    private const int PreferredLoopbackPort = 43821;
    private const string AuthEndpoint = "https://accounts.google.com/o/oauth2/v2/auth";
    private const string TokenEndpoint = "https://oauth2.googleapis.com/token";
    private const string UserInfoEndpoint = "https://www.googleapis.com/oauth2/v2/userinfo";
    private const string Scopes = "openid email profile https://www.googleapis.com/auth/drive.file";

    private readonly DpapiSecretStore _secretStore;
    private readonly HttpClient _http;
    private readonly bool _ownsHttpClient;

    public GoogleOAuthPkceClient(DpapiSecretStore secretStore, HttpClient? httpClient = null)
    {
        _secretStore = secretStore;
        _ownsHttpClient = httpClient == null;
        _http = httpClient ?? new HttpClient { Timeout = TimeSpan.FromSeconds(15) };
    }

    public static string ReadEmbeddedMetadata(string key)
    {
        var attrs = Assembly.GetExecutingAssembly().GetCustomAttributes<AssemblyMetadataAttribute>();
        foreach (var attr in attrs)
        {
            if (string.Equals(attr.Key, key, StringComparison.Ordinal))
            {
                return (attr.Value ?? string.Empty).Trim();
            }
        }
        return string.Empty;
    }

    public (string clientId, string clientSecret) ResolveClientCredentials()
    {
        var secrets = _secretStore.Load();
        var clientId = FirstNonEmpty(
            secrets.GoogleClientId,
            ReadEmbeddedMetadata("HasibuOAuthClientId"),
            Environment.GetEnvironmentVariable("HASIBU_GOOGLE_CLIENT_ID"));

        var clientSecret = FirstNonEmpty(
            secrets.GoogleClientSecret,
            ReadEmbeddedMetadata("HasibuOAuthClientSecret"),
            Environment.GetEnvironmentVariable("HASIBU_GOOGLE_CLIENT_SECRET"));

        return (clientId, clientSecret);
    }

    public async Task<OAuthSignInResult> SignInInteractiveAsync(
        string? loginHintEmail = null,
        string? overrideClientId = null,
        string? overrideClientSecret = null,
        TimeSpan? timeout = null,
        CancellationToken ct = default)
    {
        var (resolvedId, resolvedSecret) = ResolveClientCredentials();
        var clientId = string.IsNullOrWhiteSpace(overrideClientId) ? resolvedId : overrideClientId.Trim();
        var clientSecret = string.IsNullOrWhiteSpace(overrideClientSecret) ? resolvedSecret : overrideClientSecret.Trim();

        if (string.IsNullOrWhiteSpace(clientId))
        {
            return new OAuthSignInResult(false, string.Empty, "Google OAuth Client ID tanımlı değil.");
        }

        _secretStore.Update(s => s with
        {
            GoogleClientId = clientId,
            GoogleClientSecret = string.IsNullOrWhiteSpace(clientSecret) ? s.GoogleClientSecret : clientSecret,
        });

        var port = FindAvailableLoopbackPort();
        var redirectUri = $"http://127.0.0.1:{port}/oauth2callback";
        var codeVerifier = GenerateBase64UrlRandom(48);
        var codeChallenge = ComputeS256Challenge(codeVerifier);
        var expectedState = GenerateBase64UrlRandom(24);

        var query = new List<string>
        {
            $"client_id={Uri.EscapeDataString(clientId)}",
            $"redirect_uri={Uri.EscapeDataString(redirectUri)}",
            "response_type=code",
            $"scope={Uri.EscapeDataString(Scopes)}",
            $"code_challenge={Uri.EscapeDataString(codeChallenge)}",
            "code_challenge_method=S256",
            $"state={Uri.EscapeDataString(expectedState)}",
            "access_type=offline",
            "prompt=" + Uri.EscapeDataString("select_account consent"),
        };
        if (!string.IsNullOrWhiteSpace(loginHintEmail))
        {
            query.Add($"login_hint={Uri.EscapeDataString(loginHintEmail.Trim())}");
        }
        var authUrl = $"{AuthEndpoint}?{string.Join("&", query)}";

        using var listener = new HttpListener();
        listener.Prefixes.Add($"http://127.0.0.1:{port}/");
        listener.Start();

        try
        {
            Process.Start(new ProcessStartInfo(authUrl) { UseShellExecute = true });
        }
        catch (Exception ex)
        {
            return new OAuthSignInResult(false, string.Empty, $"Tarayıcı açılamadı: {ex.Message}");
        }

        using var timeoutCts = CancellationTokenSource.CreateLinkedTokenSource(ct);
        timeoutCts.CancelAfter(timeout ?? TimeSpan.FromMinutes(3));

        try
        {
            while (!timeoutCts.IsCancellationRequested)
            {
                var ctxTask = listener.GetContextAsync();
                var completed = await Task.WhenAny(ctxTask, Task.Delay(Timeout.InfiniteTimeSpan, timeoutCts.Token)).ConfigureAwait(false);
                if (completed != ctxTask)
                {
                    return new OAuthSignInResult(false, string.Empty, "Google OAuth 2.0 oturum açma süresi doldu.");
                }

                var ctx = await ctxTask.ConfigureAwait(false);
                var reqPath = ctx.Request.Url?.AbsolutePath ?? "/";
                if (!string.Equals(reqPath, "/oauth2callback", StringComparison.OrdinalIgnoreCase))
                {
                    await WriteHtmlResponseAsync(ctx.Response, 404, false, "Bulunamadı", "Hasibu OAuth geri dönüş adresi bekleniyor.");
                    continue;
                }

                var qs = ctx.Request.QueryString;
                var oauthError = qs["error"]?.Trim() ?? string.Empty;
                var code = qs["code"]?.Trim() ?? string.Empty;
                var state = qs["state"]?.Trim() ?? string.Empty;

                if (!string.IsNullOrEmpty(oauthError))
                {
                    await WriteHtmlResponseAsync(ctx.Response, 400, false, "Google Girişi İptal Edildi", $"Google hatası: {oauthError}");
                    return new OAuthSignInResult(false, string.Empty, $"Google yetkilendirmesi reddedildi: {oauthError}");
                }

                if (!string.Equals(state, expectedState, StringComparison.Ordinal) || string.IsNullOrEmpty(code))
                {
                    await WriteHtmlResponseAsync(ctx.Response, 400, false, "Güvenlik Doğrulaması Başarısız", "CSRF state veya yetkilendirme kodu geçersiz.");
                    return new OAuthSignInResult(false, string.Empty, "OAuth CSRF state doğrulaması başarısız.");
                }

                var exchange = await ExchangeAuthorizationCodeAsync(code, clientId, clientSecret, codeVerifier, redirectUri, timeoutCts.Token).ConfigureAwait(false);
                if (!exchange.Success)
                {
                    await WriteHtmlResponseAsync(ctx.Response, 502, false, "Token Takası Başarısız", exchange.Error);
                    return new OAuthSignInResult(false, string.Empty, exchange.Error);
                }

                var email = await FetchUserEmailAsync(exchange.AccessToken, timeoutCts.Token).ConfigureAwait(false);
                _secretStore.Update(s => s with
                {
                    AccessToken = exchange.AccessToken,
                    RefreshToken = string.IsNullOrEmpty(exchange.RefreshToken) ? s.RefreshToken : exchange.RefreshToken,
                    ConnectedEmail = string.IsNullOrEmpty(email) ? s.ConnectedEmail : email,
                });

                await WriteHtmlResponseAsync(
                    ctx.Response,
                    200,
                    true,
                    "Hasibu Şube Köprüsü Bağlandı",
                    $"Google Drive yetkisi ({(string.IsNullOrEmpty(email) ? "Hesap doğrulandı" : email)}) başarıyla alındı. Bu sekmeyi kapatabilirsiniz.");

                return new OAuthSignInResult(true, email, "Google Drive OAuth 2.0 bağlantısı hazır.");
            }
        }
        finally
        {
            try { listener.Stop(); } catch { }
        }

        return new OAuthSignInResult(false, string.Empty, "Oturum açma iptal edildi.");
    }

    public async Task<string?> RefreshAccessTokenAsync(CancellationToken ct = default)
    {
        var secrets = _secretStore.Load();
        if (string.IsNullOrWhiteSpace(secrets.RefreshToken)) return null;

        var (clientId, clientSecret) = ResolveClientCredentials();
        if (string.IsNullOrWhiteSpace(clientId)) return null;

        var form = new Dictionary<string, string>
        {
            ["client_id"] = clientId,
            ["refresh_token"] = secrets.RefreshToken,
            ["grant_type"] = "refresh_token",
        };
        if (!string.IsNullOrWhiteSpace(clientSecret))
        {
            form["client_secret"] = clientSecret;
        }

        using var content = new FormUrlEncodedContent(form);
        using var resp = await _http.PostAsync(TokenEndpoint, content, ct).ConfigureAwait(false);
        var body = await resp.Content.ReadAsStringAsync(ct).ConfigureAwait(false);
        if (!resp.IsSuccessStatusCode) return null;

        using var doc = JsonDocument.Parse(body);
        var root = doc.RootElement;
        var accessToken = root.TryGetProperty("access_token", out var at) ? at.GetString()?.Trim() ?? string.Empty : string.Empty;
        var refreshToken = root.TryGetProperty("refresh_token", out var rt) ? rt.GetString()?.Trim() ?? string.Empty : string.Empty;
        if (string.IsNullOrEmpty(accessToken)) return null;

        _secretStore.Update(s => s with
        {
            AccessToken = accessToken,
            RefreshToken = string.IsNullOrEmpty(refreshToken) ? s.RefreshToken : refreshToken,
        });
        return accessToken;
    }

    private async Task<(bool Success, string AccessToken, string RefreshToken, string Error)> ExchangeAuthorizationCodeAsync(
        string code,
        string clientId,
        string clientSecret,
        string codeVerifier,
        string redirectUri,
        CancellationToken ct)
    {
        var form = new Dictionary<string, string>
        {
            ["code"] = code,
            ["client_id"] = clientId,
            ["code_verifier"] = codeVerifier,
            ["grant_type"] = "authorization_code",
            ["redirect_uri"] = redirectUri,
        };
        if (!string.IsNullOrWhiteSpace(clientSecret))
        {
            form["client_secret"] = clientSecret;
        }

        using var content = new FormUrlEncodedContent(form);
        using var resp = await _http.PostAsync(TokenEndpoint, content, ct).ConfigureAwait(false);
        var body = await resp.Content.ReadAsStringAsync(ct).ConfigureAwait(false);
        if (!resp.IsSuccessStatusCode)
        {
            return (false, string.Empty, string.Empty, $"HTTP {(int)resp.StatusCode}: {body}");
        }

        using var doc = JsonDocument.Parse(body);
        var root = doc.RootElement;
        var access = root.TryGetProperty("access_token", out var at) ? at.GetString()?.Trim() ?? string.Empty : string.Empty;
        var refresh = root.TryGetProperty("refresh_token", out var rt) ? rt.GetString()?.Trim() ?? string.Empty : string.Empty;
        return string.IsNullOrEmpty(access)
            ? (false, string.Empty, string.Empty, "access_token boş döndü.")
            : (true, access, refresh, string.Empty);
    }

    /// <summary>
    /// Kayıtlı bağlı Google e-postasını döner; yoksa mevcut <paramref name="accessToken"/> ile
    /// Google userinfo uç noktasından e-postayı alıp DPAPI kasasına kaydeder.
    /// </summary>
    public async Task<string> ResolveAndCacheConnectedEmailAsync(
        string accessToken,
        CancellationToken ct = default)
    {
        var secrets = _secretStore.Load();
        if (!string.IsNullOrWhiteSpace(secrets.ConnectedEmail))
        {
            return secrets.ConnectedEmail.Trim();
        }
        if (string.IsNullOrWhiteSpace(accessToken))
        {
            return string.Empty;
        }
        var fetched = (await FetchUserEmailAsync(accessToken.Trim(), ct).ConfigureAwait(false)).Trim();
        if (!string.IsNullOrEmpty(fetched))
        {
            _secretStore.Update(s => s with { ConnectedEmail = fetched });
        }
        return fetched;
    }

    private async Task<string> FetchUserEmailAsync(string accessToken, CancellationToken ct)
    {
        try
        {
            using var req = new HttpRequestMessage(HttpMethod.Get, UserInfoEndpoint);
            req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
            using var resp = await _http.SendAsync(req, ct).ConfigureAwait(false);
            if (!resp.IsSuccessStatusCode) return string.Empty;
            var json = await resp.Content.ReadAsStringAsync(ct).ConfigureAwait(false);
            using var doc = JsonDocument.Parse(json);
            return doc.RootElement.TryGetProperty("email", out var em)
                ? em.GetString()?.Trim() ?? string.Empty
                : string.Empty;
        }
        catch
        {
            return string.Empty;
        }
    }

    private static int FindAvailableLoopbackPort()
    {
        try
        {
            using var probe = new TcpListener(IPAddress.Loopback, PreferredLoopbackPort);
            probe.Start();
            return PreferredLoopbackPort;
        }
        catch
        {
            using var ephemeral = new TcpListener(IPAddress.Loopback, 0);
            ephemeral.Start();
            return ((IPEndPoint)ephemeral.LocalEndpoint).Port;
        }
    }

    private static string GenerateBase64UrlRandom(int byteCount) =>
        Convert.ToBase64String(RandomNumberGenerator.GetBytes(byteCount))
            .TrimEnd('=')
            .Replace('+', '-')
            .Replace('/', '_');

    private static string ComputeS256Challenge(string verifier)
    {
        var hash = SHA256.HashData(Encoding.ASCII.GetBytes(verifier));
        return Convert.ToBase64String(hash)
            .TrimEnd('=')
            .Replace('+', '-')
            .Replace('/', '_');
    }

    private static string FirstNonEmpty(params string?[] candidates)
    {
        foreach (var item in candidates)
        {
            if (!string.IsNullOrWhiteSpace(item))
            {
                return item.Trim();
            }
        }
        return string.Empty;
    }

    private static async Task WriteHtmlResponseAsync(
        HttpListenerResponse response,
        int statusCode,
        bool success,
        string title,
        string detail)
    {
        var color = success ? "#10b981" : "#ef4444";
        var html = $"""
        <!DOCTYPE html>
        <html lang="tr">
        <head><meta charset="utf-8" /><title>{WebUtility.HtmlEncode(title)}</title></head>
        <body style="background:#0f172a;color:#f8fafc;font-family:sans-serif;padding:48px;text-align:center;">
          <div style="max-width:520px;margin:0 auto;background:#1e293b;border:2px solid {color};border-radius:16px;padding:28px;">
            <h2 style="color:{color};margin-top:0;">{WebUtility.HtmlEncode(title)}</h2>
            <p style="color:#cbd5e1;line-height:1.5;">{WebUtility.HtmlEncode(detail)}</p>
          </div>
        </body>
        </html>
        """;
        var bytes = Encoding.UTF8.GetBytes(html);
        response.StatusCode = statusCode;
        response.ContentType = "text/html; charset=utf-8";
        response.ContentLength64 = bytes.Length;
        await response.OutputStream.WriteAsync(bytes).ConfigureAwait(false);
        response.Close();
    }

    public void Dispose()
    {
        if (_ownsHttpClient)
        {
            _http.Dispose();
        }
    }
}
