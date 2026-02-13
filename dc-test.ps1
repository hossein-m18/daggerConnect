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
$script:GHApi = "https://api.github.com/repos/itsFLoKi/DaggerConnect/releases/latest"
$script:Results = [System.Collections.ArrayList]::new()
$script:KeyFile = "$env:USERPROFILE\.ssh\id_rsa"
$TS = Get-Date -Format "yyyyMMdd_HHmmss"

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

# ═══ BANNER ═══
function Show-Banner {
    Write-Host ""
    Write-Host "  ========================================" -Fore Cyan
    Write-Host "   DaggerConnect - Batch Testing (Win)    " -Fore Cyan
    Write-Host "  ========================================" -Fore Cyan
    Write-Host ""
}

# ═══ 25 SCENARIOS (strongest first) ═══
$Scenarios = @(
    # ⭐ httpsmux — HTTPS+TLS (strongest)
    [pscustomobject]@{G="httpsmux";L="https+obfus=off"; T="httpsmux";Prof="balanced";   Obf="disabled"; Pool=3; Smux="balanced";      Ch="off"; Kcp="default"}
    [pscustomobject]@{G="httpsmux";L="https+obfus=bal"; T="httpsmux";Prof="balanced";   Obf="balanced"; Pool=3; Smux="balanced";      Ch="off"; Kcp="default"}
    [pscustomobject]@{G="httpsmux";L="https+obfus=max"; T="httpsmux";Prof="balanced";   Obf="maximum";  Pool=3; Smux="balanced";      Ch="off"; Kcp="default"}
    [pscustomobject]@{G="httpsmux";L="https+aggr+off";  T="httpsmux";Prof="aggressive"; Obf="disabled"; Pool=3; Smux="balanced";      Ch="off"; Kcp="default"}
    [pscustomobject]@{G="httpsmux";L="https+aggr+bal";  T="httpsmux";Prof="aggressive"; Obf="balanced"; Pool=3; Smux="balanced";      Ch="off"; Kcp="default"}
    [pscustomobject]@{G="httpsmux";L="https+aggr+max";  T="httpsmux";Prof="aggressive"; Obf="maximum";  Pool=3; Smux="balanced";      Ch="off"; Kcp="default"}
    [pscustomobject]@{G="httpsmux";L="https+chunked";   T="httpsmux";Prof="balanced";   Obf="balanced"; Pool=3; Smux="balanced";      Ch="on";  Kcp="default"}
    [pscustomobject]@{G="httpsmux";L="https+smux=eff";  T="httpsmux";Prof="balanced";   Obf="balanced"; Pool=3; Smux="cpu-efficient"; Ch="off"; Kcp="default"}
    # wssmux — WSS+TLS
    [pscustomobject]@{G="wssmux";  L="wss+obfus=off";  T="wssmux";  Prof="balanced";   Obf="disabled"; Pool=3; Smux="balanced";      Ch="off"; Kcp="default"}
    [pscustomobject]@{G="wssmux";  L="wss+obfus=bal";  T="wssmux";  Prof="balanced";   Obf="balanced"; Pool=3; Smux="balanced";      Ch="off"; Kcp="default"}
    [pscustomobject]@{G="wssmux";  L="wss+obfus=max";  T="wssmux";  Prof="balanced";   Obf="maximum";  Pool=3; Smux="balanced";      Ch="off"; Kcp="default"}
    # httpmux — HTTP mimicry
    [pscustomobject]@{G="httpmux"; L="http+obfus=off";  T="httpmux"; Prof="balanced";   Obf="disabled"; Pool=3; Smux="balanced";      Ch="off"; Kcp="default"}
    [pscustomobject]@{G="httpmux"; L="http+obfus=bal";  T="httpmux"; Prof="balanced";   Obf="balanced"; Pool=3; Smux="balanced";      Ch="off"; Kcp="default"}
    [pscustomobject]@{G="httpmux"; L="http+obfus=max";  T="httpmux"; Prof="balanced";   Obf="maximum";  Pool=3; Smux="balanced";      Ch="off"; Kcp="default"}
    [pscustomobject]@{G="httpmux"; L="http+chunked";    T="httpmux"; Prof="balanced";   Obf="balanced"; Pool=3; Smux="balanced";      Ch="on";  Kcp="default"}
    # wsmux — WebSocket
    [pscustomobject]@{G="wsmux";   L="ws+obfus=off";   T="wsmux";   Prof="balanced";   Obf="disabled"; Pool=3; Smux="balanced";      Ch="off"; Kcp="default"}
    [pscustomobject]@{G="wsmux";   L="ws+obfus=bal";   T="wsmux";   Prof="balanced";   Obf="balanced"; Pool=3; Smux="balanced";      Ch="off"; Kcp="default"}
    [pscustomobject]@{G="wsmux";   L="ws+obfus=max";   T="wsmux";   Prof="balanced";   Obf="maximum";  Pool=3; Smux="balanced";      Ch="off"; Kcp="default"}
    # kcpmux — KCP/UDP
    [pscustomobject]@{G="kcpmux";  L="kcp+obfus=off";  T="kcpmux";  Prof="balanced";   Obf="disabled"; Pool=3; Smux="balanced";      Ch="off"; Kcp="default"}
    [pscustomobject]@{G="kcpmux";  L="kcp+obfus=bal";  T="kcpmux";  Prof="balanced";   Obf="balanced"; Pool=3; Smux="balanced";      Ch="off"; Kcp="default"}
    [pscustomobject]@{G="kcpmux";  L="kcp+obfus=max";  T="kcpmux";  Prof="balanced";   Obf="maximum";  Pool=3; Smux="balanced";      Ch="off"; Kcp="default"}
    [pscustomobject]@{G="kcpmux";  L="kcp+aggressive"; T="kcpmux";  Prof="balanced";   Obf="balanced"; Pool=3; Smux="balanced";      Ch="off"; Kcp="aggressive"}
    # tcpmux — plain TCP (weakest)
    [pscustomobject]@{G="tcpmux";  L="tcp+obfus=off";  T="tcpmux";  Prof="balanced";   Obf="disabled"; Pool=3; Smux="balanced";      Ch="off"; Kcp="default"}
    [pscustomobject]@{G="tcpmux";  L="tcp+obfus=bal";  T="tcpmux";  Prof="balanced";   Obf="balanced"; Pool=3; Smux="balanced";      Ch="off"; Kcp="default"}
    [pscustomobject]@{G="tcpmux";  L="tcp+obfus=max";  T="tcpmux";  Prof="balanced";   Obf="maximum";  Pool=3; Smux="balanced";      Ch="off"; Kcp="default"}
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
                    $ips  = ($parts[0].Trim()) -split ',' | ForEach-Object { $_.Trim() }
                    $port = [int]($parts[1].Trim())
                    $user = $parts[2].Trim()
                    $auth = $parts[3].Trim()
                    $srv = [pscustomobject]@{ Name=$name; IPs=$ips; Port=$port; User=$user; Auth=$auth }
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
        if (-not $f) { Write-Host "  X Iran '$Iran' not found" -Fore Red; exit 1 }
        $IranServers.Clear(); [void]$IranServers.Add($f)
    }
    if ($Kharej) {
        $f = $KharejServers | Where-Object { $_.Name -eq $Kharej }
        if (-not $f) { Write-Host "  X Kharej '$Kharej' not found" -Fore Red; exit 1 }
        $KharejServers.Clear(); [void]$KharejServers.Add($f)
    }
    if ($IranServers.Count -eq 0) { Write-Host "  X No Iran servers!" -Fore Red; exit 1 }
    if ($KharejServers.Count -eq 0) { Write-Host "  X No Kharej servers!" -Fore Red; exit 1 }
}

