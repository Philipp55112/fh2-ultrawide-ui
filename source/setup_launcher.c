/* Forza 21:9 Setup - self-extracting launcher.
   The payload (installer script, patch data, dinput8.dll, originals) is appended to this exe:
     records [u32 name_len][name (utf-8, '/' separated)][u64 size][data] ..., a record with name_len 0 ends it,
     followed by u64 payload_offset and the 8-byte magic "F21X9PAY".
   The files are extracted to %TEMP%, the installer window (PowerShell) is started elevated, then the files are removed. */
typedef unsigned char u8; typedef unsigned short u16; typedef unsigned int u32; typedef unsigned long long u64;
typedef void *HANDLE; typedef int BOOL; typedef unsigned long DWORD; typedef unsigned short WCHAR;
#define WINAPI __stdcall
__declspec(dllimport) DWORD WINAPI GetModuleFileNameW(void *, WCHAR *, DWORD);
__declspec(dllimport) HANDLE WINAPI CreateFileW(const WCHAR *, DWORD, DWORD, void *, DWORD, DWORD, HANDLE);
__declspec(dllimport) BOOL WINAPI ReadFile(HANDLE, void *, DWORD, DWORD *, void *);
__declspec(dllimport) BOOL WINAPI WriteFile(HANDLE, const void *, DWORD, DWORD *, void *);
__declspec(dllimport) BOOL WINAPI CloseHandle(HANDLE);
__declspec(dllimport) BOOL WINAPI SetFilePointerEx(HANDLE, long long, long long *, DWORD);
__declspec(dllimport) BOOL WINAPI GetFileSizeEx(HANDLE, long long *);
__declspec(dllimport) DWORD WINAPI GetTempPathW(DWORD, WCHAR *);
__declspec(dllimport) BOOL WINAPI CreateDirectoryW(const WCHAR *, void *);
__declspec(dllimport) BOOL WINAPI DeleteFileW(const WCHAR *);
__declspec(dllimport) BOOL WINAPI RemoveDirectoryW(const WCHAR *);
__declspec(dllimport) DWORD WINAPI GetTickCount(void);
__declspec(dllimport) DWORD WINAPI WaitForSingleObject(HANDLE, DWORD);
__declspec(dllimport) void WINAPI ExitProcess(u32);
__declspec(dllimport) void *WINAPI VirtualAlloc(void *, u64, DWORD, DWORD);
__declspec(dllimport) int WINAPI MultiByteToWideChar(u32, DWORD, const char *, int, WCHAR *, int);
__declspec(dllimport) int WINAPI MessageBoxW(void *, const WCHAR *, const WCHAR *, u32);
typedef struct {
    DWORD cbSize; u32 fMask; void *hwnd; const WCHAR *lpVerb, *lpFile, *lpParameters, *lpDirectory; int nShow;
    void *hInstApp, *lpIDList; const WCHAR *lpClass; void *hkeyClass; DWORD dwHotKey; void *hIcon; HANDLE hProcess;
} SEI;
__declspec(dllimport) BOOL WINAPI ShellExecuteExW(SEI *);

void *memcpy(void *d, const void *s, u64 n) { u8 *a = d; const u8 *b = s; while (n--) *a++ = *b++; return d; }
void *memset(void *d, int c, u64 n) { u8 *a = d; while (n--) *a++ = (u8)c; return d; }

static int same8(const char *a, const char *b) { int i; for (i = 0; i < 8; i++) if (a[i] != b[i]) return 0; return 1; }
static const WCHAR *TITLE = L"Forza 21:9 Ultrawide Patch";
static WCHAR g_files[64][600]; static int g_nfiles;
static WCHAR g_dirs[16][600]; static int g_ndirs;

static int wlen(const WCHAR *s) { int n = 0; while (s[n]) n++; return n; }
static WCHAR *wcat(WCHAR *d, const WCHAR *s) { int n = wlen(d); while (*s) d[n++] = *s++; d[n] = 0; return d; }
static void fail(const WCHAR *m) { MessageBoxW(0, m, TITLE, 0x10); ExitProcess(1); }
static void cleanup(void)
{
    int i;
    for (i = g_nfiles - 1; i >= 0; i--) DeleteFileW(g_files[i]);
    for (i = g_ndirs - 1; i >= 0; i--) RemoveDirectoryW(g_dirs[i]);
}
static int rd(HANDLE f, void *p, u64 n)
{
    u8 *b = p;
    while (n) { DWORD got = 0, want = n > 0x1000000 ? 0x1000000 : (DWORD)n; if (!ReadFile(f, b, want, &got, 0) || !got) return 0; b += got; n -= got; }
    return 1;
}

