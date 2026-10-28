/* Azimuth 21:9 UI loader (dinput8.dll proxy next to azimuth.exe).
   Patches Azimuth 1.0.2 in memory only (azimuth.exe on disk stays original, so FH2 Extra Options keeps working):
   - UI width the title is told (1920) -> 1080 * screen width / screen height (2580 at 3440x1440)
   - UI clip/projection aspect constant 16/9 -> 1.0256 * screen aspect (2.45 at 21:9)
   The patch runs in a thread created from DllMain: it starts after all DLLs (Extra Options too) are initialised. */
typedef unsigned char u8; typedef unsigned short u16; typedef unsigned int u32; typedef unsigned long long u64;
typedef void *HANDLE; typedef int BOOL; typedef unsigned long DWORD; typedef long HRESULT; typedef unsigned short WCHAR;
#define WINAPI __stdcall
__declspec(dllimport) void *WINAPI GetModuleHandleW(const WCHAR *);
__declspec(dllimport) BOOL WINAPI VirtualProtect(void *, u64, DWORD, DWORD *);
__declspec(dllimport) BOOL WINAPI FlushInstructionCache(HANDLE, const void *, u64);
__declspec(dllimport) HANDLE WINAPI GetCurrentProcess(void);
__declspec(dllimport) void *WINAPI LoadLibraryW(const WCHAR *);
__declspec(dllimport) void *WINAPI GetProcAddress(void *, const char *);
__declspec(dllimport) u32 WINAPI GetSystemDirectoryW(WCHAR *, u32);
__declspec(dllimport) HANDLE WINAPI CreateThread(void *, u64, DWORD (WINAPI *)(void *), void *, DWORD, DWORD *);
__declspec(dllimport) BOOL WINAPI CloseHandle(HANDLE);
__declspec(dllimport) HANDLE WINAPI CreateFileW(const WCHAR *, DWORD, DWORD, void *, DWORD, DWORD, HANDLE);
__declspec(dllimport) BOOL WINAPI WriteFile(HANDLE, const void *, DWORD, DWORD *, void *);
__declspec(dllimport) DWORD WINAPI GetModuleFileNameW(void *, WCHAR *, DWORD);
__declspec(dllimport) void WINAPI OutputDebugStringA(const char *);
__declspec(dllimport) DWORD WINAPI SetFilePointer(HANDLE, long, long *, DWORD);
__declspec(dllimport) int WINAPI GetSystemMetrics(int);
typedef struct { u64 BaseAddress, AllocationBase; DWORD AllocationProtect; u16 PartitionId, pad0; u64 RegionSize; DWORD State, Protect, Type, pad1; } MBI;
__declspec(dllimport) u64 WINAPI VirtualQuery(const void *, MBI *, u64);
__declspec(dllimport) void WINAPI Sleep(DWORD);
__declspec(dllimport) u64 WINAPI GetTickCount64(void);
__declspec(dllimport) DWORD WINAPI GetPrivateProfileStringW(const WCHAR *, const WCHAR *, const WCHAR *, WCHAR *, DWORD, const WCHAR *);
__declspec(dllimport) BOOL WINAPI ReadFile(HANDLE, void *, DWORD, DWORD *, void *);
__declspec(dllimport) void *WINAPI VirtualAlloc(void *, u64, DWORD, DWORD);
__declspec(dllimport) BOOL WINAPI ReadProcessMemory(HANDLE, const void *, void *, u64, u64 *);
__declspec(dllimport) u32 WINAPI GetPrivateProfileIntW(const WCHAR *, const WCHAR *, int, const WCHAR *);
__declspec(dllimport) u32 WINAPI GetPrivateProfileIntW(const WCHAR *, const WCHAR *, int, const WCHAR *);

void *memcpy(void *d, const void *s, u64 n) { u8 *a = d; const u8 *b = s; while (n--) *a++ = *b++; return d; }
void *memset(void *d, int c, u64 n) { u8 *a = d; while (n--) *a++ = (u8)c; return d; }
int _fltused = 0;

static void *g_self;
static u8 *g_az; static int g_az_ok;
static volatile int g_title = -2;          /* -2 not yet known, -1 unknown title, else index into titles[] */
static volatile int g_title_on;            /* 1 = 21:9 enabled for the running title */
     /* azimuth.exe base, 1 = verified Azimuth 1.0.2 */
static HANDLE g_log = (HANDLE)-1;

static int slen(const char *s) { int n = 0; while (s[n]) n++; return n; }
static void logs(const char *s)
{
    DWORD w;
    OutputDebugStringA(s);
    if (g_log != (HANDLE)-1) WriteFile(g_log, s, slen(s), &w, 0);
}
static char *put(char *p, const char *s) { while (*s) *p++ = *s++; return p; }
static char *putu(char *p, u64 v, int base)
{
    char t[24]; int n = 0;
    do { t[n++] = "0123456789abcdef"[v % base]; v /= base; } while (v);
    while (n) *p++ = t[--n];
    return p;
}
static int side_path(WCHAR *path, const WCHAR *name)
{
    DWORD n = GetModuleFileNameW(g_self, path, 560), i;
    if (!n) return 0;
    for (i = n; i && path[i - 1] != '\\'; i--) ;
    while (*name) path[i++] = *name++;
    path[i] = 0;
    return 1;
}
static void open_log(void)
{
    WCHAR path[600];
    if (!side_path(path, L"azimuth_21x9.log")) return;
    g_log = CreateFileW(path, 0x40000000 /*GENERIC_WRITE*/, 1 /*SHARE_READ*/, 0, 2 /*CREATE_ALWAYS*/, 0x80, 0);
}

/* ---- patch sites of Azimuth 1.0.2 (azimuth.exe SHA-256 42527964...) ---- */
typedef struct { u32 rva; u8 len; u8 orig[8]; u8 kind; } Site;   /* kind 0: imm32 width at +3, 1: float at +4 */
static Site az102[] = {
    { 0x295c0c, 7, { 0xc7, 0x46, 0x17, 0x80, 0x07, 0x00, 0x00 }, 0 },     /* mov dword [rsi+0x17], 1920 */
    { 0x295c46, 7, { 0xc7, 0x46, 0x01, 0x80, 0x07, 0x00, 0x00 }, 0 },     /* mov dword [rsi+0x01], 1920 */
    { 0x2941ff, 8, { 0x48, 0xc7, 0x45, 0xdf, 0x39, 0x8e, 0xe3, 0x3f }, 1 }, /* mov qword [rbp-0x21], 16/9 */
    { 0x29420e, 8, { 0x48, 0xc7, 0x45, 0xef, 0x39, 0x8e, 0xe3, 0x3f }, 1 }, /* mov qword [rbp-0x11], 16/9 */
    /* default UI clip planes (used when the title has no own UI matrix, e.g. FM5): x <= 16/9, -x <= 16/9 */
    { 0x82ed8c, 4, { 0x39, 0x8e, 0xe3, 0xbf }, 2 },                       /* plane (1,0,0,-16/9)  */
    { 0x82ed9c, 4, { 0x39, 0x8e, 0xe3, 0xbf }, 2 },                       /* plane (-1,0,0,-16/9) */
};

