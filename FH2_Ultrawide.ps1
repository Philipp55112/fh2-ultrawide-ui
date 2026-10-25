<#
  FH2 Ultrawide UI for Azimuth 0.9.10  -  installer / uninstaller
  Patches YOUR OWN files in place; no game, Azimuth or Extra Options files are shipped.

  install :  powershell -ExecutionPolicy Bypass -File FH2_Ultrawide.ps1
  remove  :  powershell -ExecutionPolicy Bypass -File FH2_Ultrawide.ps1 -Uninstall
  options :  -AzimuthDir "D:\Program Files\Azimuth Horizon 2"  -GameDir "<FH2 folder>"
             -Width 3440 -Height 1440   -NoExtraOptions   -Yes (no questions)
#>
param(
    [string]$AzimuthDir = "",
    [string]$GameDir = "",
    [int]$Width = 0,
    [int]$Height = 0,
    [switch]$Uninstall,
    [switch]$NoExtraOptions,
    [switch]$Yes,
    [switch]$PauseAtEnd
)
$ErrorActionPreference = 'Stop'
$ModVersion   = '1.0'
$AzimuthSha   = '78a5f635b3241918707b5acddeaa96bd59ccb3819490e9218ee152497ca73639'  # Azimuth 0.9.10
$UiZipSha     = '33ecf0453f0d18f20408317c2bab7f0413be6e08e2b8188398c69930f8dcfa34'  # FH2 1.0.0.64 UI.zip
$ExtraOptSha  = '1ee3116ac6ac5279744cdd93da7d535c4afe833f174361cd0b00e4b31d98d6cd'  # FH2 Extra Options 0.2.98 winmm.dll
$BackupName   = 'FH2_Ultrawide_backup'
$ScriptDir    = Split-Path -Parent $MyInvocation.MyCommand.Path

function Say([string]$m, [string]$c = 'Gray') { Write-Host $m -ForegroundColor $c }
function Done([int]$code) { if ($PauseAtEnd) { Read-Host 'Press Enter to close' | Out-Null }; exit $code }
function Fail([string]$m) { Say ""; Say "ERROR: $m" 'Red'; Say "Nothing (more) was changed." 'Red'; Done 1 }
function Sha256File([string]$p) { (Get-FileHash -Algorithm SHA256 -LiteralPath $p).Hash.ToLower() }
function Sha256Bytes([byte[]]$b) {
    $h = [Security.Cryptography.SHA256]::Create()
    ([BitConverter]::ToString($h.ComputeHash($b)) -replace '-', '').ToLower()
}
function Ask([string]$q, [string]$def) {
    if ($Yes) { return $def }
    $a = Read-Host "$q [$def]"
    if ([string]::IsNullOrWhiteSpace($a)) { return $def } else { return $a.Trim().Trim('"') }
}
function YesNo([string]$q, [bool]$def) {
    if ($Yes) { return $def }
    $d = 'n'; if ($def) { $d = 'y' }
    $a = Read-Host "$q (y/n) [$d]"
    if ([string]::IsNullOrWhiteSpace($a)) { return $def }
    return $a.Trim().ToLower().StartsWith('y')
}

