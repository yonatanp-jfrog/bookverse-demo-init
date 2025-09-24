from PIL import Image, ImageDraw, ImageFont
import os

# Create a placeholder image
width, height = 1200, 600
image = Image.new('RGB', (width, height), color='#f8f9fa')
draw = ImageDraw.Draw(image)

# Try to use a system font, fallback to default
try:
    font_large = ImageFont.truetype("/System/Library/Fonts/Arial.ttf", 48)
    font_small = ImageFont.truetype("/System/Library/Fonts/Arial.ttf", 24)
except:
    font_large = ImageFont.load_default()
    font_small = ImageFont.load_default()

# Draw BookVerse placeholder
title = "BookVerse Platform"
subtitle = "Microservices Demo Application"
instruction = "Replace this placeholder with actual BookVerse homepage screenshot"

# Calculate text positions
title_bbox = draw.textbbox((0, 0), title, font=font_large)
title_width = title_bbox[2] - title_bbox[0]
title_x = (width - title_width) // 2

subtitle_bbox = draw.textbbox((0, 0), subtitle, font=font_small)
subtitle_width = subtitle_bbox[2] - subtitle_bbox[0]
subtitle_x = (width - subtitle_width) // 2

instruction_bbox = draw.textbbox((0, 0), instruction, font=font_small)
instruction_width = instruction_bbox[2] - instruction_bbox[0]
instruction_x = (width - instruction_width) // 2

# Draw text
draw.text((title_x, height//2 - 60), title, fill='#2d3748', font=font_large)
draw.text((subtitle_x, height//2), subtitle, fill='#4a5568', font=font_small)
draw.text((instruction_x, height//2 + 80), instruction, fill='#718096', font=font_small)

# Draw border
draw.rectangle([10, 10, width-10, height-10], outline='#e2e8f0', width=3)

# Save the image
image.save('images/bookverse-homepage.png')
print("Placeholder image created at images/bookverse-homepage.png")