/* Azimuth versions: patch-site RVAs (same order as az102[]), UI generator, UI frame globals, screen-copy constants */
typedef struct { const char *name; u32 site[7]; u32 gen, frame, k960, pace, present; } AzVer;
static const AzVer azvers[] = {
    { "1.0.2", { 0x295c0c, 0x295c46, 0x2941ff, 0x29420e, 0x82ed8c, 0x82ed9c, 0 }, 0x294790, 0x8eb240, 0x82e360, 0x4eedc, 0x4ed00 },
    { "1.0.3", { 0x2a052c, 0x2a0566, 0x29eb1f, 0x29eb2e, 0x855b3c, 0x855b4c, 0 }, 0x29f0b0, 0x913470, 0x855110, 0x4e738, 0x4e550 },
};
static const AzVer *g_ver;
static volatile u8 g_fullrate;

static int ui_width(void)
{
    int cx = GetSystemMetrics(0 /*SM_CXSCREEN*/), cy = GetSystemMetrics(1 /*SM_CYSCREEN*/);
    int w;
    WCHAR ini[600];
    /* the installer writes azimuth_21x9.ini [ui] width=<UI width its UI.zip edits were made for> */
    if (side_path(ini, L"azimuth_21x9.ini")) {
        w = (int)GetPrivateProfileIntW(L"ui", L"width", 0, ini);
        if (w >= 1920 && w <= 8000) return w;
    }
    if (cx <= 0 || cy <= 0) return 2580;
    w = (int)(((u64)1080 * cx + cy / 2) / cy);
    if (w < 1920) w = 1920;                 /* 16:9 or narrower: unchanged */
    return (w + 1) & ~1;
}


/* ---- per-title patches in the GAME image (Azimuth 1.0 checks the game file's hash, so these are applied in memory) ---- */
typedef struct { u32 rva; u32 orig; u32 kind; } GSite;        /* kind 1: float := UI width */
typedef struct { u32 rva; u32 len; u8 orig[16]; u8 rep[16]; } GCode;
typedef struct { const char *name; u32 timestamp, sizeofimage, check_rva, check, code_rva, code; int widen_box; int n; GSite site[4]; int nc; GCode code_patch[4]; } Game;
static const Game games[] = {
    /* Forza Motorsport 5 1.0.0.20: UI root size 1920.0 (.data) -> UI width (2580.0); same value the 0.9 exe patch wrote */
    { "Forza Motorsport 5", 0x53d8d1f2, 0x279d000, 0x2218e98, 0x44f00000, 0xb65449, 0x2424448b, 0, 1, { { 0x2218e98, 0x44f00000, 1 } },
      /* effect pool: store the size the object was requested with, not GetDesc (Azimuth enlarges UI copy buffers ->
         pool miss -> textures re-created every frame -> fps drop in the garage). Same as the 0.9 exe patch. */
      1, { { 0xb65449, 14, { 0x8b,0x44,0x24,0x24,0x89,0x42,0x10,0x8b,0x44,0x24,0x20,0x89,0x42,0x0c },
                           { 0x8b,0x43,0x04,0x89,0x42,0x10,0x8b,0x03,0x89,0x42,0x0c,0x90,0x90,0x90 } } } },
};

static int readable(u64 a, u64 len)
{
    MBI m;
    if (!VirtualQuery((void *)a, &m, sizeof m)) return 0;
    if (m.State != 0x1000 || (m.Protect & 0x101) || !m.Protect) return 0;   /* committed, not NOACCESS/GUARD */
    return a + len <= m.BaseAddress + m.RegionSize;
}

static const Game *find_game(u8 **base_out)
{
    u64 a = 0x10000;
    MBI m;
    while (a < 0x7ffffffe0000ull && VirtualQuery((void *)a, &m, sizeof m)) {
        if (m.State == 0x1000 && m.BaseAddress == m.AllocationBase && !(m.Protect & 0x101) && m.Protect && m.RegionSize >= 0x400) {
            u8 *b = (u8 *)m.BaseAddress;
            if (b[0] == 'M' && b[1] == 'Z') {
                u32 pe = *(u32 *)(b + 0x3c);
                if (pe < 0x300 && *(u32 *)(b + pe) == 0x4550) {
                    u32 ts = *(u32 *)(b + pe + 8), soi = *(u32 *)(b + pe + 24 + 56);
                    int i;
                    for (i = 0; i < (int)(sizeof games / sizeof games[0]); i++)
                        if (games[i].timestamp == ts && games[i].sizeofimage == soi && b != g_az
                            && readable((u64)b + games[i].check_rva, 4) && readable((u64)b + games[i].code_rva, 4)
                            && *(u32 *)(b + games[i].check_rva) == games[i].check      /* image layout, sections filled */
                            && *(u32 *)(b + games[i].code_rva) == games[i].code) { *base_out = b; return &games[i]; }
                }
            }
        }
        a = m.BaseAddress + m.RegionSize;
    }
    return 0;
}


/* Azimuth 1.0 writes the UI frame box (16:9 fit: x=440 y=0 w=2560 h=1440 at 3440x1440) as immediates into the game's code:
     48 b8 <x f32><y f32>  c4 e1 f9 6e ..  48 b8 <w f32><h f32>  c4 e3 .. 22 .. 01
   For titles whose UI is widened in the game itself (FM5) the box must be the whole width: x=0, w=w+2x. */
static int widen_frame_boxes(u8 *text, u32 len)
{
    u32 i; int n = 0;
    for (i = 0; i + 0x1a < len; i++) {
        u8 *c = text + i;
        if (c[0] != 0x48 || c[1] != 0xb8 || c[10] != 0xc4 || c[11] != 0xe1 || c[12] != 0xf9 || c[13] != 0x6e
            || c[15] != 0x48 || c[16] != 0xb8 || c[25] != 0xc4 || c[26] != 0xe3) continue;
        {
            float x, w, nx = 0.0f, nw; DWORD old;
            memcpy(&x, c + 2, 4); memcpy(&w, c + 17, 4);
            if (!(x > 1.0f && x < 4000.0f && w > 100.0f && w < 16000.0f)) continue;
            nw = w + 2.0f * x;
            if (!VirtualProtect(c, 0x20, 0x40, &old)) continue;
            memcpy(c + 2, &nx, 4); memcpy(c + 17, &nw, 4);
            VirtualProtect(c, 0x20, old, &old);
            FlushInstructionCache(GetCurrentProcess(), c, 0x20);
            n++;
        }
    }
    return n;
}

