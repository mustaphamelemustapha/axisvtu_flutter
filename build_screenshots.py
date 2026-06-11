import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

# Setup paths
downloads_dir = "/Users/mustaphamelemustapha/Downloads"
output_dir = os.path.join(downloads_dir, "app_store_screenshots")
os.makedirs(output_dir, exist_ok=True)

screenshots = [
    {
        "file": "IMG_5275.PNG",
        "title": "MELE DATA",
        "subtitle": "SECURE & INSTANT MOBILE UTILITIES"
    },
    {
        "file": "IMG_5276.PNG",
        "title": "BUY DATA & AIRTIME",
        "subtitle": "FASTEST TOP-UP EXPERIENCE"
    },
    {
        "file": "IMG_5277.PNG",
        "title": "SUPER CHEAP PLANS",
        "subtitle": "HIGHLY DISCOUNTED FOR ALL NETWORKS"
    },
    {
        "file": "IMG_5278.PNG",
        "title": "INSTANT RECEIPTS",
        "subtitle": "AUTOMATED REFUNDS & TRANSACTION PROOF"
    },
    {
        "file": "IMG_5279.PNG",
        "title": "DEDICATED WALLET",
        "subtitle": "AUTOMATED BANK TRANSFER FUNDING"
    },
    {
        "file": "IMG_5281.PNG",
        "title": "SECURE ACCESS",
        "subtitle": "BIOMETRIC SIGN-IN & TRANSACTION PIN PROTECTION"
    }
]

TARGET_WIDTH = 1242
TARGET_HEIGHT = 2688

def create_gradient_radial(width, height, center_color, edge_color):
    """Create a beautiful radial glow gradient."""
    # Create base dark image
    bg = Image.new("RGBA", (width, height), edge_color)
    
    # Create glow layer
    glow = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    
    # Draw large soft circles in the center/bottom
    center_x, center_y = width // 2, height // 2 + 300
    max_radius = 800
    for r in range(max_radius, 0, -8):
        alpha = int(90 * (1.0 - (r / max_radius) ** 1.5))
        glow_draw.ellipse(
            (center_x - r, center_y - r, center_x + r, center_y + r),
            fill=(center_color[0], center_color[1], center_color[2], alpha)
        )
        
    # Apply heavy blur to the glow layer for a smooth aura effect
    glow_blurred = glow.filter(ImageFilter.GaussianBlur(80))
    return Image.alpha_composite(bg, glow_blurred)

