<#
  Forza 21:9 Ultrawide Patch for Azimuth 1.0.2 / 1.0.3
  One installer for Forza Horizon 2, FH2 Presents Fast & Furious and Forza Motorsport 5.

  - azimuth.exe stays original (FH2 Extra Options keeps working); the wide UI comes from dinput8.dll (patched in memory,
    switched on per game when it starts)
  - each selected game's UI.zip is rebuilt from the ORIGINAL (originals are found by SHA-256 and backed up)

  Started by Forza21x9_Setup.exe (window with game selection) or by Install.bat / Uninstall.bat (console).
  Console (Install.bat): -NoGui [-AzimuthDir "..."] [-Width 3440 -Height 1440] [-Games 1a96545b,7b35d917] [-Yes] [-NoShortcuts] [-Uninstall]
  Command line: -AzimuthDir "<folder with azimuth.exe>" -Width 3440 -Height 1440 -Games 1a96545b,7b35d917 -Uninstall -NoGui
#>
param(
    [string]$AzimuthDir = "",
    [int]$Width = 0,
    [int]$Height = 0,
    [switch]$Uninstall,
    [switch]$NoGui,
    [switch]$Yes,
    [string]$Games = "",
    [switch]$NoShortcuts
)
$ErrorActionPreference = 'Stop'
$ModVersion = '1.2'
$AZ_ORIG    = '42527964f48c90a537f2414200b8598ab9a6f92919bfbe046dbecccb36e7c597'   # Azimuth 1.0.2
$AZ_KNOWN   = @{ '42527964f48c90a537f2414200b8598ab9a6f92919bfbe046dbecccb36e7c597' = '1.0.2'; 'ebfd5d43a165dcec5d4007b9d41ed5b2ed122fcd02ecfef7e4ed35b40826821f' = '1.0.3' }
$AZ_OLDPAT  = 'be442a080e78a5e9e457b29074a8ede59eaf2a6ee1268baee9b93e4f03d65a8c'   # our former exe patch (blocks Extra Options)
$FM5_EXE    = 'Mount\forza_durango_release_final.exe'
$FM5_ORIG   = '94dad21851d335e9a33231dc2a1de2ecd4b93eefdf5f6772085bf6886bf47db7'
$BackupName = 'Forza21x9_backup'
$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
# titles shown in the window; 'later' = not supported yet
$Catalog = @(
    @{ id = '1a96545b'; name = 'Forza Horizon 2' },
    @{ id = '5a9771a4'; name = 'Forza Horizon 2 Presents Fast & Furious' },
    @{ id = '7b35d917'; name = 'Forza Motorsport 5' },
    @{ id = 'fh3';      name = 'Forza Horizon 3 (coming later)'; later = $true },
    @{ id = 'fm6';      name = 'Forza Motorsport 6 (coming later)'; later = $true }
)

$script:LogBox = $null
function Say([string]$m, [string]$c = 'Gray') {
    if ($script:LogBox) { $script:LogBox.AppendText($m + "`r`n"); [System.Windows.Forms.Application]::DoEvents() }
    else { Write-Host $m -ForegroundColor $c }
}
function Fail([string]$m) { throw $m }
function Sha([string]$p) { (Get-FileHash -Algorithm SHA256 -LiteralPath $p).Hash.ToLower() }
function ShaBytes([byte[]]$b) { $h = [Security.Cryptography.SHA256]::Create(); ([BitConverter]::ToString($h.ComputeHash($b)) -replace '-', '').ToLower() }