# ---------------------------------------------------------------- zip helper (exact FH2 layout)
Add-Type -Language CSharp -TypeDefinition @'
using System;
using System.IO;
using System.IO.Compression;
using System.Collections.Generic;
public static class Fh2Zip {
    static uint[] crcTable;
    static uint Crc32(byte[] data) {
        if (crcTable == null) {
            crcTable = new uint[256];
            for (uint i = 0; i < 256; i++) {
                uint c = i;
                for (int k = 0; k < 8; k++) c = ((c & 1) != 0) ? (0xEDB88320u ^ (c >> 1)) : (c >> 1);
                crcTable[i] = c;
            }
        }
        uint crc = 0xFFFFFFFFu;
        foreach (byte b in data) crc = crcTable[(crc ^ b) & 0xFF] ^ (crc >> 8);
        return crc ^ 0xFFFFFFFFu;
    }
    static ushort U16(byte[] d, int o) { return BitConverter.ToUInt16(d, o); }
    static uint U32(byte[] d, int o) { return BitConverter.ToUInt32(d, o); }
    static void P32(byte[] d, int o, uint v) { byte[] b = BitConverter.GetBytes(v); Buffer.BlockCopy(b, 0, d, o, 4); }
    static byte[] Slice(byte[] d, int o, int n) { byte[] r = new byte[n]; Buffer.BlockCopy(d, o, r, 0, n); return r; }
    static int FindEocd(byte[] d) {
        for (int i = d.Length - 22; i >= 0; i--)
            if (d[i] == 0x50 && d[i + 1] == 0x4B && d[i + 2] == 5 && d[i + 3] == 6) return i;
        throw new Exception("zip end record not found");
    }
    public static byte[] ReadEntry(string zipPath, string name) {
        byte[] d = File.ReadAllBytes(zipPath);
        int eo = FindEocd(d); int n = U16(d, eo + 10); int i = (int)U32(d, eo + 16);
        for (int e = 0; e < n; e++) {
            int nl = U16(d, i + 28), el = U16(d, i + 30), cl = U16(d, i + 32);
            string nm = System.Text.Encoding.ASCII.GetString(d, i + 46, nl);
            if (nm == name) {
                int method = U16(d, i + 10); int csz = (int)U32(d, i + 20); int usz = (int)U32(d, i + 24);
                int lo = (int)U32(d, i + 42); int lnl = U16(d, lo + 26), lel = U16(d, lo + 28);
                byte[] comp = Slice(d, lo + 30 + lnl + lel, csz);
                if (method == 0) return comp;
                using (MemoryStream ms = new MemoryStream(comp))
                using (DeflateStream ds = new DeflateStream(ms, CompressionMode.Decompress))
                using (MemoryStream o = new MemoryStream()) {
                    ds.CopyTo(o); byte[] r = o.ToArray();
                    if (r.Length != usz || Crc32(r) != U32(d, i + 16)) throw new Exception("bad entry " + name);
                    return r;
                }
            }
            i += 46 + nl + el + cl;
        }
        throw new Exception("entry not found: " + name);
    }
    static string Sha(byte[] d, int o, int n) {
        using (var h = System.Security.Cryptography.SHA256.Create()) {
            return BitConverter.ToString(h.ComputeHash(d, o, n)).Replace("-", "").ToLowerInvariant();
        }
    }
    // ops: offsets/lengths into the ORIGINAL file, verified by SHA-256 of the replaced bytes
    public static byte[] ApplyOps(byte[] orig, int[] offs, int[] lens, string[] shas, string[] news) {
        int n = offs.Length; int[] idx = new int[n];
        for (int k = 0; k < n; k++) idx[k] = k;
        Array.Sort(idx, delegate(int a, int b) { return offs[b].CompareTo(offs[a]); });
        var list = new List<byte>(orig);
        foreach (int k in idx) {
            if (offs[k] + lens[k] > list.Count) throw new Exception("patch offset out of range");
            byte[] cur = list.GetRange(offs[k], lens[k]).ToArray();
            if (Sha(cur, 0, cur.Length) != shas[k]) throw new Exception("patch mismatch at " + offs[k]);
            list.RemoveRange(offs[k], lens[k]);
            list.InsertRange(offs[k], System.Text.Encoding.UTF8.GetBytes(news[k]));
        }
        return list.ToArray();
    }
    // returns { dirstart, dirsize(incl. 22-byte end record), entries }
    public static long[] Rebuild(string src, string dst, Dictionary<string, byte[]> repl) {
        byte[] d = File.ReadAllBytes(src);
        int eo = FindEocd(d); byte[] eocd = Slice(d, eo, 22);
        int n = U16(d, eo + 10); int i = (int)U32(d, eo + 16);
        var used = new Dictionary<string, bool>();
        var cds = new List<byte[]>(); var lhs = new List<byte[]>(); var datas = new List<byte[]>(); var nlens = new List<int>();
        for (int e = 0; e < n; e++) {
            int nl = U16(d, i + 28), el = U16(d, i + 30), cl = U16(d, i + 32);
            byte[] cd = Slice(d, i, 46 + nl + el + cl);
            string nm = System.Text.Encoding.ASCII.GetString(d, i + 46, nl);
            int lo = (int)U32(d, i + 42); int lnl = U16(d, lo + 26), lel = U16(d, lo + 28);
            if (lel != 0 || el < 8 || U16(cd, 46 + nl) != 0x1123) throw new Exception("unexpected UI.zip layout");
            byte[] lh = Slice(d, lo, 30 + lnl);
            byte[] data = Slice(d, lo + 30 + lnl, (int)U32(d, i + 20));
            if (repl.ContainsKey(nm)) {
                byte[] raw = repl[nm]; used[nm] = true;
                using (MemoryStream ms = new MemoryStream()) {
                    using (DeflateStream ds = new DeflateStream(ms, CompressionLevel.Optimal, true)) ds.Write(raw, 0, raw.Length);
                    data = ms.ToArray();
                }
                uint crc = Crc32(raw);
                P32(cd, 16, crc); P32(cd, 20, (uint)data.Length); P32(cd, 24, (uint)raw.Length);
                P32(lh, 14, crc); P32(lh, 18, (uint)data.Length); P32(lh, 22, (uint)raw.Length);
                cd[10] = 8; cd[11] = 0; lh[8] = 8; lh[9] = 0;
            }
            cds.Add(cd); lhs.Add(lh); datas.Add(data); nlens.Add(nl);
            i += 46 + nl + el + cl;
        }
        if (used.Count != repl.Count) throw new Exception("not all replacement entries were found in UI.zip");
        using (MemoryStream o = new MemoryStream()) {
            for (int e = 0; e < n; e++) {
                uint lo = (uint)o.Position;
                P32(cds[e], 42, lo);
                P32(cds[e], 46 + nlens[e] + 4, lo + 30 + (uint)nlens[e]);  // extra 0x1123 = absolute data offset
                o.Write(lhs[e], 0, lhs[e].Length); o.Write(datas[e], 0, datas[e].Length);
            }
            long cdStart = o.Position;
            foreach (byte[] cd in cds) o.Write(cd, 0, cd.Length);
            long cdSize = o.Position - cdStart;
            P32(eocd, 12, (uint)cdSize); P32(eocd, 16, (uint)cdStart);
            o.Write(eocd, 0, 22);
            File.WriteAllBytes(dst, o.ToArray());
            return new long[] { cdStart, cdSize + 22, n };
        }
    }
}
'@