def make_screenshot_epic(info, index):
    src_path = os.path.join(downloads_dir, info["file"])
    if not os.path.exists(src_path):
        print(f"File not found: {src_path}")
        return
        
    print(f"Processing {info['file']} (Epic style)...")
    
    # Load user screenshot
    screenshot = Image.open(src_path).convert("RGBA")
    
    # Dynamic glow colors depending on the screen theme
    # Screen 1 & 5: Deep premium indigo/purple glow
    # Screen 2 & 3: Vibrant electric blue glow
    # Screen 4: Energetic teal/emerald glow
    glow_presets = [
        ((79, 70, 229, 255), (10, 15, 30, 255)),   # Purple/Indigo -> Dark Blue
        ((37, 99, 235, 255), (8, 12, 24, 255)),    # Electric Blue -> Dark Blue
        ((236, 72, 153, 255), (10, 12, 28, 255)),   # Hot Pink/Magenta -> Dark Blue
        ((16, 185, 129, 255), (6, 15, 22, 255)),   # Emerald/Teal -> Dark Green-Blue
        ((124, 58, 237, 255), (12, 10, 28, 255)),  # Deep Violet -> Dark Blue
        ((34, 197, 94, 255), (8, 24, 16, 255))     # Biometric Green -> Dark Green-Blue
    ]
    
    center_glow, base_bg = glow_presets[index]
    bg = create_gradient_radial(TARGET_WIDTH, TARGET_HEIGHT, center_glow, base_bg)
    
    # Draw text
    draw = ImageDraw.Draw(bg)
    
    try:
        font_title = ImageFont.truetype("/System/Library/Fonts/HelveticaNeue.ttc", 78, index=1) # Bold variant
        font_subtitle = ImageFont.truetype("/System/Library/Fonts/HelveticaNeue.ttc", 36, index=0)
    except IOError:
        font_title = ImageFont.load_default()
        font_subtitle = ImageFont.load_default()
        
    title_text = info["title"].upper()
    subtitle_text = info["subtitle"]
    
    # Title shadow/glow effect
    title_w = draw.textlength(title_text, font=font_title)
    title_x = (TARGET_WIDTH - title_w) / 2
    title_y = 200
    
    # Draw soft title backdrop text shadow
    draw.text((title_x + 2, title_y + 2), title_text, fill=(0, 0, 0, 80), font=font_title)
    draw.text((title_x, title_y), title_text, fill=(255, 255, 255, 255), font=font_title)
    
    # Draw subtitle with a premium accent line below it
    subtitle_w = draw.textlength(subtitle_text, font=font_subtitle)
    sub_x = (TARGET_WIDTH - subtitle_w) / 2
    sub_y = 310
    draw.text((sub_x, sub_y), subtitle_text, fill=(190, 210, 254, 255), font=font_subtitle)
    
    # Accent line
    line_y = sub_y + 60
    line_w = 120
    draw.line(((TARGET_WIDTH - line_w) / 2, line_y, (TARGET_WIDTH + line_w) / 2, line_y), fill=center_glow, width=6)
    
    # Resize screenshot (fits inside premium device mockup)
    orig_w, orig_h = screenshot.size
    new_w = 820
    new_h = int(orig_h * (new_w / orig_w))
    screenshot_resized = screenshot.resize((new_w, new_h), Image.Resampling.LANCZOS)
    
    # Crop screenshot slightly at the bottom if it is too tall (keep aspect ratio and height clean)
    max_screenshot_h = 1680
    if new_h > max_screenshot_h:
        screenshot_resized = screenshot_resized.crop((0, 0, new_w, max_screenshot_h))
        new_h = max_screenshot_h
        
    # Define bezel details
    bezel_thickness = 18
    corner_radius = 50
    
    # Make phone body image
    phone_w = new_w + bezel_thickness * 2
    phone_h = new_h + bezel_thickness * 2
    
    # Create the modern bezel frame
    phone = Image.new("RGBA", (phone_w, phone_h), (0, 0, 0, 0))
    p_draw = ImageDraw.Draw(phone)
    
    # Outer frame (bezel shell)
    p_draw.rounded_rectangle(
        (0, 0, phone_w, phone_h),
        radius=corner_radius,
        fill=(15, 15, 25, 255), # Dark matte titanium frame
        outline=(80, 90, 110, 255), # Metallic silver highlight
        width=3
    )
    
    # Insert screenshot inside the frame (rounded corners for screen)
    screen_mask = Image.new("L", (new_w, new_h), 0)
    screen_mask_draw = ImageDraw.Draw(screen_mask)
    screen_mask_draw.rounded_rectangle((0, 0, new_w, new_h), radius=corner_radius - bezel_thickness, fill=255)
    
    # Paste screenshot inside phone frame
    phone.paste(screenshot_resized, (bezel_thickness, bezel_thickness), mask=screen_mask)
    
    # Draw iPhone notch/dynamic island details at the top center of the screen
    island_w = 260
    island_h = 45
    island_x = (phone_w - island_w) // 2
    island_y = bezel_thickness + 12
    p_draw.rounded_rectangle((island_x, island_y, island_x + island_w, island_y + island_h), radius=22, fill=(0, 0, 0, 255))
    
    # Create a nice reflection/glare effect on the phone screen
    glare = Image.new("RGBA", (phone_w, phone_h), (0, 0, 0, 0))
    glare_draw = ImageDraw.Draw(glare)
    # Diagonal glare line
    glare_draw.polygon(
        [(0, 0), (phone_w // 2, 0), (0, phone_h // 2)], 
        fill=(255, 255, 255, 15)  # Soft semi-transparent white
    )
    phone = Image.alpha_composite(phone, glare)
    
    # Add a massive, realistic shadow underneath the entire phone
    shadow_blur = 35
    shadow_w = phone_w + shadow_blur * 2
    shadow_h = phone_h + shadow_blur * 2
    shadow = Image.new("RGBA", (shadow_w, shadow_h), (0, 0, 0, 0))
    s_draw = ImageDraw.Draw(shadow)
    
    # Draw a dark shadow rectangle
    s_draw.rounded_rectangle(
        (shadow_blur, shadow_blur, shadow_blur + phone_w, shadow_blur + phone_h),
        radius=corner_radius,
        fill=(0, 0, 0, 200) # dark shadow
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(shadow_blur))
    
    # Paste shadow and phone onto the radial background
    paste_x = (TARGET_WIDTH - phone_w) // 2
    paste_y = 480
    
    bg.paste(shadow, (paste_x - shadow_blur, paste_y - shadow_blur), mask=shadow)
    bg.paste(phone, (paste_x, paste_y), mask=phone)
    
    # Save the polished epic screenshot
    output_path = os.path.join(output_dir, f"screenshot_{index + 1}.png")
    bg.convert("RGB").save(output_path, "PNG")
    print(f"Saved: {output_path}")

# Run process for all screenshots
for idx, item in enumerate(screenshots):
    make_screenshot_epic(item, idx)

print("Epic App Store screenshots generated successfully!")
