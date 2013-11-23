package {
	import flash.display.BitmapData;
	import flash.geom.ColorTransform;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.utils.ByteArray;
	import flash.utils.Dictionary;
	import net.flashpunk.FP;


	/**
	 * Holds information and bitmap glyphs for a bitmap font.
	 * 
	 * Adapted from Beeblerox work (which built upon Pixelizer implementation).
	 * 
	 * @see https://github.com/Beeblerox/BitmapFont
	 */
	public class BitmapFont 
	{
		
		/**
		 * Creates a new bitmap font (if you pass valid parameters fromXML() is called).
		 * 
		 * Otherwise you can use one of the from_ methods to actually load the font from other formats.
		 * 
		 * Ex.:
		 *     var font = new BitmapFont(BM_DATA, XML_DATA);
		 *     // or
		 *     var font = new BitmapFont().fromPixelizer(BM_DATA2, GLYPHS);
		 *     // or
		 *     var font = new BitmapFont().fromSerialized(FONT_DATA);
		 * 
		 * @param	source		Font source image. A BitmapData object or embedded BitmapData class.
		 * @param	XMLData		Font data. An XML object or embedded XML class.
		 */
		public function BitmapFont(source:* = null, XMLData:* = null) 
		{
			if (_storedFonts == null) _storedFonts = new Dictionary(true);
			
			_colorTransform = new ColorTransform();
			
			if (source != null && XMLData != null) fromXML(source, XMLData);
		}
		
		/**
		 * Loads font data from Pixelizer's format.
		 * @param	source			Font source image. A BitmapData object or embedded BitmapData class.
		 * @param	letters			All letters (in sequential order) contained in this font.
		 * @param	glyphBGColor	An additional background color to remove (uint) - often 0xFF202020 is used for glyphs background.
		 * @return this BitmapFont
		 */
		public function fromPixelizer(source:*, letters:String, glyphBGColor:* = null):BitmapFont
		{
			var bitmapData:BitmapData;

			reset();
			
			if (source is Class) bitmapData = FP.getBitmap(source);
			else if (source is BitmapData) bitmapData = source;
			if (bitmapData == null) throw new Error("Font source must be of type BitmapData or Class.");

			_glyphString = letters;
			
			var tileRects:Vector.<Rectangle> = new Vector.<Rectangle>();
			var result:BitmapData = preparePixelizerBMD(bitmapData, tileRects, glyphBGColor);
			var currRect:Rectangle;
			
			for (var letterID:int = 0; letterID < tileRects.length; letterID++)
			{
				currRect = tileRects[letterID];
				
				// create glyph
				var bd:BitmapData = new BitmapData(Math.floor(currRect.width), Math.floor(currRect.height), true, 0x0);
				bd.copyPixels(result, currRect, FP.zero, null, null, true);
				
				// store glyph
				setGlyph(_glyphString.charCodeAt(letterID), bd);
			}
			
			if (result != null) {
				result.dispose();
				result = null;
			}
			
			return this;
		}
		
		/**
		 * Loads font data from XML (AngelCode's) format.
		 * @param	source		Font source image. A BitmapData object or embedded BitmapData class.
		 * @param	XMLData		Font data. An XML object or embedded XML class.
		 * @return	this BitmapFont.
		 */
		public function fromXML(source:*, XMLData:*):BitmapFont
		{
			var bitmapData:BitmapData;
			var xmlData:XML;
			
			reset();
			
			if (source is Class) bitmapData = FP.getBitmap(source);
			else if (source is BitmapData) bitmapData = source;
			if (bitmapData == null) throw new Error("Font source must be of type BitmapData or Class.");

			if (XMLData is Class) xmlData = FP.getXML(XMLData);
			else if (XMLData is XML) xmlData = XMLData;
			if (xmlData == null) throw new Error("Font XML data must be of type XML or Class.");

			_glyphString = "";
			
			var chars:XMLList = xmlData.chars[0].char;
			var numLetters:int = chars.length();
			var rect:Rectangle = new Rectangle();
			var point:Point = new Point();
			var char:XML;
			var bd:BitmapData;
			var charString:String;
			
			for (var i:int = 0; i < numLetters; i++) {
				char = chars[i];
				charString = String.fromCharCode(char.@id);
				_glyphString += charString;
				
				rect.x = int(char.@x);
				rect.y = int(char.@y);
				rect.width = int(char.@width);
				rect.height = int(char.@height);
				
				point.x = int(char.@xoffset);
				point.y = int(char.@yoffset);
				
				var xadvance:int = int(char.@xadvance);
				var charWidth:int = xadvance;
				
				if (rect.width > xadvance)
				{
					charWidth = int(rect.width);
					point.x = 0;
				}
				
				// create glyph
				if (charString != " " && charString != "" && rect.height > 0)
				{
					bd = new BitmapData(charWidth, int(char.@height) + int(char.@yoffset), true, 0x0);
				}
				else
				{
					bd = new BitmapData(charWidth, 1, true, 0x0);
				}
				
				bd.copyPixels(bitmapData, rect, point, null, null, true);
				
				// store glyph
				setGlyph(char.@id, bd);
			}			
			
			return this;
		}

		/**
		 * Serializes the font as a bit font by encoding it into a big string (only extended-ASCII glyphs between in the range [32..254] are valid, no alpha is encoded, pixels are either on (if alpha == 1) or off (otherwise)).
		 * 
		 * Format:
		 * 	   [fromCharCode(numGlyphs + 32)][fromCharCode(maxWidth + 32)][fromCharCode(height + 32)] then for each glyph [char][fromCharCode(width + 32)][fromCharCode(height + 32)][series of 0 or 1 for each pixel of the glyph]...
		 * 
		 *     the resulting string is then written to a ByteArray and escaped.
		 * 
		 * @return	Serialized font string.
		 */
		public function serialize():String 
		{
			var charCode:int;
			var glyph:BitmapData;
			var nGlyphs:int = _glyphString.length;
			var output:String = "";
			
			output += String.fromCharCode(nGlyphs + 32);
			output += String.fromCharCode(maxWidth + 32);
			output += String.fromCharCode(height + 32);

			for (var i:int = 0; i < nGlyphs; i++) 
			{
				charCode = _glyphString.charCodeAt(i);
				glyph = _glyphs[charCode];
				
				output += _glyphString.charAt(i);
				output += String.fromCharCode(glyph.width + 32);
				output += String.fromCharCode(glyph.height + 32);
				
				for (var py:int = 0; py < glyph.height; py++) 
				{
					for (var px:int = 0; px < glyph.width; px++) 
					{
						var pixel:uint = glyph.getPixel32(px, py) & 0xFF000000;
						output += (pixel == 0xFF000000) ? "1" : "0";
					}
				}
			}
			
			var byteArray:ByteArray = new ByteArray();
			byteArray.writeUTF(output);
			return escape(byteArray.toString());
		}

		/**
		 * Deserializes and loads a font encoded with serialize().
		 * 
		 * @return	The deserialized BitmapFont.
		 */
		public function fromSerialized(encodedFont:String):BitmapFont 
		{
			reset();
			
			var byteArray:ByteArray = new ByteArray();
			byteArray.writeUTF(unescape(encodedFont));
			byteArray.position = 0;
			var deserialized:String = byteArray.readUTF().toString();
			
			var letters:String = "";
			var letterPos:int = 0;
			var i:int = 2;	// skip first two bytes
			
			var n:int = deserialized.charCodeAt(i) - 32;	// number of glyphs
			var w:int = deserialized.charCodeAt(++i) - 32;	// max width of single glyph
			var h:int = deserialized.charCodeAt(++i) - 32;	// max height of single glyph
			
			var size:int = int(Math.ceil(Math.sqrt(n * (w + 1) * (h + 1))) + Math.max(w, h));
			var rows:int = int(size / (h + 1));
			var cols:int = int(size / (w + 1));
			var bd:BitmapData = new BitmapData(size, size, true, 0xFFFF0000);
			var len:int = deserialized.length;
			
			while (i < len)
			{
				letters += deserialized.charAt(++i);
				
				if (i >= len) break;
				
				var gw:int = deserialized.charCodeAt(++i) - 32;
				var gh:int = deserialized.charCodeAt(++i) - 32;
				for (var py:int = 0; py < gh; py++) 
				{
					for (var px:int = 0; px < gw; px++) 
					{
						i++;
						
						var pixelOn:Boolean = deserialized.charAt(i) == "1"; 
						bd.setPixel32(1 + (letterPos % cols) * (w + 1) + px, 1 + int(letterPos / cols) * (h + 1) + py, pixelOn ? 0xFFFFFFFF : 0x0);
					}
				}
				
				letterPos++;
			}
			
			var font:BitmapFont = new BitmapFont().fromPixelizer(bd, letters);
			bd.dispose();
			bd = null;
			
			return font;
		}
		
		/**
		 * Internal function. Resets current font
		 */
		private function reset():void
		{
			dispose();
			_maxWidth = 0;
			_maxHeight = 0;
			_glyphs = new Array();
			_glyphString = "";
		}
		
		/**
		 * Adjusts the font BitmapData making background transparent and stores glyphs positions in the rects array.
		 * 
		 * @param	bitmapData		The BitmapData containing the font glyphs.
		 * @param	rects			A Vector that will be populate with Rectangles representing glyphs positions and dimensions.
		 * @param	glyphBGColor	An additional background color to remove (uint) - often 0xFF202020 is used for glyphs background.
		 * @return The modified BitmapData.
		 */
		private function preparePixelizerBMD(bitmapData:BitmapData, rects:Vector.<Rectangle>, glyphBGColor:* = null):BitmapData
		{
			var bgColor:int = bitmapData.getPixel(0, 0);	// general background color (sampled from the top-left pixel)
			var cy:int = 0;
			var cx:int;
			
			while (cy < bitmapData.height)
			{
				var rowHeight:int = 0;
				cx = 0;
				
				while (cx < bitmapData.width)
				{
					if (int(bitmapData.getPixel(cx, cy)) != bgColor) 
					{
						// found non bg pixel
						var gx:int = cx;
						var gy:int = cy;
						
						// find width and height of glyph
						while (int(bitmapData.getPixel(gx, cy)) != bgColor)
						{
							gx++;
						}
						
						while (int(bitmapData.getPixel(cx, gy)) != bgColor)
						{
							gy++;
						}
						
						var gw:int = gx - cx;
						var gh:int = gy - cy;
						
						rects.push(new Rectangle(cx, cy, gw, gh));
						
						// store max size
						if (gh > rowHeight) 
						{
							rowHeight = gh;
						}
						if (gh > _maxHeight) 
						{
							_maxHeight = gh;
						}
						
						// go to next glyph
						cx += gw;
					}
					
					cx++;
				}
				// next row
				cy += (rowHeight + 1);
			}
			
			var resultBitmapData:BitmapData = bitmapData.clone();
			
			// remove background color
			
			var bgColor32:uint = bitmapData.getPixel32(0, 0);
			
			resultBitmapData.threshold(bitmapData, bitmapData.rect, FP.zero, "==", bgColor32, 0x00000000, 0xFFFFFFFF, true);
			
			if (glyphBGColor != null)
				resultBitmapData.threshold(resultBitmapData, resultBitmapData.rect, FP.zero, "==", glyphBGColor, 0x00000000, 0xFFFFFFFF, true);
			
			return resultBitmapData;
		}
		
		/**
		 * Prepares and returns a set of glyphs using the specified parameters.
		 */
		public function getPreparedGlyphs(scale:Number, color:int, useColorTransform:Boolean = true):Array
		{
			var result:Array = new Array();
			
			FP.matrix.identity();
			FP.matrix.scale(scale, scale);
			
			var colorMultiplier:Number = 0.00392;
			_colorTransform.redOffset = 0;
			_colorTransform.greenOffset = 0;
			_colorTransform.blueOffset = 0;
			_colorTransform.redMultiplier = (color >> 16) * colorMultiplier;
			_colorTransform.greenMultiplier = (color >> 8 & 0xff) * colorMultiplier;
			_colorTransform.blueMultiplier = (color & 0xff) * colorMultiplier;
			
			var glyph:BitmapData;
			var preparedGlyph:BitmapData;
			for (var i:int = 0; i < _glyphs.length; i++)
			{
				glyph = _glyphs[i];
				var bdWidth:int;
				var bdHeight:int;
				if (glyph != null)
				{
					if (scale > 0)
					{
						bdWidth = Math.ceil(glyph.width * scale);
						bdHeight = Math.ceil(glyph.height * scale);
					}
					else
					{
						bdWidth = 1;
						bdHeight = 1;
					}
					
					preparedGlyph = new BitmapData(bdWidth, bdHeight, true, 0x00000000);
					if (useColorTransform)
					{
						preparedGlyph.draw(glyph,  FP.matrix, _colorTransform);
					}
					else
					{
						preparedGlyph.draw(glyph,  FP.matrix);
					}
					result[i] = preparedGlyph;
				}
			}
			
			return result;
		}
		
		/** Returns a string with all the supported glyphs. */
		public function get supportedGlyphs():String {
			return _glyphString;
		}
		
		/**
		 * Clears all resources used by the font.
		 */
		public function dispose():void 
		{
			if (_glyphs != null) {
				var bmd:BitmapData;
				for (var i:int = 0; i < _glyphs.length; i++) 
				{
					bmd = _glyphs[i];
					if (bmd != null) 
					{
						_glyphs[i].dispose();
					}
				}
				_glyphs = null;
			}
		}
		
		/**
		 * Sets the BitmapData for a specific glyph.
		 */
		private function setGlyph(charID:int, bitmapData:BitmapData):void 
		{
			if (_glyphs[charID] != null) 
			{
				_glyphs[charID].dispose();
			}
			
			_glyphs[charID] = bitmapData;
			
			if (bitmapData.width > _maxWidth) 
			{
				_maxWidth = bitmapData.width;
			}
			if (bitmapData.height > _maxHeight) 
			{
				_maxHeight = bitmapData.height;
			}
		}
		
		/**
		 * Renders a string of text onto bitmap data using the font.
		 * @param	bitmapData	Where to render the text.
		 * @param	text		Test to render.
		 * @param	color		Color of text to render.
		 * @param	offsetX		X position of text output.
		 * @param	offsetY		Y position of text output.
		 */
		public function render(bitmapData:BitmapData, fontData:Array, text:String, color:uint, offsetX:Number, offsetY:Number, letterSpacing:int):void 
		{
			FP.point.x = offsetX;
			FP.point.y = offsetY;

			var glyph:BitmapData;
			
			for (var i:int = 0; i < text.length; i++) 
			{
				var charCode:int = text.charCodeAt(i);

				glyph = fontData[charCode];
				if (glyph != null) 
				{
					bitmapData.copyPixels(glyph, glyph.rect, FP.point, null, null, true);
					FP.point.x += glyph.width + letterSpacing;
				}
			}
		}
			
		/**
		 * Returns the width of a certain test string.
		 * @param	text			String to measure.
		 * @param	letterSpacing	Distance between letters.
		 * @param	fontScale		"size" of the font.
		 * @return	Width in pixels.
		 */
		public function getTextWidth(text:String, letterSpacing:* = null, fontScale:* = null):int 
		{
			var w:int = 0;
			letterSpacing = letterSpacing != null ? letterSpacing : 0;
			fontScale = fontScale != null ? fontScale : 1.0;
			
			var textLength:int = text.length;
			for (var i:int = 0; i < textLength; i++) 
			{
				var charCode:int = text.charCodeAt(i);
				var glyph:BitmapData = _glyphs[charCode];
				if (glyph != null) 
				{
					w += glyph.width;
				}
			}
			
			w = Math.round(w * fontScale);
			
			if (textLength > 1)
			{
				w += (textLength - 1) * letterSpacing;
			}
			
			return w;
		}
		
		/**
		 * Returns the height of font in pixels.
		 */
		public function get height():int 
		{
			return _maxHeight;
		}
		
		/**
		 * Returns the width of the largest glyph.
		 */
		public function get maxWidth():int 
		{
			return _maxWidth;
		}
		
		/**
		 * Returns number of glyphs available in this font.
		 * @return Number of glyphs available in this font.
		 */
		public function get numGlyphs():int 
		{
			return _glyphString.length;
		}
		
		/**
		 * Stores a font for global use using an identifier.
		 * @param	fontName	String identifer for the font.
		 * @param	font		Font to store.
		 */
		public static function store(fontName:String, font:BitmapFont):void 
		{
			_storedFonts[fontName] = font;
		}
		
		/**
		 * Retrieves a font previously stored.
		 * @param	fontName	Identifier of font to fetch.
		 * @return	Stored font, or null if no font was found.
		 */
		public static function fetch(fontName:String):BitmapFont 
		{
			if (_storedFonts == null) return null;
			var f:BitmapFont = _storedFonts[fontName];
			return f;
		}

		/**
		 * Creates and stores the default font for later use.
		 */
		public static function createDefaultFont():void
		{
			var defaultFont:BitmapFont = new BitmapFont().fromSerialized(DEFAULT_FONT_DATA);
			BitmapFont.store("default", defaultFont);
		}

		/** Serialized default font data. (04B_03__.ttf @ 8px) */
		public static const DEFAULT_FONT_DATA:String = "%0A%FF%7F%26%28%20%24%210000%21%22%26001010100010%22%24%240000101010100000%23%26%26000000010100111110010100111110010100%24%25%2700000001000111011000001101110000100%25%26%26000000100100000100001000010000010010%26%26%26000000011000100000011010100100011010%27%22%2400101000%28%23%26000010100100100010%29%23%26000100010010010100*%24%2500001010010010100000+%24%26000000000100111001000000%2C%23%27000000000000000010100-%24%2500000000000011100000.%22%26000000000010/%26%260000000000100001000010000100001000000%25%260000001100100101001010010011001%23%260001100100100100102%25%260000011100000100110010000111103%25%260000011100000100110000010111004%25%260000000100011001010011110001005%25%260000011110100001110000010111006%25%260000001100100001110010010011007%25%260000011110000100010001000010008%25%260000001100100100110010010011009%25%26000000110010010011100001001100%3A%22%26000010001000%3B%22%26000010001010%3C%24%26000000100100100001000010%3D%24%26000000001110000011100000%3E%24%26000010000100001001001000%3F%25%26000001110000010011000000001000@%26%26000000011100100010101110101010011100A%25%26000000110010010100101111010010B%25%26000001110010010111001001011100C%24%26000001101000100010000110D%25%26000001110010010100101001011100E%24%26000011101000111010001110F%24%26000011101000111010001000G%25%26000000111010000101101001001110H%25%26000001001010010111101001010010I%24%26000011100100010001001110J%25%26000000011000010000101001001100K%25%26000001001010100110001010010010L%24%26000010001000100010001110M%26%26000000100010110110101010100010100010N%25%26000001001011010101101001010010O%25%26000000110010010100101001001100P%25%26000001110010010100101110010000Q%25%2700000011001001010010100100110000010R%25%26000001110010010100101110010010S%25%26000000111010000011000001011100T%24%26000011100100010001000100U%25%26000001001010010100101001001100V%25%26000001001010010101001010001000W%26%26000000100010101010101010101010010100X%25%26000001001010010011001001010010Y%25%26000001001010010011100001001100Z%24%26000011100010010010001110%5B%23%26000110100100100110%5C%26%26000000100000010000001000000100000010%5D%23%26000110010010010110%5E%24%240000010010100000_%25%26000000000000000000000000011110%60%23%24000100010000a%25%26000000000001110100101001001110b%25%26000001000011100100101001011100c%24%26000000000110100010000110d%25%26000000001001110100101001001110e%25%26000000000001100101101100001100f%24%26000000100100111001000100g%25%280000000000011101001010010011100001001100h%25%26000001000011100100101001010010i%22%26001000101010j%23%28000010000010010010010100k%25%26000001000010010101001110010010l%22%26001010101010m%26%26000000000000111100101010101010101010n%25%26000000000011100100101001010010o%25%26000000000001100100101001001100p%25%280000000000111001001010010111001000010000q%25%280000000000011101001010010011100001000010r%24%26000000001010110010001000s%25%26000000000001110110000011011100t%24%26000001001110010001000010u%25%26000000000010010100101001001110v%25%26000000000010010100101010001000w%26%26000000000000101010101010010100010100x%24%26000000001010010001001010y%25%280000000000100101001010010011100001001100z%25%26000000000011110001000100011110%7B%24%26000001100100100001000110%7C%22%26001010101010%7D%24%26000011000100001001001100%7E%25%2400000010101010000000";

		
		// BitmapFont information
		protected var _glyphs:Array;

		protected var _glyphString:String;
		protected var _maxHeight:int = 0;
		protected var _maxWidth:int = 0;
		
		protected var _colorTransform:ColorTransform;
		
		// BitmapFonts cache
		protected static var _storedFonts:Dictionary;
	}
}