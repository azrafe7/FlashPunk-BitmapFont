FlashPunk-BitmapFont
====================

`BitmapFont` and `BitmapText` classes for [FlashPunk](http://useflashpunk.net/) 1.7.x

Code adapted/improved for FlashPunk from [https://github.com/Beeblerox/BitmapFont](https://github.com/Beeblerox/BitmapFont).

Supports various formats of BitmapFonts:

 - XML/AngelCode's (bitmap + meta data in xml file)
 - Pixelizer (bitmap + list of characters supported)
 - Serialized (a plain string defining the font data)
 
`BitmapText` exposes various properties to change the visual style of the text (color, outline, multiline, fixedWidth, shadow, align, etc.).
Just remember that some of them need to also enable the respective flag. Ex.:

```as3
	...
    bitmapText.outlineColor = 0xFF0000;		// red outline
	bitmapText.outline = true;				// <- enable the outline
	...
```

You can find a simple demo [here](https://dl.dropboxusercontent.com/u/32864004/dev/FPDemo/BitmapFontTest.swf)

In the demo a couple (triple?) of _free_ fonts have been used:

 - [New Super Mario Font U](http://www.dafont.com/new-super-mario-font-u.font)
 - [Alagard](http://www.dafont.com/alagard.font)
 - [Round Font](https://github.com/johanp/Pixelizer)
 
Some excellent and free tools you may find useful for exporting font data from ttf:

 - [BMFont/AngelCode](http://www.angelcode.com/products/bmfont/)
 - [Littera](http://kvazars.com/littera/)
 
`BitmapText` extends `Image` so you're still free to scale, rotate, etc. ( but be warned that result may be very _blurred/pixelly_ )

Check `TestWorld.as` to see how to use it.


It needs more testing so if you find any bugs I'll be glad to here it from you.