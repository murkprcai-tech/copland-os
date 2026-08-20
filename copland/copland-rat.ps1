# COPLAND OS -- rat-helper: freie ki-stimmen befragen (openrouter + groq, 0 euro)
# aufruf:  copland-rat.ps1 -Ki nemotron -Prompt "frage"   (oder -Ki groq)
# keys als user-umgebungsvariablen: OPENROUTER_API_KEY, GROQ_API_KEY
# zaehlt aufrufe pro tag in %LOCALAPPDATA%\copland-rat-usage.json (fuers panel)

param(
    [Parameter(Mandatory)][string]$Prompt,
    [ValidateSet('nemotron', 'groq', 'qwen', 'gemini', 'mistral')][string]$Ki = 'nemotron',
    [int]$MaxTokens = 1200
)
$ErrorActionPreference = 'Stop'

$conf = @{
    nemotron = @{
        url    = 'https://openrouter.ai/api/v1/chat/completions'
        # fallback-kette: free-kapazitaet schwankt, erstes funktionierendes modell gewinnt
        models = @('nvidia/nemotron-3-ultra-550b-a55b:free', 'nvidia/nemotron-3-super-120b-a12b:free', 'openai/gpt-oss-20b:free')
        key    = [Environment]::GetEnvironmentVariable('OPENROUTER_API_KEY', 'User')
    }
    groq = @{
        url    = 'https://api.groq.com/openai/v1/chat/completions'
        models = @('llama-3.3-70b-versatile')
        key    = [Environment]::GetEnvironmentVariable('GROQ_API_KEY', 'User')
    }
    qwen = @{
        # alibaba-modell, laeuft ueber den groq-key (denker mit <think>-block)
        url    = 'https://api.groq.com/openai/v1/chat/completions'
        models = @('qwen/qwen3.6-27b')
        key    = [Environment]::GetEnvironmentVariable('GROQ_API_KEY', 'User')
    }
    gemini = @{
        # googles openai-kompatibler endpoint (ai studio free tier)
        url    = 'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions'
        models = @('gemini-2.5-flash')
        key    = [Environment]::GetEnvironmentVariable('GEMINI_API_KEY', 'User')
    }
    mistral = @{
        url    = 'https://api.mistral.ai/v1/chat/completions'
        models = @('mistral-large-latest', 'mistral-small-latest')
        key    = [Environment]::GetEnvironmentVariable('MISTRAL_API_KEY', 'User')
    }
}
$c = $conf[$Ki]
if (-not $c.key) { Write-Error "kein api-key fuer $Ki (umgebungsvariable fehlt)"; exit 1 }

$resp = $null
foreach ($mdl in $c.models) {
    $body = @{
        model      = $mdl
        max_tokens = $MaxTokens
        messages   = @(@{ role = 'user'; content = $Prompt })
    } | ConvertTo-Json -Depth 4
    try {
        $try = Invoke-RestMethod -Uri $c.url -Method Post -TimeoutSec 120 -Headers @{
            Authorization  = "Bearer $($c.key)"
            'Content-Type' = 'application/json'
        } -Body ([System.Text.Encoding]::UTF8.GetBytes($body))
        if ($try.choices) { $resp = $try; break }
    } catch { }
}
if (-not $resp) { Write-Error "$Ki nicht erreichbar (alle modelle der kette fehlgeschlagen)"; exit 1 }

# tages-zaehler fuers panel
$uf = "$env:LOCALAPPDATA\copland-rat-usage.json"
$today = Get-Date -Format 'yyyy-MM-dd'
$u = if (Test-Path $uf) { Get-Content $uf -Raw | ConvertFrom-Json } else { $null }
if (-not $u -or $u.date -ne $today) { $u = [pscustomobject]@{ date = $today; nemotron = 0; groq = 0; qwen = 0; gemini = 0; mistral = 0 } }
if (-not ($u.PSObject.Properties.Name -contains $Ki)) { $u | Add-Member -NotePropertyName $Ki -NotePropertyValue 0 }
$u.$Ki = [int]$u.$Ki + 1
$u | ConvertTo-Json -Compress | Set-Content $uf -Encoding utf8

# denker-modelle (qwen u.a.) liefern ihren gedankengang in <think>...</think> -- raus damit
$out = $resp.choices[0].message.content
$out = $out -replace '(?s)<think>.*?</think>\s*', ''
$out.Trim()
