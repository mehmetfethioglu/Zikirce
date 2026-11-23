"""
Blender 4.2 Studio-Rigged 3D Character Builder for OrganicScore.
Builds 6 stylized Chibi-Pixar 3D runner characters on the 23-bone Rig_Medium skeleton
with BVH surface weight transfer from Mannequin_Medium.glb and embeds 4 full 3D skeletal
animations (Run, Walk, Idle, Jump) into assets/models/char_*.glb + renders matching
studio PNG cards into assets/images/characters/char_*.png.
"""
import bpy
import bmesh
import json
import math
import os
import sys
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree
from mathutils.interpolate import poly_3d_calc

PARTS_DIR = r"C:\Users\theak\.gemini\antigravity\brain\87e55887-5885-4873-8ca0-310fc26b136b\scratch\kk_parts"
REPO_ROOT = r"c:\Users\theak\source\repos\organicscore"
MODELS_OUT_DIR = os.path.join(REPO_ROOT, "assets", "models")
IMAGES_OUT_DIR = os.path.join(REPO_ROOT, "assets", "images", "characters")
SCRATCH_DIR = r"C:\Users\theak\.gemini\antigravity\brain\87e55887-5885-4873-8ca0-310fc26b136b\scratch"

os.makedirs(MODELS_OUT_DIR, exist_ok=True)
os.makedirs(IMAGES_OUT_DIR, exist_ok=True)


def srgb_to_linear(h):
    h = h.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i : i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return (out[0], out[1], out[2], 1.0)


def spow(x, p):
    return math.copysign(abs(x) ** p, x) if x else 0.0


def orient_outward(verts, faces, ref):
    score = 0.0
    for f in faces:
        pts = [Vector(verts[i]) for i in f]
        n = Vector((0, 0, 0))
        for i in range(len(pts)):
            a, b = pts[i], pts[(i + 1) % len(pts)]
            n += Vector(
                (
                    (a.y - b.y) * (a.z + b.z),
                    (a.z - b.z) * (a.x + b.x),
                    (a.x - b.x) * (a.y + b.y),
                )
            )
        c = sum(pts, Vector((0, 0, 0))) / len(pts)
        if n.length > 1e-12 and (c - ref(c)).length > 1e-9:
            score += n.normalized().dot((c - ref(c)).normalized())
    if score < 0:
        faces = [list(reversed(f)) for f in faces]
    return verts, faces


def rotated(vf, center, rx=0.0, ry=0.0, rz=0.0):
    if not (rx or ry or rz):
        return vf
    m = (
        Matrix.Rotation(rz, 3, "Z")
        @ Matrix.Rotation(ry, 3, "Y")
        @ Matrix.Rotation(rx, 3, "X")
    )
    c = Vector(center)
    return [tuple(m @ (Vector(v) - c) + c) for v in vf[0]], vf[1]


def mirrored(vf):
    return [(-v[0], v[1], v[2]) for v in vf[0]], [list(reversed(f)) for f in vf[1]]


def ring_faces(rings):
    faces = []
    for k in range(len(rings) - 1):
        A, B = rings[k], rings[k + 1]
        if len(A) == 1 and len(B) == 1:
            continue
        if len(A) == 1:
            n = len(B)
            for u in range(n):
                faces.append([A[0], B[(u + 1) % n], B[u]])
        elif len(B) == 1:
            n = len(A)
            for u in range(n):
                faces.append([A[u], A[(u + 1) % n], B[0]])
        else:
            n = len(A)
            for u in range(n):
                faces.append([A[u], A[(u + 1) % n], B[(u + 1) % n], B[u]])
    return faces


def ellipsoid(
    center, radii, n=2.0, m=2.0, segs=18, rings=12, zmin=None, zmax=None, rot=None
):
    cx, cy, cz = center
    rx, ry, rz = radii
    tmax = 1.0 if zmax is None else max(-1.0, min(1.0, (zmax - cz) / rz))
    tmin = -1.0 if zmin is None else max(-1.0, min(1.0, (zmin - cz) / rz))
    v0, v1 = math.asin(spow(tmax, m / 2.0)), math.asin(spow(tmin, m / 2.0))
    verts, ring_idx = [], []
    for k in range(rings + 1):
        v = v0 + (v1 - v0) * k / rings
        rad = spow(math.cos(v), 2.0 / m)
        z = cz + rz * spow(math.sin(v), 2.0 / m)
        if rad < 1e-6:
            verts.append((cx, cy, z))
            ring_idx.append([len(verts) - 1])
        else:
            idx = []
            for u in range(segs):
                a = 2 * math.pi * u / segs
                verts.append(
                    (
                        cx + rx * rad * spow(math.cos(a), 2.0 / n),
                        cy + ry * rad * spow(math.sin(a), 2.0 / n),
                        z,
                    )
                )
                idx.append(len(verts) - 1)
            ring_idx.append(idx)
    faces = ring_faces(ring_idx)
    vf = orient_outward(verts, faces, lambda p: Vector(center))
    return rotated(vf, center, *(rot or (0, 0, 0)))


