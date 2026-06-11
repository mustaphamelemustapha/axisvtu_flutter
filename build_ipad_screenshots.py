import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

# Setup paths
downloads_dir = "/Users/mustaphamelemustapha/Downloads"
output_dir = os.path.join(downloads_dir, "app_store_screenshots_ipad")
os.makedirs(output_dir, exist_ok=True)

screenshots = [
    {
        "file": "IMG_5275.PNG",
        "title": "MELE DATA ON IPAD",
        "subtitle": "MANAGE UTILITIES ON THE BIG SCREEN"
    },
    {
        "file": "IMG_5276.PNG",
        "title": "CHOOSE SERVICES INSTANTLY",
        "subtitle": "EASY NAVIGATION & OPERATOR SELECTION"
    },
    {
        "file": "IMG_5277.PNG",
        "title": "DISCOUNTED UTILITY PLANS",
        "subtitle": "CHOOSE THE BEST BUNDLES FOR MOBILE DATA"
    },
    {
        "file": "IMG_5278.PNG",
        "title": "DETAILED RECEIPTS",
        "subtitle": "TRANSACTION RECEIPTS ALWAYS ACCESSIBLE"
    },
    {
        "file": "IMG_5279.PNG",
        "title": "FUND AUTOMATICALLY",
        "subtitle": "DEDICATED AUTO-FUNDING BANK ACCOUNTS"
    },
    {
        "file": "IMG_5281.PNG",
        "title": "SECURE TRANSACTION LOCK",
        "subtitle": "MAXIMUM BIOMETRIC AND PIN SECURITY"
    }
]

# 13-inch iPad Pro resolution: 2048 x 2732
TARGET_WIDTH = 2048
TARGET_HEIGHT = 2732

def create_gradient_radial(width, height, center_color, edge_color):
    """Create a beautiful radial glow gradient for iPad."""
    bg = Image.new("RGBA", (width, height), edge_color)
    glow = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    
    center_x, center_y = width // 2, height // 2 + 400
    max_radius = 1200
    for r in range(max_radius, 0, -12):
        alpha = int(90 * (1.0 - (r / max_radius) ** 1.5))
        glow_draw.ellipse(
            (center_x - r, center_y - r, center_x + r, center_y + r),
            fill=(center_color[0], center_color[1], center_color[2], alpha)
        )
        
    glow_blurred = glow.filter(ImageFilter.GaussianBlur(100))
    return Image.alpha_composite(bg, glow_blurred)

