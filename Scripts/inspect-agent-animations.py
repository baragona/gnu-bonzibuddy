"""Read an ACS v2 animation directory as data; never loads the Agent runtime.

Usage: python3 Scripts/inspect-agent-animations.py /path/to/Bonzi.acs
Format reference: https://uploads.s.zeid.me/ms-agent-format-spec.html
"""
import hashlib
import json
import struct
import sys
from pathlib import Path

blob = Path(sys.argv[1]).read_bytes()

def unpack(fmt, pos):
    size = struct.calcsize(fmt)
    if pos < 0 or pos + size > len(blob):
        raise ValueError('Field outside file')
    values = struct.unpack_from(fmt, blob, pos)
    return values, pos + size

def string(pos):
    (count,), pos = unpack('<I', pos)
    end = pos + count * 2
    if end + (2 if count else 0) > len(blob):
        raise ValueError('String outside file')
    value = blob[pos:end].decode('utf-16le')
    if count and blob[end:end + 2] != b'\0\0':
        raise ValueError('Missing string terminator')
    return value, end + (2 if count else 0)

(signature,), _ = unpack('<I', 0)
if signature != 0xABCDABC3:
    raise ValueError('Expected an ACS v2 file')
(offset, length), _ = unpack('<II', 12)
if offset + length > len(blob):
    raise ValueError('Animation directory outside file')
(count,), pos = unpack('<I', offset)
entries = []
for _ in range(count):
    name, pos = string(pos)
    (start, size), pos = unpack('<II', pos)
    if start + size > len(blob):
        raise ValueError('Animation outside file')
    internal, cursor = string(start)
    (transition,), cursor = unpack('<B', cursor)
    returning, cursor = string(cursor)
    (frames,), cursor = unpack('<H', cursor)
    if cursor > start + size or transition > 2:
        raise ValueError('Invalid animation header')
    entries.append(dict(name=name, internalName=internal, frameCount=frames,
                        transition=transition, returnAnimation=returning))
if pos != offset + length:
    raise ValueError('Animation directory length mismatch')
print(json.dumps(dict(sha256=hashlib.sha256(blob).hexdigest(), bytes=len(blob),
                     animationCount=count, singleFrameEntries=sum(e['frameCount'] == 1 for e in entries),
                     animations=entries), indent=2))