# ═══ NATIVE SSH (no modules needed) ═══
function Invoke-Ssh {
    param($ip, [int]$port, $user, $command, [int]$timeout = 30)
    $sshArgs = @(
        "-p", $port,
        "-o", "StrictHostKeyChecking=no",
        "-o", "UserKnownHostsFile=NUL",
        "-o", "BatchMode=yes",
        "-o", "ConnectTimeout=15",
        "-o", "LogLevel=ERROR",
        "-i", $script:KeyFile
    )
    # Auto SOCKS proxy for Kharej IPs
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

    # Quick check: if DC already exists, skip everything
    $dcOk = Invoke-Ssh $ip $port $user "test -f $($script:DCBin) && echo yes || echo no" 10
    if ($dcOk -eq "yes") { Write-Host "OK (cached)" -Fore Green; return $true }

    # DC not found — install packages + DC
    Write-Host "installing..." -NoNewline -Fore Yellow
    $out = Invoke-Ssh $ip $port $user 'export DEBIAN_FRONTEND=noninteractive; apt-get update -qq >/dev/null 2>&1; apt-get install -y -qq curl wget jq openssl iperf3 >/dev/null 2>&1; echo PKG_OK' 120
    if ($out -notmatch "PKG_OK") { Write-Host "[pkg warn] " -Fore Yellow -NoNewline }
    $installCmd = "mkdir -p $($script:DCDir); wget -q -O $($script:DCBin) $($script:GHRepo)/releases/latest/download/DaggerConnect 2>/dev/null; chmod +x $($script:DCBin); test -f $($script:DCBin) && echo DC_OK || echo DC_FAIL"
    $out = Invoke-Ssh $ip $port $user $installCmd 120
    if ($out -notmatch "DC_OK") { Write-Host "X DC failed!" -Fore Red; return $false }
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
    return "http_mimic:`n  fake_domain: ""www.google.com""`n  fake_path: ""/search""`n  user_agent: ""Mozilla/5.0""`n  chunked_encoding: $ch`n  session_cookie: true`n  custom_headers:`n    - ""Accept-Language: en-US,en;q=0.9""`n    - ""Accept-Encoding: gzip, deflate, br"""
}
$Adv = "advanced:`n  tcp_nodelay: true`n  tcp_keepalive: 3`n  tcp_read_buffer: 32768`n  tcp_write_buffer: 32768`n  cleanup_interval: 1`n  session_timeout: 15`n  connection_timeout: 20`n  stream_timeout: 45`n  max_connections: 300`n  max_udp_flows: 150`n  udp_flow_timeout: 90`n  udp_buffer_size: 262144"

