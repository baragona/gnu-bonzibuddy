"""Extract ACS v2 reference frames/timing without Windows or third-party packages.

Original data stays outside app resources. Format observation by Remy Lebeau:
https://uploads.s.zeid.me/ms-agent-format-spec.html
Usage: python3 Scripts/extract-agent-reference.py Bonzi.acs Validation/Original
"""
import argparse
import hashlib
import html
import json
import struct
import zlib
from pathlib import Path

class Reader:
    def __init__(self, data, pos=0):
        self.data, self.pos = data, pos
    def take(self, size):
        if size < 0 or self.pos + size > len(self.data):
            raise ValueError('Truncated ACS data')
        data = self.data[self.pos:self.pos+size]
        self.pos += size
        return data
    def read(self, fmt):
        return struct.unpack('<'+fmt, self.take(struct.calcsize('<'+fmt)))
    def number(self, fmt):
        return self.read(fmt)[0]
    def string(self):
        count = self.number('I')
        value = self.take(count*2).decode('utf-16le')
        if count and self.take(2) != b'\0\0':
            raise ValueError('Unterminated ACS string')
        return value
    def block(self):
        return self.take(self.number('I'))

def decompress(data, expected):
    if not data or data[0] != 0:
        raise ValueError('Invalid compressed stream')
    bit, out = 8, bytearray()
    def read(count):
        nonlocal bit
        if bit+count > len(data)*8:
            raise ValueError('Truncated bit stream')
        value = sum(((data[(bit+i)//8] >> ((bit+i)%8)) & 1) << i for i in range(count))
        bit += count
        return value
    while True:
        if read(1) == 0:
            out.append(read(8))
        else:
            kind = 0
            while kind < 3 and read(1):
                kind += 1
            offset = read([6,9,12,20][kind])
            if kind == 3 and offset == 0xfffff:
                break
            offset += [1,65,577,4673][kind]
            power = 0
            while read(1):
                power += 1
                if power > 11:
                    raise ValueError('Invalid copy length')
            count = 2 + (kind == 3) + (1 << power)-1 + read(power)
            if offset > len(out) or len(out)+count > expected:
                raise ValueError('Invalid back reference')
            for _ in range(count):
                out.append(out[-offset])
        if len(out) > expected:
            raise ValueError('Decoded buffer overflow')
    if len(out) != expected:
        raise ValueError(f'Decoded {len(out)} bytes, expected {expected}')
    return out

def png(width, height, rgba):
    def chunk(kind, data):
        return struct.pack('>I',len(data))+kind+data+struct.pack('>I',zlib.crc32(kind+data))
    scan = b''.join(b'\0'+rgba[y*width*4:(y+1)*width*4] for y in range(height))
    return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',width,height,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(scan))+chunk(b'IEND',b'')

def extract(path, output):
    data = path.read_bytes()
    r = Reader(data)
    if r.number('I') != 0xabcdabc3:
        raise ValueError('Expected ACS v2')
    locators = [r.read('II') for _ in range(4)]
    c = Reader(data,locators[0][0])
    c.take(28)
    width,height,transparent,flags = c.read('HHBI')
    c.take(4)
    if flags & 0x20:
        c.take(38)
        if c.number('B'):
            c.take(2);c.string();c.take(4);c.string()
    if flags & 0x200:
        c.take(14);c.string();c.take(10)
    palette = [c.take(4) for _ in range(c.number('I'))]
    if len(palette) != 256:
        raise ValueError('Expected 256-color palette')
    # The stored table is Windows BGRA; transparent palette index comes from the header.
    colors = [bytes([p[2],p[1],p[0],0 if i==transparent else 255]) for i,p in enumerate(palette)]
    r = Reader(data,locators[2][0])
    image_locations = [r.read('III')[:2] for _ in range(r.number('I'))]
    cache = {}
    def image(index):
        if index not in cache:
            start,size = image_locations[index]
            im = Reader(data[start:start+size])
            _,w,h,compressed = im.read('BHHB')
            pixels = im.block();stride=(w+3)&~3
            if compressed:
                pixels = decompress(pixels,stride*h)
            if len(pixels) != stride*h:
                raise ValueError('Image size mismatch')
            rgba=b''.join(colors[pixels[(h-1-y)*stride+x]] for y in range(h) for x in range(w))
            cache[index] = w,h,rgba
        return cache[index]
    r = Reader(data,locators[1][0])
    directory = [(r.string(),r.read('II')) for _ in range(r.number('I'))]
    animations=[]
    output.mkdir(parents=True,exist_ok=True)
    for name,(start,size) in directory:
        a=Reader(data[start:start+size])
        internal=a.string();transition=a.number('B');returning=a.string()
        frames=[]
        for _ in range(a.number('H')):
            images=[a.read('Ihh') for _ in range(a.number('H'))]
            sound,duration,exit_frame=a.read('HHh')
            branches=[a.read('HH') for _ in range(a.number('B'))]
            overlays=[]
            for _ in range(a.number('B')):
                kind,replace,index,unknown,region,x,y,w,h=a.read('BBHBBhhHH')
                if region:a.block()
                overlays.append(dict(kind=kind,replace=replace,image=index,x=x,y=y))
            frames.append(dict(images=images,durationMS=duration*10,sound=sound,exitFrame=exit_frame,branches=branches,overlays=overlays))
        if a.pos != size:
            raise ValueError(f'{name}: frame data length mismatch {a.pos}/{size}')
        folder=output/name;folder.mkdir(exist_ok=True)
        # A horizontal atlas retains every frame in storage order. Branch metadata is separate.
        sheet_width=width*len(frames);sheet=bytearray(sheet_width*height*4)
        for i,frame in enumerate(frames):
            for index,x,y in reversed(frame['images']):
                w,h,rgba=image(index)
                for iy in range(h):
                    if not 0<=y+iy<height:continue
                    for ix in range(w):
                        if not 0<=x+ix<width:continue
                        src=(iy*w+ix)*4
                        if rgba[src+3]:
                            dest=((y+iy)*sheet_width+i*width+x+ix)*4
                            sheet[dest:dest+4]=rgba[src:src+4]
        (folder/'frames.png').write_bytes(png(sheet_width,height,sheet))
        animations.append(dict(name=name,internalName=internal,transition=transition,returnAnimation=returning,frames=frames))
        print(name,len(frames),flush=True)
    report=dict(sha256=hashlib.sha256(data).hexdigest(),width=width,height=height,imageCount=len(image_locations),decodedImages=len(cache),animations=animations)
    (output/'animations.json').write_text(json.dumps(report,indent=2)+'\n')
    cards=''.join('<h2>'+html.escape(a['name'])+'</h2><div class="strip"><img src="'+html.escape(a['name'],quote=True)+'/frames.png"></div>' for a in animations)
    (output/'index.html').write_text('<!doctype html><meta charset="utf-8"><title>Original Bonzi frames</title><style>body{background:#bbb;font:16px system-ui;margin:24px}.strip{overflow:auto;background:#999}img{height:160px}h2{font-size:18px}</style><h1>Original Bonzi frame atlas</h1><p>All frames in storage order. Timing, branches, exits and mouth overlays are retained in animations.json; this is not branch-aware playback.</p>'+cards)
    return report

if __name__ == '__main__':
    args=argparse.ArgumentParser();args.add_argument('acs',type=Path);args.add_argument('output',type=Path)
    options=args.parse_args();extract(options.acs,options.output)
