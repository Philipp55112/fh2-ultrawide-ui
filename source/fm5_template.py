"""Turn the fixed-2580 FM5 ops into width-independent templates.
placeholders: @W@ UI width, @S@ (W-1920)/2, @K@ W/1920, @E:a:op:dec[:f]@ value from original number a:
  op S: a+S   op K: a*W/1920   op F: a+f*S      @TICKS@ extra header tick marks from 2220 to W"""
import json,re,zipfile,difflib,sys
sp=re.compile(r'(-?\d+(?:\.\d+)?)')
W0,S0,K0=2580,330,2580/1920
def dec(x): return len(x.split('.')[1]) if '.' in x else 0
def fmt(v,d): return ('%.*f'%(d,v)) if d else str(int(round(v)))
def render(t,W):
    S=(W-1920)/2; K=W/1920
    def ev(m):
        a=float(m.group(1)); op=m.group(2); d=int(m.group(3)); f=float(m.group(4) or 0)
        v={'S':a+S,'K':a*K,'F':a+f*S}[op]; return fmt(v,d)
    t=re.sub(r'@E:(-?[\d.]+):([SKF]):(\d+)(?::([\d.]+))?@',ev,t)
    t=t.replace('@TICKS@',''.join(' M%d,0 V5'%x for x in range(2220,W+1,20)))
    t=t.replace('@LTICKS@',''.join(' M%d,1.5 V9'%x for x in range(2224,W+204,101)))
    kk=('%.5f'%K).rstrip('0')
    return t.replace('@W@',str(W)).replace('@S@',fmt(S,0)).replace('@K@',kk)
def tmpl(old,new):
    if 'M2220,0' in new:
        i=new.index(' M2220,0 V5'); j=new.index(' M2580,0 V5')+len(' M2580,0 V5')
        new=new[:i]+'\x00T\x00'+new[j:]
    to=sp.split(old); tn=sp.split(new); out=[]
    for t,i1,i2,j1,j2 in difflib.SequenceMatcher(None,to,tn,autojunk=False).get_opcodes():
        seg=tn[j1:j2]
        if t=='equal': out+=seg; continue
        olds=[x for x in to[i1:i2] if sp.fullmatch(x)]
        for x in seg:
            if not sp.fullmatch(x): out.append(x); continue
            v=float(x); d=dec(x); r=None
            if x=='2580': r='@W@'
            elif x=='1.34375': r='@K@'
            elif x=='330': r='@S@'
            else:
                for o in olds:
                    of=float(o)
                    if abs(v-(of+S0))<1e-9: r='@E:%s:S:%d@'%(o,d); break
                for o in ([] if r else olds):
                    of=float(o)
                    if of and abs(v-of*K0)<0.51 and fmt(of*K0,d)==x: r='@E:%s:K:%d@'%(o,d); break
                if not r and x in('1426','1273'):
                    o={'1426':'1014','1273':'862'}[x]; r='@E:%s:F:0:%.6f@'%(o,(v-float(o))/S0)
            out.append(r if r else x)
    return ''.join(out).replace('\x00T\x00','@TICKS@')
if __name__=='__main__':
    ops=json.load(open(sys.argv[1])); A=zipfile.ZipFile(sys.argv[2]); ref=zipfile.ZipFile(sys.argv[3])
    t=ops['titles']['7b35d917']; bad=0
    for n,f in t['files'].items():
        a=A.read(n)
        for op in f['ops']:
            old=a[op[0]:op[0]+op[1]].decode('utf-8'); op[3]=tmpl(old,op[3])
        # verify W0 render == reference
        r=bytearray(a)
        for off,ln,h,new in sorted(f['ops'],key=lambda o:-o[0]): r[off:off+ln]=render(new,W0).encode()
        if bytes(r)!=ref.read(n): bad+=1; print('MISMATCH',n)
    t['uiwidth']=0
    json.dump(ops,open(sys.argv[4],'w'),separators=(',',':'))
    print('files',len(t['files']),'mismatch',bad)