function Build-ServerYaml($sc) {
    $tp = $script:TunnelPort; $psk = $script:PSK; $dcd = $script:DCDir; $tport = $script:TestPort
    $y = "mode: ""server""`nlisten: ""0.0.0.0:${tp}""`ntransport: ""$($sc.T)""`npsk: ""${psk}""`nprofile: ""$($sc.Prof)""`nverbose: true`nheartbeat: 2"
    if ($sc.T -in "wssmux","httpsmux") { $y += "`ncert_file: ""${dcd}/certs/cert.pem""`nkey_file: ""${dcd}/certs/key.pem""" }
    $y += "`n`nmaps:`n  - type: tcp`n    bind: ""0.0.0.0:${tport}""`n    target: ""127.0.0.1:${tport}"""
    if (-not $Quick) { $y += "`n  - type: tcp`n    bind: ""0.0.0.0:5201""`n    target: ""127.0.0.1:5201""" }
    $y += "`n`n" + (Get-ObfusBlock $sc.Obf) + "`n`n" + (Get-SmuxBlock $sc.Smux)
    if ($sc.T -eq "kcpmux") { $y += "`n`n" + (Get-KcpBlock $sc.Kcp) }
    if ($sc.T -in "httpmux","httpsmux") { $y += "`n`n" + (Get-MimicryBlock $sc.Ch) }
    $y += "`n`n$Adv"
    return $y
}
function Build-ClientYaml($sc, $irIp) {
    $psk = $script:PSK; $tp = $script:TunnelPort
    $y = "mode: ""client""`npsk: ""${psk}""`nprofile: ""$($sc.Prof)""`nverbose: true`nheartbeat: 2"
    $y += "`n`npaths:`n  - transport: ""$($sc.T)""`n    addr: ""${irIp}:${tp}""`n    connection_pool: $($sc.Pool)`n    aggressive_pool: true`n    retry_interval: 1`n    dial_timeout: 5"
    $y += "`n`n" + (Get-ObfusBlock $sc.Obf) + "`n`n" + (Get-SmuxBlock $sc.Smux)
    if ($sc.T -eq "kcpmux") { $y += "`n`n" + (Get-KcpBlock $sc.Kcp) }
    if ($sc.T -in "httpmux","httpsmux") { $y += "`n`n" + (Get-MimicryBlock $sc.Ch) }
    $y += "`n`n$Adv"
    return $y
}