void __stdcall start(void)
{
    static WCHAR self[600], dir[600], path[700], params[1200];
    HANDLE f; long long size = 0; u64 tail[2], off; char magic[9] = "F21X9PAY";
    u32 tick = GetTickCount(), i;
    if (!GetModuleFileNameW(0, self, 580)) fail(L"Cannot find the setup file.");
    f = CreateFileW(self, 0x80000000, 1, 0, 3, 0x80, 0);
    if (f == (HANDLE)-1 || !GetFileSizeEx(f, &size) || size < 32) fail(L"Cannot read the setup file.");
    SetFilePointerEx(f, size - 16, 0, 0);
    if (!rd(f, tail, 16) || !same8((const char *)&tail[1], magic)) fail(L"The setup file is damaged (no payload).");
    off = tail[0];
    SetFilePointerEx(f, (long long)off, 0, 0);
    /* %TEMP%\Forza21x9_Setup_<tick> */
    if (!GetTempPathW(520, dir)) fail(L"No temp folder.");
    wcat(dir, L"Forza21x9_Setup_");
    { WCHAR t[12]; int n = 0; u32 v = tick; do { t[n++] = (WCHAR)('0' + v % 10); v /= 10; } while (v); { int k = wlen(dir); while (n) dir[k++] = t[--n]; dir[k] = 0; } }
    CreateDirectoryW(dir, 0); memcpy(g_dirs[g_ndirs++], dir, (wlen(dir) + 1) * 2);
    for (;;) {
        u32 nl; static char name[400]; static WCHAR wn[400]; u64 sz; u8 *buf; HANDLE o; DWORD w;
        if (!rd(f, &nl, 4)) fail(L"The setup file is damaged.");
        if (!nl) break;
        if (nl >= sizeof name || !rd(f, name, nl) || !rd(f, &sz, 8)) fail(L"The setup file is damaged.");
        name[nl] = 0;
        i = (u32)MultiByteToWideChar(65001, 0, name, -1, wn, 400);
        if (!i) fail(L"Bad file name in the setup.");
        path[0] = 0; wcat(path, dir);
        /* create sub folders */
        for (i = 0; wn[i]; i++) if (wn[i] == '/') {
            static WCHAR sub[700]; int k;
            sub[0] = 0; wcat(sub, dir); k = wlen(sub); sub[k++] = '\\';
            { u32 j; for (j = 0; j < i; j++) sub[k++] = wn[j] == '/' ? '\\' : wn[j]; } sub[k] = 0;
            if (CreateDirectoryW(sub, 0) && g_ndirs < 16) memcpy(g_dirs[g_ndirs++], sub, (wlen(sub) + 1) * 2);
        }
        { int k = wlen(path); path[k++] = '\\'; for (i = 0; wn[i]; i++) path[k++] = wn[i] == '/' ? '\\' : wn[i]; path[k] = 0; }
        buf = VirtualAlloc(0, sz ? sz : 1, 0x3000, 0x04);
        if (!buf || !rd(f, buf, sz)) fail(L"The setup file is damaged.");
        o = CreateFileW(path, 0x40000000, 0, 0, 2, 0x80, 0);
        if (o == (HANDLE)-1) { cleanup(); fail(L"Cannot write to the temp folder."); }
        { u64 left = sz; u8 *p = buf; while (left) { DWORD n = left > 0x1000000 ? 0x1000000 : (DWORD)left; if (!WriteFile(o, p, n, &w, 0)) break; p += w; left -= w; } }
        CloseHandle(o);
        if (g_nfiles < 64) memcpy(g_files[g_nfiles++], path, (wlen(path) + 1) * 2);
    }
    CloseHandle(f);
    /* powershell -File "<dir>\Forza21x9.ps1" elevated (Azimuth usually lives under Program Files) */
    params[0] = 0;
    wcat(params, L"-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -STA -File \"");
    wcat(params, dir); wcat(params, L"\\Forza21x9.ps1\"");
    {
        SEI s; memset(&s, 0, sizeof s);
        s.cbSize = sizeof s; s.fMask = 0x40 /*SEE_MASK_NOCLOSEPROCESS*/; s.lpVerb = L"runas"; s.lpFile = L"powershell.exe";
        s.lpParameters = params; s.lpDirectory = dir; s.nShow = 0;
        if (!ShellExecuteExW(&s) || !s.hProcess) { cleanup(); fail(L"The setup needs administrator rights (Azimuth is usually under Program Files)."); }
        WaitForSingleObject(s.hProcess, 0xffffffff);
        CloseHandle(s.hProcess);
    }
    cleanup();
    ExitProcess(0);
}
