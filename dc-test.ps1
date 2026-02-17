<#
.SYNOPSIS
    DaggerConnect Batch Testing Tool - Windows Edition (Native SSH)
.EXAMPLE
    .\dc-test.ps1 -SetupKeys              # One-time: copy SSH key to all servers
    .\dc-test.ps1 -Group tcpmux -Quick     # Test tcpmux without iperf
    .\dc-test.ps1 -DryRun                  # Show test plan only
    .\dc-test.ps1                           # Full test (all 25 scenarios)
#>
[CmdletBinding()]
param(
    [string]$ConfigFile = "servers.conf",
    [ValidateSet("", "tcpmux", "kcpmux", "wsmux", "wssmux", "httpmux", "httpsmux")]
    [string]$Group = "",
    [string]$Iran = "",
    [string]$Kharej = "",
    [int]$ProxyPort = 10808,
    [switch]$Quick,
    [switch]$DryRun,
    [switch]$SetupKeys
)

$ErrorActionPreference = "Continue"
$script:PSK = "test-dagger-12345"
$script:TunnelPort = 443
$script:TestPort = 9999
$script:TestDuration = 10
$script:DCBin = "/usr/local/bin/DaggerConnect"
$script:DCDir = "/etc/DaggerConnect"
$script:DCSys = "/etc/systemd/system"
$script:GHRepo = "https://github.com/itsFLoKi/DaggerConnect"
$script:DCVer = "v1.4"
$script:GHApi = "https://api.github.com/repos/itsFLoKi/DaggerConnect/releases/latest"
$script:Results = [System.Collections.ArrayList]::new()
$script:KeyFile = "$env:USERPROFILE\.ssh\id_rsa"
$TS = Get-Date -Format "yyyyMMdd_HHmmss"
$script:CsvFile = "results_${TS}.csv"

# SOCKS proxy for Kharej connections (via connect.exe)
$script:KharejIPs = @()
$script:ConnectExe = ""
$connectCopy = Join-Path $env:USERPROFILE "connect.exe"
if (Test-Path $connectCopy) {
    $script:ConnectExe = $connectCopy
} elseif (Test-Path "C:\Program Files\Git\mingw64\bin\connect.exe") {
    # Copy to user dir to avoid spaces in path
    Copy-Item "C:\Program Files\Git\mingw64\bin\connect.exe" $connectCopy -Force 2>$null
    if (Test-Path $connectCopy) { $script:ConnectExe = $connectCopy }
}

# Persistent SSH session pool
$script:Sessions = @{}
# ═══ BANNER ═══
function Show-Banner {
    Write-Host ""
    Write-Host "  ========================================" -Fore Cyan
    Write-Host "   DaggerConnect - Batch Testing (Win)    " -Fore Cyan
    Write-Host "  ========================================" -Fore Cyan
    Write-Host ""
}

# ═══ SCENARIOS (one per protocol, strongest settings) ═══
$Scenarios = @(
    [pscustomobject]@{G="tcpmux";  L="tcpmux";   T="tcpmux";  Prof="aggressive"; Obf="disabled"; Pool=3; Smux="balanced"; Ch="on"; Kcp="default"}
    [pscustomobject]@{G="kcpmux";  L="kcpmux";   T="kcpmux";  Prof="aggressive"; Obf="disabled"; Pool=3; Smux="balanced"; Ch="on"; Kcp="aggressive"}
    [pscustomobject]@{G="httpmux"; L="httpmux";  T="httpmux"; Prof="aggressive"; Obf="disabled"; Pool=3; Smux="balanced"; Ch="on"; Kcp="default"}
    [pscustomobject]@{G="httpsmux";L="httpsmux"; T="httpsmux";Prof="aggressive"; Obf="disabled"; Pool=3; Smux="balanced"; Ch="on"; Kcp="default"}
)

# ═══ PARSE CONFIG ═══
$IranServers  = [System.Collections.ArrayList]::new()
$KharejServers = [System.Collections.ArrayList]::new()

function Parse-Config {
    if (-not (Test-Path $ConfigFile)) { Write-Host "  X $ConfigFile not found!" -Fore Red; exit 1 }
    $section = ""
    foreach ($raw in Get-Content $ConfigFile) {
        $line = ($raw -replace '#.*', '').Trim()
        if (-not $line) { continue }
        if ($line -match '^\[(.+)\]$') { $section = $Matches[1]; continue }
        switch ($section) {
            { $_ -in "iran","kharej" } {
                if ($line -match '^([a-zA-Z0-9_-]+)\s*=\s*(.+)$') {
                    $name = $Matches[1]
                    $parts = $Matches[2] -split '\|'
                    if ($parts.Count -lt 4) { continue }
                    $ips  = @(($parts[0].Trim()) -split ',' | ForEach-Object { $_.Trim() })
                    $port = [int]($parts[1].Trim())
                    $user = $parts[2].Trim()
                    $auth = $parts[3].Trim()
                    $srvPsk = if ($parts.Count -ge 5) { $parts[4].Trim() } else { "" }
                    $srv = [pscustomobject]@{ Name=$name; IPs=$ips; Port=$port; User=$user; Auth=$auth; Psk=$srvPsk }
                    if ($section -eq "iran") { [void]$IranServers.Add($srv) } else { [void]$KharejServers.Add($srv) }
                }
            }
            "settings" {
                if ($line -match '^psk\s*=\s*(.+)$')           { $script:PSK = $Matches[1].Trim() }
                if ($line -match '^tunnel_port\s*=\s*(\d+)$')  { $script:TunnelPort = [int]$Matches[1] }
                if ($line -match '^test_port\s*=\s*(\d+)$')    { $script:TestPort = [int]$Matches[1] }
                if ($line -match '^test_duration\s*=\s*(\d+)$'){ $script:TestDuration = [int]$Matches[1] }
            }
        }
    }
    if ($Iran) {
        $f = $IranServers | Where-Object { $_.Name -eq $Iran }
        if (-not $f) { $f = $KharejServers | Where-Object { $_.Name -eq $Iran } }
        if (-not $f) { Write-Host "  X Server '$Iran' not found" -Fore Red; exit 1 }
        $IranServers.Clear(); [void]$IranServers.Add($f)
    }
    if ($Kharej) {
        $f = $KharejServers | Where-Object { $_.Name -eq $Kharej }
        if (-not $f) { $f = $IranServers | Where-Object { $_.Name -eq $Kharej } }
        if (-not $f) { Write-Host "  X Server '$Kharej' not found" -Fore Red; exit 1 }
        $KharejServers.Clear(); [void]$KharejServers.Add($f)
    }
    if ($IranServers.Count -eq 0) { Write-Host "  X No Iran servers!" -Fore Red; exit 1 }
    if ($KharejServers.Count -eq 0) { Write-Host "  X No Kharej servers!" -Fore Red; exit 1 }
}