# ═══ DEPLOY ═══
function Deploy-Yaml($ip, $port, $user, $role, $yaml, $transport) {
    $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($yaml))
    Invoke-Ssh $ip $port $user "mkdir -p $($script:DCDir); echo '$b64' | base64 -d > $($script:DCDir)/${role}.yaml" 15 | Out-Null

    if ($role -eq "server" -and ($transport -eq "wssmux" -or $transport -eq "httpsmux")) {
        Invoke-Ssh $ip $port $user "if [ ! -f $($script:DCDir)/certs/cert.pem ]; then mkdir -p $($script:DCDir)/certs; openssl req -x509 -newkey rsa:2048 -keyout $($script:DCDir)/certs/key.pem -out $($script:DCDir)/certs/cert.pem -days 365 -nodes -subj /CN=www.google.com 2>/dev/null; fi" 30 | Out-Null
    }

    $svc = "[Unit]`nDescription=DaggerConnect ${role}`nAfter=network.target`n[Service]`nType=simple`nExecStart=$($script:DCBin) -c $($script:DCDir)/${role}.yaml`nRestart=always`nRestartSec=3`nLimitNOFILE=1048576`n[Install]`nWantedBy=multi-user.target"
    $b64s = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($svc))
    Invoke-Ssh $ip $port $user "echo '$b64s' | base64 -d > $($script:DCSys)/DaggerConnect-${role}.service; systemctl daemon-reload; systemctl stop DaggerConnect-${role} 2>/dev/null; sleep 1; systemctl start DaggerConnect-${role}" 20 | Out-Null
}

function Stop-DC($ip, $port, $user, $role) {
    Invoke-Ssh $ip $port $user "systemctl stop DaggerConnect-${role} 2>/dev/null; true" 10 | Out-Null
}

# ═══ TEST ═══
function Wait-Tunnel($irIp, $irP, $irU, $khIp, $khP, $khU) {
    for ($w = 0; $w -lt 20; $w++) {
        $srv = Invoke-Ssh $irIp $irP $irU 'systemctl is-active DaggerConnect-server 2>/dev/null || echo dead' 10
        $cli = Invoke-Ssh $khIp $khP $khU 'systemctl is-active DaggerConnect-client 2>/dev/null || echo dead' 10
        if ($srv -eq "active" -and $cli -eq "active") {
            $ok = Invoke-Ssh $khIp $khP $khU 'journalctl -u DaggerConnect-client -n 20 --no-pager 2>/dev/null | grep -ci "session added\|connected\|established" || echo 0' 10
            try { if ([int]$ok -gt 0) { return $true } } catch {}
        }
        Start-Sleep 1
    }
    return $false
}

function Get-Latency($irIp, $irP, $irU, $khIp) {
    $out = Invoke-Ssh $irIp $irP $irU "ping -c 3 -W 3 $khIp 2>/dev/null | tail -1 | awk -F/ '{print `$5}'" 15
    if ($out -and $out -match '^[\d.]') { return "${out}ms" }
    return "-"
}

function Get-Bandwidth($irIp, $irP, $irU, $khIp, $khP, $khU) {
    if ($Quick) { return "-" }
    Invoke-Ssh $khIp $khP $khU 'pkill -f "iperf3 -s" 2>/dev/null; sleep 0.5; iperf3 -s -p 5201 -D 2>/dev/null' 10 | Out-Null
    Start-Sleep 2
    $dur = $script:TestDuration
    $out = Invoke-Ssh $irIp $irP $irU "iperf3 -c 127.0.0.1 -p 5201 -t $dur -P 2 --json 2>/dev/null | python3 -c 'import sys,json;d=json.load(sys.stdin);print(round(d[""end""][""sum_received""][""bits_per_second""]/1e6,1))' 2>/dev/null || echo -" ($dur + 30)
    Invoke-Ssh $khIp $khP $khU 'pkill -f "iperf3 -s" 2>/dev/null' 10 | Out-Null
    if ($out -and $out -match '^[\d.]') { return "${out} Mbps" }
    return "-"
}