/* ---- diagnosis: log every place where the game's code in memory differs from its file (= Azimuth's patches) ---- */
static HANDLE g_dlog = (HANDLE)-1;
static void dlogs(const char *s) { DWORD w; if (g_dlog != (HANDLE)-1) WriteFile(g_dlog, s, slen(s), &w, 0); }
static char *puthex(char *p, const u8 *b, u32 n) { u32 i; for (i = 0; i < n; i++) { *p++ = "0123456789abcdef"[b[i] >> 4]; *p++ = "0123456789abcdef"[b[i] & 15]; } return p; }
static void dump_stub(u64 t)
{
    static char buf[700]; char *p;
    if (!readable(t, 256)) return;
    p = put(buf, "    stub 0x"); p = putu(p, t, 16); p = put(p, ": "); p = puthex(p, (u8 *)t, 256); p = put(p, "\r\n"); *p = 0; dlogs(buf);
}
static void diff_game(u8 *base, const WCHAR *title)
{
    static WCHAR ini[600], folder[600], path[700]; static char buf[700]; char *p;
    HANDLE f; DWORD rd; u32 pe, tva, tsz, traw, i, j, k, n = 0; u8 *file;
    if (!side_path(ini, L"azimuth_21x9_diff.log")) return;
    g_dlog = CreateFileW(ini, 0x40000000, 1, 0, 2, 0x80, 0);
    side_path(ini, L"data\\azimuth.ini");
    if (!GetPrivateProfileStringW(title, L"folder", L"", folder, 560, ini)) { dlogs("no folder in azimuth.ini\r\n"); return; }
    for (i = 0; folder[i]; i++) path[i] = folder[i];
    { const WCHAR *e = L"\\Mount\\forza_durango_release_final.exe"; while (*e) path[i++] = *e++; path[i] = 0; }
    f = CreateFileW(path, 0x80000000, 3, 0, 3, 0x80, 0);
    if (f == (HANDLE)-1) { dlogs("cannot open game exe\r\n"); return; }
    pe = *(u32 *)(base + 0x3c);
    { u8 *sec = base + pe + 24 + *(u16 *)(base + pe + 20); tva = *(u32 *)(sec + 12); tsz = *(u32 *)(sec + 8); traw = *(u32 *)(sec + 20); }
    file = VirtualAlloc(0, tsz + 0x1000, 0x3000, 0x04);
    if (!file) return;
    SetFilePointer(f, (long)traw, 0, 0);
    ReadFile(f, file, tsz, &rd, 0); CloseHandle(f);
    p = put(buf, "game .text rva 0x"); p = putu(p, tva, 16); p = put(p, " size 0x"); p = putu(p, tsz, 16); p = put(p, " read 0x"); p = putu(p, rd, 16); p = put(p, "\r\n"); *p = 0; dlogs(buf);
    for (i = 0; i < rd; i++) {
        if (base[tva + i] == file[i]) continue;
        j = i; k = i;
        while (j < rd && (j - k) < 16) { if (base[tva + j] != file[j]) k = j; j++; }   /* merge runs closer than 16 bytes */
        p = put(buf, "rva 0x"); p = putu(p, tva + i, 16); p = put(p, " len "); p = putu(p, k - i + 1, 10); p = put(p, "\r\n  file "); 
        p = puthex(p, file + i, (k - i + 1) > 96 ? 96 : (k - i + 1)); p = put(p, "\r\n  mem  ");
        p = puthex(p, base + tva + i, (k - i + 1) > 96 ? 96 : (k - i + 1)); p = put(p, "\r\n"); *p = 0; dlogs(buf);
        for (j = i; j + 12 <= k + 1 + 12 && j + 12 < rd; j++)                    /* mov rax, imm64 ; call/jmp rax */
            if (base[tva + j] == 0x48 && base[tva + j + 1] == 0xb8 && base[tva + j + 10] == 0xff && (base[tva + j + 11] == 0xd0 || base[tva + j + 11] == 0xe0))
                dump_stub(*(u64 *)(base + tva + j + 2));
        if (++n > 400) break;
        i = k;
    }
    p = put(buf, "diff runs: "); p = putu(p, n, 10); p = put(p, "\r\n"); *p = 0; dlogs(buf);
    { u8 *fr = g_az + g_ver->frame; p = put(buf, "frame globals: "); p = puthex(p, fr, 32); p = put(p, "  e9210: "); p = puthex(p, g_az + 0x8e9210, 4);
      p = put(p, " e9258: "); p = puthex(p, g_az + 0x8e9258, 4); p = put(p, "\r\n"); *p = 0; dlogs(buf); }
    { static const u32 r[][2] = { { 0x8e9200, 0x80 }, { 0x912280, 0xc0 }, { 0x9124c0, 0x40 }, { 0x909c60, 0x8 } }; int q;
      for (q = 0; q < 4; q++) { p = put(buf, "az+0x"); p = putu(p, r[q][0], 16); p = put(p, ": "); p = puthex(p, g_az + r[q][0], r[q][1]); p = put(p, "\r\n"); *p = 0; dlogs(buf); } }
    p = put(buf, "azimuth base 0x"); p = putu(p, (u64)g_az, 16); p = put(p, "\r\n"); *p = 0; dlogs(buf);
    CloseHandle(g_dlog); g_dlog = (HANDLE)-1;
}


/* Azimuth replaces the game's UI-element projection aspect (xmm14) by a stub with constants +16/9 / -16/9:
   game:  48 b8 <stub> ff d0      stub: c5f2591d14000000 c5fa590d08000000 c3 ... +0x18: +16/9  +0x1c: -16/9
   With the widened UI the aspect must be UI width / 1080. */
static int fix_aspect_stubs(u8 *text, u32 len, float aspect)
{
    static const u8 sig[17] = { 0xc5,0xf2,0x59,0x1d,0x14,0,0,0, 0xc5,0xfa,0x59,0x0d,0x08,0,0,0, 0xc3 };
    u32 i, j; int n = 0;
    for (i = 0; i + 12 < len; i++) {
        u8 *c = text + i; u64 t; u8 *st; DWORD old;
        if (c[0] != 0x48 || c[1] != 0xb8 || c[10] != 0xff || c[11] != 0xd0) continue;
        t = *(u64 *)(c + 2);
        if (t < 0x10000 || !readable(t, 0x20)) continue;
        st = (u8 *)t;
        for (j = 0; j < 17 && st[j] == sig[j]; j++) ;
        if (j < 17 || *(u32 *)(st + 0x18) != 0x3fe38e39 || *(u32 *)(st + 0x1c) != 0xbfe38e39) continue;
        if (!VirtualProtect(st, 0x20, 0x40, &old)) continue;
        { float a = aspect, b = -aspect; memcpy(st + 0x18, &a, 4); memcpy(st + 0x1c, &b, 4); }
        VirtualProtect(st, 0x20, old, &old);
        FlushInstructionCache(GetCurrentProcess(), st, 0x20);
        n++;
    }
    return n;
}


/* ---- D3D11.X context hooks (diagnosis + FM5 scissor fix) ----
   The game calls context methods through a function table inside the context object: [ctx + (slot+4)*8].
   slot 44 RSSetViewports, 45 RSSetScissorRects. We find the context objects by scanning private RW memory for a long run
   of pointers into Azimuth's code, then replace those two entries. */
