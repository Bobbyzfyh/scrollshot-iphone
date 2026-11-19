from pathlib import Path
import json
from PIL import Image, ImageDraw

assets = Path(__file__).resolve().parents[1] / 'Scrollshot/Assets.xcassets'
icon = assets / 'AppIcon.appiconset'
icon.mkdir(parents=True, exist_ok=True)
image = Image.new('RGB', (1024, 1024), '#234ed4')
draw = ImageDraw.Draw(image)
draw.rounded_rectangle((255, 128, 769, 889), radius=72, fill='#fffdf5')
for y, right in [(268, 654), (354, 618), (440, 655)]:
    draw.rounded_rectangle((350, y, right, y + 28), radius=14, fill='#9fb5fa')
draw.line((512, 548, 512, 738), fill='#234ed4', width=35)
draw.line((426, 666, 512, 750, 598, 666), fill='#234ed4', width=35)
image.save(icon / 'AppIcon.png')
(assets / 'Contents.json').write_text(json.dumps({'info': {'author': 'xcode', 'version': 1}}, indent=2), encoding='utf-8')
(icon / 'Contents.json').write_text(json.dumps({'images': [{'filename': 'AppIcon.png', 'idiom': 'universal', 'platform': 'ios', 'size': '1024x1024'}], 'info': {'author': 'xcode', 'version': 1}}, indent=2), encoding='utf-8')
print('Generated original app icon.')
