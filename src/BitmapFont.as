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
			var byteArray:ByteArray = new ByteArray();
			
			byteArray.writeShort(nGlyphs);
			byteArray.writeShort(maxWidth);
			byteArray.writeShort(height);

			for (var i:int = 0; i < nGlyphs; i++) 
			{
				charCode = _glyphString.charCodeAt(i);
				glyph = _glyphs[charCode];
				
				byteArray.writeUTF(_glyphString.charAt(i));
				byteArray.writeShort(glyph.width);
				byteArray.writeShort(glyph.height);
				
				for (var py:int = 0; py < glyph.height; py++) 
				{
					for (var px:int = 0; px < glyph.width; px++) 
					{
						var pixel:uint = glyph.getPixel32(px, py) & 0xFF000000;
						byteArray.writeBoolean(pixel == 0xFF000000);
					}
				}
			}
			
			byteArray.position = 0;
			byteArray.compress();
			output = ByteArray2String(byteArray);
			return output;
		}

		/**
		 * Deserializes and loads a font encoded with serialize().
		 * 
		 * @return	The deserialized BitmapFont.
		 */
		public function fromSerialized(encodedFont:String):BitmapFont 
		{
			reset();
			
			var byteArray:ByteArray = String2ByteArray(encodedFont);
			byteArray.position = 0;
			byteArray.uncompress();
			byteArray.position = 0;
			
			var letters:String = "";
			var letterPos:int = 0;
			
			var n:int = byteArray.readShort();	// number of glyphs
			var w:int = byteArray.readShort();	// max width of single glyph
			var h:int = byteArray.readShort();	// max height of single glyph
			
			var size:int = int(Math.ceil(Math.sqrt(n * (w + 1) * (h + 1))) + Math.max(w, h));
			var rows:int = int(size / (h + 1));
			var cols:int = int(size / (w + 1));
			var bd:BitmapData = new BitmapData(size, size, true, 0xFFFF0000);
			var len:int = byteArray.length;
			
			while (byteArray.position < len)
			{
				letters += byteArray.readUTF();
				
				if (byteArray.position >= len) break;
				
				var gw:int = byteArray.readShort();
				var gh:int = byteArray.readShort();
				for (var py:int = 0; py < gh; py++) 
				{
					for (var px:int = 0; px < gw; px++) 
					{
						var pixelOn:Boolean = byteArray.readBoolean();
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
		 * Encodes a ByteArray into a String. 
		 * 
		 * @param byteArray		The ByteArray to be encoded.
		 * @param mustEscape	Whether the returned string chars must be escaped.
		 * @return The encoded string.
		 */
		public static function ByteArray2String(byteArray:ByteArray, mustEscape:Boolean = true):String {
			var origPos:uint = byteArray.position;
			var result:Array = new Array();
			var output:String;

			for (byteArray.position = 0; byteArray.position < byteArray.length - 1; )
				result.push(byteArray.readShort());

			if (byteArray.position != byteArray.length)
				result.push(byteArray.readByte() << 8);

			byteArray.position = origPos;
			output = String.fromCharCode.apply(null, result);
			return (mustEscape ? escape(output) : output);
		}
		
		/** 
		 * Decodes a ByteArray from a String. 
		 * 
		 * @param str			The string to be decoded.
		 * @param mustUnescape	Whether the string chars must be unescaped.
		 * @return The decoded ByteArray.
		 */
		public static function String2ByteArray(str:String, mustUnescape:Boolean = true):ByteArray {
			var result:ByteArray = new ByteArray();
			var encodedStr:String = (mustUnescape ? unescape(str) : str);
			
			for (var i:int = 0; i < encodedStr.length; ++i) {
				result.writeShort(encodedStr.charCodeAt(i));
			}
			
			result.position = 0;
			return result;
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
		public static const DEFAULT_FONT_DATA:String = "%u78DA%u8D56%u8582%u1C21%u0CCD%u6BE7%uF6F6%u33EA%uEEEE%uEEAE%u57EF%uD5DD%uDDBF%uBD0C%u1003%u66EF%u6667%u5820%u21C9%u4B42%u8066%u6944%u63C2%u22EA%u08D4%u3F58%u4C0B%uC25C%u1821%uCE84%u0F4B%u02B5%u8B44%u99EE%u074B%u03DF%u88F2%u2032%uF64F%uA34F%u5846%u5334%u2DAC%u914A%uC80A%u1147%u4C58%uAE42%u416C%u936F%u3201%u2BAC%u7E08%u354A%uE4C5%u48BD%u9501%u54C7%uD610%u56D1%uC2B4%u92F9%u18E9%uEA4C%u806A%u49FD%u3561%uF994%u5FC1%uDAD6%u0612%u9B41%u19BA%uD842%u5817%u444E%u53F1%u64A9%uEB59%uAACC%u83A5%u6E48%u61B0%u6237%u1ABC%uB557%u8C7F%u089B%u82D8%u917A%u4682%uC2C6%u47ED%u9B19%u2C14%u6C7C%uB7C8%u6AB6%u07C2%u9522%u1BDA%uAD43%u4C09%u5E52%uB14D%uEDE0%u7068%u7AF0%uDC76%u2B09%uA2C4%u4BDA%u5121%u5247%u0BA2%u9D5E%u9206%uD2BA%u6857%uC337%u544A%uDADD%u6682%uC589%u3D1C%u23D5%uB0D7%u4FF5%uACFB%u343F%u34D9%uA4C1%u7E9B%u3E02%u5BF2%uE000%u93FD%u2AEE%u1E9C%u1005%uE13F%uE436%u0AD4%u3840%u7674%u76F3%uE1C1%uC4C9%uA1E9%uDF23%u5E29%u244C%u3001%u3B2A%uB880%u220C%u3DDB%uB196%u0CAB%uADA7%u1C17%uF02C%uC3FC%u134E%u0C92%uE3E4%u498B%u85F3%u8A14%u4694%u714A%uED68%u60CD%u9CA7%uAD22%u0B26%u8DCF%uD82C%uB771%uB219%u75B6%u5424%u14B3%uF3CE%uD968%uBB2F%u2A3A%uEF8A%u6306%u0353%u96B5%u665F%u28D4%u651E%u8FEB%uE27C%uCAC4%uA5C1%u4869%u9DC3%u652D%uF083%u9252%uEFCA%u5CE2%uFAF7%u6A23%u7455%u71B9%u3614%u95F4%u5D6F%u45B6%u0437%uD364%u82F1%u6468%u6E54%u6EAF%u7ECC%u7FB3%u21AF%uF008%uE156%u9BC9%u1797%uDB0E%u9D3D%uA7A2%uB83B%u5ABC%u7D11%uBBEB%u8D9D%uF087%u7B8D%u0320%uF6EF%uF381%uEF4F%uBA59%u93E7%uF593%uCF85%u0741%u6867%uB73B%uE161%uB1AE%uDC5E%u71DD%u23EB%u9476%u7210%u1EFB%uB316%u4551%u7962%u1561%u40D1%uD3CA%u1ADD%u4972%u9378%u5615%u6D97%u63CF%u838C%uF11C%u884C%u2C5F%u4CC6%u9606%u2FF9%uE2A5%u39F8%u2AF8%u725C%uDD7B%u24D9%u5E17%u62C9%u15F3%uFCBE%uB1F7%uB944%u7DEB%u2F12%u12BA%u4656%uBFF3%uCE6A%u5BFE%uBEE9%uD162%uA77D%uF02E%u1BAC%u2519%uEAC7%uF97A%u380D%u3FB9%u5394%uF358%u383E%uB732%uB0B8%u7FE2%u8B9E%u5845%uBCE3%uC4D7%uC215%u553D%uE99B%u6FC3%u4C2A%uEC7B%uE5FF%u4625%u49ED%u8F12%u975E%u4DFB%uE667%uE1D4%u964D%u2606%uBFAA%u6816%u674C%uCFF9%uDB1E%uDCEE%uBE12%uC77F%uEA7C%uFAAB%uA5AA%uB8A3%uC4F1%uBFA0%uB5F3%u40D3%uF31F%uA7D6%u2506";

		
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