typedef struct { int l, t, r, b; } RECT_;
typedef struct { float x, y, w, h, mn, mx; } VP_;
typedef void (*SCIS)(void *, u32, const RECT_ *);
typedef void (*VPS)(void *, u32, const VP_ *);
static struct { void *ctx; SCIS sc; VPS vp; } g_ctx[8];
static volatile int g_nctx; static int g_fixscissor;
static HANDLE g_hlog = (HANDLE)-1;
static struct { u64 ret; int a, b, c, d, kind; } g_seen[96];
static volatile int g_nseen;
static int g_bx0 = 440, g_bx1 = 3000, g_full = 3440;
static void hlog_once(int kind, u64 ret, int a, int b, int c, int d)
{
    int i; char buf[200], *p; DWORD w;
    for (i = 0; i < g_nseen; i++) if (g_seen[i].ret == ret && g_seen[i].a == a && g_seen[i].b == b && g_seen[i].c == c && g_seen[i].d == d && g_seen[i].kind == kind) return;
    if (g_nseen >= 96 || g_hlog == (HANDLE)-1) return;
    g_seen[g_nseen].ret = ret; g_seen[g_nseen].a = a; g_seen[g_nseen].b = b; g_seen[g_nseen].c = c; g_seen[g_nseen].d = d; g_seen[g_nseen].kind = kind; g_nseen++;
    p = put(buf, kind == 0 ? "scissor " : (kind == 1 ? "SCISSOR-WIDENED " : "viewport "));
    p = put(p, "from 0x"); p = putu(p, ret, 16);
    p = put(p, " : "); p = putu(p, (u64)(u32)a, 10); p = put(p, " "); p = putu(p, (u64)(u32)b, 10); p = put(p, " "); p = putu(p, (u64)(u32)c, 10); p = put(p, " "); p = putu(p, (u64)(u32)d, 10);
    p = put(p, "\r\n"); *p = 0;
    WriteFile(g_hlog, buf, slen(buf), &w, 0);
}
static int find_ctx(void *ctx) { int i; for (i = 0; i < g_nctx; i++) if (g_ctx[i].ctx == ctx) return i; return -1; }
static void hk_scissor(void *ctx, u32 n, const RECT_ *r)
{
    int i = find_ctx(ctx); u64 ret = (u64)__builtin_return_address(0);
    if (i < 0) return;
    if (n >= 1 && r) {
        if (g_fixscissor && r[0].l == g_bx0 && r[0].r == g_bx1) {
            RECT_ tmp[16]; u32 k;
            for (k = 0; k < n && k < 16; k++) tmp[k] = r[k];
            tmp[0].l = 0; tmp[0].r = g_full;
            hlog_once(1, ret, r[0].l, r[0].t, r[0].r, r[0].b);
            g_ctx[i].sc(ctx, n < 16 ? n : 16, tmp);
            return;
        }
        hlog_once(0, ret, r[0].l, r[0].t, r[0].r, r[0].b);
    }
    g_ctx[i].sc(ctx, n, r);
}
static void hk_viewports(void *ctx, u32 n, const VP_ *v)
{
    int i = find_ctx(ctx); u64 ret = (u64)__builtin_return_address(0);
    if (i < 0) return;
    if (n >= 1 && v) {
        if (0 && v[0].y == 0.0f && v[0].x == (float)g_bx0 && v[0].x + v[0].w == (float)g_bx1) {
            VP_ tmp[16]; u32 k;
            for (k = 0; k < n && k < 16; k++) tmp[k] = v[k];
            tmp[0].x = 0.0f; tmp[0].w = (float)g_full;
            hlog_once(1, ret, (int)v[0].x, (int)v[0].y, (int)v[0].w, (int)v[0].h);
            g_ctx[i].vp(ctx, n < 16 ? n : 16, tmp);
            return;
        }
        hlog_once(2, ret, (int)v[0].x, (int)v[0].y, (int)v[0].w, (int)v[0].h);
    }
    g_ctx[i].vp(ctx, n, v);
}
static void hook_contexts(void)
{
    static u64 chunk[0x20000];          /* 1 MB */
    u64 a = 0x10000, lo = (u64)g_az + 0x1000, hi = (u64)g_az + 0x7b4000;
    MBI m; char buf[200], *p; WCHAR path[600];
    if (g_hlog == (HANDLE)-1 && side_path(path, L"azimuth_21x9_d3d.log")) g_hlog = CreateFileW(path, 0x40000000, 1, 0, 2, 0x80, 0);
    while (a < 0x7ffffffe0000ull && VirtualQuery((void *)a, &m, sizeof m) && g_nctx < 8) {
        if (m.State == 0x1000 && m.Type == 0x20000 && m.Protect == 0x04 && m.RegionSize <= 0x4000000) {
            u64 off;
            for (off = 0; off < m.RegionSize && g_nctx < 8; off += sizeof chunk) {
                u64 len = m.RegionSize - off, got = 0, i, run = 0;
                if (len > sizeof chunk) len = sizeof chunk;
                if (!ReadProcessMemory(GetCurrentProcess(), (void *)(m.BaseAddress + off), chunk, len, &got)) continue;
                for (i = 0; i < got / 8; i++) {
                    if (chunk[i] >= lo && chunk[i] < hi) { run++; continue; }
                    if (run >= 190 && run <= 260) {   /* real context tables have 200 entries; shorter runs are the tail after an already hooked slot */
                        u64 start = m.BaseAddress + off + (i - run) * 8;          /* address of first table entry */
                        void *ctx = (void *)(start - 0x20);
                        u64 *slot45 = (u64 *)(start + 45 * 8);          /* ctx+0x188 = RSSetViewports (game 0x140717b55) */
                        u64 *slot46 = (u64 *)(start + 46 * 8);          /* ctx+0x190 = RSSetScissorRects */
                        if (find_ctx(ctx) < 0 && g_nctx < 8 && *slot45 != (u64)hk_viewports && *slot46 >= lo && *slot46 < hi) {
                            g_ctx[g_nctx].ctx = ctx; g_ctx[g_nctx].vp = (VPS)*slot45; g_ctx[g_nctx].sc = (SCIS)*slot46; g_nctx++;
                            *slot45 = (u64)hk_viewports; *slot46 = (u64)hk_scissor;
                            p = put(buf, "context 0x"); p = putu(p, (u64)ctx, 16); p = put(p, " table run "); p = putu(p, run, 10);
                            p = put(p, " vp 0x"); p = putu(p, (u64)g_ctx[g_nctx - 1].vp - (u64)g_az, 16);
                            p = put(p, " sc 0x"); p = putu(p, (u64)g_ctx[g_nctx - 1].sc - (u64)g_az, 16); p = put(p, " (az rva)\r\n"); *p = 0;
                            { DWORD w; if (g_hlog != (HANDLE)-1) WriteFile(g_hlog, buf, slen(buf), &w, 0); }
                            { static const int sl[] = { -4, -3, -2, -1, 43, 44, 45, 76, 97 }; int q; DWORD w;
                              for (q = 0; q < 9; q++) { u64 t = *(u64 *)(start + sl[q] * 8);
                                p = put(buf, "  slot "); if (sl[q] < 0) p = put(p, "-"); p = putu(p, sl[q] < 0 ? -sl[q] : sl[q], 10); p = put(p, " = 0x"); p = putu(p, t, 16);
                                if (t >= lo && t < hi) { p = put(p, " : "); p = puthex(p, (u8 *)t, 24); }
                                p = put(p, "\r\n"); *p = 0; if (g_hlog != (HANDLE)-1) WriteFile(g_hlog, buf, slen(buf), &w, 0); } }
                        }
                    }
                    run = 0;
                }
            }
        }
        a = m.BaseAddress + m.RegionSize;
    }
    if (!g_nctx) { DWORD w; if (g_hlog != (HANDLE)-1) WriteFile(g_hlog, "no context found\r\n", 18, &w, 0); }
}


