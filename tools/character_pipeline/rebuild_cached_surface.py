"""Close sparse surface voxels before marching cubes; keep native TRELLIS coordinates."""
import argparse, struct
from pathlib import Path
import numpy as np
from scipy import ndimage
from skimage.measure import marching_cubes
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('source', type=Path, help='TRELLIS pbr_voxels.bin cache')
parser.add_argument('destination', type=Path, help='New .meshbin file; must not exist')
args = parser.parse_args()
source, destination = args.source, args.destination
if destination.exists():
    parser.error('Destination already exists; preserve previous candidates')
with source.open('rb') as stream:
    magic,count,channels,resolution=struct.unpack('<8sqii',stream.read(24))
    if magic != b'TRLPBR1\0' or resolution != 1024 or count <= 0 or channels != 6:
        raise ValueError('Expected a 1024-resolution, 6-channel TRELLIS PBR cache')
    raw = np.fromfile(stream,dtype='<i4',count=count*4).reshape(-1,4)
    if len(raw) != count or np.any(raw[:,0] != 0) or np.any(raw[:,1:] < 0) or np.any(raw[:,1:] >= resolution):
        raise ValueError('Invalid or unsupported voxel coordinates')
    coords = raw[:,1:]//2
scale=resolution//2
minimum=coords.min(axis=0)-4
coords=coords-minimum
shape=coords.max(axis=0)+5
volume=np.zeros(shape,dtype=bool)
volume[tuple(coords.T)]=True
print('Grid',shape.tolist(),'occupied',int(volume.sum()),flush=True)
volume=ndimage.binary_closing(volume,iterations=2)
volume=ndimage.binary_fill_holes(volume)
print('Closed occupied',int(volume.sum()),flush=True)
vertices,faces,_,_=marching_cubes(volume.astype(np.float32),level=0.5,allow_degenerate=False)
vertices=((vertices+minimum+0.5)/scale-0.5).astype('<f4')
faces=faces.astype('<i4')
if not np.isfinite(vertices).all():
    raise ValueError('Rebuilt surface contains non-finite vertices')
with destination.open('xb') as stream:
    stream.write(struct.pack('<8sQQII',b'TRLMESH1',len(vertices),len(faces),0,0))
    stream.write(vertices.tobytes());stream.write(faces.tobytes())
print('Saved',len(vertices),len(faces),flush=True)