def make_ipad_screenshot(info, index):
    src_path = os.path.join(downloads_dir, info["file"])
    if not os.path.exists(src_path):
        print(f"File not found: {src_path}")
        return
        
    print(f"Processing iPad {info['file']}...")
    
    # Load user screenshot
    screenshot = Image.open(src_path).convert("RGBA")
    
    # Glow presets
    glow_presets = [
        ((79, 70, 229, 255), (10, 15, 30, 255)),   # Purple
        ((37, 99, 235, 255), (8, 12, 24, 255)),    # Blue
        ((236, 72, 153, 255), (10, 12, 28, 255)),   # Pink
        ((16, 185, 129, 255), (6, 15, 22, 255)),   # Green
        ((124, 58, 237, 255), (12, 10, 28, 255)),  # Violet
        ((34, 197, 94, 255), (8, 24, 16, 255))     # Bright Green
    ]
    
    center_glow, base_bg = glow_presets[index]
    bg = create_gradient_radial(TARGET_WIDTH, TARGET_HEIGHT, center_glow, base_bg)
    
    # Draw Text
    draw = ImageDraw.Draw(bg)
    try:
        font_title = ImageFont.truetype("/System/Library/Fonts/HelveticaNeue.ttc", 110, index=1) # Bold
        font_subtitle = ImageFont.truetype("/System/Library/Fonts/HelveticaNeue.ttc", 50, index=0)
    except IOError:
        font_title = ImageFont.load_default()
        font_subtitle = ImageFont.load_default()
        
    title_text = info["title"].upper()
    subtitle_text = info["subtitle"]
    
    # Title
    title_w = draw.textlength(title_text, font=font_title)
    title_x = (TARGET_WIDTH - title_w) / 2
    title_y = 220
    draw.text((title_x + 3, title_y + 3), title_text, fill=(0, 0, 0, 80), font=font_title)
    draw.text((title_x, title_y), title_text, fill=(255, 255, 255, 255), font=font_title)
    
    # Subtitle
    subtitle_w = draw.textlength(subtitle_text, font=font_subtitle)
    sub_x = (TARGET_WIDTH - subtitle_w) / 2
    sub_y = 360
    draw.text((sub_x, sub_y), subtitle_text, fill=(190, 210, 254, 255), font=font_subtitle)
    
    # Accent line
    line_y = sub_y + 80
    line_w = 180
    draw.line(((TARGET_WIDTH - line_w) / 2, line_y, (TARGET_WIDTH + line_w) / 2, line_y), fill=center_glow, width=8)
    
    # iPad Pro Mockup Size (4:3 aspect ratio bezel, but framing the app inside a vertical tablet body)
    # The iPad is wider, so we scale the screen nicely
    # Let's frame the portrait screenshot centered inside the iPad Pro screen
    # Resizing screen: width = 1100
    orig_w, orig_h = screenshot.size
    new_w = 1100
    new_h = int(orig_h * (new_w / orig_w))
    screenshot_resized = screenshot.resize((new_w, new_h), Image.Resampling.LANCZOS)
    
    # Crop screen to clean tablet proportions if needed
    max_h = 1750
    if new_h > max_h:
        screenshot_resized = screenshot_resized.crop((0, 0, new_w, max_h))
        new_h = max_h
        
    # Bezel
    bezel_thickness = 32
    corner_radius = 65
    
    phone_w = new_w + bezel_thickness * 2
    phone_h = new_h + bezel_thickness * 2
    
    phone = Image.new("RGBA", (phone_w, phone_h), (0, 0, 0, 0))
    p_draw = ImageDraw.Draw(phone)
    
    # Outer tablet frame
    p_draw.rounded_rectangle(
        (0, 0, phone_w, phone_h),
        radius=corner_radius,
        fill=(18, 18, 28, 255),
        outline=(90, 100, 120, 255),
        width=4
    )
    
    # Mask for tablet screen
    screen_mask = Image.new("L", (new_w, new_h), 0)
    screen_mask_draw = ImageDraw.Draw(screen_mask)
    screen_mask_draw.rounded_rectangle((0, 0, new_w, new_h), radius=corner_radius - bezel_thickness, fill=255)
    
    phone.paste(screenshot_resized, (bezel_thickness, bezel_thickness), mask=screen_mask)
    
    # iPad Camera Notch / Details
    camera_radius = 8
    camera_x = phone_w // 2
    camera_y = bezel_thickness // 2
    p_draw.ellipse((camera_x - camera_radius, camera_y - camera_radius, camera_x + camera_radius, camera_y + camera_radius), fill=(0, 0, 0, 255))
    
    # Glare
    glare = Image.new("RGBA", (phone_w, phone_h), (0, 0, 0, 0))
    glare_draw = ImageDraw.Draw(glare)
    glare_draw.polygon([(0, 0), (phone_w // 2, 0), (0, phone_h // 2)], fill=(255, 255, 255, 12))
    phone = Image.alpha_composite(phone, glare)
    
    # Shadow
    shadow_blur = 45
    shadow_w = phone_w + shadow_blur * 2
    shadow_h = phone_h + shadow_blur * 2
    shadow = Image.new("RGBA", (shadow_w, shadow_h), (0, 0, 0, 0))
    s_draw = ImageDraw.Draw(shadow)
    s_draw.rounded_rectangle(
        (shadow_blur, shadow_blur, shadow_blur + phone_w, shadow_blur + phone_h),
        radius=corner_radius,
        fill=(0, 0, 0, 180)
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(shadow_blur))
    
    # Paste
    paste_x = (TARGET_WIDTH - phone_w) // 2
    paste_y = 560
    
    bg.paste(shadow, (paste_x - shadow_blur, paste_y - shadow_blur), mask=shadow)
    bg.paste(phone, (paste_x, paste_y), mask=phone)
    
    output_path = os.path.join(output_dir, f"ipad_screenshot_{index + 1}.png")
    bg.convert("RGB").save(output_path, "PNG")
    print(f"Saved iPad screenshot: {output_path}")

# Run process
for idx, item in enumerate(screenshots):
    make_ipad_screenshot(item, idx)

print("All iPad screenshots generated successfully!")