/* ---- diagnosis: count calls of FM5's UI element render-target creation (game+0xb5eb40, r8d=w r9d=h) ---- */
static volatile long g_rtc; static volatile u32 g_rtw, g_rth;
static void rt_count(u64 w, u64 h) { g_rtc++; g_rtw = (u32)w; g_rth = (u32)h; }
static int hook_game_counter(u8 *base)
{
    u8 *f = base + 0xb5eb40, *s; DWORD old; int k = 0;
    static const u8 pro[15] = { 0x48,0x89,0x5c,0x24,0x08, 0x48,0x89,0x74,0x24,0x10, 0x48,0x89,0x7c,0x24,0x18 };
    int i; for (i = 0; i < 15; i++) if (f[i] != pro[i]) return 0;
    s = VirtualAlloc(0, 0x1000, 0x3000, 0x40); if (!s) return 0;
    /* push rcx,rdx,r8,r9 ; mov rcx,r8 ; mov rdx,r9 ; sub rsp,28h ; mov rax,imm ; call rax ; add rsp,28h ; pop r9,r8,rdx,rcx */
    s[k++]=0x51; s[k++]=0x52; s[k++]=0x41; s[k++]=0x50; s[k++]=0x41; s[k++]=0x51;
    s[k++]=0x4c; s[k++]=0x89; s[k++]=0xc1;  s[k++]=0x4c; s[k++]=0x89; s[k++]=0xca;
    s[k++]=0x48; s[k++]=0x83; s[k++]=0xec; s[k++]=0x28;
    s[k++]=0x48; s[k++]=0xb8; { u64 v=(u64)rt_count; memcpy(s+k,&v,8); k+=8; }
    s[k++]=0xff; s[k++]=0xd0;
    s[k++]=0x48; s[k++]=0x83; s[k++]=0xc4; s[k++]=0x28;
    s[k++]=0x41; s[k++]=0x59; s[k++]=0x41; s[k++]=0x58; s[k++]=0x5a; s[k++]=0x59;
    memcpy(s+k,pro,15); k+=15;
    s[k++]=0xff; s[k++]=0x25; s[k++]=0; s[k++]=0; s[k++]=0; s[k++]=0; { u64 v=(u64)(f+15); memcpy(s+k,&v,8); k+=8; }
    if (!VirtualProtect(f, 15, 0x40, &old)) return 0;
    f[0]=0xff; f[1]=0x25; f[2]=f[3]=f[4]=f[5]=0; { u64 v=(u64)s; memcpy(f+6,&v,8); } f[14]=0x90;
    VirtualProtect(f, 15, old, &old); FlushInstructionCache(GetCurrentProcess(), f, 15);
    return 1;
}
static DWORD WINAPI rt_logger(void *arg)
{
    char buf[160], *p; long last = 0; int t = 0; (void)arg;
    for (;;) {
        Sleep(2000); t += 2;
        { long c = g_rtc, d = c - last; last = c;
          if (d > 0) { p = put(buf, "perf: t="); p = putu(p, t, 10); p = put(p, "s element RT creates/s="); p = putu(p, (u64)(d / 2), 10);
            p = put(p, " last "); p = putu(p, g_rtw, 10); p = put(p, "x"); p = putu(p, g_rth, 10); p = put(p, "\r\n"); *p = 0; logs(buf); } }
    }
}