def closest_on_polyline(pts, p):
    best, bd = pts[0], 1e18
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        ab = b - a
        t = (
            max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
            if ab.length_squared > 0
            else 0.0
        )
        q = a + ab * t
        d = (p - q).length_squared
        if d < bd:
            best, bd = q, d
    return best


def tube(points, radii, segs=14, caps=(True, True), cap_rings=3, ellip=(1.0, 1.0)):
    P = [Vector(p) for p in points]
    R = list(radii)
    T = []
    for i in range(len(P)):
        t = (
            (P[1] - P[0])
            if i == 0
            else (P[-1] - P[-2])
            if i == len(P) - 1
            else (P[i + 1] - P[i - 1])
        )
        T.append(t.normalized())
    up = Vector((0, 0, 1)) if abs(T[0].z) < 0.9 else Vector((1, 0, 0))
    nrm = T[0].cross(up).normalized()
    frames = []
    for t in T:
        nrm = (nrm - t * nrm.dot(t)).normalized()
        frames.append((nrm.copy(), t.cross(nrm)))
    verts, rings = [], []

    def ring(center, nn, bb, rad):
        idx = []
        for u in range(segs):
            a = 2 * math.pi * u / segs
            verts.append(
                tuple(
                    center
                    + nn * (math.cos(a) * rad * ellip[0])
                    + bb * (math.sin(a) * rad * ellip[1])
                )
            )
            idx.append(len(verts) - 1)
        return idx

    if caps[0]:
        verts.append(tuple(P[0] - T[0] * R[0]))
        rings.append([len(verts) - 1])
        for k in range(cap_rings, 0, -1):
            phi = (math.pi / 2) * k / (cap_rings + 1)
            rings.append(
                ring(
                    P[0] - T[0] * (R[0] * math.sin(phi)),
                    frames[0][0],
                    frames[0][1],
                    R[0] * math.cos(phi),
                )
            )
    for i in range(len(P)):
        rings.append(ring(P[i], frames[i][0], frames[i][1], R[i]))
    if caps[1]:
        for k in range(1, cap_rings + 1):
            phi = (math.pi / 2) * k / (cap_rings + 1)
            rings.append(
                ring(
                    P[-1] + T[-1] * (R[-1] * math.sin(phi)),
                    frames[-1][0],
                    frames[-1][1],
                    R[-1] * math.cos(phi),
                )
            )
        verts.append(tuple(P[-1] + T[-1] * R[-1]))
        rings.append([len(verts) - 1])
    faces = ring_faces(rings)
    return orient_outward(verts, faces, lambda p: closest_on_polyline(P, p))


def lerp_profile(profile, z):
    pts = profile
    if z <= pts[0][0]:
        return pts[0][1], pts[0][2]
    if z >= pts[-1][0]:
        return pts[-1][1], pts[-1][2]
    for i in range(len(pts) - 1):
        if pts[i][0] <= z <= pts[i + 1][0]:
            p0 = pts[max(i - 1, 0)]
            p1, p2 = pts[i], pts[i + 1]
            p3 = pts[min(i + 2, len(pts) - 1)]
            t = (z - p1[0]) / (p2[0] - p1[0])
            out = []
            for k in (1, 2):
                a, b, c, d = p0[k], p1[k], p2[k], p3[k]
                out.append(
                    0.5
                    * (
                        (2 * b)
                        + (-a + c) * t
                        + (2 * a - 5 * b + 4 * c - d) * t * t
                        + (-a + 3 * b - 3 * c + d) * t**3
                    )
                )
            return max(out[0], 0.0), max(out[1], 0.0)
    return pts[-1][1], pts[-1][2]


def lathe(
    profile,
    grow=0.0,
    zmin=None,
    zmax=None,
    segs=24,
    n=2.4,
    rings=26,
    cx=0.0,
    cy=0.0,
    close_top=True,
    close_bottom=True,
):
    z0 = profile[0][0] if zmin is None else zmin
    z1 = profile[-1][0] if zmax is None else zmax
    verts, rings_idx = [], []
    for k in range(rings + 1):
        z = z1 - (z1 - z0) * k / rings
        rx, ry = lerp_profile(profile, z)
        rx, ry = (rx + grow, ry + grow) if (rx > 1e-6 or grow) else (rx, ry)
        pole = (
            (rx < 1e-6 and ry < 1e-6)
            or (k == 0 and close_top and zmax is None)
            or (k == rings and close_bottom and zmin is None)
        )
        if pole and (rx < 0.02 or ry < 0.02):
            verts.append((cx, cy, z))
            rings_idx.append([len(verts) - 1])
        else:
            idx = []
            for u in range(segs):
                a = 2 * math.pi * u / segs
                verts.append(
                    (
                        cx + rx * spow(math.cos(a), 2.0 / n),
                        cy + ry * spow(math.sin(a), 2.0 / n),
                        z,
                    )
                )
                idx.append(len(verts) - 1)
            rings_idx.append(idx)
    faces = ring_faces(rings_idx)
    return orient_outward(verts, faces, lambda p: Vector((cx, cy, p.z)))