# ═══ RUN ONE TEST ═══
function Run-Test($sc, $irSrv, $irIp, $khSrv, $khIp) {
    $status = "FAIL"; $lat = "-"; $bw = "-"

    if ($DryRun) {
        Write-Host "  [DRY] $($sc.L) -- $($sc.T) | prof=$($sc.Prof) | obf=$($sc.Obf) | ch=$($sc.Ch) | kcp=$($sc.Kcp) | smux=$($sc.Smux)" -Fore Cyan
        [void]$script:Results.Add([pscustomobject]@{Iran=$irSrv.Name;Kharej=$khSrv.Name;Group=$sc.G;Test=$sc.L;IranIP=$irIp;KharejIP=$khIp;Status="DRY";Latency="-";BW="-"})
        return
    }

    Write-Host "  > $($sc.L) ($irIp -> $khIp)..." -Fore DarkGray -NoNewline

    Stop-DC $irIp $irSrv.Port $irSrv.User "server"
    Stop-DC $khIp $khSrv.Port $khSrv.User "client"
    Start-Sleep 1

    Deploy-Yaml $irIp $irSrv.Port $irSrv.User "server" (Build-ServerYaml $sc) $sc.T
    Deploy-Yaml $khIp $khSrv.Port $khSrv.User "client" (Build-ClientYaml $sc $irIp) $sc.T

    if (Wait-Tunnel $irIp $irSrv.Port $irSrv.User $khIp $khSrv.Port $khSrv.User) {
        $status = "OK"
        $lat = Get-Latency $irIp $irSrv.Port $irSrv.User $khIp
        $bw = Get-Bandwidth $irIp $irSrv.Port $irSrv.User $khIp $khSrv.Port $khSrv.User
        Write-Host " OK  $lat  $bw" -Fore Green
    } else {
        $err = Invoke-Ssh $khIp $khSrv.Port $khSrv.User 'journalctl -u DaggerConnect-client -n 2 --no-pager 2>/dev/null | tail -1 | cut -c1-60' 10
        Write-Host " FAIL  $err" -Fore Red
    }

    Stop-DC $irIp $irSrv.Port $irSrv.User "server"
    Stop-DC $khIp $khSrv.Port $khSrv.User "client"
    [void]$script:Results.Add([pscustomobject]@{Iran=$irSrv.Name;Kharej=$khSrv.Name;Group=$sc.G;Test=$sc.L;IranIP=$irIp;KharejIP=$khIp;Status=$status;Latency=$lat;BW=$bw})
    Start-Sleep 1
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
    $csv = "results_$TS.csv"
    "Iran,Kharej,Group,Test,IranIP,KharejIP,Status,Latency,Bandwidth" | Out-File $csv -Encoding UTF8
    foreach ($r in $script:Results) {
        "$($r.Iran),$($r.Kharej),$($r.Group),$($r.Test),$($r.IranIP),$($r.KharejIP),$($r.Status),$($r.Latency),$($r.BW)" | Out-File $csv -Append -Encoding UTF8
    }
    Write-Host "`n  Saved: $csv" -Fore Green
    $total = $script:Results.Count
    $pass = @($script:Results | Where-Object { $_.Status -eq "OK" }).Count
    Write-Host "  Total=$total  Pass=$pass  Fail=$($total-$pass)" -Fore White
}

# ═══ MAIN ═══
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
    Write-Host "  ====== Install ======" -Fore Cyan
    $seen = @{}
    foreach ($ir in $IranServers) {
        $fip = $ir.IPs[0]
        if (-not $seen.ContainsKey($fip)) { Install-On $ir.Name $fip $ir.Port $ir.User; $seen[$fip] = $true }
    }
    foreach ($kh in $KharejServers) {
        $fip = $kh.IPs[0]
        if (-not $seen.ContainsKey($fip)) { Install-On $kh.Name $fip $kh.Port $kh.User; $seen[$fip] = $true }
    }
    Write-Host ""
}

Write-Host "  ====== Testing ======" -Fore Cyan
$lastG = ""
foreach ($sc in $tests) {
    if ($sc.G -ne $lastG) { $lastG = $sc.G; Write-Host "`n  ----- $lastG -----" -Fore Yellow }
    foreach ($ir in $IranServers) {
        foreach ($kh in $KharejServers) {
            foreach ($irIp in $ir.IPs) {
                foreach ($khIp in $kh.IPs) { Run-Test $sc $ir $irIp $kh $khIp }
            }
        }
    }
}

Write-Host "`n  ====== Summary ======" -Fore Cyan
Show-Results