# ------------------------------------------------------------------ zip helper (exact Forza layout: extra field 0x1123 = absolute data offset)
Add-Type -Language CSharp -TypeDefinition @'
using System;
using System.IO;
using System.IO.Compression;
using System.Collections.Generic;
public static class ForzaZip {
    static uint[] crcTable;
    static uint Crc32(byte[] data) {
        if (crcTable == null) {
            crcTable = new uint[256];
            for (uint i = 0; i < 256; i++) { uint c = i; for (int k = 0; k < 8; k++) c = ((c & 1) != 0) ? (0xEDB88320u ^ (c >> 1)) : (c >> 1); crcTable[i] = c; }
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
        for (int i = d.Length - 22; i >= 0; i--) if (d[i] == 0x50 && d[i + 1] == 0x4B && d[i + 2] == 5 && d[i + 3] == 6) return i;
        throw new Exception("zip end record not found");
    }
    // { dirstart, dirsize incl. 22-byte end record, entries } of a zip as it is
    public static long[] DirInfo(string path) {
        byte[] d = File.ReadAllBytes(path); int eo = FindEocd(d);
        return new long[] { U32(d, eo + 16), (long)U32(d, eo + 12) + 22, U16(d, eo + 10) };
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
        using (var h = System.Security.Cryptography.SHA256.Create()) return BitConverter.ToString(h.ComputeHash(d, o, n)).Replace("-", "").ToLowerInvariant();
    }
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
                P32(cds[e], 46 + nlens[e] + 4, lo + 30 + (uint)nlens[e]);
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

# zipmanifest.xml: point the ui.zip entry at the central directory of the given UI.zip
function Set-Manifest([string]$manifest, [string]$uizip) {
    $info = [ForzaZip]::DirInfo($uizip)
    $latin = [Text.Encoding]::GetEncoding(28591)
    $man = $latin.GetString([IO.File]::ReadAllBytes($manifest))
    $rx = '(path="game:\\media\\ui\.zip"[^>]*?dirstart=")\d+(" dirsize=")\d+(")'
    if (-not [regex]::IsMatch($man, $rx, 'IgnoreCase')) { Fail "ui.zip entry not found in $manifest" }
    $man = [regex]::Replace($man, $rx, ('${1}' + $info[0] + '${2}' + $info[1] + '${3}'), 'IgnoreCase')
    [IO.File]::WriteAllBytes($manifest, $latin.GetBytes($man))
    return $info
}

# put a game's original UI back from the backup ($true if something was restored)
function Restore-Title([string]$bdir) {
    if (-not (Test-Path -LiteralPath (Join-Path $bdir 'UI.zip'))) { return $false }
    $st = @{}; Get-Content -LiteralPath (Join-Path $bdir 'state.txt') | ForEach-Object { $k, $v = $_ -split '=', 2; $st[$k] = $v }
    $media = $st['media']
    Copy-Item -LiteralPath (Join-Path $bdir 'UI.zip') -Destination (Join-Path $media 'UI.zip') -Force
    $null = Set-Manifest (Join-Path $media 'zipmanifest.xml') (Join-Path $media 'UI.zip')
    $mo = Join-Path $bdir 'mediaoverride'
    if (Test-Path -LiteralPath $mo) {
        $target = Join-Path (Split-Path -Parent $media) 'mediaoverride'
        Get-ChildItem -LiteralPath $mo -Recurse -File | ForEach-Object {
            $dest = Join-Path $target $_.FullName.Substring($mo.Length).TrimStart('\')
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
            Copy-Item -LiteralPath $_.FullName -Destination $dest -Force
        }
    }
    Remove-Item -LiteralPath $bdir -Recurse -Force
    return $true
}

function Find-Azimuth {
    foreach ($c in @('D:\Program Files\Azimuth All in One', 'C:\Program Files\Azimuth All in One', 'C:\Program Files\Azimuth', (Split-Path -Parent $ScriptDir))) {
        if ($c -and (Test-Path -LiteralPath (Join-Path $c 'azimuth.exe'))) { return $c }
    }
    return ''
}

# games configured in Azimuth: data\azimuth.ini [title-<id>] folder=...
function Get-GameDirs([string]$az) {
    $dirs = @{}
    $ini = Join-Path $az 'data\azimuth.ini'
    if (Test-Path -LiteralPath $ini) {
        $txt = [IO.File]::ReadAllText($ini)
        foreach ($m in [regex]::Matches($txt, '(?ms)^\[title-(\w+)\]\s*$(.*?)(?=^\[|\z)')) {
            $f = [regex]::Match($m.Groups[2].Value, '(?m)^folder=(.*?)\s*$')
            if ($f.Success -and $f.Groups[1].Value) { $dirs[$m.Groups[1].Value.ToLower()] = $f.Groups[1].Value }
        }
    }
    return $dirs
}

# titles currently patched (from the backup folder)
function Get-InstalledTitles([string]$az) {
    $r = @{}
    $b = Join-Path $az $BackupName
    if (Test-Path -LiteralPath $b) { Get-ChildItem -LiteralPath $b -Directory | ForEach-Object { if (Test-Path -LiteralPath (Join-Path $_.FullName 'UI.zip')) { $r[$_.Name] = $true } } }
    return $r
}

function Get-ScreenSize {
    $w = 0; $h = 0
    try {
        $vc = Get-CimInstance Win32_VideoController | Where-Object { $_.CurrentHorizontalResolution -gt 0 } | Sort-Object CurrentHorizontalResolution -Descending | Select-Object -First 1
        if ($vc) { $w = [int]$vc.CurrentHorizontalResolution; $h = [int]$vc.CurrentVerticalResolution }
    } catch { }
    if ($w -le 0) { Add-Type -AssemblyName System.Windows.Forms; $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds; $w = $b.Width; $h = $b.Height }
    return @($w, $h)
}


# fill the width placeholders of an op text (same rules as tools/fm5tmpl.py)
$script:Inv = [Globalization.CultureInfo]::InvariantCulture
function Format-Num([double]$v, [int]$d) { if ($d -gt 0) { return $v.ToString('F' + $d, $script:Inv) } else { return ([Math]::Round($v, [MidpointRounding]::ToEven)).ToString('0', $script:Inv) } }
function Render-Op([string]$t, [int]$W) {
    $S = ($W - 1920) / 2.0; $K = $W / 1920.0
    if ($t.IndexOf('@') -lt 0) { return $t }
    $t = [regex]::Replace($t, '@E:(-?[\d.]+):([SKF]):(\d+)(?::([\d.]+))?@', {
        param($m)
        $a = [double]::Parse($m.Groups[1].Value, $script:Inv); $d = [int]$m.Groups[3].Value
        $f = 0.0; if ($m.Groups[4].Success) { $f = [double]::Parse($m.Groups[4].Value, $script:Inv) }
        switch ($m.Groups[2].Value) { 'S' { $v = $a + $S } 'K' { $v = $a * $K } default { $v = $a + $f * $S } }
        Format-Num $v $d
    })
    if ($t.Contains('@TICKS@')) { $sb = New-Object Text.StringBuilder; for ($x = 2220; $x -le $W; $x += 20) { [void]$sb.Append(" M$x,0 V5") }; $t = $t.Replace('@TICKS@', $sb.ToString()) }
    if ($t.Contains('@LTICKS@')) { $sb = New-Object Text.StringBuilder; for ($x = 2224; $x -le ($W + 203); $x += 101) { [void]$sb.Append(" M$x,1.5 V9") }; $t = $t.Replace('@LTICKS@', $sb.ToString()) }
    $ks = $K.ToString('F5', $script:Inv).TrimEnd('0')
    $PR = 40 - [int]$S
    return $t.Replace('@W@', "$W").Replace('@S@', (Format-Num $S 0)).Replace('@K@', $ks).Replace('@PR@', "$PR")
}

# ============================================================== desktop shortcuts (azimuth.exe --game=fh2|fh2-ff|fm5 --skip-launcher)
function Convert-PngToIco([string]$png, [string]$ico) {
    Add-Type -AssemblyName System.Drawing
    $img = [System.Drawing.Image]::FromFile($png)
    $bmp = New-Object System.Drawing.Bitmap 256, 256
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.Clear([System.Drawing.Color]::Transparent)
    $s = [Math]::Min(256.0 / $img.Width, 256.0 / $img.Height); $w = [int]($img.Width * $s); $h = [int]($img.Height * $s)
    $g.DrawImage($img, [int]((256 - $w) / 2), [int]((256 - $h) / 2), $w, $h)
    $g.Dispose(); $img.Dispose()
    $ms = New-Object IO.MemoryStream; $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose(); $pb = $ms.ToArray()
    $fs = [IO.File]::Create($ico); $bw = New-Object IO.BinaryWriter($fs)
    $bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]1)                    # ICONDIR: 1 image
    $bw.Write([byte]0); $bw.Write([byte]0); $bw.Write([byte]0); $bw.Write([byte]0)      # 256x256, no palette
    $bw.Write([uint16]1); $bw.Write([uint16]32); $bw.Write([uint32]$pb.Length); $bw.Write([uint32]22)
    $bw.Write($pb); $bw.Close()
}
function Remove-GameShortcuts([string]$az) {
    $list = Join-Path $az "$BackupName\shortcuts.txt"
    if (-not (Test-Path -LiteralPath $list)) { return }
    foreach ($l in (Get-Content -LiteralPath $list -Encoding UTF8)) { if ($l -and $l.EndsWith('.lnk') -and (Test-Path -LiteralPath $l)) { Remove-Item -LiteralPath $l -Force } }
    Remove-Item -LiteralPath $list -Force
    Say "Shortcuts      : desktop shortcuts removed"
}
# names of the games added in Azimuth: data\azimuth.ini [title-<id>] name=...  (azimuth.exe --game= takes this name)
function Get-GameNames([string]$az) {
    $names = @{}
    $ini = Join-Path $az 'data\azimuth.ini'
    if (Test-Path -LiteralPath $ini) {
        $txt = [IO.File]::ReadAllText($ini)
        foreach ($m in [regex]::Matches($txt, '(?ms)^\[title-(\w+)\]\s*$(.*?)(?=^\[|\z)')) {
            $f = [regex]::Match($m.Groups[2].Value, '(?m)^name=(.*?)\s*$')
            if ($f.Success -and $f.Groups[1].Value) { $names[$m.Groups[1].Value.ToLower()] = $f.Groups[1].Value }
        }
    }
    return $names
}
function New-GameShortcuts([string]$az, [hashtable]$dirs) {
    Remove-GameShortcuts $az
    $desk = [Environment]::GetFolderPath('Desktop'); $sh = New-Object -ComObject WScript.Shell
    $icoDir = Join-Path $az "$BackupName\icons"; New-Item -ItemType Directory -Force -Path $icoDir | Out-Null
    $exe = Join-Path $az 'azimuth.exe'; $made = @()
    foreach ($t in $Catalog) {
        if ($t.later -or -not $dirs.ContainsKey($t.id)) { continue }
        $gd = $dirs[$t.id]; $icon = "$exe,0"
        $png = Join-Path $gd 'Mount\Logo.png'
        if (Test-Path -LiteralPath $png) { try { $i = Join-Path $icoDir "$($t.id).ico"; Convert-PngToIco $png $i; $icon = "$i,0" } catch { } }
        $lnk = Join-Path $desk (($t.name -replace '[\\/:*?"<>|]', '') + '.lnk')
        $s = $sh.CreateShortcut($lnk)
        # --game= takes Azimuth's short name of the title (its built-in table: fh2, fh2-ff, fm5, fm6, fh3)
        $short = @{ '1a96545b' = 'fh2'; '5a9771a4' = 'fh2-ff'; '7b35d917' = 'fm5'; '64f9397e' = 'fm6'; '4ce1dfab' = 'fh3' }[$t.id]
        if (-not $short) { continue }
        $s.TargetPath = $exe; $s.Arguments = "--game=$short --skip-launcher"; $s.WorkingDirectory = $az
        $s.IconLocation = $icon; $s.Description = "$($t.name) - Azimuth"; $s.Save()
        $made += $lnk
        Say ("Shortcut       : {0}" -f [IO.Path]::GetFileName($lnk))
    }
    $made | Set-Content -LiteralPath (Join-Path $az "$BackupName\shortcuts.txt") -Encoding UTF8
}

# ============================================================== UNINSTALL
function Invoke-Uninstall([string]$az) {
    $ops = Get-Content -LiteralPath (Join-Path $ScriptDir 'Forza21x9_ops.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $Backup = Join-Path $az $BackupName; $Dll = Join-Path $az 'dinput8.dll'; $Ini = Join-Path $az 'azimuth_21x9.ini'
    foreach ($tp in $ops.titles.PSObject.Properties) {
        if (Restore-Title (Join-Path $Backup $tp.Name)) { Say ("{0,-42}: original UI restored" -f $tp.Value.name) }
    }
    if ((Test-Path -LiteralPath $Dll) -and (Test-Path -LiteralPath (Join-Path $Backup 'dll_installed.txt'))) {
        Remove-Item -LiteralPath $Dll -Force
        $prev = Join-Path $Backup 'dinput8_previous.dll'
        if (Test-Path -LiteralPath $prev) { Copy-Item -LiteralPath $prev -Destination $Dll -Force; Say "dinput8.dll    : previous file restored" }
        else { Say "dinput8.dll    : removed" }
    }
    try { Remove-GameShortcuts $az } catch { }
    if (Test-Path -LiteralPath $Ini) { Remove-Item -LiteralPath $Ini -Force }
    if (Test-Path -LiteralPath $Backup) { Remove-Item -LiteralPath $Backup -Recurse -Force }
    Say ""; Say "Uninstalled. All games run with their original UI (16:9) again." 'Green'
}

# ============================================================== INSTALL
function Invoke-Install([string]$az, [int]$Width, [int]$Height, [string[]]$Selected, [bool]$MakeShortcuts = $true) {
    $AzExe = Join-Path $az 'azimuth.exe'
    if (-not (Test-Path -LiteralPath $AzExe)) { Fail "azimuth.exe not found in '$az'." }
    $Backup = Join-Path $az $BackupName; $Dll = Join-Path $az 'dinput8.dll'; $Ini = Join-Path $az 'azimuth_21x9.ini'
    $GameDirs = Get-GameDirs $az
    $ops = Get-Content -LiteralPath (Join-Path $ScriptDir 'Forza21x9_ops.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $OurDll = Join-Path $ScriptDir 'dinput8.dll'; $OurDllSha = Sha $OurDll
    Say "Azimuth folder : $az"

    # resolution -> UI width (same formula as dinput8.dll)
    $W = [int][Math]::Floor((1080.0 * $Width + [Math]::Floor($Height / 2)) / $Height)
    $W = ($W + 1) -band (-bnot 1)
    if ($W -le 1920) { Fail "$Width x $Height is not wider than 16:9 - this patch is for ultrawide screens only." }
    $S = [int](($W - 1920) / 2); $PR = 40 - $S
    Say ("Resolution     : {0} x {1} -> UI width {2} (shift {3})" -f $Width, $Height, $W, $S)

    # azimuth.exe must be the original
    $azh = Sha $AzExe
    if ($AZ_KNOWN.ContainsKey($azh)) { Say "azimuth.exe    : Azimuth $($AZ_KNOWN[$azh]) original - OK" }
    elseif ($azh -eq $AZ_OLDPAT) {
        $src = $null
        foreach ($c in @((Join-Path $az 'azimuth_original.exe'), (Join-Path $ScriptDir 'Originals\azimuth.exe'))) {
            if ((Test-Path -LiteralPath $c) -and (Sha $c) -eq $AZ_ORIG) { $src = $c; break }
        }
        if (-not $src) { Fail "azimuth.exe is still our old exe patch and no original was found to restore it." }
        Copy-Item -LiteralPath $src -Destination $AzExe -Force
        Say "azimuth.exe    : old exe patch replaced by the original" 'Yellow'
    }
    else { Say "WARNING: unknown azimuth.exe version - dinput8.dll will not patch anything (see azimuth_21x9.log)." 'Yellow' }

    # plan every game in memory first
    $Plan = @(); $Remove = @()
    foreach ($tp in $ops.titles.PSObject.Properties) {
        $tid = $tp.Name; $t = $tp.Value
        $label = "{0,-42}:" -f $t.name
        if (-not $GameDirs.ContainsKey($tid)) { continue }
        if ($Selected -notcontains $tid) {
            if (Test-Path -LiteralPath (Join-Path (Join-Path $Backup $tid) 'UI.zip')) { $Remove += [pscustomobject]@{ tid = $tid; label = $label } }
            continue
        }
        $game = $GameDirs[$tid]; $media = Join-Path $game 'Mount\media'
        if (-not (Test-Path -LiteralPath (Join-Path $media 'UI.zip'))) { Say "$label no Mount\media\UI.zip in $game - skipped" 'Yellow'; continue }
        if ([int]$t.uiwidth -gt 0 -and [int]$t.uiwidth -ne $W) { Say "$label UI layout only available for UI width $($t.uiwidth) (3440x1440) - skipped" 'Yellow'; continue }
        # find the original UI.zip by SHA-256
        $bdir = Join-Path $Backup $tid
        $cands = @((Join-Path $bdir 'UI.zip'), (Join-Path $media 'UI.zip'), (Join-Path $ScriptDir "Originals\$tid\UI.zip"),
                   (Join-Path (Split-Path -Parent $game) '_backup_original_ui\UI.zip'), (Join-Path $game '_backup_original_ui\UI.zip'))
        foreach ($d in (Get-ChildItem -LiteralPath (Split-Path -Parent $az) -Directory -ErrorAction SilentlyContinue)) {
            $cands += (Join-Path $d.FullName 'FH2_Ultrawide_backup\UI.zip'); $cands += (Join-Path $d.FullName '_backup_original_ui\UI.zip')
        }
        $orig = $null
        foreach ($c in $cands) { if ((Test-Path -LiteralPath $c) -and (Sha $c) -eq $t.ui_sha256) { $orig = $c; break } }
        if (-not $orig) { Say "$label original UI.zip not found (put it into Originals\$tid\) - skipped" 'Red'; continue }
        # FM5: Azimuth 1.0 only accepts the original game exe
        $exeFix = $null
        if ($tid -eq '7b35d917') {
            if ((Sha (Join-Path $game $FM5_EXE)) -ne $FM5_ORIG) {
                foreach ($c in @((Join-Path (Split-Path -Parent $game) '_backup_original_ui\forza_durango_release_final.exe'), (Join-Path $bdir 'forza_durango_release_final.exe'))) {
                    if ((Test-Path -LiteralPath $c) -and (Sha $c) -eq $FM5_ORIG) { $exeFix = $c; break }
                }
                if (-not $exeFix) { Say "$label game exe is not the original and no original was found - skipped" 'Red'; continue }
            }
        }
        $repl = New-Object 'System.Collections.Generic.Dictionary[string,byte[]]'
        foreach ($p in $t.files.PSObject.Properties) {
            $raw = [ForzaZip]::ReadEntry($orig, $p.Name)
            if ((ShaBytes $raw) -ne $p.Value.sha256) { Fail "unexpected content: $($p.Name)" }
            $o = $p.Value.ops; $n = $o.Count
            $offs = New-Object 'int[]' $n; $lens = New-Object 'int[]' $n; $shas = New-Object 'string[]' $n; $news = New-Object 'string[]' $n
            for ($k = 0; $k -lt $n; $k++) {
                $offs[$k] = [int]$o[$k][0]; $lens[$k] = [int]$o[$k][1]; $shas[$k] = [string]$o[$k][2]
                $news[$k] = Render-Op ([string]$o[$k][3]) $W
            }
            $repl[$p.Name] = [ForzaZip]::ApplyOps($raw, $offs, $lens, $shas, $news)
        }
        $conf = @(); $mo = Join-Path $game 'Mount\mediaoverride\UI'
        if (Test-Path -LiteralPath $mo) {
            foreach ($p in $t.files.PSObject.Properties) { $c = Join-Path $mo ($p.Name -replace '/', '\'); if (Test-Path -LiteralPath $c) { $conf += $c } }
        }
        $Plan += [pscustomobject]@{ tid = $tid; name = $t.name; label = $label; game = $game; media = $media; orig = $orig; repl = $repl; exeFix = $exeFix; conf = $conf }
    }

    # write
    New-Item -ItemType Directory -Force -Path $Backup | Out-Null
    foreach ($g in $Remove) { if (Restore-Title (Join-Path $Backup $g.tid)) { Say "$($g.label) patch removed, original UI restored" 'Green' } }
    $Installed = @{}
    foreach ($g in $Plan) {
        $bdir = Join-Path $Backup $g.tid
        New-Item -ItemType Directory -Force -Path $bdir | Out-Null
        $bzip = Join-Path $bdir 'UI.zip'
        if ($g.orig -ne $bzip) { Copy-Item -LiteralPath $g.orig -Destination $bzip -Force }
        if ((Sha $bzip) -ne $ops.titles.($g.tid).ui_sha256) { Fail "backup of the original UI.zip failed ($($g.name))." }
        @("media=$($g.media)", "uiwidth=$W", "version=$ModVersion") | Set-Content -LiteralPath (Join-Path $bdir 'state.txt') -Encoding ASCII
        foreach ($c in $g.conf) {
            $dest = Join-Path (Join-Path $bdir 'mediaoverride') $c.Substring((Join-Path $g.game 'Mount\mediaoverride').Length).TrimStart('\')
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
            Move-Item -LiteralPath $c -Destination $dest -Force
        }
        if ($g.exeFix) { Copy-Item -LiteralPath $g.exeFix -Destination (Join-Path $g.game $FM5_EXE) -Force; Say "$($g.label) game exe set back to the original" }
        $tmp = Join-Path $g.media 'UI.zip.21x9_tmp'
        $null = [ForzaZip]::Rebuild($bzip, $tmp, $g.repl)
        Move-Item -LiteralPath $tmp -Destination (Join-Path $g.media 'UI.zip') -Force
        $null = Set-Manifest (Join-Path $g.media 'zipmanifest.xml') (Join-Path $g.media 'UI.zip')
        Say "$($g.label) 21:9 UI installed ($($g.repl.Count) files)" 'Green'
        $Installed[$g.tid] = $true
    }

    $OldOwn = @('ccf76b01f192fd38b5d946c9271a07f7c7d23674d2e4a659f31ac799d8d245f0', '546271db1a01d99b019b37637e29c9475668a1f858946f17072f9a58921f2f1a',
                '7466723fbd25d223d870874345ecc77e18f1bcde89a0d4ee2ee8493e2ecd4bc1')   # (installer always replaces it with the bundled one)   # earlier versions of our dinput8.dll
    if ((Test-Path -LiteralPath $Dll) -and (Sha $Dll) -ne $OurDllSha -and $OldOwn -notcontains (Sha $Dll) -and -not (Test-Path -LiteralPath (Join-Path $Backup 'dll_installed.txt'))) {
        Copy-Item -LiteralPath $Dll -Destination (Join-Path $Backup 'dinput8_previous.dll') -Force
        Say "dinput8.dll    : existing file backed up (dinput8_previous.dll)" 'Yellow'
    }
    Copy-Item -LiteralPath $OurDll -Destination $Dll -Force
    "x" | Set-Content -LiteralPath (Join-Path $Backup 'dll_installed.txt') -Encoding ASCII
    $iniLines = @('; written by the Forza 21:9 setup', '[ui]', "width=$W", '', '[titles]')
    foreach ($tp in $ops.titles.PSObject.Properties) { $on = 0; if ($Installed.ContainsKey($tp.Name)) { $on = 1 }; $iniLines += "$($tp.Name)=$on" }
    $iniLines += @('', '[fm5]', '; 1 = garage / pre-race at the full frame rate (FM5 itself halves it there), 0 = original', 'full_rate=1')
    $iniLines | Set-Content -LiteralPath $Ini -Encoding ASCII
    Say "dinput8.dll    : installed (UI width $W)" 'Green'

    try {
        & icacls "$az" /grant "$($env:USERDOMAIN)\$($env:USERNAME):(OI)(CI)M" /T /C /Q | Out-Null
        Say "Permissions    : $env:USERNAME may write to the Azimuth folder (no administrator needed to play)"
    } catch { Say "Could not set permissions: $($_.Exception.Message)" 'Yellow' }

    if ($MakeShortcuts) { try { New-GameShortcuts $az $GameDirs } catch { Say "Shortcuts could not be created: $($_.Exception.Message)" 'Yellow' } }
    else { try { Remove-GameShortcuts $az } catch { } }
    Say ""
    Say "Done! Start azimuth.exe as usual." 'Green'
    foreach ($tp in $ops.titles.PSObject.Properties) {
        if ($GameDirs.ContainsKey($tp.Name)) { $st = 'original UI'; if ($Installed.ContainsKey($tp.Name)) { $st = '21:9' }; Say ("  {0,-42}: {1}" -f $tp.Value.name, $st) }
    }
}

# ============================================================== command line
if ($NoGui) {
    try {
        if (-not $AzimuthDir) { $AzimuthDir = Find-Azimuth }
        if (-not $Yes) {
            # let the user confirm or pick the Azimuth folder
            Write-Host ''
            if ($AzimuthDir) { Write-Host "Azimuth folder found: $AzimuthDir" -ForegroundColor White }
            else { Write-Host 'Azimuth folder not found automatically.' -ForegroundColor Yellow }
            $a = ''
            if ($AzimuthDir) { $a = Read-Host 'Use this folder? (y = yes, n = choose another folder) [y]' }
            if (-not $AzimuthDir -or ($a -and $a.Trim().ToLower().StartsWith('n'))) {
                $picked = ''
                try {
                    Add-Type -AssemblyName System.Windows.Forms
                    $fd = New-Object System.Windows.Forms.FolderBrowserDialog
                    $fd.Description = 'Select the Azimuth folder (the one that contains azimuth.exe)'
                    if ($AzimuthDir) { $fd.SelectedPath = $AzimuthDir }
                    Write-Host 'A folder selection window opened (it may be behind this window).'
                    if ($fd.ShowDialog() -eq 'OK') { $picked = $fd.SelectedPath }
                } catch { }
                if (-not $picked) { $picked = (Read-Host 'Azimuth folder (contains azimuth.exe)').Trim().Trim('"') }
                $AzimuthDir = $picked
            }
        }
        if (-not $AzimuthDir -or -not (Test-Path -LiteralPath (Join-Path $AzimuthDir 'azimuth.exe'))) { Fail "azimuth.exe not found in '$AzimuthDir'." }
        if ($Uninstall) { Invoke-Uninstall $AzimuthDir; return }
        if ($Width -le 0 -or $Height -le 0) {
            $wh = Get-ScreenSize; $Width = $wh[0]; $Height = $wh[1]
            if (-not $Yes) {
                $a = Read-Host "Screen resolution $Width x $Height - press Enter to accept or type e.g. 3440x1440"
                if ($a -match '^\s*(\d+)\s*[xX*]\s*(\d+)\s*$') { $Width = [int]$matches[1]; $Height = [int]$matches[2] }
            }
        }
        $dirs = Get-GameDirs $AzimuthDir; $inst = Get-InstalledTitles $AzimuthDir
        $sel = @()
        if ($Games) { $sel = @($Games.ToLower() -split '[,; ]+' | Where-Object { $_ }) }
        else {
            Write-Host ''; Write-Host 'Install the 21:9 patch for:' -ForegroundColor White
            foreach ($t in $Catalog) {
                if ($t.later) { Write-Host ("  {0}" -f $t.name) -ForegroundColor DarkGray; continue }
                if (-not $dirs.ContainsKey($t.id)) { Write-Host ("  {0} (not set up in Azimuth)" -f $t.name) -ForegroundColor DarkGray; continue }
                $def = ($inst.Count -eq 0) -or $inst.ContainsKey($t.id)
                $on = $def
                if (-not $Yes) {
                    $d = 'n'; if ($def) { $d = 'y' }
                    $a = Read-Host ("  {0,-42} (y/n) [{1}]" -f $t.name, $d)
                    if (-not [string]::IsNullOrWhiteSpace($a)) { $on = $a.Trim().ToLower().StartsWith('y') }
                }
                if ($on) { $sel += $t.id }
            }
            Write-Host ''
        }
        $mk = -not $NoShortcuts
        if ($mk -and -not $Yes) { $a = Read-Host 'Create desktop shortcuts that start each game directly? (y/n) [y]'; if ($a -and $a.Trim().ToLower().StartsWith('n')) { $mk = $false } }
        Invoke-Install $AzimuthDir $Width $Height $sel $mk
    } catch { Say "ERROR: $($_.Exception.Message)" 'Red'; exit 1 }
    return
}

# ============================================================== window
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$form = New-Object System.Windows.Forms.Form
$form.Text = "Forza 21:9 Ultrawide Patch $ModVersion - Azimuth 1.0.2 / 1.0.3"
$form.Size = New-Object System.Drawing.Size(640, 600)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'; $form.MaximizeBox = $false
$font = New-Object System.Drawing.Font('Segoe UI', 9)
$form.Font = $font

function Add-Label($text, $x, $y, $w = 600, $bold = $false) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $text; $l.Location = New-Object System.Drawing.Point($x, $y); $l.Size = New-Object System.Drawing.Size($w, 20)
    if ($bold) { $l.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold) }
    $form.Controls.Add($l); return $l
}

Add-Label 'Azimuth folder (contains azimuth.exe):' 12 12 | Out-Null
$tbAz = New-Object System.Windows.Forms.TextBox
$tbAz.Location = New-Object System.Drawing.Point(12, 34); $tbAz.Size = New-Object System.Drawing.Size(510, 24)
$tbAz.Text = Find-Azimuth
$form.Controls.Add($tbAz)
$btBrowse = New-Object System.Windows.Forms.Button
$btBrowse.Text = 'Browse...'; $btBrowse.Location = New-Object System.Drawing.Point(530, 32); $btBrowse.Size = New-Object System.Drawing.Size(82, 26)
$form.Controls.Add($btBrowse)

Add-Label 'Screen resolution:' 12 70 120 | Out-Null
$wh = Get-ScreenSize
$tbW = New-Object System.Windows.Forms.TextBox; $tbW.Location = New-Object System.Drawing.Point(140, 67); $tbW.Size = New-Object System.Drawing.Size(60, 24); $tbW.Text = "$($wh[0])"
$tbH = New-Object System.Windows.Forms.TextBox; $tbH.Location = New-Object System.Drawing.Point(222, 67); $tbH.Size = New-Object System.Drawing.Size(60, 24); $tbH.Text = "$($wh[1])"
$form.Controls.Add($tbW); $form.Controls.Add($tbH)
Add-Label 'x' 206 70 14 | Out-Null

Add-Label 'Install the 21:9 patch for:' 12 104 600 $true | Out-Null
$checks = @{}
$y = 128
foreach ($t in $Catalog) {
    $cb = New-Object System.Windows.Forms.CheckBox
    $cb.Location = New-Object System.Drawing.Point(24, $y); $cb.Size = New-Object System.Drawing.Size(580, 22)
    $cb.Text = $t.name; $cb.Tag = $t.id
    if ($t.later) { $cb.Enabled = $false }
    $form.Controls.Add($cb); $checks[$t.id] = $cb
    $y += 24
}

$cbLnk = New-Object System.Windows.Forms.CheckBox
$cbLnk.Location = New-Object System.Drawing.Point(12, ($y + 6)); $cbLnk.Size = New-Object System.Drawing.Size(600, 22)
$cbLnk.Text = 'Create desktop shortcuts that start each game directly (without the launcher)'; $cbLnk.Checked = $true
$form.Controls.Add($cbLnk); $y += 30

function Update-Games {
    $az = $tbAz.Text.Trim().Trim('"')
    $dirs = @{}; $inst = @{}
    if ($az -and (Test-Path -LiteralPath (Join-Path $az 'azimuth.exe'))) { $dirs = Get-GameDirs $az; $inst = Get-InstalledTitles $az }
    foreach ($t in $Catalog) {
        $cb = $checks[$t.id]
        if ($t.later) { continue }
        if ($dirs.ContainsKey($t.id)) {
            $cb.Enabled = $true; $cb.Text = $t.name
            $cb.Checked = ($inst.Count -eq 0) -or $inst.ContainsKey($t.id)
        } else {
            $cb.Enabled = $false; $cb.Checked = $false; $cb.Text = "$($t.name)  (not set up in Azimuth)"
        }
    }
}
$tbAz.Add_TextChanged({ Update-Games })
$btBrowse.Add_Click({
    $fd = New-Object System.Windows.Forms.FolderBrowserDialog
    $fd.Description = 'Select the Azimuth 1.0 folder (contains azimuth.exe)'
    if ($tbAz.Text) { $fd.SelectedPath = $tbAz.Text }
    if ($fd.ShowDialog() -eq 'OK') { $tbAz.Text = $fd.SelectedPath }
})

$log = New-Object System.Windows.Forms.TextBox
$log.Multiline = $true; $log.ScrollBars = 'Vertical'; $log.ReadOnly = $true
$log.Location = New-Object System.Drawing.Point(12, ($y + 10)); $log.Size = New-Object System.Drawing.Size(600, (480 - $y))
$log.Font = New-Object System.Drawing.Font('Consolas', 8.5)
$form.Controls.Add($log)
$script:LogBox = $log

$btInstall = New-Object System.Windows.Forms.Button
$btInstall.Text = 'Install / Update'; $btInstall.Location = New-Object System.Drawing.Point(12, 520); $btInstall.Size = New-Object System.Drawing.Size(140, 30)
$btUninstall = New-Object System.Windows.Forms.Button
$btUninstall.Text = 'Uninstall all'; $btUninstall.Location = New-Object System.Drawing.Point(162, 520); $btUninstall.Size = New-Object System.Drawing.Size(120, 30)
$btClose = New-Object System.Windows.Forms.Button
$btClose.Text = 'Close'; $btClose.Location = New-Object System.Drawing.Point(512, 520); $btClose.Size = New-Object System.Drawing.Size(100, 30)
$form.Controls.Add($btInstall); $form.Controls.Add($btUninstall); $form.Controls.Add($btClose)
$btClose.Add_Click({ $form.Close() })

function Set-Busy($b) { $btInstall.Enabled = -not $b; $btUninstall.Enabled = -not $b; $btBrowse.Enabled = -not $b; $form.Cursor = $(if ($b) { 'WaitCursor' } else { 'Default' }) }

$btInstall.Add_Click({
    $log.Clear(); Set-Busy $true
    try {
        $az = $tbAz.Text.Trim().Trim('"')
        $sel = @(); foreach ($t in $Catalog) { if ($checks[$t.id].Checked) { $sel += $t.id } }
        $w = 0; $h = 0
        if (-not [int]::TryParse($tbW.Text, [ref]$w) -or -not [int]::TryParse($tbH.Text, [ref]$h) -or $w -le 0 -or $h -le 0) { Fail 'Please enter the screen resolution.' }
        Invoke-Install $az $w $h $sel $cbLnk.Checked
    } catch { Say ""; Say "ERROR: $($_.Exception.Message)" }
    Set-Busy $false; Update-Games
})
$btUninstall.Add_Click({
    $r = [System.Windows.Forms.MessageBox]::Show('Remove the 21:9 patch from all games?', 'Uninstall', 'YesNo', 'Question')
    if ($r -ne 'Yes') { return }
    $log.Clear(); Set-Busy $true
    try { Invoke-Uninstall ($tbAz.Text.Trim().Trim('"')) } catch { Say ""; Say "ERROR: $($_.Exception.Message)" }
    Set-Busy $false; Update-Games
})

Update-Games
Say "Forza 21:9 Ultrawide Patch $ModVersion"
Say "Select the games and press 'Install / Update'. Unselected games get their original UI back."
Say "Games the patch does not know yet stay original automatically."
[void]$form.ShowDialog()
