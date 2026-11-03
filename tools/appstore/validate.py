import glob, os, re, sys
from PIL import Image
A=sys.argv[1]; errs=[]; todos=[]
SIZES={'iphone-6.9':{(1320,2868)},'iphone-6.3':{(1206,2622)},'iphone-6.1':{(1179,2556)},'ipad-13':{(2752,2064),(2064,2752)},'ipad-12.9':{(2732,2048),(2048,2732)}}
MK={'header_5244x2950.png':(5244,2950),'header_3840x1646.png':(3840,1646),'search_5244x2950.png':(5244,2950),'search_3840x2560.png':(3840,2560),'search_1920x1280.png':(1920,1280)}
for f in glob.glob(A+'/**/*.png',recursive=True):
    im=Image.open(f)
    if im.mode!='RGB': errs.append(f'{f}: mode {im.mode}')
    parts=f.split('/'); d=parts[-2]; n=parts[-1]
    if d in SIZES and im.size not in SIZES[d]: errs.append(f'{f}: {im.size}')
    if n in MK and im.size!=MK[n]: errs.append(f'{f}: {im.size}')
for lang in ['nl-NL','en-US']:
    for d in SIZES:
        c=len(glob.glob(f'{A}/screenshots/{lang}/{d}/*.png'))
        if not 1<=c<=10: errs.append(f'{lang}/{d}: {c} screenshots')
    for n in MK:
        if not os.path.exists(f'{A}/marketing/{lang}/{n}'): errs.append(f'missing {lang}/{n}')
nl=sorted(os.listdir(f'{A}/screenshots/nl-NL')); en=sorted(os.listdir(f'{A}/screenshots/en-US'))
if nl!=en: errs.append('device folders differ')
LIM={'name':30,'subtitle':30,'promotional_text':170,'description':4000,'release_notes':4000}
for lang in ['nl-NL','en-US']:
    M=f'{A}/metadata/{lang}'
    for k,l in LIM.items():
        t=open(f'{M}/{k}.txt').read().strip()
        print(f'{lang} {k}: {len(t)}/{l}')
        if len(t)>l: errs.append(f'{lang} {k} too long')
    kw=open(f'{M}/keywords.txt').read().strip(); b=len(kw.encode())
    print(f'{lang} keywords: {b}/100 bytes')
    if b>100: errs.append(f'{lang} keywords {b} bytes')
    if ', ' in kw: errs.append(f'{lang} keywords spaces after comma')
    title=(open(f'{M}/name.txt').read()+' '+open(f'{M}/subtitle.txt').read()).lower()
    tw=set(re.findall(r'\w+',title))
    for k in kw.split(','):
        for word in re.findall(r'\w+',k.lower()):
            if word in tw: errs.append(f'{lang} keyword "{k}" repeats "{word}" from name/subtitle')
    for u in ['support_url','marketing_url','privacy_url']:
        t=open(f'{M}/{u}.txt').read().strip()
        if 'TODO' in t: todos.append(f'{lang} {u}: {t}')
        elif not re.match(r'^https://[\w.-]+\.\w+(/\S*)?$',t): errs.append(f'{lang} {u} invalid: {t}')
for f in glob.glob(A+'/**/*.md',recursive=True)+glob.glob(A+'/**/*.txt',recursive=True):
    for i,line in enumerate(open(f)):
        if 'TODO' in line and 'url' not in f: todos.append(f'{os.path.relpath(f,A)}:{i+1}: {line.strip()[:90]}')
print('\nERRORS:',*errs or ['none'],sep='\n  ')
print('TODO:',*todos,sep='\n  ')