class Kit:
    def __init__(self):
        self.g = {}

    def add(self, group, mat, src, vf, smooth=True):
        v, f = vf
        d = self.g.setdefault(
            group, {"mat": mat, "smooth": smooth, "v": [], "f": [], "src": []}
        )
        base = len(d["v"])
        d["v"].extend(v)
        d["src"].extend([src] * len(v))
        d["f"].extend([[i + base for i in face] for face in f])

    def lr(self, group_base, mat, src_base, make, smooth=True):
        vf = make()
        self.add(group_base + "L", mat, src_base + "L", vf, smooth)
        self.add(group_base + "R", mat, src_base + "R", mirrored(vf), smooth)

    def lr_same(self, group, mat, src_base, make, smooth=True):
        vf = make()
        self.add(group, mat, src_base + "L", vf, smooth)
        self.add(group, mat, src_base + "R", mirrored(vf), smooth)


HEAD_C = (0.0, 0.0, 1.68)
HEAD_R = (0.50, 0.47, 0.47)
TORSO = [
    (0.30, 0.10, 0.09),
    (0.36, 0.22, 0.18),
    (0.44, 0.31, 0.24),
    (0.52, 0.335, 0.255),
    (0.62, 0.30, 0.235),
    (0.76, 0.31, 0.24),
    (0.92, 0.345, 0.26),
    (1.06, 0.365, 0.27),
    (1.18, 0.33, 0.25),
    (1.26, 0.22, 0.19),
    (1.31, 0.09, 0.08),
]


def rigid(bone):
    return "rigid:" + bone


