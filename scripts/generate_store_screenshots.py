#!/usr/bin/env python3
"""Render App Store screenshots that match the shipping SwiftUI screens."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "fastlane" / "screenshots" / "en-US"
LOGO = ROOT / "FitbitHealthSync" / "Assets.xcassets" / "LaunchLogo.imageset" / "launch-logo.png"
FONT_DIR = Path("/usr/share/fonts/truetype/macos")

GROUPED = (242, 242, 247)
WHITE = (255, 255, 255)
INDIGO = (88, 86, 214)
INDIGO_SOFT = (88, 86, 214, 20)
LABEL = (0, 0, 0)
SECONDARY = (108, 108, 112)
GREEN = (52, 199, 89)
ORANGE = (255, 149, 0)
RED = (255, 59, 48)
BLUE = (0, 122, 255)
SEPARATOR = (198, 198, 200)
TAB_BG = (255, 255, 255)
STATUS_BG = (0, 0, 0)

IPHONE_SIZES = [
    (1242, 2688),
    (1284, 2778),
    (1290, 2796),
    (1320, 2868),
]
IPAD_SIZES = [
    (2048, 2732),
    (2064, 2752),
]

METRICS = [
    ("Active Energy", "flame"),
    ("Body Fat %", "percent"),
    ("Body Weight", "scale"),
    ("Resting Heart Rate", "heart"),
    ("Sleep", "bed"),
    ("Steps", "walk"),
]


def font(weight: str, size: float) -> ImageFont.FreeTypeFont:
    names = {
        "regular": "Inter-Regular.ttf",
        "medium": "Inter-Medium.ttf",
        "semibold": "Inter-SemiBold.ttf",
        "bold": "Inter-Bold.ttf",
        "mono": "JetBrainsMono-Regular.ttf",
    }
    return ImageFont.truetype(str(FONT_DIR / names[weight]), int(round(size)))


def rounded_rect(draw: ImageDraw.ImageDraw, xy, radius, fill, outline=None, width=1):
    draw.rounded_rectangle(xy, radius=radius, fill=fill, outline=outline, width=width)


def paste_round(base: Image.Image, overlay: Image.Image, xy, radius: int):
    mask = Image.new("L", overlay.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, overlay.size[0] - 1, overlay.size[1] - 1), radius=radius, fill=255
    )
    base.paste(overlay, xy, mask)


def text_size(draw: ImageDraw.ImageDraw, text: str, fnt: ImageFont.FreeTypeFont):
    bbox = draw.textbbox((0, 0), text, font=fnt)
    return bbox[2] - bbox[0], bbox[3] - bbox[1]


class Screen:
    def __init__(self, width: int, height: int):
        self.w = width
        self.h = height
        self.is_ipad = width >= 1600
        self.s = width / (834.0 if self.is_ipad else 430.0)
        self.img = Image.new("RGBA", (width, height), (*GROUPED, 255))
        self.draw = ImageDraw.Draw(self.img, "RGBA")
        self.side = int(48 * self.s) if self.is_ipad else int(16 * self.s)
        self.tab_h = int(83 * self.s)
        self.status_h = int(54 * self.s) if not self.is_ipad else int(32 * self.s)

    def pt(self, n: float) -> int:
        return int(round(n * self.s))

    def draw_status_bar(self, time: str = "9:41"):
        d = self.draw
        s = self.s
        fnt = font("semibold", 15 * s)
        d.text((self.pt(24), self.pt(14)), time, font=fnt, fill=LABEL)
        # Trailing status icons
        right = self.w - self.pt(18)
        # Battery
        bw, bh = self.pt(25), self.pt(12)
        bx = right - bw
        by = self.pt(18)
        d.rounded_rectangle((bx, by, bx + bw, by + bh), radius=self.pt(3), outline=LABEL, width=max(1, self.pt(1.2)))
        d.rectangle((bx + 2, by + 2, bx + bw - self.pt(5), by + bh - 2), fill=GREEN)
        d.rectangle((bx + bw, by + self.pt(3), bx + bw + self.pt(2), by + bh - self.pt(3)), fill=LABEL)
        # Wi-Fi arcs
        wx = bx - self.pt(22)
        wy = by + bh
        for i, r in enumerate((10, 6, 2)):
            d.arc(
                (wx - self.pt(r), wy - self.pt(r * 1.6), wx + self.pt(r), wy + self.pt(r * 0.2)),
                200,
                340,
                fill=LABEL,
                width=max(1, self.pt(1.4)),
            )
        # Cellular
        cx = wx - self.pt(28)
        for i, h in enumerate((4, 6, 8, 11)):
            x = cx + i * self.pt(4)
            d.rectangle((x, wy - self.pt(h), x + self.pt(3), wy), fill=LABEL)
        if not self.is_ipad:
            island_w, island_h = self.pt(126), self.pt(36)
            ix = (self.w - island_w) // 2
            iy = self.pt(11)
            d.rounded_rectangle((ix, iy, ix + island_w, iy + island_h), radius=island_h // 2, fill=STATUS_BG)

    def draw_tab_bar(self, selected: str):
        y = self.h - self.tab_h
        self.draw.rectangle((0, y, self.w, self.h), fill=TAB_BG)
        self.draw.line((0, y, self.w, y), fill=SEPARATOR, width=1)
        items = [("Home", "house"), ("Settings", "sliders"), ("Activity", "ecg")]
        slot = self.w / 3
        for i, (name, icon) in enumerate(items):
            cx = int(slot * (i + 0.5))
            color = INDIGO if name == selected else SECONDARY
            iy = y + self.pt(12)
            self._tab_icon(icon, cx, iy, color)
            fnt = font("medium", 10 * self.s)
            tw, _ = text_size(self.draw, name, fnt)
            self.draw.text((cx - tw // 2, y + self.pt(40)), name, font=fnt, fill=color)
        # Home indicator
        bar_w = self.pt(134) if not self.is_ipad else self.pt(160)
        bx = (self.w - bar_w) // 2
        by = self.h - self.pt(9)
        self.draw.rounded_rectangle((bx, by, bx + bar_w, by + self.pt(5)), radius=self.pt(2.5), fill=(0, 0, 0))

    def _tab_icon(self, name: str, cx: int, y: int, color):
        s = self.pt(11)
        d = self.draw
        if name == "house":
            d.polygon(
                [(cx, y), (cx + s, y + s), (cx + s, y + s * 1.7), (cx - s, y + s * 1.7), (cx - s, y + s)],
                outline=color,
            )
            d.line([(cx, y), (cx + s, y + s)], fill=color, width=max(2, self.pt(1.6)))
            d.line([(cx, y), (cx - s, y + s)], fill=color, width=max(2, self.pt(1.6)))
        elif name == "sliders":
            for i, (xoff, knob) in enumerate(((-10, 6), (0, -4), (10, 2))):
                x = cx + self.pt(xoff)
                d.line([(x, y), (x, y + self.pt(22))], fill=color, width=max(2, self.pt(1.6)))
                d.ellipse((x - self.pt(4), y + self.pt(10 + knob), x + self.pt(4), y + self.pt(18 + knob)), fill=color)
        else:
            pts = []
            for i in range(8):
                x = cx - self.pt(12) + i * self.pt(3.4)
                amp = self.pt(8) if i in (2, 5) else self.pt(3 if i % 2 == 0 else 6)
                pts.append((x, y + self.pt(11) + ((-1) ** i) * amp))
            d.line(pts, fill=color, width=max(2, self.pt(1.8)), joint="curve")

    def large_title(self, title: str, y: int) -> int:
        fnt = font("bold", 34 * self.s)
        self.draw.text((self.side, y), title, font=fnt, fill=LABEL)
        return y + self.pt(52)

    def card(self, x, y, w, h, radius=None):
        radius = self.pt(16) if radius is None else radius
        rounded_rect(self.draw, (x, y, x + w, y + h), radius, WHITE)
        return y + h

    def primary_button(self, x, y, w, h, label: str, icon: str | None, color, enabled=True):
        fill = color if enabled else (174, 174, 178)
        rounded_rect(self.draw, (x, y, x + w, y + h), self.pt(14), fill)
        fnt = font("semibold", 17 * self.s)
        tw, th = text_size(self.draw, label, fnt)
        tx = x + (w - tw) // 2
        if icon:
            tx = x + (w - tw - self.pt(28)) // 2 + self.pt(22)
            self._draw_named_icon(icon, x + (w - tw - self.pt(28)) // 2 + self.pt(8), y + h // 2, WHITE)
        self.draw.text((tx, y + (h - th) // 2 - 1), label, font=fnt, fill=WHITE)

    def _draw_named_icon(self, name: str, cx: int, cy: int, color):
        d = self.draw
        r = self.pt(9)
        if name == "sync":
            d.arc((cx - r, cy - r, cx + r, cy + r), 40, 300, fill=color, width=max(2, self.pt(1.8)))
            d.polygon(
                [(cx + r - 1, cy - self.pt(4)), (cx + r + self.pt(5), cy), (cx + r - self.pt(4), cy + self.pt(3))],
                fill=color,
            )
        elif name == "person":
            d.ellipse((cx - self.pt(5), cy - r, cx + self.pt(5), cy - 1), outline=color, width=max(2, self.pt(1.6)))
            d.arc((cx - r, cy, cx + r, cy + r + self.pt(6)), 200, 340, fill=color, width=max(2, self.pt(1.6)))
        elif name == "reconnect":
            d.arc((cx - r, cy - r, cx + r, cy + r), 20, 280, fill=color, width=max(2, self.pt(1.8)))
            d.polygon(
                [(cx - self.pt(2), cy - r), (cx + self.pt(6), cy - r + self.pt(2)), (cx, cy - r + self.pt(8))],
                fill=color,
            )
        elif name == "minus":
            d.ellipse((cx - r, cy - r, cx + r, cy + r), outline=color, width=max(2, self.pt(1.6)))
            d.line([(cx - self.pt(5), cy), (cx + self.pt(5), cy)], fill=color, width=max(2, self.pt(1.8)))

    def metric_icon(self, kind: str, x: int, y: int, color=INDIGO):
        d = self.draw
        s = self.pt(7)
        if kind == "flame":
            d.polygon(
                [(x, y + s * 2), (x - s, y), (x, y - s), (x + s * 0.4, y), (x + s, y + s), (x, y + s * 2)],
                outline=color,
            )
        elif kind == "percent":
            fnt = font("semibold", 11 * self.s)
            d.text((x - self.pt(7), y - self.pt(8)), "%", font=fnt, fill=color)
        elif kind == "scale":
            d.ellipse((x - s, y - s, x + s, y + s), outline=color, width=max(2, self.pt(1.4)))
            d.line([(x, y), (x + s * 0.6, y - s * 0.4)], fill=color, width=max(2, self.pt(1.4)))
        elif kind == "heart":
            d.polygon(
                [
                    (x, y + s),
                    (x - s, y - s * 0.2),
                    (x - s * 0.2, y - s),
                    (x, y - s * 0.4),
                    (x + s * 0.2, y - s),
                    (x + s, y - s * 0.2),
                ],
                outline=color,
            )
        elif kind == "bed":
            d.line([(x - s, y + s), (x + s, y + s)], fill=color, width=max(2, self.pt(1.5)))
            d.line([(x - s, y + s), (x - s, y - s * 0.2)], fill=color, width=max(2, self.pt(1.5)))
            d.line([(x - s, y), (x + s * 0.2, y)], fill=color, width=max(2, self.pt(1.5)))
        elif kind == "walk":
            d.ellipse((x - self.pt(3), y - s, x + self.pt(3), y - s + self.pt(6)), outline=color, width=max(2, self.pt(1.3)))
            d.line([(x, y - self.pt(2)), (x, y + self.pt(4))], fill=color, width=max(2, self.pt(1.5)))
            d.line([(x, y), (x - s, y + s)], fill=color, width=max(2, self.pt(1.5)))
            d.line([(x, y), (x + s, y + s)], fill=color, width=max(2, self.pt(1.5)))

    def wrapped_text(self, text: str, fnt, fill, x, y, max_w) -> int:
        words = text.split()
        lines, cur = [], ""
        for word in words:
            trial = f"{cur} {word}".strip()
            tw, _ = text_size(self.draw, trial, fnt)
            if tw <= max_w:
                cur = trial
            else:
                if cur:
                    lines.append(cur)
                cur = word
        if cur:
            lines.append(cur)
        lh = int(fnt.size * 1.28)
        for i, line in enumerate(lines):
            self.draw.text((x, y + i * lh), line, font=fnt, fill=fill)
        return y + len(lines) * lh


def _draw_check(screen: Screen, cx: int, cy: int):
    screen.draw.ellipse((cx - screen.pt(13), cy - screen.pt(13), cx + screen.pt(13), cy + screen.pt(13)), fill=GREEN)
    screen.draw.line(
        [(cx - screen.pt(6), cy), (cx - screen.pt(1), cy + screen.pt(5)), (cx + screen.pt(7), cy - screen.pt(5))],
        fill=WHITE,
        width=max(2, screen.pt(2)),
    )


def render_home(width: int, height: int, mode: str) -> Image.Image:
    screen = Screen(width, height)
    screen.draw_status_bar()
    y = screen.large_title("Fitbit Health Sync", screen.status_h + screen.pt(8))
    content_w = screen.w - 2 * screen.side
    connected = mode == "connected"
    reconnect = mode == "reconnect"
    is_linked = connected or reconnect

    banner_h = screen.pt(84)
    screen.card(screen.side, y, content_w, banner_h)
    accent = GREEN if is_linked else ORANGE
    cx = screen.side + screen.pt(42)
    cy = y + banner_h // 2
    r = screen.pt(26)
    screen.draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(*accent, 40))
    if is_linked:
        _draw_check(screen, cx, cy)
        if connected:
            title, sub = "Connected to Google Health", "Auto-sync Google Health data to Apple Health"
        else:
            title, sub = "Connected to Fitbit (legacy)", "Reconnect with Google — Fitbit API ends in 18 days"
    else:
        screen.draw.ellipse((cx - screen.pt(13), cy - screen.pt(13), cx + screen.pt(13), cy + screen.pt(13)), fill=ORANGE)
        fnt = font("bold", 16 * screen.s)
        tw, th = text_size(screen.draw, "!", fnt)
        screen.draw.text((cx - tw // 2, cy - th // 2 - 1), "!", font=fnt, fill=WHITE)
        title, sub = "Not Connected", "Tap below to connect your account"
    tx = screen.side + screen.pt(72)
    screen.draw.text((tx, y + screen.pt(18)), title, font=font("semibold", 17 * screen.s), fill=LABEL)
    screen.wrapped_text(sub, font("regular", 13 * screen.s), SECONDARY, tx, y + screen.pt(42), content_w - screen.pt(118))
    if is_linked:
        screen._draw_named_icon("minus", screen.side + content_w - screen.pt(28), cy, RED)
    y += banner_h + screen.pt(16)

    gap = screen.pt(12)
    tile_w = (content_w - gap) // 2
    tile_h = screen.pt(96)
    last_sync = {
        "connected": "Aug 14, 2026 at 6:40 AM",
        "reconnect": "Aug 12, 2026 at 8:15 PM",
    }.get(mode, "Never")
    values = [
        ("Last Sync", last_sync, INDIGO, True),
        ("Status", "Idle", GREEN, False),
    ]
    for i, (label, value, color, clock) in enumerate(values):
        x = screen.side + i * (tile_w + gap)
        screen.card(x, y, tile_w, tile_h, radius=screen.pt(14))
        icon_y = y + screen.pt(16)
        if clock:
            screen.draw.arc(
                (x + screen.pt(14), icon_y, x + screen.pt(36), icon_y + screen.pt(22)),
                30,
                310,
                fill=color,
                width=max(2, screen.pt(1.8)),
            )
        else:
            ox, oy = x + screen.pt(25), icon_y + screen.pt(11)
            screen.draw.ellipse((ox - screen.pt(11), oy - screen.pt(11), ox + screen.pt(11), oy + screen.pt(11)), outline=color, width=max(2, screen.pt(1.8)))
            screen.draw.line(
                [(ox - screen.pt(5), oy), (ox - screen.pt(1), oy + screen.pt(4)), (ox + screen.pt(6), oy - screen.pt(5))],
                fill=color,
                width=max(2, screen.pt(1.8)),
            )
        screen.draw.text((x + screen.pt(14), y + screen.pt(46)), label, font=font("regular", 12 * screen.s), fill=SECONDARY)
        vf = font("semibold", 13 * screen.s)
        screen.wrapped_text(value, vf, LABEL, x + screen.pt(14), y + screen.pt(64), tile_w - screen.pt(24))
    y += tile_h + screen.pt(16)

    inner_x = screen.side + screen.pt(16)
    inner_w = content_w - screen.pt(32)
    blocks = []
    cursor = 0
    privacy = "Fitbit Health Sync collects health and fitness data (weight, body fat, steps, sleep, resting heart rate, and active energy) to write it into Apple Health on this device. Data stays on your phone."
    if reconnect:
        blocks.append(("banner", "The Fitbit Web API shuts down in 18 days (1 Sept 2026). Reconnect with Google to keep syncing."))
        blocks.append(("privacy", privacy))
        blocks.append(("btn", ("Reconnect with Google", "reconnect", ORANGE, True)))
    elif not connected:
        blocks.append(("privacy", privacy))
        blocks.append(("btn", ("Connect Google Health", "person", INDIGO, True)))
    blocks.append(("btn", ("Sync Now", "sync", INDIGO if is_linked else (174, 174, 178), is_linked)))

    # Measure height
    probe = ImageDraw.Draw(Image.new("RGB", (10, 10)))
    height_needed = screen.pt(32)
    for kind, payload in blocks:
        if kind in ("banner", "privacy"):
            fnt = font("semibold" if kind == "banner" else "regular", 13 * screen.s if kind == "banner" else 12 * screen.s)
            words = payload.split()
            lines, cur = 1, ""
            for word in words:
                trial = f"{cur} {word}".strip()
                tw, _ = text_size(probe, trial, fnt)
                if tw <= inner_w:
                    cur = trial
                else:
                    lines += 1
                    cur = word
            height_needed += int(fnt.size * 1.28) * lines + screen.pt(10)
        else:
            height_needed += screen.pt(64)
    screen.card(screen.side, y, content_w, height_needed)
    cursor = y + screen.pt(16)
    for kind, payload in blocks:
        if kind == "banner":
            cursor = screen.wrapped_text(payload, font("semibold", 13 * screen.s), ORANGE, inner_x, cursor, inner_w) + screen.pt(8)
        elif kind == "privacy":
            cursor = screen.wrapped_text(payload, font("regular", 12 * screen.s), SECONDARY, inner_x, cursor, inner_w) + screen.pt(12)
        else:
            label, icon, color, enabled = payload
            screen.primary_button(inner_x, cursor, inner_w, screen.pt(52), label, icon, color, enabled=enabled)
            cursor += screen.pt(64)
    y += height_needed + screen.pt(16)

    # Metrics
    screen.draw.text((screen.side + screen.pt(4), y), "Syncing Metrics", font=font("semibold", 17 * screen.s), fill=LABEL)
    y += screen.pt(34)
    chip_gap = screen.pt(10)
    chip_w = (content_w - chip_gap) // 2
    chip_h = screen.pt(40)
    grid_h = chip_h * 3 + chip_gap * 2 + screen.pt(32)
    screen.card(screen.side, y, content_w, grid_h)
    gy = y + screen.pt(16)
    for i, (name, kind) in enumerate(METRICS):
        col = i % 2
        row = i // 2
        x = screen.side + screen.pt(16) + col * (chip_w - screen.pt(8) + chip_gap)
        cy = gy + row * (chip_h + chip_gap)
        w = chip_w - screen.pt(16)
        screen.draw.rounded_rectangle(
            (x, cy, x + w, cy + chip_h),
            radius=screen.pt(10),
            fill=(88, 86, 214, 18),
            outline=(88, 86, 214, 40),
        )
        screen.metric_icon(kind, x + screen.pt(16), cy + chip_h // 2)
        screen.draw.text((x + screen.pt(30), cy + screen.pt(11)), name, font=font("medium", 12 * screen.s), fill=LABEL)

    screen.draw_tab_bar("Home")
    return screen.img


def render_launch(width: int, height: int) -> Image.Image:
    screen = Screen(width, height)
    screen.draw_status_bar()
    card_w = min(screen.w - 2 * screen.pt(32), screen.pt(360) if not screen.is_ipad else screen.pt(420))
    card_h = screen.pt(210)
    x = (screen.w - card_w) // 2
    y = (screen.h - card_h) // 2 - screen.pt(20)
    screen.card(x, y, card_w, card_h, radius=screen.pt(18))
    logo = Image.open(LOGO).convert("RGBA")
    logo_s = screen.pt(72)
    logo = logo.resize((logo_s, logo_s), Image.Resampling.LANCZOS)
    # Round the logo like an app icon
    mask = Image.new("L", logo.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, logo_s - 1, logo_s - 1), radius=int(logo_s * 0.22), fill=255)
    rounded = Image.new("RGBA", logo.size)
    rounded.paste(logo, mask=mask)
    lx = x + (card_w - logo_s) // 2
    screen.img.paste(rounded, (lx, y + screen.pt(24)), rounded)
    title = "Fitbit Health Sync"
    fnt = font("bold", 28 * screen.s)
    tw, _ = text_size(screen.draw, title, fnt)
    screen.draw.text((x + (card_w - tw) // 2, y + screen.pt(112)), title, font=fnt, fill=LABEL)
    sub = "Auto-sync Google Health to Apple Health"
    sf = font("regular", 17 * screen.s)
    sw, _ = text_size(screen.draw, sub, sf)
    if sw > card_w - screen.pt(32):
        sf = font("regular", 15 * screen.s)
        sw, _ = text_size(screen.draw, sub, sf)
    screen.draw.text((x + (card_w - sw) // 2, y + screen.pt(152)), sub, font=sf, fill=SECONDARY)
    return screen.img


def render_settings(width: int, height: int) -> Image.Image:
    screen = Screen(width, height)
    screen.draw_status_bar()
    y = screen.large_title("Settings", screen.status_h + screen.pt(8))
    content_w = screen.w - 2 * screen.side

    header = font("regular", 13 * screen.s)
    screen.draw.text((screen.side + screen.pt(4), y), "BACKGROUND SYNC INTERVAL", font=header, fill=SECONDARY)
    y += screen.pt(28)
    row_h = screen.pt(52)
    screen.card(screen.side, y, content_w, row_h, radius=screen.pt(12))
    # Segmented control
    pad = screen.pt(6)
    seg_x = screen.side + pad
    seg_y = y + pad
    seg_w = content_w - 2 * pad
    seg_h = row_h - 2 * pad
    screen.draw.rounded_rectangle((seg_x, seg_y, seg_x + seg_w, seg_y + seg_h), radius=screen.pt(8), fill=(118, 118, 128, 24))
    options = ["2h", "4h", "8h", "12h"]
    slot = seg_w / 4
    selected = 1
    for i, label in enumerate(options):
        sx = seg_x + int(i * slot)
        if i == selected:
            screen.draw.rounded_rectangle(
                (sx + 2, seg_y + 2, sx + int(slot) - 2, seg_y + seg_h - 2),
                radius=screen.pt(7),
                fill=WHITE,
            )
        fnt = font("semibold" if i == selected else "medium", 13 * screen.s)
        tw, th = text_size(screen.draw, label, fnt)
        screen.draw.text((sx + (slot - tw) / 2, seg_y + (seg_h - th) / 2 - 1), label, font=fnt, fill=LABEL)
    y += row_h + screen.pt(10)
    footer = "Background sync is best-effort. iOS decides when it actually runs — keep Background App Refresh on."
    y = screen.wrapped_text(footer, font("regular", 12 * screen.s), SECONDARY, screen.side + screen.pt(4), y, content_w) + screen.pt(22)

    screen.draw.text((screen.side + screen.pt(4), y), "METRICS TO SYNC", font=header, fill=SECONDARY)
    y += screen.pt(28)
    rows = [
        ("Body Weight", "scale"),
        ("Body Fat %", "percent"),
        ("Steps", "walk"),
        ("Sleep", "bed"),
        ("Resting Heart Rate", "heart"),
        ("Active Energy", "flame"),
    ]
    row_h = screen.pt(52)
    list_h = row_h * len(rows)
    screen.card(screen.side, y, content_w, list_h, radius=screen.pt(12))
    for i, (name, kind) in enumerate(rows):
        ry = y + i * row_h
        if i > 0:
            screen.draw.line(
                (screen.side + screen.pt(54), ry, screen.side + content_w - screen.pt(16), ry),
                fill=SEPARATOR,
                width=1,
            )
        screen.metric_icon(kind, screen.side + screen.pt(28), ry + row_h // 2)
        screen.draw.text((screen.side + screen.pt(52), ry + screen.pt(16)), name, font=font("regular", 17 * screen.s), fill=LABEL)
        # Toggle on
        tw, th = screen.pt(51), screen.pt(31)
        tx = screen.side + content_w - tw - screen.pt(16)
        ty = ry + (row_h - th) // 2
        screen.draw.rounded_rectangle((tx, ty, tx + tw, ty + th), radius=th // 2, fill=INDIGO)
        knob = th - screen.pt(4)
        screen.draw.ellipse((tx + tw - knob - 2, ty + 2, tx + tw - 2, ty + 2 + knob), fill=WHITE)

    screen.draw_tab_bar("Settings")
    return screen.img


def render_activity(width: int, height: int) -> Image.Image:
    screen = Screen(width, height)
    screen.draw_status_bar()
    y = screen.large_title("Activity", screen.status_h + screen.pt(8))
    content_w = screen.w - 2 * screen.side
    header = font("regular", 13 * screen.s)
    screen.draw.text((screen.side + screen.pt(4), y), "BACKGROUND", font=header, fill=SECONDARY)
    y += screen.pt(28)
    row_h = screen.pt(44)
    second_h = screen.pt(58)
    screen.card(screen.side, y, content_w, row_h + second_h, radius=screen.pt(12))
    screen.draw.text(
        (screen.side + screen.pt(16), y + screen.pt(12)),
        "Background App Refresh: On",
        font=font("regular", 15 * screen.s),
        fill=LABEL,
    )
    screen.draw.line(
        (screen.side + screen.pt(16), y + row_h, screen.side + content_w - screen.pt(16), y + row_h),
        fill=SEPARATOR,
        width=1,
    )
    screen.wrapped_text(
        "Last background sync: Aug 14, 2026 at 6:40 AM",
        font("regular", 15 * screen.s),
        LABEL,
        screen.side + screen.pt(16),
        y + row_h + screen.pt(10),
        content_w - screen.pt(32),
    )
    y += row_h + second_h + screen.pt(10)
    footer = "iOS decides when background sync runs. Open the app and tap Sync Now if you need an immediate update."
    y = screen.wrapped_text(footer, font("regular", 12 * screen.s), SECONDARY, screen.side + screen.pt(4), y, content_w) + screen.pt(20)

    screen.draw.text((screen.side + screen.pt(4), y), "LOGS", font=header, fill=SECONDARY)
    y += screen.pt(28)
    logs = [
        "[2026-08-14T06:40:12Z] Sync complete (32 samples).",
        "[2026-08-14T06:40:12Z]   Active Energy: 7",
        "[2026-08-14T06:40:12Z]   Body Fat %: 2",
        "[2026-08-14T06:40:12Z]   Body Weight: 3",
        "[2026-08-14T06:40:12Z]   Resting Heart Rate: 7",
        "[2026-08-14T06:40:12Z]   Sleep: 6",
        "[2026-08-14T06:40:12Z]   Steps: 7",
        "[2026-08-14T06:40:11Z] Starting manual sync...",
        "[2026-08-14T06:40:08Z] Google Health connected.",
        "[2026-08-14T06:40:08Z] BG schedule: On · next attempt in ≥4h (iOS decides)",
    ]
    row_h = screen.pt(36)
    list_h = min(row_h * len(logs), screen.h - y - screen.tab_h - screen.pt(16))
    screen.card(screen.side, y, content_w, list_h, radius=screen.pt(12))
    mf = font("mono", 11 * screen.s)
    for i, line in enumerate(logs):
        ry = y + i * row_h
        if ry + row_h > y + list_h:
            break
        if i > 0:
            screen.draw.line(
                (screen.side + screen.pt(16), ry, screen.side + content_w - screen.pt(16), ry),
                fill=SEPARATOR,
                width=1,
            )
        screen.draw.text((screen.side + screen.pt(16), ry + screen.pt(10)), line, font=mf, fill=LABEL)

    # Clear button in nav
    cf = font("regular", 17 * screen.s)
    tw, _ = text_size(screen.draw, "Clear", cf)
    screen.draw.text((screen.w - screen.side - tw, screen.status_h + screen.pt(18)), "Clear", font=cf, fill=(255, 59, 48))

    screen.draw_tab_bar("Activity")
    return screen.img


def save(img: Image.Image, name: str, width: int, height: int):
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / f"{name}-{width}x{height}.png"
    img.convert("RGB").save(path, "PNG", optimize=True)
    print(f"wrote {path}")


def main():
    # Remove previous Fitbit-era store shots so deliver overwrite is a clean set.
    if OUT.exists():
        for old in OUT.iterdir():
            if old.suffix.lower() in {".png", ".jpg", ".jpeg"}:
                old.unlink()

    screens = {
        "01-launch": render_launch,
        "02-home-connected": lambda w, h: render_home(w, h, "connected"),
        "03-home-reconnect": lambda w, h: render_home(w, h, "reconnect"),
        "04-settings": render_settings,
        "05-activity": render_activity,
    }
    for w, h in IPHONE_SIZES + IPAD_SIZES:
        for name, fn in screens.items():
            save(fn(w, h), name, w, h)


if __name__ == "__main__":
    main()
