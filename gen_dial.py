import math

cx, cy = 300.0, 300.0
half_w, half_h = 286.0, 286.0
corner_r = 60.0

def get_squircle_point(angle_rad):
    cos_a = math.cos(angle_rad)
    sin_a = math.sin(angle_rad)
    sign_x = 1.0 if cos_a >= 0 else -1.0
    sign_y = 1.0 if sin_a >= 0 else -1.0
    straight_w = half_w - corner_r
    straight_h = half_h - corner_r

    if abs(cos_a) > 1e-6:
        t_x = (sign_x * half_w) / cos_a
        hit_y = t_x * sin_a
        if t_x > 0 and abs(hit_y) <= straight_h:
            return cx + sign_x * half_w, cy + hit_y

    if abs(sin_a) > 1e-6:
        t_y = (sign_y * half_h) / sin_a
        hit_x = t_y * cos_a
        if t_y > 0 and abs(hit_x) <= straight_w:
            return cx + hit_x, cy + sign_y * half_h

    corner_cx = sign_x * straight_w
    corner_cy = sign_y * straight_h
    b = -2.0 * (cos_a * corner_cx + sin_a * corner_cy)
    c = corner_cx * corner_cx + corner_cy * corner_cy - corner_r * corner_r
    disc = b * b - 4.0 * c
    if disc >= 0:
        t = (-b + math.sqrt(disc)) / 2.0
        return cx + t * cos_a, cy + t * sin_a

    return cx + half_w * cos_a, cy + half_h * sin_a

xml_lines = [
    '<?xml version="1.0" encoding="utf-8"?>',
    '<vector xmlns:android="http://schemas.android.com/apk/res/android"',
    '    android:width="600dp"',
    '    android:height="600dp"',
    '    android:viewportWidth="600"',
    '    android:viewportHeight="600">',
    ''
]

for i in range(60):
    angle_deg = i * 6.0 - 90.0
    angle_rad = math.radians(angle_deg)
    ox, oy = get_squircle_point(angle_rad)
    is_cardinal = (i % 15 == 0) # 12, 3, 6, 9
    is_hour = (i % 5 == 0)

    if is_cardinal:
        continue

    cos_a = math.cos(angle_rad)
    sin_a = math.sin(angle_rad)

    if is_hour:
        # Hour baton capsule
        tick_len = 22.0
        ix = ox - tick_len * cos_a
        iy = oy - tick_len * sin_a
        xml_lines.append(
            f'    <!-- Hour {i//5} -->'
        )
        xml_lines.append(
            f'    <path android:strokeColor="@color/widget_digital_primary" android:strokeWidth="6.5" android:strokeLineCap="round" android:pathData="M {ox:.1f},{oy:.1f} L {ix:.1f},{iy:.1f}" />'
        )
    else:
        # Minute tick
        tick_len = 8.5
        ix = ox - tick_len * cos_a
        iy = oy - tick_len * sin_a
        xml_lines.append(
            f'    <path android:strokeColor="@color/widget_digital_secondary" android:strokeWidth="2.0" android:strokeLineCap="round" android:pathData="M {ox:.1f},{oy:.1f} L {ix:.1f},{iy:.1f}" />'
        )

xml_lines.append('</vector>\n')

with open('android/app/src/main/res/drawable/widget_analog_dial_marks.xml', 'w', encoding='utf-8') as f:
    f.write('\n'.join(xml_lines))
print("Generated widget_analog_dial_marks.xml successfully!")