def build_chibi_runner_kit(char_spec):
    kit = Kit()
    # 1. Head, ears, rosy Pixar nose, glossy eyes + dual specular highlights, brows, mouth
    head = ellipsoid(HEAD_C, HEAD_R, n=2.3, m=2.3, segs=30, rings=20)
    kit.add("skin_head", "skin", rigid("head"), head)
    bvh = BVHTree.FromPolygons([Vector(v) for v in head[0]], head[1])

    def front(x, z):
        hit = bvh.ray_cast(Vector((x, -2.0, z)), Vector((0, 1, 0)))
        return hit[0].y if hit[0] is not None else -HEAD_R[1]

    def side(y, z, sign):
        hit = bvh.ray_cast(Vector((sign * 2.0, y, z)), Vector((-sign, 0, 0)))
        return hit[0].x if hit[0] is not None else sign * HEAD_R[0]

    ex, ez = 0.19, 1.70
    for s in (1, -1):
        y = front(s * ex, ez)
        kit.add(
            "face_eyes",
            "eyes",
            rigid("head"),
            ellipsoid(
                (s * ex, y + 0.012, ez),
                (0.056, 0.042, 0.088),
                segs=16,
                rings=10,
                rot=(0, 0, s * 0.18),
            ),
        )
        # Main top-left eye shine + secondary bottom-right eye shine
        kit.add(
            "face_eyeshine",
            "eyeshine",
            rigid("head"),
            ellipsoid(
                (s * ex - s * 0.016, y - 0.024, ez + 0.036),
                (0.019, 0.013, 0.025),
                segs=10,
                rings=6,
            ),
        )
        kit.add(
            "face_eyeshine",
            "eyeshine",
            rigid("head"),
            ellipsoid(
                (s * ex + s * 0.018, y - 0.022, ez - 0.028),
                (0.010, 0.009, 0.012),
                segs=8,
                rings=5,
            ),
        )
        by = front(s * ex, 1.86)
        kit.add(
            "face_brows",
            "hair",
            rigid("head"),
            tube(
                [
                    (s * (ex - 0.08), by + 0.008, 1.86),
                    (s * ex, by + 0.004, 1.885),
                    (s * (ex + 0.08), by + 0.012, 1.865),
                ],
                [0.022, 0.024, 0.020],
                segs=10,
                cap_rings=2,
            ),
        )
        sx = side(0.0, 1.62, s)
        kit.add(
            "skin_head",
            "skin",
            rigid("head"),
            ellipsoid(
                (sx - s * 0.012, 0.0, 1.62), (0.045, 0.075, 0.10), segs=12, rings=8
            ),
        )

    # Cute rounded pinkish-coral Pixar nose!
    kit.add(
        "face_nose",
        "nose",
        rigid("head"),
        ellipsoid(
            (0, front(0, 1.56) - 0.018, 1.56), (0.068, 0.078, 0.062), segs=14, rings=10
        ),
    )

    # Smile mouth (happy upward curve)
    mouth = [
        (x, front(x, 1.40 + 2.4 * x * x) + 0.004, 1.40 + 2.4 * x * x)
        for x in (-0.095, -0.05, 0.0, 0.05, 0.095)
    ]
    kit.add("face_mouth", "mouth", rigid("head"), tube(mouth, [0.018] * 5, segs=10, cap_rings=2))

    # 2. Hands (visible outside cuffs)
    def hand():
        v, f = ellipsoid(
            (0.84, 0.0, 1.08), (0.105, 0.088, 0.098), n=2.2, m=2.2, segs=14, rings=9
        )
        t = ellipsoid((0.815, -0.075, 1.11), (0.04, 0.045, 0.05), segs=10, rings=6)
        base = len(v)
        return v + t[0], f + [[i + base for i in face] for face in t[1]]

    kit.lr("skin_hand", "skin", "arm", hand)

    # 3. Hair style per character
    hstyle = char_spec["hair_style"]
    # Base hair volume
    kit.add(
        "hair",
        "hair",
        rigid("head"),
        ellipsoid((0, 0.0, 2.04), (0.54, 0.51, 0.28), n=2.2, m=2.2, segs=24, rings=14),
    )
    kit.add(
        "hair",
        "hair",
        rigid("head"),
        ellipsoid((0, 0.27, 1.82), (0.515, 0.275, 0.36), n=2.2, m=2.2, segs=20, rings=12),
    )
    for s in (1, -1):
        kit.add(
            "hair",
            "hair",
            rigid("head"),
            ellipsoid((s * 0.475, 0.08, 1.84), (0.12, 0.30, 0.26), segs=14, rings=9),
        )

    if hstyle in ("swept", "tousled"):
        # Dynamic swept Pixar pompadour / wave locks
        locks = [
            [(-0.22, -0.36, 2.05), (-0.02, -0.44, 2.18), (0.24, -0.36, 2.26)],
            [(-0.34, -0.26, 2.02), (-0.14, -0.38, 2.22), (0.14, -0.32, 2.31)],
            [(0.05, -0.38, 2.06), (0.25, -0.40, 2.17), (0.40, -0.28, 2.18)],
            [(-0.20, 0.0, 2.26), (0.05, -0.10, 2.34), (0.28, -0.05, 2.28)],
        ]
        for pts in locks:
            kit.add("hair", "hair", rigid("head"), tube(pts, [0.10, 0.12, 0.07], segs=10))
    elif hstyle == "ponytail":
        # Swept front bangs + high sporty ponytail visible from 3/4 front & side
        bangs = [
            [(-0.32, -0.32, 2.02), (-0.08, -0.44, 2.10), (0.22, -0.38, 2.04)],
            [(0.10, -0.40, 2.06), (0.28, -0.36, 2.00), (0.40, -0.24, 1.92)],
        ]
        for pts in bangs:
            kit.add("hair", "hair", rigid("head"), tube(pts, [0.09, 0.11, 0.07], segs=10))
        kit.add(
            "hair_band",
            "accent",
            rigid("head"),
            ellipsoid((-0.06, 0.22, 2.24), (0.14, 0.12, 0.09), segs=12, rings=6),
        )
        kit.add(
            "hair",
            "hair",
            rigid("head"),
            tube(
                [(-0.08, 0.24, 2.28), (-0.22, 0.42, 2.34), (-0.34, 0.58, 2.05), (-0.38, 0.64, 1.72)],
                [0.14, 0.18, 0.14, 0.06],
                segs=12,
            ),
        )
    elif hstyle == "bob":
        bangs = [
            [(-0.34, -0.30, 2.02), (0.0, -0.44, 2.10), (0.34, -0.30, 2.02)],
        ]
        for pts in bangs:
            kit.add("hair", "hair", rigid("head"), tube(pts, [0.09, 0.11, 0.09], segs=10))
        for s in (1, -1):
            kit.add(
                "hair",
                "hair",
                rigid("head"),
                ellipsoid(
                    (s * 0.48, -0.04, 1.62), (0.14, 0.28, 0.34), segs=14, rings=10
                ),
            )
        # Cute sport headband across crown
        kit.add(
            "hair_band",
            "accent",
            rigid("head"),
            tube(
                [(-0.49, -0.05, 1.90), (-0.28, -0.36, 2.12), (0.0, -0.44, 2.18), (0.28, -0.36, 2.12), (0.49, -0.05, 1.90)],
                [0.032, 0.038, 0.040, 0.038, 0.032],
                segs=10,
            ),
        )

    # 4. Beard & Handlebar Mustache (for Atlas & Demir — matching the reference image!)
    if char_spec.get("has_beard"):
        kit.add(
            "beard",
            "hair",
            rigid("head"),
            ellipsoid(
                (0, -0.21, 1.33),
                (0.42, 0.31, 0.21),
                n=2.2,
                m=2.2,
                segs=24,
                rings=12,
                zmax=1.48,
            ),
        )
        for s in (1, -1):
            m_pts = [
                (0.0, -0.46, 1.48),
                (s * 0.12, -0.45, 1.47),
                (s * 0.24, -0.39, 1.49),
            ]
            kit.add(
                "beard",
                "hair",
                rigid("head"),
                tube(m_pts, [0.052, 0.046, 0.026], segs=10, cap_rings=2),
            )

    # 5. Glasses / Visor accessory
    acc = char_spec.get("accessory")
    if acc == "glasses":
        for s in (1, -1):
            ring_pts = [
                (
                    s * 0.19 + 0.11 * math.cos(a),
                    -0.47,
                    1.70 + 0.10 * math.sin(a),
                )
                for a in [i * math.pi / 8 for i in range(17)]
            ]
            kit.add("glasses", "accent", rigid("head"), tube(ring_pts, [0.016] * 17, segs=8))
        kit.add(
            "glasses",
            "accent",
            rigid("head"),
            tube([(-0.08, -0.47, 1.71), (0.08, -0.47, 1.71)], [0.015, 0.015], segs=8),
        )
    elif acc == "visor":
        # Sleek Cyber-Sport Shield Visor Glasses (frame + tinted shield)
        visor_top = [
            (-0.44, -0.24, 1.79),
            (-0.22, -0.47, 1.80),
            (0.0, -0.50, 1.79),
            (0.22, -0.47, 1.80),
            (0.44, -0.24, 1.79),
        ]
        kit.add(
            "visor",
            "accent",
            rigid("head"),
            tube(visor_top, [0.022, 0.026, 0.028, 0.026, 0.022], segs=10),
        )
        for s in (1, -1):
            lens_pts = [
                (
                    s * 0.19 + 0.125 * math.cos(a),
                    -0.475,
                    1.70 + 0.095 * math.sin(a),
                )
                for a in [i * math.pi / 8 for i in range(17)]
            ]
            kit.add("visor", "accent", rigid("head"), tube(lens_pts, [0.018] * 17, segs=8))

    # 6. Puffy Athletic Zip-Up Hoodie (grow=0.050 so it sits cleanly OVER the trousers with zero hip clipping!)
    kit.add(
        "shirt",
        "shirt",
        "torso",
        lathe(
            TORSO,
            grow=0.050,
            zmin=0.55,
            zmax=1.285,
            segs=26,
            n=2.4,
            rings=26,
            close_top=False,
            close_bottom=False,
        ),
    )
    # Puffy Hoodie Hood around the collar/neck
    hood_pts = [
        (-0.24, -0.16, 1.25),
        (-0.28, 0.14, 1.30),
        (0.0, 0.30, 1.35),
        (0.28, 0.14, 1.30),
        (0.24, -0.16, 1.25),
    ]
    kit.add(
        "shirt",
        "shirt",
        "torso",
        tube(hood_pts, [0.075, 0.095, 0.11, 0.095, 0.075], segs=12, cap_rings=2),
    )

    # Long puffy sleeves + white ribbed cuffs
    def sleeve(x0, x1, r0, r1):
        return tube(
            [(x0, 0.0, 1.107), ((x0 + x1) / 2, 0.006, 1.107), (x1, 0.01, 1.107)],
            [r0, (r0 + r1) / 2, r1],
            segs=14,
            caps=(False, False),
        )

    kit.lr_same("shirt", "shirt", "arm", lambda: sleeve(0.15, 0.67, 0.165, 0.132))
    kit.lr_same("cuff", "linen", "arm", lambda: sleeve(0.65, 0.73, 0.138, 0.134))

    # White Hoodie Drawstrings on the front chest (signature detail from user's reference image!)
    for s in (1, -1):
        ds_pts = [
            (s * 0.085, -0.25, 1.22),
            (s * 0.095, -0.31, 1.06),
            (s * 0.090, -0.315, 0.90),
        ]
        kit.add("cuff", "linen", "torso", tube(ds_pts, [0.018, 0.018, 0.022], segs=8))

    # Backpack & Dark Shoulder Straps (from user's reference image!)
    kit.add(
        "pack",
        "pack",
        "torso",
        ellipsoid((0, 0.37, 0.95), (0.24, 0.13, 0.28), n=3.0, m=3.0, segs=18, rings=12),
    )
    for s in (1, -1):
        kit.add(
            "pack",
            "belt",
            "torso",
            tube(
                [
                    (s * 0.18, 0.30, 1.20),
                    (s * 0.20, -0.05, 1.30),
                    (s * 0.21, -0.29, 1.12),
                    (s * 0.19, -0.28, 0.82),
                ],
                [0.028] * 4,
                segs=8,
                cap_rings=2,
            ),
        )

    # 7. Tapered Athletic Joggers:
    # Single continuous leg tube from hip (z=0.54) through knee (z=0.31) to ankle (z=0.21)
    # + high pelvis band (z=0.47..0.60, grow=0.018) tucked inside hoodie so ZERO spike or knee gap occurs!
    kit.add(
        "trousers",
        "trousers",
        "torso",
        lathe(
            TORSO,
            grow=0.018,
            zmin=0.47,
            zmax=0.60,
            segs=24,
            n=2.4,
            rings=10,
            close_top=False,
            close_bottom=True,
        ),
    )
    kit.lr_same(
        "trousers",
        "trousers",
        "leg",
        lambda: tube(
            [
                (0.171, 0.0, 0.53),
                (0.171, -0.003, 0.42),
                (0.171, -0.005, 0.31),
                (0.171, 0.008, 0.21),
            ],
            [0.164, 0.158, 0.144, 0.130],
            segs=16,
            caps=(True, False),
            cap_rings=3,
        ),
    )

    # 8. White Crew Socks + Chunky Two-Tone Running Sneakers
    kit.lr_same(
        "cuff",
        "linen",
        "leg",
        lambda: tube(
            [(0.171, 0.008, 0.225), (0.171, 0.018, 0.130)],
            [0.125, 0.122],
            segs=14,
            caps=(False, False),
        ),
    )
    # Sneaker upper (boots material)
    kit.lr_same(
        "boots",
        "boots",
        "leg",
        lambda: ellipsoid(
            (0.171, -0.075, 0.082),
            (0.135, 0.255, 0.085),
            n=2.3,
            m=2.2,
            segs=16,
            rings=10,
        ),
    )
    # Chunky white foam midsole (linen material)
    kit.lr_same(
        "cuff",
        "linen",
        "leg",
        lambda: ellipsoid(
            (0.171, -0.078, 0.032),
            (0.145, 0.270, 0.036),
            n=2.5,
            m=2.5,
            segs=16,
            rings=8,
            zmin=0.005,
            zmax=0.058,
        ),
    )
    return kit