static DWORD WINAPI game_thread(void *arg)
{
    int w = (int)(u64)arg, i, fixes = 0, dumped = 0;
    u64 t0 = GetTickCount64(), tf = 0;
    u8 *base = 0;
    const Game *g = 0;
    char buf[256], *p;
    float fw = (float)w;
    u32 v; memcpy(&v, &fw, 4);
    while (!g) {
        if (GetTickCount64() - t0 > 30ull * 60 * 1000) return 0;     /* no known game within 30 minutes */
        g = find_game(&base);
        if (!g) Sleep(10);
    }
    tf = GetTickCount64();
    while (g_title == -2 && GetTickCount64() - tf < 20000) Sleep(5);      /* wait for the generator decision */
    if (g_title == 2 && g_fullrate) {
        /* FM5 renderer SetPresentMode(this, edx) at game+0x711620 stores [this+0a0h]; mode 1 = "every 2nd vblank"
           (garage, pre-race: 30 fps on Xbox), which the game and Azimuth turn into frame_rate/2.
           New setter: if (edx == 1) edx = 0; [rcx+0a0h] = edx; ret */
        static const u8 o2[16] = { 0x89,0x91,0xa0,0,0,0, 0xc3, 0xcc,0xcc,0xcc,0xcc,0xcc,0xcc,0xcc,0xcc,0xcc };
        static const u8 r2[14] = { 0x83,0xfa,0x01, 0x75,0x02, 0x31,0xd2, 0x89,0x91,0xa0,0,0,0, 0xc3 };
        u8 *a = base + 0x711620; DWORD old; int j, same = 1; u64 tw = GetTickCount64();
        while (GetTickCount64() - tw < 20000) { same = 1; for (j = 0; j < 16; j++) if (a[j] != o2[j]) same = 0; if (same) break; Sleep(5); }
        if (same && VirtualProtect(a, 16, 0x40, &old)) {
            memcpy(a, r2, 14); VirtualProtect(a, 16, old, &old); FlushInstructionCache(GetCurrentProcess(), a, 16);
            logs("azimuth 21:9: FM5 present mode 1 (every 2nd vblank: garage/pre-race) -> mode 0 (full rate)\r\n");
        } else logs("azimuth 21:9: FM5 present mode setter not found - left alone\r\n");
    }
    if (!g_title_on || g_title != 2) { logs("azimuth 21:9: FM5 21:9 disabled - game left untouched\r\n"); return 0; }
    p = put(buf, "azimuth 21:9: game "); p = put(p, g->name); p = put(p, " at 0x"); p = putu(p, (u64)base, 16);
    p = put(p, " after "); p = putu(p, tf - t0, 10); p = put(p, " ms\r\n"); *p = 0; logs(buf);
    if (g_az_ok && *(float *)(g_az + g_ver->k960) == 960.0f && *(float *)(g_az + g_ver->k960 + 0x10) == 1920.0f) {
        /* Azimuth's screen-copy helpers map UI -> screen as frame_x + ui * frame_w / 1920 around centre 960.
           Our UI is w wide and fills the screen: centre w/2, width w (frame made full width below). */
        float *c = (float *)(g_az + g_ver->k960); DWORD old;
        if (VirtualProtect(c, 0x14, 0x04, &old)) { c[0] = (float)w * 0.5f; c[4] = (float)w; VirtualProtect(c, 0x14, old, &old);
            logs("azimuth 21:9: screen-copy UI centre/width 960/1920 -> UI width/2 / UI width\r\n"); }
    }
    if (0 && hook_game_counter(base)) { HANDLE t = CreateThread(0, 0, rt_logger, 0, 0, 0); if (t) CloseHandle(t); }
    for (i = 0; i < g->nc; i++) {
        const GCode *c = &g->code_patch[i];
        u8 *a = base + c->rva; DWORD old; u32 j, same = 1;
        for (j = 0; j < c->len; j++) if (a[j] != c->orig[j]) same = 0;
        if (!same) { logs("azimuth 21:9: game code differs, code patch skipped\r\n"); continue; }
        if (VirtualProtect(a, c->len, 0x40, &old)) {
            memcpy(a, c->rep, c->len);
            VirtualProtect(a, c->len, old, &old);
            FlushInstructionCache(GetCurrentProcess(), a, c->len);
            p = put(buf, "azimuth 21:9: patched game code +0x"); p = putu(p, c->rva, 16); p = put(p, "\r\n"); *p = 0; logs(buf);
        }
    }
    /* the loader may still be filling the image: wait until the check value is there, then patch; keep it for 60 s */
    {
        u64 lastscan = 0;
        while (GetTickCount64() - tf < 60000) {
        if (GetTickCount64() - lastscan >= 200) {
            u32 pe = *(u32 *)(base + 0x3c);
            u8 *sec = base + pe + 24 + *(u16 *)(base + pe + 20);          /* first section = .text */
            u32 tva = *(u32 *)(sec + 12), tsz = *(u32 *)(sec + 8);
            int k;
            lastscan = GetTickCount64();
            if (g_az_ok && *(float *)(g_az + g_ver->k960 + 0x10) == (float)w) {
                float *fr = (float *)(g_az + g_ver->frame);      /* [4] x, [5] y, [6] w, [7] h of Azimuth's UI frame */
                if (fr[4] > 1.0f && fr[4] < 4000.0f && fr[6] > 100.0f) {
                    fr[6] += 2.0f * fr[4]; fr[4] = 0.0f;
                    p = put(buf, "azimuth 21:9: UI frame -> full width after "); p = putu(p, GetTickCount64() - t0, 10);
                    p = put(p, " ms\r\n"); *p = 0; logs(buf);
                }
            }
            if (readable((u64)base + tva, tsz) && (k = fix_aspect_stubs(base + tva, tsz, (float)w / 1080.0f)) > 0) {
                p = put(buf, "azimuth 21:9: UI element aspect 16/9 -> UI aspect at "); p = putu(p, k, 10); p = put(p, " stub(s) after ");
                p = putu(p, GetTickCount64() - t0, 10); p = put(p, " ms\r\n"); *p = 0; logs(buf);
            }
            if (g->widen_box && readable((u64)base + tva, tsz) && (k = widen_frame_boxes(base + tva, tsz)) > 0) {
                p = put(buf, "azimuth 21:9: UI frame box widened at "); p = putu(p, k, 10); p = put(p, " site(s) after ");
                p = putu(p, GetTickCount64() - t0, 10); p = put(p, " ms\r\n"); *p = 0; logs(buf);
            }
        }
        for (i = 0; i < g->n; i++) {
            u32 *a = (u32 *)(base + g->site[i].rva);
            if (*a == g->site[i].orig) {
                DWORD old;
                if (VirtualProtect(a, 4, 0x04 /*PAGE_READWRITE*/, &old)) {
                    *a = v;
                    VirtualProtect(a, 4, old, &old);
                    p = put(buf, "azimuth 21:9: patched game+0x"); p = putu(p, g->site[i].rva, 16);
                    p = put(p, " after "); p = putu(p, GetTickCount64() - t0, 10); p = put(p, " ms\r\n"); *p = 0; logs(buf);
                    ++fixes;
                }
            }
        }
        if ((dumped == 0 && GetTickCount64() - tf > 15000) || (dumped == 1 && GetTickCount64() - tf > 30000) || (dumped == 2 && GetTickCount64() - tf > 50000)) {
            dumped++;
            if (g_az_ok) {
                int sw = GetSystemMetrics(0), sh = GetSystemMetrics(1);
                g_full = sw; g_bx0 = (sw - sh * 16 / 9) / 2; g_bx1 = g_bx0 + sh * 16 / 9; g_fixscissor = 0;
                (void)hook_contexts;
            }
        }
        Sleep(1);
        }
    }
    return 0;
}


/* ---- per-title switch: the UI patches only matter while Azimuth's UI generator (az+0x294790) runs for a title.
   We hook its entry, find out which game image is loaded and write either our values or the originals. ---- */
typedef struct { const char *id; u32 ts, soi; const WCHAR *key; } Title;
static const Title titles[] = {
    { "1a96545b", 0x565501ed, 0x3a18000, L"1a96545b" },   /* Forza Horizon 2 1.0.0.64 */
    { "5a9771a4", 0x55b62fde, 0x3a89000, L"5a9771a4" },   /* FH2 Presents Fast & Furious 1.0.0.6 */
    { "7b35d917", 0x53d8d1f2, 0x279d000, L"7b35d917" },   /* Forza Motorsport 5 1.0.0.20 */
};
static int g_w; static float g_clip;

