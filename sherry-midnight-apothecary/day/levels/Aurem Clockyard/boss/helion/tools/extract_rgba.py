#!/usr/bin/env python3
"""Re-extract Helion frames from a replacement source video.
Requires: Python 3, opencv-python, numpy.
This key is tuned to the current dark blue-gray JiMeng background.
"""
import cv2, numpy as np, os, sys, math
src=sys.argv[1]
out=sys.argv[2] if len(sys.argv)>2 else 'frames'
os.makedirs(out,exist_ok=True)
out_fps=12.0
cap=cv2.VideoCapture(src); dur=cap.get(cv2.CAP_PROP_FRAME_COUNT)/cap.get(cv2.CAP_PROP_FPS)
for i in range(int(math.floor(min(15.0,dur)*out_fps))):
    cap.set(cv2.CAP_PROP_POS_MSEC,(i/out_fps)*1000); ok,fr=cap.read()
    if not ok: break
    hsv=cv2.cvtColor(fr,cv2.COLOR_BGR2HSV); H,S,V=cv2.split(hsv)
    bg=((S<82)&(V<150))|((H>=85)&(H<=125)&(S<120)&(V<175))
    orange=(((H<35)|(H>170))&(S>85)&(V>80)); white=((S<45)&(V>155)); bg[orange|white]=False
    a=np.where(bg,0,255).astype(np.uint8); a=cv2.GaussianBlur(a,(0,0),0.65)
    rgba=cv2.cvtColor(fr,cv2.COLOR_BGR2BGRA); rgba[:,:,3]=a
    rgba=cv2.resize(rgba,(640,480),interpolation=cv2.INTER_AREA)
    cv2.imwrite(os.path.join(out,f'helion_{i:04d}.png'),rgba)
cap.release()