def load_weight_sources():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(
        filepath=os.path.join(PARTS_DIR, "Mannequin_Medium.glb")
    )
    region = {
        "torso": "Body",
        "armL": "ArmLeft",
        "armR": "ArmRight",
        "legL": "LegLeft",
        "legR": "LegRight",
    }
    out = {}
    for key, part in region.items():
        obj = next(
            o
            for o in bpy.data.objects
            if o.type == "MESH" and o.name.endswith("_" + part)
        )
        me = obj.data
        names = {g.index: g.name for g in obj.vertex_groups}
        verts = [obj.matrix_world @ v.co for v in me.vertices]
        weights = [
            {names[g.group]: g.weight for g in v.groups if g.weight > 1e-4}
            for v in me.vertices
        ]
        tris = []
        for p in me.polygons:
            idx = list(p.vertices)
            for i in range(1, len(idx) - 1):
                tris.append((idx[0], idx[i], idx[i + 1]))
        out[key] = {
            "bvh": BVHTree.FromPolygons(verts, tris),
            "verts": verts,
            "tris": tris,
            "w": weights,
        }
    return out


def weights_at(src, co):
    loc, nrm, fi, dist = src["bvh"].find_nearest(co)
    tri = src["tris"][fi]
    bary = poly_3d_calc([src["verts"][i] for i in tri], loc)
    acc = {}
    for bw, vi in zip(bary, tri):
        for name, w in src["w"][vi].items():
            acc[name] = acc.get(name, 0.0) + w * bw
    return acc