# ---------------------------------------------------------------- banner
Say ""
Say "  Forza Horizon 2 (Azimuth 0.9.10) - Ultrawide UI  v$ModVersion" 'Cyan'
Say "  HUD at the screen edges, menus/videos kept 16:9" 'Cyan'
Say ""

# ---------------------------------------------------------------- locate Azimuth
if (-not $AzimuthDir) {
    foreach ($c in @($ScriptDir, (Split-Path -Parent $ScriptDir))) {
        if ($c -and (Test-Path -LiteralPath (Join-Path $c 'azimuth.exe'))) { $AzimuthDir = $c; break }
    }
}
if (-not $AzimuthDir) { $AzimuthDir = Ask 'Path to your Azimuth folder (contains azimuth.exe)' 'C:\Program Files\Azimuth Horizon 2' }
$AzExe = Join-Path $AzimuthDir 'azimuth.exe'
if (-not (Test-Path -LiteralPath $AzExe)) { Fail "azimuth.exe not found in '$AzimuthDir'." }
# need write access (e.g. C:\Program Files) -> restart elevated
$probe = Join-Path $AzimuthDir ('.fh2uw_' + [guid]::NewGuid().ToString('N'))
try { [IO.File]::WriteAllText($probe, 'x'); Remove-Item -LiteralPath $probe -Force }
catch {
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($isAdmin) { Fail "cannot write to '$AzimuthDir'." }
    Say "Write access to '$AzimuthDir' needs administrator rights - asking Windows ..." 'Yellow'
    $a = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $MyInvocation.MyCommand.Path + '"'), '-AzimuthDir', ('"' + $AzimuthDir + '"'))
    if ($GameDir) { $a += @('-GameDir', ('"' + $GameDir + '"')) }
    if ($Width -gt 0) { $a += @('-Width', "$Width", '-Height', "$Height") }
    if ($Uninstall) { $a += '-Uninstall' }
    if ($NoExtraOptions) { $a += '-NoExtraOptions' }
    if ($Yes) { $a += '-Yes' }
    $a += @('-PauseAtEnd')
    Start-Process -FilePath 'powershell.exe' -ArgumentList $a -Verb RunAs
    exit 0
}
$Backup = Join-Path $AzimuthDir $BackupName
$State  = Join-Path $Backup 'install_state.txt'
Say "Azimuth folder : $AzimuthDir"