static int detect_title(void)
{
    u64 a = 0x10000; MBI m;
    while (a < 0x7ffffffe0000ull && VirtualQuery((void *)a, &m, sizeof m)) {
        if (m.State == 0x1000 && m.BaseAddress == m.AllocationBase && !(m.Protect & 0x101) && m.Protect && m.RegionSize >= 0x400
            && (u8 *)m.BaseAddress != g_az && (u8 *)m.BaseAddress != (u8 *)g_self) {
            u8 *b = (u8 *)m.BaseAddress;
            if (b[0] == 'M' && b[1] == 'Z') {
                u32 pe = *(u32 *)(b + 0x3c);
                if (pe < 0x300 && *(u32 *)(b + pe) == 0x4550) {
                    u32 ts = *(u32 *)(b + pe + 8), soi = *(u32 *)(b + pe + 24 + 56); int i;
                    for (i = 0; i < (int)(sizeof titles / sizeof titles[0]); i++)
                        if (titles[i].ts == ts && titles[i].soi == soi) return i;
                }
            }
        }
        a = m.BaseAddress + m.RegionSize;
    }
    return -1;
}
static void write_sites(int on)
{
    int i;
    for (i = 0; i < (int)(sizeof az102 / sizeof az102[0]); i++) {
        u8 *a = g_az + az102[i].rva; DWORD old;
        if (!VirtualProtect(a, 16, 0x40, &old)) continue;
        if (!on) memcpy(a, az102[i].orig, az102[i].len);
        else if (az102[i].kind == 0) { u32 v = (u32)g_w; memcpy(a + 3, &v, 4); }
        else if (az102[i].kind == 2) { float nc = -g_clip; memcpy(a, &nc, 4); }
        else memcpy(a + 4, &g_clip, 4);
        VirtualProtect(a, 16, old, &old);
        FlushInstructionCache(GetCurrentProcess(), a, 16);
    }
}
/* Azimuth 1.0 paces every Present by the game's sync interval: FM5 presents its garage / pre-race / menus with
   interval 2 (30 fps on Xbox) -> frame_rate/2. full_rate: pace by interval 1 (mov ebx,[rsi+0fch] -> mov ebx,1). */
static int g_pace_state = -1;
static void pace_site(int full)
{
    static const u8 org[6] = { 0x8b, 0x9e, 0xfc, 0x00, 0x00, 0x00 }, rep[6] = { 0xbb, 0x01, 0x00, 0x00, 0x00, 0x90 };
    u8 *a; DWORD old; int i, isorg = 1, isrep = 1;
    if (!g_az_ok || !g_ver->pace || full == g_pace_state) return;
    a = g_az + g_ver->pace;
    for (i = 0; i < 6; i++) { if (a[i] != org[i]) isorg = 0; if (a[i] != rep[i]) isrep = 0; }
    if (!isorg && !isrep) { logs("azimuth 21:9: frame pacing site differs - left alone\r\n"); g_pace_state = full; return; }
    if ((full && isrep) || (!full && isorg)) { g_pace_state = full; return; }
    if (!VirtualProtect(a, 6, 0x40, &old)) return;
    memcpy(a, full ? rep : org, 6);
    VirtualProtect(a, 6, old, &old); FlushInstructionCache(GetCurrentProcess(), a, 6);
    g_pace_state = full;
    logs(full ? "azimuth 21:9: FM5 full frame rate in garage/menus ON (sync interval 2 -> 1)\r\n" : "azimuth 21:9: frame pacing original\r\n");
}
/* Azimuth's swap chain Present(this, SyncInterval edx, flags r8d): count the intervals the game asks for and, for FM5
   (g_fullrate), turn 2..4 into 1 - FM5 asks for 2 in garage / pre-race (30 fps on Xbox) and Azimuth paces that as frame_rate/2. */
static volatile long g_iv[8];
static int hook_present(void)
{
    static const u8 pro[14] = { 0x48,0x89,0x5c,0x24,0x10, 0x55, 0x56, 0x57, 0x41,0x54, 0x41,0x55, 0x41,0x56 };
    u8 *f, *s; DWORD old; int k = 0, i, jl;
    if (!g_ver->present) return 0;
    f = g_az + g_ver->present;
    for (i = 0; i < 14; i++) if (f[i] != pro[i]) return 0;
    s = VirtualAlloc(0, 0x1000, 0x3000, 0x40); if (!s) return 0;
    s[k++]=0x89; s[k++]=0xd0;                                   /* mov eax,edx */
    s[k++]=0x83; s[k++]=0xe0; s[k++]=0x07;                      /* and eax,7 */
    s[k++]=0x49; s[k++]=0xbb; { u64 v=(u64)g_iv; memcpy(s+k,&v,8); k+=8; }      /* mov r11,g_iv */
    s[k++]=0xf0; s[k++]=0x41; s[k++]=0xff; s[k++]=0x04; s[k++]=0x83;            /* lock inc dword [r11+rax*4] */
    s[k++]=0x49; s[k++]=0xbb; { u64 v=(u64)&g_fullrate; memcpy(s+k,&v,8); k+=8; }   /* mov r11,&g_fullrate */
    s[k++]=0x41; s[k++]=0x80; s[k++]=0x3b; s[k++]=0x00;         /* cmp byte [r11],0 */
    s[k++]=0x74; jl=k; s[k++]=0;                                 /* je L */
    s[k++]=0x83; s[k++]=0xfa; s[k++]=0x01;                      /* cmp edx,1 */
    s[k++]=0x76; s[k++]=0;  { int a=k-1;
    s[k++]=0x83; s[k++]=0xfa; s[k++]=0x04;                      /* cmp edx,4 */
    s[k++]=0x77; s[k++]=0;  { int b=k-1;
    s[k++]=0xba; s[k++]=1; s[k++]=0; s[k++]=0; s[k++]=0;        /* mov edx,1 */
    s[jl]=(u8)(k-jl-1); s[a]=(u8)(k-a-1); s[b]=(u8)(k-b-1); } }
    memcpy(s+k,pro,14); k+=14;
    s[k++]=0xff; s[k++]=0x25; s[k++]=0; s[k++]=0; s[k++]=0; s[k++]=0; { u64 v=(u64)(f+14); memcpy(s+k,&v,8); k+=8; }
    if (!VirtualProtect(f, 14, 0x40, &old)) return 0;
    f[0]=0xff; f[1]=0x25; f[2]=f[3]=f[4]=f[5]=0; { u64 v=(u64)s; memcpy(f+6,&v,8); }
    VirtualProtect(f, 14, old, &old); FlushInstructionCache(GetCurrentProcess(), f, 14);
    return 1;
}
static DWORD WINAPI iv_logger(void *arg)
{
    char buf[200], *p; long last[8] = {0}; int t = 0, i, any; (void)arg;
    for (;;) {
        Sleep(2000); t += 2;
        p = put(buf, "present: t="); p = putu(p, t, 10); p = put(p, "s sync interval/s"); any = 0;
        for (i = 0; i < 8; i++) { long c = g_iv[i], d = c - last[i]; last[i] = c;
            if (d > 0) { p = put(p, " ["); p = putu(p, i, 10); p = put(p, "]="); p = putu(p, (u64)(d / 2), 10); any = 1; } }
        p = put(p, "\r\n"); *p = 0;
        if (any && t <= 1200) logs(buf);
    }
}
static void title_enabled_check(void)
{
    WCHAR ini[600]; int t = detect_title(), on = 0, src = 0; char buf[200], *p;
    if (t < 0 && side_path(ini, L"data\\azimuth.ini")) {          /* image not mapped yet: title chosen in the launcher */
        WCHAR g[32]; int i, j;
        if (GetPrivateProfileStringW(L"launcher", L"game", L"", g, 32, ini))
            for (i = 0; i < (int)(sizeof titles / sizeof titles[0]); i++) {
                for (j = 0; titles[i].key[j] && (g[j] | 0x20) == titles[i].key[j]; j++) ;
                if (!titles[i].key[j] && !g[j]) { t = i; src = 1; }
            }
    }
    if (t >= 0 && side_path(ini, L"azimuth_21x9.ini")) on = GetPrivateProfileIntW(L"titles", titles[t].key, 1, ini) != 0;
    if (g_w <= 1920) on = 0;
    write_sites(on);
    { int full = 0; if (t == 2) { full = 1; if (side_path(ini, L"azimuth_21x9.ini")) full = GetPrivateProfileIntW(L"fm5", L"full_rate", 1, ini) != 0; } g_fullrate = (u8)full;
      logs(full ? "azimuth 21:9: FM5 full frame rate ON (Present sync interval 2..4 -> 1)\r\n" : "azimuth 21:9: frame pacing original\r\n"); }
    g_title_on = on; g_title = t;
    p = put(buf, "azimuth 21:9: UI generator for title "); p = put(p, t >= 0 ? titles[t].id : "unknown");
    p = put(p, src ? " (from launcher)" : ""); p = put(p, on ? " -> 21:9 ON\r\n" : " -> original (16:9 UI)\r\n"); *p = 0; logs(buf);
}
static void *g_stub;
static int hook_generator(void)
{
    static const u8 pro[14] = { 0x48,0x8b,0xc4, 0x48,0x89,0x58,0x20, 0x55, 0x56, 0x57, 0x41,0x54, 0x41,0x55 };
    u8 *f = g_az + g_ver->gen, *s; DWORD old; int k = 0, i;
    for (i = 0; i < 14; i++) if (f[i] != pro[i]) return 0;
    s = VirtualAlloc(0, 0x1000, 0x3000, 0x40);
    if (!s) return 0;
    /* push rcx,rdx,r8,r9 ; sub rsp,28h ; mov rax,imm ; call rax ; add rsp,28h ; pop r9,r8,rdx,rcx */
    s[k++] = 0x51; s[k++] = 0x52; s[k++] = 0x41; s[k++] = 0x50; s[k++] = 0x41; s[k++] = 0x51;
    s[k++] = 0x48; s[k++] = 0x83; s[k++] = 0xec; s[k++] = 0x28;
    s[k++] = 0x48; s[k++] = 0xb8; { u64 v = (u64)title_enabled_check; memcpy(s + k, &v, 8); k += 8; }
    s[k++] = 0xff; s[k++] = 0xd0;
    s[k++] = 0x48; s[k++] = 0x83; s[k++] = 0xc4; s[k++] = 0x28;
    s[k++] = 0x41; s[k++] = 0x59; s[k++] = 0x41; s[k++] = 0x58; s[k++] = 0x5a; s[k++] = 0x59;
    memcpy(s + k, pro, 14); k += 14;                                       /* original prologue */
    s[k++] = 0xff; s[k++] = 0x25; s[k++] = 0; s[k++] = 0; s[k++] = 0; s[k++] = 0;   /* jmp [rip+0] */
    { u64 v = (u64)(f + 14); memcpy(s + k, &v, 8); k += 8; }
    g_stub = s;
    if (!VirtualProtect(f, 14, 0x40, &old)) return 0;
    f[0] = 0xff; f[1] = 0x25; f[2] = f[3] = f[4] = f[5] = 0;
    { u64 v = (u64)s; memcpy(f + 6, &v, 8); }
    VirtualProtect(f, 14, old, &old);
    FlushInstructionCache(GetCurrentProcess(), f, 14);
    return 1;
}