# ═══ PERSISTENT SSH SESSIONS (background reader thread) ═══
function Open-PersistentSsh($ip, $port, $user) {
    $sshArgs = @(
        "-T", "-p", $port,
        "-o", "StrictHostKeyChecking=no",
        "-o", "UserKnownHostsFile=NUL",
        "-o", "BatchMode=yes",
        "-o", "ServerAliveInterval=10",
        "-o", "ServerAliveCountMax=3",
        "-o", "LogLevel=ERROR",
        "-i", $script:KeyFile
    )
    if ($script:ConnectExe -and $ProxyPort -gt 0 -and ($script:KharejIPs -contains $ip)) {
        $sshArgs += @("-o", "ProxyCommand=$($script:ConnectExe) -S 127.0.0.1:$ProxyPort %h %p")
    }
    $sshArgs += "${user}@${ip}"

    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo.FileName = "ssh"
    $proc.StartInfo.Arguments = ($sshArgs | ForEach-Object { if ($_ -match '\s') { "`"$_`"" } else { $_ } }) -join " "
    $proc.StartInfo.UseShellExecute = $false
    $proc.StartInfo.RedirectStandardInput = $true
    $proc.StartInfo.RedirectStandardOutput = $true
    $proc.StartInfo.RedirectStandardError = $true
    $proc.StartInfo.CreateNoWindow = $true
    $proc.Start() | Out-Null

    # Background reader: reads stdout lines into a ConcurrentQueue
    $queue = [System.Collections.Concurrent.ConcurrentQueue[string]]::new()
    $reader = $proc.StandardOutput
    $ps = [powershell]::Create()
    $ps.AddScript({
        param($reader, $queue)
        while ($true) {
            try {
                $line = $reader.ReadLine()
                if ($line -eq $null) { break }
                $queue.Enqueue($line)
            } catch { break }
        }
    }).AddArgument($reader).AddArgument($queue) | Out-Null
    $handle = $ps.BeginInvoke()

    # Verify connection — send marker and wait for it in the queue
    $marker = "RDY_$(Get-Random)"
    $proc.StandardInput.WriteLine("echo $marker")
    $proc.StandardInput.Flush()
    $found = $false
    $deadline = [DateTime]::Now.AddSeconds(20)
    while ([DateTime]::Now -lt $deadline) {
        $line = $null
        if ($queue.TryDequeue([ref]$line)) {
            if ($line -eq $marker) { $found = $true; break }
        } else {
            Start-Sleep -Milliseconds 100
        }
    }
    if ($found) {
        $script:Sessions[$ip] = @{ Proc = $proc; Queue = $queue; PS = $ps; Handle = $handle }
        return $true
    }
    try { $ps.Stop(); $ps.Dispose() } catch {}
    try { $proc.Kill() } catch {}
    $proc.Dispose()
    return $false
}

function Send-Cmd($ip, $command, [int]$timeout = 30) {
    $session = $script:Sessions[$ip]
    if (-not $session) { return "" }
    $proc = $session.Proc
    $queue = $session.Queue
    if ($proc.HasExited) { return "" }

    # Drain any leftover lines from previous commands
    $junk = $null
    while ($queue.TryDequeue([ref]$junk)) {}

    $marker = "XDONE_$(Get-Random)"
    $proc.StandardInput.WriteLine("$command; echo $marker")
    $proc.StandardInput.Flush()

    $lines = @()
    $deadline = [DateTime]::Now.AddSeconds($timeout)
    while ([DateTime]::Now -lt $deadline) {
        $line = $null
        if ($queue.TryDequeue([ref]$line)) {
            if ($line -eq $marker) { break }
            $lines += $line
        } else {
            Start-Sleep -Milliseconds 50
        }
    }
    return ($lines -join "`n").Trim()
}

function Close-AllSessions {
    foreach ($ip in @($script:Sessions.Keys)) {
        $session = $script:Sessions[$ip]
        if ($session) {
            try {
                $session.Proc.StandardInput.WriteLine("exit")
                $session.Proc.WaitForExit(3000) | Out-Null
                if (-not $session.Proc.HasExited) { $session.Proc.Kill() }
            } catch {}
            try { $session.PS.Stop(); $session.PS.Dispose() } catch {}
            $session.Proc.Dispose()
        }
    }
    $script:Sessions.Clear()
}

# ═══ SSH (auto-uses persistent sessions) ═══
function Invoke-Ssh {
    param($ip, [int]$port, $user, $command, [int]$timeout = 30)

    # Prefer persistent session if available
    $sess = $script:Sessions[$ip]
    if ($sess -and $sess.Proc -and -not $sess.Proc.HasExited) {
        return Send-Cmd $ip $command $timeout
    }

    # Fallback: one-shot SSH (used by Setup-Keys etc.)
    $sshArgs = @(
        "-p", $port,
        "-o", "StrictHostKeyChecking=no",
        "-o", "UserKnownHostsFile=NUL",
        "-o", "BatchMode=yes",
        "-o", "ConnectTimeout=15",
        "-o", "LogLevel=ERROR",
        "-i", $script:KeyFile
    )
    if ($script:ConnectExe -and $ProxyPort -gt 0 -and ($script:KharejIPs -contains $ip)) {
        $sshArgs += @("-o", "ProxyCommand=$($script:ConnectExe) -S 127.0.0.1:$ProxyPort %h %p")
    }
    $sshArgs += @("${user}@${ip}", $command)
    try {
        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo.FileName = "ssh"
        $proc.StartInfo.Arguments = ($sshArgs | ForEach-Object { if ($_ -match '\s') { "`"$_`"" } else { $_ } }) -join " "
        $proc.StartInfo.UseShellExecute = $false
        $proc.StartInfo.RedirectStandardOutput = $true
        $proc.StartInfo.RedirectStandardError = $true
        $proc.StartInfo.CreateNoWindow = $true
        $proc.Start() | Out-Null

        $done = $proc.WaitForExit($timeout * 1000)
        $output = $proc.StandardOutput.ReadToEnd().Trim()
        if (-not $done) { try { $proc.Kill() } catch {} }
        $proc.Dispose()
        return $output
    } catch {
        return ""
    }
}

# ═══ SSH KEY SETUP ═══
function Setup-Keys {
    # Generate key if needed
    if (-not (Test-Path $script:KeyFile)) {
        Write-Host "  Generating SSH key..." -Fore Yellow
        & ssh-keygen -t rsa -b 4096 -f $script:KeyFile -N '""' -q
        Write-Host "  Key generated: $($script:KeyFile)" -Fore Green
    } else {
        Write-Host "  SSH key exists: $($script:KeyFile)" -Fore Green
    }

    $pubKey = Get-Content "$($script:KeyFile).pub"
    Write-Host ""
    Write-Host "  Now copying key to all servers..." -Fore Yellow
    Write-Host "  You will be asked for each server's PASSWORD once." -Fore Yellow
    Write-Host ""

    $allServers = [System.Collections.ArrayList]::new()
    $seen = @{}
    foreach ($s in $IranServers) {
        $fip = $s.IPs[0]
        if (-not $seen.ContainsKey($fip)) {
            [void]$allServers.Add(@{Name=$s.Name; IP=$fip; Port=$s.Port; User=$s.User; IsKharej=$false})
            $seen[$fip] = $true
        }
    }
    foreach ($s in $KharejServers) {
        $fip = $s.IPs[0]
        if (-not $seen.ContainsKey($fip)) {
            [void]$allServers.Add(@{Name=$s.Name; IP=$fip; Port=$s.Port; User=$s.User; IsKharej=$true})
            $seen[$fip] = $true
        }
    }

    foreach ($s in $allServers) {
        Write-Host "  [$($s.Name)] $($s.IP):$($s.Port) " -Fore White -NoNewline
        $isKh = $s.IsKharej

        # Test if key already works (auto-proxy via KharejIPs)
        $test = Invoke-Ssh $s.IP $s.Port $s.User 'echo OK' 15
        if ($test -eq "OK") {
            Write-Host "already OK" -Fore Green
            continue
        }

        # Copy key interactively (user types password)
        if ($isKh -and $script:ConnectExe) {
            Write-Host "(via proxy :$ProxyPort) " -Fore DarkGray -NoNewline
        }
        Write-Host "-> enter password:" -Fore Yellow
        $copyCmd = "mkdir -p ~/.ssh; echo '$pubKey' >> ~/.ssh/authorized_keys; chmod 700 ~/.ssh; chmod 600 ~/.ssh/authorized_keys; echo KEY_OK"
        $proxyArgs = @()
        if ($isKh -and $script:ConnectExe -and $ProxyPort -gt 0) {
            $proxyArgs = @("-o", "ProxyCommand=$($script:ConnectExe) -S 127.0.0.1:$ProxyPort %h %p")
        }
        & ssh -p $s.Port -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL @proxyArgs "$($s.User)@$($s.IP)" $copyCmd

        # Verify
        $test = Invoke-Ssh $s.IP $s.Port $s.User 'echo OK' 15
        if ($test -eq "OK") {
            Write-Host "  Key copied successfully!" -Fore Green
        } else {
            Write-Host "  WARNING: Key auth not working. Check password." -Fore Red
        }
    }
    Write-Host ""
    Write-Host "  Done! Now run: .\dc-test.ps1 -Quick -Group tcpmux" -Fore Cyan
}

# ═══ INSTALL ═══
function Install-On($label, $ip, $port, $user) {
    Write-Host "  [$label] $ip " -NoNewline
    $test = Invoke-Ssh $ip $port $user 'echo OK' 10
    if ($test -ne "OK") { Write-Host "X SSH failed!" -Fore Red; return $false }

    # Quick check: if DC v1.4 already exists, skip
    $dcOk = Invoke-Ssh $ip $port $user "test -f $($script:DCBin) && test -f $($script:DCDir)/.ver_$($script:DCVer) && echo yes || echo no" 10
    if ($dcOk -eq "yes") { Write-Host "OK (cached)" -Fore Green; return $true }

    Write-Host "installing $($script:DCVer)..." -NoNewline -Fore Yellow

    # Step 1: Download binary first (fast, most important)
    $dlUrl = "$($script:GHRepo)/releases/download/$($script:DCVer)/DaggerConnect"
    $installCmd = "mkdir -p $($script:DCDir); wget -q -O $($script:DCBin) $dlUrl 2>/dev/null; chmod +x $($script:DCBin); test -x $($script:DCBin) && touch $($script:DCDir)/.ver_$($script:DCVer) && echo DC_OK || echo DC_FAIL"
    $out = Invoke-Ssh $ip $port $user $installCmd 60
    if ($out -notmatch "DC_OK") { Write-Host "X DC failed!" -Fore Red; return $false }

    # Step 2: Install packages only if nc/openssl missing
    $need = Invoke-Ssh $ip $port $user 'which nc >/dev/null 2>&1 && which openssl >/dev/null 2>&1 && echo HAS || echo NEED' 5
    if ($need -ne "HAS") {
        $out = Invoke-Ssh $ip $port $user 'export DEBIAN_FRONTEND=noninteractive; fuser -k /var/lib/dpkg/lock-frontend 2>/dev/null; apt-get update -qq >/dev/null 2>&1; apt-get install -y -qq netcat-openbsd openssl libpcap-dev >/dev/null 2>&1; echo PKG_OK' 60
        if ($out -notmatch "PKG_OK") { Write-Host "[pkg warn] " -Fore Yellow -NoNewline }
    }

    Write-Host "OK" -Fore Green
    return $true
}

# ═══ YAML BLOCKS ═══
function Get-ObfusBlock($level) {
    switch ($level) {
        "disabled" { return "obfuscation:`n  enabled: false" }
        "balanced" { return "obfuscation:`n  enabled: true`n  min_padding: 16`n  max_padding: 512`n  min_delay_ms: 5`n  max_delay_ms: 50`n  burst_chance: 0.15" }
        "maximum"  { return "obfuscation:`n  enabled: true`n  min_padding: 128`n  max_padding: 2048`n  min_delay_ms: 15`n  max_delay_ms: 150`n  burst_chance: 0.3" }
    }
}
function Get-SmuxBlock($preset) {
    switch ($preset) {
        "balanced"      { return "smux:`n  keepalive: 8`n  max_recv: 8388608`n  max_stream: 8388608`n  frame_size: 16384`n  version: 2" }
        "cpu-efficient" { return "smux:`n  keepalive: 10`n  max_recv: 8388608`n  max_stream: 8388608`n  frame_size: 8192`n  version: 2" }
    }
}
function Get-KcpBlock($preset) {
    switch ($preset) {
        "default"    { return "kcp:`n  nodelay: 1`n  interval: 10`n  resend: 2`n  nc: 1`n  sndwnd: 256`n  rcvwnd: 256`n  mtu: 1200" }
        "aggressive" { return "kcp:`n  nodelay: 1`n  interval: 5`n  resend: 2`n  nc: 1`n  sndwnd: 1024`n  rcvwnd: 1024`n  mtu: 1200" }
    }
}
function Get-MimicryBlock($ch) {
    return "http_mimic:`n  fake_domain: ""www.google.com""`n  fake_path: ""/search""`n  user_agent: ""Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36""`n  chunked_encoding: $ch`n  session_cookie: true`n  custom_headers:`n    - ""Accept-Language: en-US,en;q=0.9""`n    - ""Accept-Encoding: gzip, deflate, br"""
}
# DPI Bypass: Both (Light + Raw Socket) - strongest
function Get-DpiBlock($role) {
    $dpi = "light_dpi_bypass:`n  enabled: true`n  sni_split: true`n  ttl_manipulation: false`n  segment_size: 1200`n  pacing_delay_ms: 2`n  jitter_range_ms: 1"
    # Raw socket needs interface/IP/MAC - auto-detect on server
    if ($role -eq "server") {
        $dpi += "`n`nraw_socket:`n  enabled: true`n  interface: ""auto""`n  local_ip: ""auto""`n  local_port: $($script:TunnelPort)`n  gateway_mac: ""auto""`n  desync_method: ""split""`n  batch_size: 32`n  buffer_size: 2097152`n  coalesce_ms: 1`n  max_packet_size: 1400`n  randomize_ttl: true`n  min_ttl: 64`n  max_ttl: 128`n  fragment_first_packet: true`n  fragment_size: 40"
    }
    return $dpi
}
$Adv = "advanced:`n  tcp_nodelay: true`n  tcp_keepalive: 3`n  tcp_read_buffer: 32768`n  tcp_write_buffer: 32768`n  cleanup_interval: 1`n  session_timeout: 15`n  connection_timeout: 20`n  stream_timeout: 45`n  max_connections: 300`n  max_udp_flows: 150`n  udp_flow_timeout: 90`n  udp_buffer_size: 262144"

function Build-ServerYaml($sc, $psk) {
    $tp = $script:TunnelPort; $dcd = $script:DCDir; $tport = $script:TestPort
    if (-not $psk) { $psk = $script:PSK }
    $y = "mode: ""server""`nlisten: ""0.0.0.0:${tp}""`ntransport: ""$($sc.T)""`npsk: ""${psk}""`nprofile: ""$($sc.Prof)""`nverbose: true`nheartbeat: 2"
    if ($sc.T -in "wssmux","httpsmux") { $y += "`ncert_file: ""${dcd}/certs/cert.pem""`nkey_file: ""${dcd}/certs/key.pem""" }
    $y += "`n`nmaps:`n  - type: tcp`n    bind: ""0.0.0.0:${tport}""`n    target: ""127.0.0.1:${tport}"""
    $y += "`n`n" + (Get-ObfusBlock $sc.Obf) + "`n`n" + (Get-SmuxBlock $sc.Smux)
    if ($sc.T -eq "kcpmux") { $y += "`n`n" + (Get-KcpBlock $sc.Kcp) }
    if ($sc.T -in "httpmux","httpsmux") { $y += "`n`n" + (Get-MimicryBlock $sc.Ch) }
    $y += "`n`n" + (Get-DpiBlock "server")
    $y += "`n`n$Adv"
    return $y
}
function Build-ClientYaml($sc, $irIp, $psk) {
    if (-not $psk) { $psk = $script:PSK }
    $tp = $script:TunnelPort
    $y = "mode: ""client""`npsk: ""${psk}""`nprofile: ""$($sc.Prof)""`nverbose: true`nheartbeat: 2"
    $y += "`n`npaths:`n  - transport: ""$($sc.T)""`n    addr: ""${irIp}:${tp}""`n    connection_pool: $($sc.Pool)`n    aggressive_pool: true`n    retry_interval: 1`n    dial_timeout: 5"
    $y += "`n`n" + (Get-ObfusBlock $sc.Obf) + "`n`n" + (Get-SmuxBlock $sc.Smux)
    if ($sc.T -eq "kcpmux") { $y += "`n`n" + (Get-KcpBlock $sc.Kcp) }
    if ($sc.T -in "httpmux","httpsmux") { $y += "`n`n" + (Get-MimicryBlock $sc.Ch) }
    $y += "`n`n" + (Get-DpiBlock "client")
    $y += "`n`n$Adv"
    return $y
}

# ═══ DEPLOY + START (combined into 1 SSH per server) ═══
function Deploy-And-Start($ip, $port, $user, $role, $yaml, $transport) {
    $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($yaml))
    $svc = "[Unit]`nDescription=DaggerConnect ${role}`nAfter=network.target`n[Service]`nType=simple`nExecStart=$($script:DCBin) -c $($script:DCDir)/${role}.yaml`nRestart=always`nRestartSec=3`nLimitNOFILE=1048576`n[Install]`nWantedBy=multi-user.target"
    $b64s = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($svc))

    $certCmd = ""
    if ($role -eq "server" -and ($transport -eq "wssmux" -or $transport -eq "httpsmux")) {
        $certCmd = "if [ ! -f $($script:DCDir)/certs/cert.pem ]; then mkdir -p $($script:DCDir)/certs; openssl req -x509 -newkey rsa:2048 -keyout $($script:DCDir)/certs/key.pem -out $($script:DCDir)/certs/cert.pem -days 365 -nodes -subj /CN=www.google.com 2>/dev/null; fi;"
    }

    # One SSH: force-stop + kill + wait port free + write yaml + certs + write service + start
    $cmd = "systemctl stop DaggerConnect-${role} 2>/dev/null; pkill -9 -f 'DaggerConnect.*${role}' 2>/dev/null; sleep 1; for i in 1 2 3 4 5; do ss -tlnp | grep -q ':${tp} ' || break; sleep 0.5; done; mkdir -p $($script:DCDir); echo '$b64' | base64 -d > $($script:DCDir)/${role}.yaml; ${certCmd} echo '$b64s' | base64 -d > $($script:DCSys)/DaggerConnect-${role}.service; systemctl daemon-reload; systemctl restart DaggerConnect-${role}; echo DEPLOYED"
    Invoke-Ssh $ip $port $user $cmd 30 | Out-Null
    Start-Sleep 2
}

# Wait for tunnel: check for ESTABLISHED connections on tunnel port (reliable)
function Wait-Tunnel-Remote($irIp, $irP, $irU, $khIp, $khP, $khU) {
    $tp = $script:TunnelPort
    # Check if DaggerConnect-server has ESTABLISHED connections on port 443
    $cmd = "for i in `$(seq 1 15); do sleep 1; if ss -tnp 2>/dev/null | grep ':${tp} ' | grep -q ESTAB; then echo TUNNEL_OK; exit 0; fi; done; echo TIMEOUT"
    $result = Invoke-Ssh $irIp $irP $irU $cmd 25
    if ($result -ne "TUNNEL_OK") {
        $st = Invoke-Ssh $khIp $khP $khU 'systemctl is-active DaggerConnect-client 2>/dev/null' 5
        if ($st -match 'failed|dead') { return "CRASHED" }
    }
    return $result
}

function Stop-Both($irIp, $irP, $irU, $khIp, $khP, $khU) {
    $tp = $script:TunnelPort; $tport = $script:TestPort
    # Stop server on Iran - wait for port 443 to be freed
    Invoke-Ssh $irIp $irP $irU "systemctl stop DaggerConnect-server 2>/dev/null; pkill -9 -f 'DaggerConnect' 2>/dev/null; sleep 1; for i in 1 2 3 4 5 6 7 8; do ss -tlnp | grep -q ':${tp} ' || break; sleep 0.5; done; pkill -f 'nc -l -p $tport' 2>/dev/null; true" 15 | Out-Null
    # Stop client on Kharej
    Invoke-Ssh $khIp $khP $khU "systemctl stop DaggerConnect-client 2>/dev/null; pkill -9 -f 'DaggerConnect' 2>/dev/null; pkill -f 'nc -l -p $tport' 2>/dev/null; true" 10 | Out-Null
    Start-Sleep 2
}

function Get-Latency($irIp, $irP, $irU, $khIp) {
    $out = Invoke-Ssh $irIp $irP $irU "ping -c 3 -W 3 $khIp 2>/dev/null | tail -1 | awk -F/ '{print `$5}'" 15
    if ($out -and $out -match '^[\d.]') { return "${out}ms" }
    return "-"
}

function Get-Bandwidth($irIp, $irP, $irU, $khIp, $khP, $khU) {
    if ($Quick) { return "-" }
    $tport = $script:TestPort
    $sizeMB = 5

    # Clean any leftover nc
    Invoke-Ssh $khIp $khP $khU "pkill -f 'nc -l -p $tport' 2>/dev/null; true" 5 | Out-Null
    Start-Sleep 1

    # Download: Kharej sends data, Iran receives through tunnel
    Invoke-Ssh $khIp $khP $khU "nohup bash -c 'dd if=/dev/zero bs=1M count=$sizeMB 2>/dev/null | timeout 15 nc -l -p $tport -q 1' &>/dev/null &" 5 | Out-Null
    Start-Sleep 2
    $dlOut = Invoke-Ssh $irIp $irP $irU "S=`$(date +%s%N); timeout 15 nc -w 10 127.0.0.1 $tport > /dev/null 2>/dev/null; E=`$(date +%s%N); echo `$(( (E-S)/1000000 ))" 20

    # Upload: Iran sends data, Kharej receives through tunnel
    Start-Sleep 1
    Invoke-Ssh $khIp $khP $khU "pkill -f 'nc -l -p $tport' 2>/dev/null; nohup bash -c 'timeout 15 nc -l -p $tport -q 1 > /dev/null' &>/dev/null &" 5 | Out-Null
    Start-Sleep 2
    $ulOut = Invoke-Ssh $irIp $irP $irU "S=`$(date +%s%N); dd if=/dev/zero bs=1M count=$sizeMB 2>/dev/null | timeout 15 nc -w 10 127.0.0.1 $tport -q 1; E=`$(date +%s%N); echo `$(( (E-S)/1000000 ))" 20

    Invoke-Ssh $khIp $khP $khU "pkill -f 'nc -l -p $tport' 2>/dev/null; true" 5 | Out-Null

    $dl = "-"; $ul = "-"
    if ($dlOut -match '^\d+$' -and [int]$dlOut.Trim() -gt 500) {
        $dl = [math]::Round(($sizeMB * 8 * 1000) / [int]$dlOut.Trim(), 1)
    }
    if ($ulOut -match '^\d+$' -and [int]$ulOut.Trim() -gt 500) {
        $ul = [math]::Round(($sizeMB * 8 * 1000) / [int]$ulOut.Trim(), 1)
    }
    if ($dl -ne "-" -or $ul -ne "-") { return "DL:${dl} UL:${ul} Mbps" }
    return "-"
}

# ═══ RUN ONE TEST (staged output) ═══
function Run-Test($sc, $irSrv, $irIp, $khSrv, $khIp) {
    $status = "FAIL"; $lat = "-"; $bw = "-"

    if ($DryRun) {
        Write-Host "  [DRY] $($sc.L) -- $($sc.T) | prof=$($sc.Prof) | obf=$($sc.Obf)" -Fore Cyan
        $row = [pscustomobject]@{Iran=$irSrv.Name;Kharej=$khSrv.Name;Group=$sc.G;Test=$sc.L;IranIP=$irIp;KharejIP=$khIp;Status="DRY";Latency="-";BW="-"}
        [void]$script:Results.Add($row)
        return
    }

    Write-Host "  > $($sc.L) ($irIp -> $khIp) " -Fore DarkGray -NoNewline

    # Stage 1: Deploy (use Iran server's PSK)
    $irPsk = $irSrv.Psk
    Deploy-And-Start $irIp $irSrv.Port $irSrv.User "server" (Build-ServerYaml $sc $irPsk) $sc.T
    Deploy-And-Start $khIp $khSrv.Port $khSrv.User "client" (Build-ClientYaml $sc $irIp $irPsk) $sc.T

    # Stage 2: Check tunnel
    $result = Wait-Tunnel-Remote $irIp $irSrv.Port $irSrv.User $khIp $khSrv.Port $khSrv.User

    if ($result -eq "TUNNEL_OK") {
        $status = "OK"
        Write-Host "OK " -Fore Green -NoNewline

        # Stage 3: Latency
        $lat = Get-Latency $irIp $irSrv.Port $irSrv.User $khIp
        Write-Host "$lat " -Fore White -NoNewline

        # Stage 4: Bandwidth
        $bw = Get-Bandwidth $irIp $irSrv.Port $irSrv.User $khIp $khSrv.Port $khSrv.User
        Write-Host "$bw" -Fore Cyan
    } else {
        # Get error from client log (most useful)
        $errCmd = 'journalctl -u DaggerConnect-client --since "20 seconds ago" --no-pager 2>/dev/null | tail -3 | head -1 | sed "s/.*DaggerConnect\[[0-9]*\]: //" | cut -c1-80'
        $cliErr = Invoke-Ssh $khIp $khSrv.Port $khSrv.User $errCmd 8
        $errMsg = if ($cliErr) { $cliErr.Trim() } else { $result }
        $failType = if ($result -eq "CRASHED") { "CRASH" } else { "FAIL" }
        Write-Host "$failType $errMsg" -Fore Red
    }

    Stop-Both $irIp $irSrv.Port $irSrv.User $khIp $khSrv.Port $khSrv.User
    $row = [pscustomobject]@{Iran=$irSrv.Name;Kharej=$khSrv.Name;Group=$sc.G;Test=$sc.L;IranIP=$irIp;KharejIP=$khIp;Status=$status;Latency=$lat;BW=$bw}
    [void]$script:Results.Add($row)
    "$($row.Iran),$($row.Kharej),$($row.Group),$($row.Test),$($row.IranIP),$($row.KharejIP),$($row.Status),$($row.Latency),$($row.BW)" | Out-File $script:CsvFile -Append -Encoding UTF8
}

# ═══ RESULTS ═══
function Show-Results {
    if ($script:Results.Count -eq 0) { return }
    Write-Host "`n  ======= Results =======" -Fore Cyan
    $lastG = ""
    foreach ($r in $script:Results) {
        if ($r.Group -ne $lastG) { $lastG = $r.Group; Write-Host "`n  --- $lastG ---" -Fore Yellow }
        $c = if ($r.Status -eq "OK") { "Green" } elseif ($r.Status -eq "DRY") { "Cyan" } else { "Red" }
        Write-Host ("  {0,-5} > {1,-5} | {2,-20} | {3,-6} | {4,-8} | {5}" -f $r.Iran, $r.Kharej, $r.Test, $r.Status, $r.Latency, $r.BW) -Fore $c
    }
    $total = $script:Results.Count
    $pass = @($script:Results | Where-Object { $_.Status -eq "OK" }).Count
    Write-Host "`n  Total=$total  Pass=$pass  Fail=$($total-$pass)" -Fore White
}

# ═══ CLEANUP (remove DC from server after tests) ═══
function Cleanup-Server($ip, $port, $user, $role) {
    $cmd = "systemctl stop DaggerConnect-${role} 2>/dev/null; systemctl disable DaggerConnect-${role} 2>/dev/null; rm -f $($script:DCSys)/DaggerConnect-${role}.service; rm -rf $($script:DCDir); rm -f $($script:DCBin); systemctl daemon-reload 2>/dev/null; echo CLEANED"
    Invoke-Ssh $ip $port $user $cmd 15 | Out-Null
}

# ═══ MAIN ═══
# Kill orphaned SSH sessions from previous runs
Get-Process ssh -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Show-Banner
Parse-Config

# Build Kharej IP list for auto SOCKS proxy
$script:KharejIPs = @()
foreach ($kh in $KharejServers) { $script:KharejIPs += $kh.IPs }
if ($script:ConnectExe -and $script:KharejIPs.Count -gt 0) {
    Write-Host "  Proxy: SOCKS5 127.0.0.1:$ProxyPort for Kharej ($($script:KharejIPs.Count) IPs)" -Fore DarkGray
}

if ($SetupKeys) {
    Setup-Keys
    exit 0
}

# Check SSH key exists (not needed for dry-run)
if (-not $DryRun -and -not (Test-Path $script:KeyFile)) {
    Write-Host "  X No SSH key found!" -Fore Red
    Write-Host "  Run first: .\dc-test.ps1 -SetupKeys" -Fore Yellow
    exit 1
}

$tests = $Scenarios
if ($Group) { $tests = @($tests | Where-Object { $_.G -eq $Group }) }

$pairs = 0
foreach ($ir in $IranServers) { foreach ($kh in $KharejServers) { $pairs += $ir.IPs.Count * $kh.IPs.Count } }
$total = $tests.Count * $pairs

Write-Host "  Servers:" -Fore White
foreach ($ir in $IranServers) { Write-Host "    IR $($ir.Name): $($ir.IPs -join ', ')" -Fore Green }
foreach ($kh in $KharejServers) { Write-Host "    KH $($kh.Name): $($kh.IPs -join ', ')" -Fore Green }
Write-Host "  Tests: $($tests.Count) scenarios x $pairs pairs = $total total" -Fore Yellow
Write-Host ""

if (-not $DryRun) {
    # Open persistent SSH sessions to all servers
    Write-Host "  ====== Connect ======" -Fore Cyan
    $seen = @{}
    foreach ($ir in $IranServers) {
        $fip = $ir.IPs[0]
        if (-not $seen.ContainsKey($fip)) {
            Write-Host "  [$($ir.Name)] $fip " -NoNewline
            if (Open-PersistentSsh $fip $ir.Port $ir.User) { Write-Host "connected" -Fore Green } else { Write-Host "FAILED" -Fore Red }
            $seen[$fip] = $true
        }
    }
    foreach ($kh in $KharejServers) {
        $fip = $kh.IPs[0]
        if (-not $seen.ContainsKey($fip)) {
            Write-Host "  [$($kh.Name)] $fip " -NoNewline
            if (Open-PersistentSsh $fip $kh.Port $kh.User) { Write-Host "connected" -Fore Green } else { Write-Host "FAILED" -Fore Red }
            $seen[$fip] = $true
        }
    }
    # Also open sessions for extra IPs
    foreach ($ir in $IranServers) {
        foreach ($ip in $ir.IPs) {
            if (-not $seen.ContainsKey($ip)) {
                Open-PersistentSsh $ip $ir.Port $ir.User | Out-Null
                $seen[$ip] = $true
            }
        }
    }
    foreach ($kh in $KharejServers) {
        foreach ($ip in $kh.IPs) {
            if (-not $seen.ContainsKey($ip)) {
                Open-PersistentSsh $ip $kh.Port $kh.User | Out-Null
                $seen[$ip] = $true
            }
        }
    }
    Write-Host "  Sessions: $($script:Sessions.Count) open" -Fore DarkGray

    # Bidirectional ping check — every IP pair
    Write-Host ""
    Write-Host "  ====== Ping Check ======" -Fore Cyan
    foreach ($ir in $IranServers) {
        foreach ($kh in $KharejServers) {
            foreach ($irIp in $ir.IPs) {
                foreach ($khIp in $kh.IPs) {
                    Write-Host "  ${irIp} <-> ${khIp}: " -NoNewline
                    # Iran -> Kharej
                    $p1 = Invoke-Ssh $irIp $ir.Port $ir.User "ping -c 2 -W 3 $khIp >/dev/null 2>&1 && echo YES || echo NO" 10
                    # Kharej -> Iran
                    $p2 = Invoke-Ssh $khIp $kh.Port $kh.User "ping -c 2 -W 3 $irIp >/dev/null 2>&1 && echo YES || echo NO" 10
                    $ir2kh = if ($p1 -eq "YES") { "OK" } else { "X" }
                    $kh2ir = if ($p2 -eq "YES") { "OK" } else { "X" }
                    if ($ir2kh -eq "OK" -and $kh2ir -eq "OK") {
                        Write-Host "IR->KH=$ir2kh  KH->IR=$kh2ir" -Fore Green
                    } elseif ($ir2kh -eq "OK" -or $kh2ir -eq "OK") {
                        Write-Host "IR->KH=$ir2kh  KH->IR=$kh2ir" -Fore Yellow
                    } else {
                        Write-Host "IR->KH=$ir2kh  KH->IR=$kh2ir" -Fore Red
                    }
                }
            }
        }
    }

    Write-Host ""
    Write-Host "  ====== Install ======" -Fore Cyan
    $seen2 = @{}
    foreach ($ir in $IranServers) {
        $fip = $ir.IPs[0]
        if (-not $seen2.ContainsKey($fip)) { Install-On $ir.Name $fip $ir.Port $ir.User | Out-Null; $seen2[$fip] = $true }
    }
    foreach ($kh in $KharejServers) {
        $fip = $kh.IPs[0]
        if (-not $seen2.ContainsKey($fip)) { Install-On $kh.Name $fip $kh.Port $kh.User | Out-Null; $seen2[$fip] = $true }
    }
    Write-Host ""
}

# Init CSV with header (or read existing for dedup)
$existingTests = @{}
if (Test-Path $script:CsvFile) {
    foreach ($line in Get-Content $script:CsvFile | Select-Object -Skip 1) {
        $cols = $line -split ','
        if ($cols.Count -ge 6) { $existingTests["$($cols[3])|$($cols[4])|$($cols[5])"] = $true }
    }
} else {
    "Iran,Kharej,Group,Test,IranIP,KharejIP,Status,Latency,Bandwidth" | Out-File $script:CsvFile -Encoding UTF8
}

Write-Host "  ====== Testing ======" -Fore Cyan
Write-Host "  (Ctrl+C to stop - results auto-saved to $($script:CsvFile))" -Fore DarkGray

try {
    $lastG = ""
    foreach ($sc in $tests) {
        if ($sc.G -ne $lastG) { $lastG = $sc.G; Write-Host "`n  ----- $lastG -----" -Fore Yellow }
        foreach ($ir in $IranServers) {
            foreach ($kh in $KharejServers) {
                foreach ($irIp in $ir.IPs) {
                    foreach ($khIp in $kh.IPs) {
                        # Skip if already tested
                        $testKey = "$($sc.L)|$irIp|$khIp"
                        if ($existingTests.ContainsKey($testKey)) {
                            Write-Host "  > $($sc.L) ($irIp -> $khIp) SKIP (already tested)" -Fore DarkGray
                            continue
                        }
                        Run-Test $sc $ir $irIp $kh $khIp
                    }
                }
            }
        }
    }
} finally {
    # Cleanup all servers
    Write-Host "`n  ====== Cleanup ======" -Fore Cyan
    $cleaned = @{}
    foreach ($ir in $IranServers) {
        foreach ($ip in $ir.IPs) {
            if (-not $cleaned.ContainsKey($ip)) {
                Write-Host "  [$($ir.Name)] $ip cleaning..." -NoNewline
                Cleanup-Server $ip $ir.Port $ir.User "server"
                Write-Host " OK" -Fore Green
                $cleaned[$ip] = $true
            }
        }
    }
    foreach ($kh in $KharejServers) {
        foreach ($ip in $kh.IPs) {
            if (-not $cleaned.ContainsKey($ip)) {
                Write-Host "  [$($kh.Name)] $ip cleaning..." -NoNewline
                Cleanup-Server $ip $kh.Port $kh.User "client"
                Write-Host " OK" -Fore Green
                $cleaned[$ip] = $true
            }
        }
    }

    Write-Host "`n  ====== Summary ======" -Fore Cyan
    Show-Results
    Close-AllSessions
    Write-Host "  Results saved: $($script:CsvFile)" -Fore Green
}