# ---------------------------------------------------------------- uninstall
if ($Uninstall) {
    if (-not (Test-Path -LiteralPath $State)) { Fail "No backup found in '$Backup' - is the mod installed?" }
    $st = @{}; Get-Content -LiteralPath $State | ForEach-Object { $k, $v = $_ -split '=', 2; $st[$k] = $v }
    Say "Restoring original files from $Backup ..."
    Copy-Item -LiteralPath (Join-Path $Backup 'azimuth.exe') -Destination $AzExe -Force
    if (Test-Path -LiteralPath (Join-Path $Backup 'winmm.dll')) {
        Copy-Item -LiteralPath (Join-Path $Backup 'winmm.dll') -Destination (Join-Path $AzimuthDir 'winmm.dll') -Force
    }
    Copy-Item -LiteralPath (Join-Path $Backup 'UI.zip') -Destination (Join-Path $st['media'] 'UI.zip') -Force
    Copy-Item -LiteralPath (Join-Path $Backup 'zipmanifest.xml') -Destination (Join-Path $st['media'] 'zipmanifest.xml') -Force
    $mo = Join-Path $Backup 'mediaoverride'
    if (Test-Path -LiteralPath $mo) {
        $target = Join-Path (Split-Path -Parent $st['media']) 'mediaoverride'
        Get-ChildItem -LiteralPath $mo -Recurse -File | ForEach-Object {
            $rel = $_.FullName.Substring($mo.Length).TrimStart('\')
            $dest = Join-Path $target $rel
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
            Copy-Item -LiteralPath $_.FullName -Destination $dest -Force
        }
    }
    if ((Sha256File $AzExe) -ne $AzimuthSha) { Fail "restored azimuth.exe does not match the original - check '$Backup'." }
    Remove-Item -LiteralPath $Backup -Recurse -Force
    Say ""; Say "Uninstalled. Original Azimuth, UI and Extra Options files are back." 'Green'
    Done 0
}

if (Test-Path -LiteralPath $State) {
    Fail "The mod is already installed (backup '$Backup' exists). Run the uninstaller first, then install again (e.g. for another resolution)."
}
$azHash = Sha256File $AzExe
if ($azHash -ne $AzimuthSha) { Fail "azimuth.exe is not the original Azimuth 0.9.10 build (SHA-256 $azHash). Only 0.9.10 is supported." }
Say "azimuth.exe    : Azimuth 0.9.10 OK"

# ---------------------------------------------------------------- patch data
$opsPath = Join-Path $ScriptDir 'FH2_Ultrawide_ops.json'
if (-not (Test-Path -LiteralPath $opsPath)) { Fail "FH2_Ultrawide_ops.json is missing next to the script." }
$ops = Get-Content -LiteralPath $opsPath -Raw | ConvertFrom-Json
$known = @{}
foreach ($tp in $ops.titles.PSObject.Properties) { $known[$tp.Name] = $tp.Value }

# ---------------------------------------------------------------- locate game (FH2 or FH2 Presents Fast & Furious)
if (-not $GameDir) {
    $ini = Join-Path $AzimuthDir 'data\azimuth.ini'
    if (Test-Path -LiteralPath $ini) {
        $txt = [IO.File]::ReadAllText($ini)
        $sel = [regex]::Match($txt, '(?m)^game=(\w+)\s*$')
        $cands = @()
        foreach ($m in [regex]::Matches($txt, '(?ms)^\[title-(\w+)\]\s*$(.*?)(?=^\[|\z)')) {
            $f = [regex]::Match($m.Groups[2].Value, '(?m)^folder=(.*?)\s*$')
            if ($f.Success -and $f.Groups[1].Value -and (Test-Path -LiteralPath (Join-Path $f.Groups[1].Value 'Mount\media\UI.zip'))) {
                $isSel = $sel.Success -and ($sel.Groups[1].Value -eq $m.Groups[1].Value)
                if ($isSel) { $cands = @($f.Groups[1].Value) + $cands } else { $cands += $f.Groups[1].Value }
            }
        }
        foreach ($c in $cands) {
            if ($known.ContainsKey((Sha256File (Join-Path $c 'Mount\media\UI.zip')))) { $GameDir = $c; break }
        }
        if (-not $GameDir -and $cands.Count -gt 0) { $GameDir = $cands[0] }
    }
}
if (-not $GameDir -or -not (Test-Path -LiteralPath (Join-Path $GameDir 'Mount\media\UI.zip'))) {
    $GameDir = Ask 'Path to your Forza Horizon 2 (or FH2 Fast & Furious) game folder (contains Mount\media)' $GameDir
}
$Media = Join-Path $GameDir 'Mount\media'
$UiZip = Join-Path $Media 'UI.zip'
$Manifest = Join-Path $Media 'zipmanifest.xml'
if (-not (Test-Path -LiteralPath $UiZip) -or -not (Test-Path -LiteralPath $Manifest)) { Fail "UI.zip / zipmanifest.xml not found in '$Media'." }
Say "Game folder    : $GameDir"
$uiHash = Sha256File $UiZip
if (-not $known.ContainsKey($uiHash)) { Fail "UI.zip is not an original, supported file (SHA-256 $uiHash). Supported: FH2 1.0.0.64 and FH2 Presents Fast & Furious 1.0.0.6. Restore the original UI.zip (and zipmanifest.xml) first." }
$title = $known[$uiHash]
Say "Game           : $($title.name) - original UI.zip OK"

# ---------------------------------------------------------------- resolution
if ($Width -le 0 -or $Height -le 0) {
    $dw = 3440; $dh = 1440
    try {
        Add-Type -AssemblyName System.Windows.Forms
        $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
        if ($b.Width -gt 0) { $dw = $b.Width; $dh = $b.Height }
    } catch { }
    $Width  = [int](Ask 'Screen width in pixels'  "$dw")
    $Height = [int](Ask 'Screen height in pixels' "$dh")
}
$aspect = [double]$Width / [double]$Height
if ($aspect -lt 1.80) { Fail "$Width x $Height is not wider than 16:9 - this mod is only for ultrawide screens." }
$W = [int]([Math]::Round(1080.0 * $aspect / 2.0) * 2)   # UI width in 1080p units, even
$S = [int](($W - 1920) / 2)                             # shift of 16:9-anchored 3D elements
$PR = 40 - $S
if ($aspect -lt 2.39) { $clip = 2.45 } else { $clip = [Math]::Round($aspect * 1.026, 3) }
Say ("Resolution     : {0} x {1}  (aspect {2:N3}, UI width {3}, shift {4})" -f $Width, $Height, $aspect, $W, $S)
if ([Math]::Abs($aspect - 3440.0 / 1440.0) -gt 0.02) {
    Say "NOTE: tested on 3440x1440. Other ultrawide ratios use the same math but are untested." 'Yellow'
}

# ---------------------------------------------------------------- Extra Options
$Winmm = Join-Path $AzimuthDir 'winmm.dll'
$patchEO = $false
if ((Test-Path -LiteralPath $Winmm) -and -not $NoExtraOptions) {
    $wh = Sha256File $Winmm
    if ($wh -eq $ExtraOptSha) {
        $patchEO = YesNo 'FH2 Extra Options 0.2.98 found. Make it accept the patched azimuth.exe?' $true
    } else {
        Say "NOTE: a winmm.dll is present but it is not FH2 Extra Options 0.2.98 - left unchanged." 'Yellow'
        Say "      (Extra Options refuses a modified azimuth.exe; only 0.2.98 can be adjusted.)" 'Yellow'
    }
}

$files = $title.files
$fileCount = @($files.PSObject.Properties).Count

$mediaOverride = Join-Path $GameDir 'Mount\mediaoverride\UI'
$conflicts = @()
if (Test-Path -LiteralPath $mediaOverride) {
    foreach ($p in $files.PSObject.Properties) {
        $cand = Join-Path $mediaOverride ($p.Name -replace '/', '\')
        if (Test-Path -LiteralPath $cand) { $conflicts += $cand }
    }
}

Say ""
Say "This will:" 'White'
Say "  - back up the originals to $Backup"
Say "  - patch azimuth.exe (UI width $W, clip limit $clip)"
Say "  - rebuild Mount\media\UI.zip ($fileCount UI files) and update zipmanifest.xml"
if ($patchEO) { Say "  - adjust FH2 Extra Options' winmm.dll to accept the patched azimuth.exe" }
if ($conflicts.Count -gt 0) { Say "  - move $($conflicts.Count) conflicting file(s) out of Mount\mediaoverride\UI into the backup" }
if (-not (YesNo 'Continue?' $true)) { Say 'Cancelled.'; Done 0 }

# ---------------------------------------------------------------- build everything in memory first
Say ""; Say "Applying UI changes ..."
$repl = New-Object 'System.Collections.Generic.Dictionary[string,byte[]]'
foreach ($p in $files.PSObject.Properties) {
    $name = $p.Name
    $orig = [Fh2Zip]::ReadEntry($UiZip, $name)
    if ((Sha256Bytes $orig) -ne $p.Value.sha256) { Fail "unexpected content in $name" }
    $o = $p.Value.ops; $n = $o.Count
    $offs = New-Object 'int[]' $n; $lens = New-Object 'int[]' $n
    $shas = New-Object 'string[]' $n; $news = New-Object 'string[]' $n
    for ($k = 0; $k -lt $n; $k++) {
        $offs[$k] = [int]$o[$k][0]; $lens[$k] = [int]$o[$k][1]; $shas[$k] = [string]$o[$k][2]
        $news[$k] = ([string]$o[$k][3]).Replace('@W@', "$W").Replace('@S@', "$S").Replace('@PR@', "$PR")
    }
    try { $repl[$name] = [Fh2Zip]::ApplyOps($orig, $offs, $lens, $shas, $news) } catch { Fail "cannot patch ${name}: $($_.Exception.Message)" }
}

$exe = [IO.File]::ReadAllBytes($AzExe)
function CheckBytes([int]$o, [string]$hex) {
    $exp = for ($i = 0; $i -lt $hex.Length; $i += 2) { [Convert]::ToByte($hex.Substring($i, 2), 16) }
    for ($i = 0; $i -lt $exp.Count; $i++) { if ($exe[$o + $i] -ne $exp[$i]) { Fail "azimuth.exe has unexpected bytes at 0x$('{0:X}' -f $o)" } }
}
CheckBytes 0x3F713 'c7411780070000'      # mov dword [rcx+0x17], 1920   (UI size from the display)
CheckBytes 0x3FA28 '48c74598398ee33f'    # 16/9 clip plane constant #1
CheckBytes 0x3FA46 '48c745a8398ee33f'    # 16/9 clip plane constant #2
[BitConverter]::GetBytes([uint32]$W).CopyTo($exe, 0x3F716)
$cb = [BitConverter]::GetBytes([single]$clip)
$cb.CopyTo($exe, 0x3FA2C); $cb.CopyTo($exe, 0x3FA4A)
$newExeSha = Sha256Bytes $exe

# ---------------------------------------------------------------- backup
New-Item -ItemType Directory -Force -Path $Backup | Out-Null
Copy-Item -LiteralPath $AzExe -Destination (Join-Path $Backup 'azimuth.exe') -Force
if (Test-Path -LiteralPath $Winmm) { Copy-Item -LiteralPath $Winmm -Destination (Join-Path $Backup 'winmm.dll') -Force }
Copy-Item -LiteralPath $UiZip -Destination (Join-Path $Backup 'UI.zip') -Force
Copy-Item -LiteralPath $Manifest -Destination (Join-Path $Backup 'zipmanifest.xml') -Force
if ((Sha256File (Join-Path $Backup 'UI.zip')) -ne $uiHash) { Fail "backup copy failed." }
foreach ($c in $conflicts) {
    $rel = $c.Substring((Join-Path $GameDir 'Mount\mediaoverride').Length).TrimStart('\')
    $dest = Join-Path (Join-Path $Backup 'mediaoverride') $rel
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
    Move-Item -LiteralPath $c -Destination $dest -Force
}
@("media=$Media", "width=$Width", "height=$Height", "uiwidth=$W", "version=$ModVersion") | Set-Content -LiteralPath $State -Encoding ASCII
Say "Backup         : done"

# ---------------------------------------------------------------- write
$tmpZip = Join-Path $Media 'UI.zip.ultrawide_tmp'
$r = [Fh2Zip]::Rebuild($UiZip, $tmpZip, $repl)
$latin = [Text.Encoding]::GetEncoding(28591)
$man = $latin.GetString([IO.File]::ReadAllBytes($Manifest))
$rx = '(path="game:\\media\\ui\.zip"[^>]*?dirstart=")\d+(" dirsize=")\d+(")'
if (-not [regex]::IsMatch($man, $rx, 'IgnoreCase')) { Remove-Item -LiteralPath $tmpZip -Force; Fail "ui.zip entry not found in zipmanifest.xml" }
$man = [regex]::Replace($man, $rx, ('${1}' + $r[0] + '${2}' + $r[1] + '${3}'), 'IgnoreCase')
Move-Item -LiteralPath $tmpZip -Destination $UiZip -Force
[IO.File]::WriteAllBytes($Manifest, $latin.GetBytes($man))
[IO.File]::WriteAllBytes($AzExe, $exe)
Say ("UI.zip         : rebuilt (dirstart {0}, dirsize {1})" -f $r[0], $r[1])
Say "azimuth.exe    : patched"

if ($patchEO) {
    $w = [IO.File]::ReadAllBytes($Winmm)
    $oldRaw = for ($i = 0; $i -lt 64; $i += 2) { [Convert]::ToByte($AzimuthSha.Substring($i, 2), 16) }
    $newRaw = for ($i = 0; $i -lt 64; $i += 2) { [Convert]::ToByte($newExeSha.Substring($i, 2), 16) }
    $oldHex = [Text.Encoding]::ASCII.GetBytes($AzimuthSha); $newHex = [Text.Encoding]::ASCII.GetBytes($newExeSha)
    function FindSeq([byte[]]$hay, $needle) {
        for ($i = 0; $i -le $hay.Length - $needle.Count; $i++) {
            $ok = $true
            for ($j = 0; $j -lt $needle.Count; $j++) { if ($hay[$i + $j] -ne $needle[$j]) { $ok = $false; break } }
            if ($ok) { return $i }
        }
        return -1
    }
    $p1 = FindSeq $w $oldRaw; $p2 = FindSeq $w $oldHex
    if ($p1 -lt 0) { Say "WARNING: could not adjust Extra Options (hash not found) - left unchanged." 'Yellow' }
    else {
        for ($i = 0; $i -lt 32; $i++) { $w[$p1 + $i] = $newRaw[$i] }
        if ($p2 -ge 0) { for ($i = 0; $i -lt 64; $i++) { $w[$p2 + $i] = $newHex[$i] } }
        [IO.File]::WriteAllBytes($Winmm, $w)
        Say "Extra Options  : now accepts the patched azimuth.exe"
    }
}

Say ""
Say "Done! Start the game with azimuth.exe as usual." 'Green'
Say "To undo everything run Uninstall.bat (originals are in $BackupName)." 'Green'
Say "Changed resolution later? Uninstall, then install again." 'Gray'
Done 0