static DWORD WINAPI patch_thread(void *arg)
{
    u8 *base = GetModuleHandleW(0);
    char buf[256], *p;
    int i, j, k, ok = 1, w = ui_width();
    float clip = (float)w / 1080.0f * 1.026f;           /* same rule as the FH2 Ultrawide installer */
    (void)arg;
    if (w * 100 < 239 * 1080) { u32 k = 0x401ccccd; memcpy(&clip, &k, 4); }   /* below 2.39:1 -> exactly 2.45, as tested */
    if (w == 1920) clip = 16.0f / 9.0f;
    p = put(buf, "azimuth 21:9: screen "); p = putu(p, GetSystemMetrics(0), 10); p = put(p, "x");
    p = putu(p, GetSystemMetrics(1), 10); p = put(p, " -> UI width "); p = putu(p, w, 10); p = put(p, "\r\n"); *p = 0;
    logs(buf);
    ok = 0;
    for (k = 0; k < (int)(sizeof azvers / sizeof azvers[0]) && !ok; k++) {
        int good = 1;
        for (i = 0; i < (int)(sizeof az102 / sizeof az102[0]); i++)
            for (j = 0; j < az102[i].len; j++)
                if (base[azvers[k].site[i] + j] != az102[i].orig[j]) good = 0;
        if (good) {
            ok = 1; g_ver = &azvers[k];
            for (i = 0; i < (int)(sizeof az102 / sizeof az102[0]); i++) az102[i].rva = azvers[k].site[i];
            p = put(buf, "azimuth 21:9: Azimuth "); p = put(p, azvers[k].name); p = put(p, " detected\r\n"); *p = 0; logs(buf);
        }
    }
    g_az = base; g_az_ok = ok;
    if (w > 1920) { HANDLE t = CreateThread(0, 0, game_thread, (void *)(u64)w, 0, 0); if (t) CloseHandle(t); }
    if (!ok) { logs("azimuth 21:9: unknown Azimuth version (bytes differ) - nothing patched\r\n"); return 0; }
    g_w = w; g_clip = clip;
    if (hook_present()) logs("azimuth 21:9: Present hooked\r\n");
    if (hook_generator()) logs("azimuth 21:9: UI generator hooked - titles are switched when they start\r\n");
    else { logs("azimuth 21:9: generator hook failed - patching for all titles\r\n"); write_sites(1); g_title_on = 1; g_title = 2; }
    return 0;
}

BOOL WINAPI DllMain(void *inst, DWORD reason, void *res)
{
    (void)res;
    if (reason == 1) {
        HANDLE t;
        g_self = inst;
        open_log();
        t = CreateThread(0, 0, patch_thread, 0, 0, 0);
        if (t) CloseHandle(t);
    }
    return 1;
}

/* ---- dinput8 forwarding ---- */
typedef HRESULT (WINAPI *DI8C)(void *, DWORD, const void *, void **, void *);
static void *real_dinput8(void)
{
    static void *m;
    WCHAR path[300]; u32 n;
    const WCHAR *name = L"\\dinput8.dll";
    if (m) return m;
    n = GetSystemDirectoryW(path, 260);
    if (!n) return 0;
    while (*name) path[n++] = *name++;
    path[n] = 0;
    return m = LoadLibraryW(path);
}
__declspec(dllexport) HRESULT WINAPI DirectInput8Create(void *inst, DWORD ver, const void *iid, void **out, void *outer)
{
    void *m = real_dinput8();
    DI8C f = m ? (DI8C)GetProcAddress(m, "DirectInput8Create") : 0;
    if (!f) return (HRESULT)0x80004005;
    return f(inst, ver, iid, out, outer);
}