def top_influences(acc, n=4):
    items = sorted(acc.items(), key=lambda kv: -kv[1])[:n]
    total = sum(w for _, w in items) or 1.0
    return [(k, w / total) for k, w in items if w / total > 0.01]


def new_material(name, hexcolor, roughness=0.52, metallic=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = srgb_to_linear(hexcolor)
    b.inputs["Roughness"].default_value = roughness
    b.inputs["Metallic"].default_value = metallic
    m.diffuse_color = srgb_to_linear(hexcolor)
    return m


CHARACTERS = [
    {
        "id": "atlas",
        "glb": "char_atlas.glb",
        "png": "char_atlas_runner.png",
        "hair_style": "swept",
        "has_beard": True,
        "accessory": None,
        "colors": {
            "skin": "#F3B998",
            "nose": "#E5856B",
            "hair": "#3D2114",
            "eyes": "#1C120C",
            "eyeshine": "#FFFFFF",
            "mouth": "#B84A39",
            "shirt": "#F97316",
            "linen": "#F8FAFC",
            "trousers": "#1E293B",
            "belt": "#0F172A",
            "pack": "#334155",
            "boots": "#EA580C",
            "accent": "#F59E0B",
        },
    },
    {
        "id": "nova",
        "glb": "char_nova.glb",
        "png": "char_nova_sprinter.png",
        "hair_style": "ponytail",
        "has_beard": False,
        "accessory": None,
        "colors": {
            "skin": "#F6C4A6",
            "nose": "#EC8C74",
            "hair": "#5C2C18",
            "eyes": "#16201C",
            "eyeshine": "#FFFFFF",
            "mouth": "#C85244",
            "shirt": "#10B981",
            "linen": "#F8FAFC",
            "trousers": "#1E293B",
            "belt": "#0F172A",
            "pack": "#1E293B",
            "boots": "#059669",
            "accent": "#34D399",
        },
    },
    {
        "id": "kaan",
        "glb": "char_kaan.glb",
        "png": "char_kaan_guardian.png",
        "hair_style": "tousled",
        "has_beard": False,
        "accessory": None,
        "colors": {
            "skin": "#EEB492",
            "nose": "#E28268",
            "hair": "#1E1B18",
            "eyes": "#18181B",
            "eyeshine": "#FFFFFF",
            "mouth": "#B84A39",
            "shirt": "#22C55E",
            "linen": "#F8FAFC",
            "trousers": "#27272A",
            "belt": "#18181B",
            "pack": "#27272A",
            "boots": "#16A34A",
            "accent": "#4ADE80",
        },
    },
    {
        "id": "lina",
        "glb": "char_lina.glb",
        "png": "char_lina_zen.png",
        "hair_style": "bob",
        "has_beard": False,
        "accessory": None,
        "colors": {
            "skin": "#F7C8AC",
            "nose": "#EE8E78",
            "hair": "#8B4A24",
            "eyes": "#241814",
            "eyeshine": "#FFFFFF",
            "mouth": "#D95B50",
            "shirt": "#F43F5E",
            "linen": "#F8FAFC",
            "trousers": "#2A1B2E",
            "belt": "#1A101D",
            "pack": "#3B2242",
            "boots": "#E11D48",
            "accent": "#FDA4AF",
        },
    },
    {
        "id": "demir",
        "glb": "char_demir.glb",
        "png": "char_demir_alchemist.png",
        "hair_style": "swept",
        "has_beard": True,
        "accessory": "glasses",
        "colors": {
            "skin": "#EBB08E",
            "nose": "#DE7E64",
            "hair": "#94A3B8",
            "eyes": "#0F172A",
            "eyeshine": "#FFFFFF",
            "mouth": "#A84436",
            "shirt": "#0284C7",
            "linen": "#F8FAFC",
            "trousers": "#0F172A",
            "belt": "#1E293B",
            "pack": "#1E293B",
            "boots": "#0369A1",
            "accent": "#FBBF24",
        },
    },
    {
        "id": "zefir",
        "glb": "char_zefir.glb",
        "png": "char_zefir_legend.png",
        "hair_style": "swept",
        "has_beard": False,
        "accessory": "visor",
        "colors": {
            "skin": "#F2BC9E",
            "nose": "#E5866E",
            "hair": "#C4B5FD",
            "eyes": "#1E1B4B",
            "eyeshine": "#FFFFFF",
            "mouth": "#B84A39",
            "shirt": "#7C3AED",
            "linen": "#FDE68A",
            "trousers": "#17132B",
            "belt": "#0F0B1E",
            "pack": "#2E1065",
            "boots": "#6D28D9",
            "accent": "#06B6D4",
        },
    },
]


def build_and_export_character(char_spec, sources):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    # Import Rig_Medium from Body.glb
    bpy.ops.import_scene.gltf(filepath=os.path.join(PARTS_DIR, "Body.glb"))
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    for o in list(bpy.data.objects):
        if o.type == "MESH":
            bpy.data.objects.remove(o, do_unlink=True)
    for m in list(bpy.data.materials):
        bpy.data.materials.remove(m)
    arm.name = "Rig_Medium"

    kit = build_chibi_runner_kit(char_spec)
    colors = char_spec["colors"]
    mats = {}
    for gname, d in kit.g.items():
        me = bpy.data.meshes.new(gname)
        me.from_pydata([tuple(v) for v in d["v"]], [], d["f"])
        me.update()
        for p in me.polygons:
            p.use_smooth = d["smooth"]
        mname = d["mat"]
        if mname not in mats:
            rough = 0.15 if mname in ("eyes", "eyeshine", "accent") else 0.55
            metal = 0.45 if mname == "accent" else 0.0
            mats[mname] = new_material(mname, colors[mname], rough, metal)
        me.materials.append(mats[mname])
        obj = bpy.data.objects.new(gname, me)
        bpy.context.scene.collection.objects.link(obj)
        for bone in arm.data.bones:
            obj.vertex_groups.new(name=bone.name)
        for i, (co, src) in enumerate(zip(d["v"], d["src"])):
            if src.startswith("rigid:"):
                infl = [(src[6:], 1.0)]
            else:
                infl = top_influences(weights_at(sources[src], Vector(co)))
            for bone_name, w in infl:
                obj.vertex_groups[bone_name].add([i], w, "REPLACE")
        obj.parent = arm
        mod = obj.modifiers.new("Armature", "ARMATURE")
        mod.object = arm

    # Import animations from Rig_Medium_MovementBasic.glb and Rig_Medium_General.glb
    bpy.ops.import_scene.gltf(
        filepath=os.path.join(PARTS_DIR, "Rig_Medium_MovementBasic.glb")
    )
    bpy.ops.import_scene.gltf(
        filepath=os.path.join(PARTS_DIR, "Rig_Medium_General.glb")
    )
    for o in list(bpy.data.objects):
        if o != arm and (o.type == "ARMATURE" or o.name.startswith("Icosphere")):
            bpy.data.objects.remove(o, do_unlink=True)

    # Select and rename the 4 core actions into clean NLA tracks: Run, Walk, Idle, Jump
    wanted_map = {
        "Run": "Running_A",
        "Walk": "Walking_A",
        "Idle": "Idle_A",
        "Jump": "Jump_Full_Short",
    }
    chosen_actions = {}
    for clean_name, prefix in wanted_map.items():
        act = next((a for a in bpy.data.actions if prefix in a.name), None)
        if act:
            act.name = clean_name
            act.use_fake_user = True
            chosen_actions[clean_name] = act

    for a in list(bpy.data.actions):
        if a.name not in chosen_actions:
            bpy.data.actions.remove(a, do_unlink=True)

    arm.animation_data_create()
    ad = arm.animation_data
    for tr in list(ad.nla_tracks):
        ad.nla_tracks.remove(tr)
    ad.action = None
    for clean_name in ["Run", "Walk", "Idle", "Jump"]:
        act = chosen_actions.get(clean_name)
        if act:
            tr = ad.nla_tracks.new()
            tr.name = clean_name
            st = tr.strips.new(clean_name, int(act.frame_range[0]), act)

    # Export GLB with NLA tracks
    glb_path = os.path.join(MODELS_OUT_DIR, char_spec["glb"])
    bpy.ops.export_scene.gltf(
        filepath=glb_path,
        export_format="GLB",
        export_yup=True,
        export_apply=False,
        export_skins=True,
        export_animations=True,
        export_animation_mode="NLA_TRACKS",
        export_force_sampling=True,
        export_optimize_animation_size=True,
        export_materials="EXPORT",
        export_cameras=False,
        export_lights=False,
    )
    print(f"Exported {glb_path} ({os.path.getsize(glb_path) // 1024} KB)")

    # Render matching Studio PNG Card in mid-stride 3/4 Running pose!
    ad.action = chosen_actions["Run"]
    arm.rotation_mode = "XYZ"
    arm.rotation_euler = (0, 0, math.radians(26))
    bpy.context.scene.frame_set(5)

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x = 640
    scene.render.resolution_y = 800
    scene.render.film_transparent = True

    cam_d = bpy.data.cameras.new("StudioCam")
    cam_d.lens = 58
    cam = bpy.data.objects.new("StudioCam", cam_d)
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.location = (0.0, -5.2, 1.22)
    cam.rotation_euler = (math.radians(89), 0, 0)

    lights = [
        ((3.0, -3.5, 3.8), 650, (1.0, 0.98, 0.95)),
        ((-3.0, -2.5, 2.6), 320, (0.90, 0.95, 1.0)),
        ((0.0, 2.8, 3.2), 400, (1.0, 1.0, 1.0)),
    ]
    for pos, energy, col in lights:
        ld = bpy.data.lights.new("L", type="AREA")
        ld.energy = energy
        ld.color = col
        ld.size = 3.5
        lo = bpy.data.objects.new("L", ld)
        scene.collection.objects.link(lo)
        lo.location = pos
        direction = Vector((0, 0, 1.2)) - Vector(pos)
        lo.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()

    png_path = os.path.join(IMAGES_OUT_DIR, char_spec["png"])
    scene.render.filepath = png_path
    bpy.ops.render.render(write_still=True)
    print(f"Rendered studio card {png_path}")


def main():
    sources = load_weight_sources()
    for spec in CHARACTERS:
        build_and_export_character(spec, sources)


if __name__ == "__main__":
    main()
