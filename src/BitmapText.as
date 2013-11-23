package {

	import flash.display.BitmapData;
	import flash.text.TextFormatAlign;
	import net.flashpunk.graphics.Image;

	/**
	 * Used for drawing text using a BitmapFont.
	 *
	 * Adapted from Beeblerox work (which built upon Pixelizer implementation).
	 * 
	 * @see https://github.com/Beeblerox/BitmapFont
	 */
	public class BitmapText extends Image
	{
		/**
		 * Constructor.
		 * @param	text		Text to display.
		 * @param	x			X offset.
		 * @param	y			Y offset.
		 * @param 	font		The BitmapFont to use (pass null to use the default one).
		 * @param	options		An object containing key/value pairs of property/value to set on the BitmapText object.
		 */ 
		public function BitmapText(text:String, x:Number = 0, y:Number = 0, font:BitmapFont = null, options:* = null) 
		{
			_text = text;
			_align = TextFormatAlign.LEFT;
			
			if (font == null)
			{
				if (BitmapFont.fetch("default") == null)
				{
					BitmapFont.createDefaultFont();
				}
				_font = BitmapFont.fetch("default");
			}
			else
			{
				_font = font;
			}
			
			this.x = x;
			this.y = y;

			_fieldWidth = 2;
			_fieldHeight = _font.height;
			
			super(new BitmapData(_fieldWidth, _fieldHeight, true, 0));
			
			lock();
			if (options != null)
			{
				for (var property:String in options) {
					if (hasOwnProperty(property)) {
						this[property] = options[property];
					} else {
						throw new Error('"' + property + '" is not a property of BitmapText');
					}
				}
			}

			updateGlyphs(true, _shadow, _outline);
			
			_pendingTextChange = true;
			unlock();
			
			updateTextBuffer();
		}
		
		/**
		 * Clears all resources used.
		 */
		public function destroy():void 
		{
			_font = null;

			clearPreparedGlyphs(_preparedTextGlyphs);
			clearPreparedGlyphs(_preparedShadowGlyphs);
			clearPreparedGlyphs(_preparedOutlineGlyphs);
		}
		
		/** Sets the number of spaces with which tab ("\t") will be replaced. */
		public function get numSpacesInTab():int 
		{
			return _numSpacesInTab;
		}
		public function set numSpacesInTab(value:int):void
		{
			if (_numSpacesInTab != value && value > 0)
			{
				_numSpacesInTab = value;
				_tabSpaces = "";
				for (var i:int = 0; i < value; i++)
				{
					_tabSpaces += " ";
				}
				_pendingTextChange = true;
				updateTextBuffer();
			}
		}
		
		/**
		 * Text to display.
		 */
		public function get text():String
		{
			return _text;
		}
		public function set text(text:String):void
		{
			if (text != _text)
			{
				_text = text;
				_pendingTextChange = true;
				updateTextBuffer();
			}
		}
		
		/** Updates the text buffer, which is the source for the image buffer. */
		public function updateTextBuffer(forceUpdate:Boolean = false):void 
		{
			if (_font == null || locked || (!_pendingTextChange && !forceUpdate))
			{
				return;
			}
			
			var preparedText:String = (_autoUpperCase) ? _text.toUpperCase() : _text;
			var calcFieldWidth:int = _fieldWidth;
			var rows:Vector.<String> = new Vector.<String>();

			var fontHeight:int = Math.floor(_font.height * _fontScale);
			
			// cut text into pices
			var lineComplete:Boolean;
			
			// get words
			var lines:Array = (preparedText.split("\n"));
			var i:int = -1;
			var j:int = -1;
			if (!_multiLine)
			{
				lines = [lines[0]];
			}
			
			var wordLength:int;
			var word:String;
			var tempStr:String;
			while (++i < lines.length) 
			{
				if (_fixedWidth)
				{
					lineComplete = false;
					var words:Array = [];
					if (!wordWrap)
					{
						words = lines[i].split("\t").join(_tabSpaces).split(" ");
					}
					else
					{
						words = lines[i].split("\t").join(" \t ").split(" ");
					}
					
					if (words.length > 0) 
					{
						var wordPos:int = 0;
						var txt:String = "";
						while (!lineComplete) 
						{
							word = words[wordPos];
							var changed:Boolean = false;
							var currentRow:String = txt + word;
							
							if (_wordWrap)
							{
								var prevWord:String = (wordPos > 0) ? words[wordPos - 1] : "";
								var nextWord:String = (wordPos < words.length) ? words[wordPos + 1] : "";
								if (prevWord != "\t") currentRow += " ";
								
								if (_font.getTextWidth(currentRow, _letterSpacing, _fontScale) > _fieldWidth) 
								{
									if (txt == "")
									{
										words.splice(0, 1);
									}
									else
									{
										rows.push(txt.substr(0, txt.length - 1));
									}
									
									txt = "";
									if (_multiLine)
									{
										if (word == "\t" && (wordPos < words.length))
										{
											words.splice(0, wordPos + 1);
										}
										else
										{
											words.splice(0, wordPos);
										}
									}
									else
									{
										words.splice(0, words.length);
									}
									wordPos = 0;
									changed = true;
								}
								else
								{
									if (word == "\t")
									{
										txt += _tabSpaces;
									}
									if (nextWord == "\t" || prevWord == "\t")
									{
										txt += word;
									}
									else
									{
										txt += word + " ";
									}
									wordPos++;
								}
							}
							else
							{
								if (_font.getTextWidth(currentRow, _letterSpacing, _fontScale) > _fieldWidth) 
								{
									if (word != "")
									{
										j = 0;
										tempStr = "";
										wordLength = word.length;
										while (j < wordLength)
										{
											currentRow = txt + word.charAt(j);
											if (_font.getTextWidth(currentRow, _letterSpacing, _fontScale) > _fieldWidth) 
											{
												rows.push(txt.substr(0, txt.length - 1));
												txt = "";
												word = "";
												wordPos = words.length;
												j = wordLength;
												changed = true;
											}
											else
											{
												txt += word.charAt(j);
											}
											j++;
										}
									}
									else
									{
										changed = false;
										wordPos = words.length;
									}
								}
								else
								{
									txt += word + " ";
									wordPos++;
								}
							}
							
							if (wordPos >= words.length) 
							{
								if (!changed) 
								{
									calcFieldWidth = Math.floor(Math.max(calcFieldWidth, _font.getTextWidth(txt, _letterSpacing, _fontScale)));
									rows.push(txt);
								}
								lineComplete = true;
							}
						}
					}
					else
					{
						rows.push("");
					}
				}
				else
				{
					var lineWithoutTabs:String = lines[i].split("\t").join(_tabSpaces);
					calcFieldWidth = Math.floor(Math.max(calcFieldWidth, _font.getTextWidth(lineWithoutTabs, _letterSpacing, _fontScale)));
					rows.push(lineWithoutTabs);
				}
			}
			
			var finalWidth:int = calcFieldWidth + _padding * 2 + (_outline ? 2 : 0);
			var finalHeight:int = Math.floor(_padding * 2 + Math.max(1, (rows.length * fontHeight + (_shadow ? 1 : 0)) + (_outline ? 2 : 0))) + ((rows.length >= 1) ? _lineSpacing * (rows.length - 1) : 0);
			
			if (_source != null) 
			{
				if (finalWidth > _sourceRect.width || finalHeight > _sourceRect.height) 
				{
					_source.dispose();
					_source = null;
				}
			}
			
			if (_source == null) 
			{
				_source = new BitmapData(finalWidth, finalHeight, !_background, _backgroundColor);
				_sourceRect = source.rect;
				createBuffer();
			} 
			else 
			{
				_source.fillRect(_sourceRect, _backgroundColor);
			}
			
			_fieldWidth = int(_sourceRect.width);
			_fieldHeight = int(_sourceRect.height);
			
			if (_fontScale > 0)
			{
				_source.lock();
				
				// render text
				var row:int = 0;
				var t:String;
				
				for (var r:int = 0; r < rows.length; r++) 
				{
					t = rows[r];
					
					var ox:int = 0; // LEFT
					var oy:int = 0;
					if (_align == TextFormatAlign.CENTER) 
					{
						if (_fixedWidth)
						{
							ox = Math.floor((_fieldWidth - _font.getTextWidth(t, _letterSpacing, _fontScale)) / 2);
						}
						else
						{
							ox = Math.floor((finalWidth - _font.getTextWidth(t, _letterSpacing, _fontScale)) / 2);
						}
					}
					if (align == TextFormatAlign.RIGHT) 
					{
						if (_fixedWidth)
						{
							ox = _fieldWidth - Math.floor(_font.getTextWidth(t, _letterSpacing, _fontScale));
						}
						else
						{
							ox = finalWidth - Math.floor(_font.getTextWidth(t, _letterSpacing, _fontScale)) - 2 * padding;
						}
					}
					if (_outline) 
					{
						for (var py:int = 0; py < (2 + 1); py++) 
						{
							for (var px:int = 0; px < (2 + 1); px++) 
							{
								_font.render(_source, _preparedOutlineGlyphs, t, _outlineColor, px + ox + _padding, py + row * (fontHeight + _lineSpacing) + _padding, _letterSpacing);
							}
						}
						ox += 1;
						oy += 1;
					}
					if (_shadow) 
					{
						_font.render(_source, _preparedShadowGlyphs, t, _shadowColor, 1 + ox + _padding, 1 + oy + row * (fontHeight + _lineSpacing) + _padding, _letterSpacing);
					}
					_font.render(_source, _preparedTextGlyphs, t, _textColor, ox + _padding, oy + row * (fontHeight + _lineSpacing) + _padding, _letterSpacing);
					row++;
				}
				
				_source.unlock();
			}
			
			super.updateBuffer();
			_pendingTextChange = false;
		}
		
		/**
		 * Specifies whether the text field should have a filled background.
		 */
		public function get background():Boolean
		{
			return _background;
		}
		public function set background(value:Boolean):void
		{
			if (_background != value)
			{
				_background = value;
				_pendingTextChange = true;
				updateTextBuffer();
			}
		}
		
		/**
		 * Specifies the color of the text field background.
		 */
		public function get backgroundColor():int
		{
			return _backgroundColor;
		}
		public function set backgroundColor(value:int):void
		{
			if (_backgroundColor != value)
			{
				_backgroundColor = value;
				if (_background)
				{
					_pendingTextChange = true;
					updateTextBuffer();
				}
			}
		}
		
		/**
		 * Specifies whether the text should have a shadow.
		 */
		public function get shadow():Boolean
		{
			return _shadow;
		}
		public function set shadow(value:Boolean):void		
		{
			if (_shadow != value)
			{
				_shadow = value;
				_outline = false;
				updateGlyphs(false, _shadow, false);
				_pendingTextChange = true;
				updateTextBuffer();
			}
		}
		
		/**
		 * Specifies the color of the text field shadow.
		 */
		public function get shadowColor():int
		{
			return _shadowColor;
		}
		public function set shadowColor(value:int):void		
		{
			if (_shadowColor != value)
			{
				_shadowColor = value;
				updateGlyphs(false, _shadow, false);
				_pendingTextChange = true;
				updateTextBuffer();
			}
		}
		
		/**
		 * Sets the padding of the text field. This is the distance between the text and the border of the background (if any).
		 */
		public function get padding():int
		{
			return _padding;
		}
		public function set padding(value:int):void		
		{
			if (_padding != value)
			{
				_padding = value;
				_pendingTextChange = true;
				updateTextBuffer();
			}
		}
		
		/**
		 * Sets the color of the text.
		 */
		public function get textColor():int
		{
			return _textColor;
		}
		public function set textColor(value:int):void		
		{
			if (_textColor != value)
			{
				_textColor = value;
				updateGlyphs(true, false, false);
				_pendingTextChange = true;
				updateTextBuffer();
			}
		}
		
		/**
		 * Specifies whether the text field should use text color.
		 */
		public function get useTextColor():Boolean 
		{
			return _useTextColor;
		}
		public function set useTextColor(value:Boolean):void		
		{
			if (_useTextColor != value)
			{
				_useTextColor = value;
				updateGlyphs(true, false, false);
				_pendingTextChange = true;
				updateTextBuffer();
			}
		}
		
		/**
		 * Sets the width of the text field. If the text does not fit, it will spread on multiple lines.
		 */
		public function setWidth(value:int):int 
		{
			if (value < 1) 
			{
				value = 1;
			}
			if (value != _fieldWidth)
			{
				_fieldWidth = value;
				
				_source.dispose();
				_source = null;
				_source = new BitmapData(_fieldWidth, _fieldHeight, !_background, _backgroundColor);
				_sourceRect = source.rect;
				createBuffer();

				_pendingTextChange = true;
				updateTextBuffer();
			}
			
			return value;
		}
		
		/**
		 * Alignment ("left", "center" or "right").
		 */
		public function get align():String { return _align; }
		public function set align(value:String):void		
		{
			if (_align != value)
			{
				_align = value;
				_pendingTextChange = true;
				updateTextBuffer();
			}
		}
		
		/**
		 * Specifies whether the text field will break into multiple lines or not on overflow.
		 */
		public function get multiLine():Boolean
		{
			return _multiLine;
		}
		public function set multiLine(value:Boolean):void		
		{
			if (_multiLine != value)
			{
				_multiLine = value;
				_pendingTextChange = true;
				updateTextBuffer();
			}
		}
		
		/**
		 * Specifies whether the text should have an outline.
		 */
		public function get outline():Boolean
		{
			return _outline;
		}
		public function set outline(value:Boolean):void		
		{
			if (_outline != value)
			{
				_outline = value;
				_shadow = false;
				updateGlyphs(false, false, true);
				_pendingTextChange = true;
				updateTextBuffer();
			}
		}
		
		/**
		 * Specifies the color to use for the text outline.
		 */
		public function get outlineColor():int
		{
			return _outlineColor;
		}
		public function set outlineColor(value:int):void		
		{
			if (_outlineColor != value)
			{
				_outlineColor = value;
				updateGlyphs(false, false, _outline);
				_pendingTextChange = true;
				updateTextBuffer();
			}
		}
		
		/**
		 * Sets which BitmapFont to use for rendering.
		 */
		public function get font():BitmapFont
		{
			return _font;
		}
		public function set font(font:BitmapFont):void		
		{
			if (_font != font)
			{
				_font = font;
				updateGlyphs(true, _shadow, _outline);
				_pendingTextChange = true;
				updateTextBuffer();
			}
		}
		
		/**
		 * Sets the distance between lines.
		 */
		public function get lineSpacing():int
		{
			return _lineSpacing;
		}
		public function set lineSpacing(value:int):void		
		{
			if (_lineSpacing != value)
			{
				_lineSpacing = Math.floor(Math.abs(value));
				_pendingTextChange = true;
				updateTextBuffer();
			}
		}
		
		/**
		 * Sets the "font size" of the text.
		 */
		public function get fontScale():Number
		{
			return _fontScale;
		}
		public function set fontScale(value:Number):void		
		{
			var tmp:Number = Math.abs(value);
			if (tmp != _fontScale)
			{
				_fontScale = tmp;
				updateGlyphs(true, _shadow, _outline);
				_pendingTextChange = true;
				updateTextBuffer();
			}
		}
		
		/** Sets the space between each character. */
		public function get letterSpacing():int
		{
			return _letterSpacing;
		}
		public function set letterSpacing(value:int):void		
		{
			var tmp:int = Math.floor(Math.abs(value));
			if (tmp != _letterSpacing)
			{
				_letterSpacing = tmp;
				_pendingTextChange = true;
				updateTextBuffer();
			}
		}
		
		/** Automatically uppercase the text. */
		public function get autoUpperCase():Boolean 
		{
			return _autoUpperCase;
		}
		public function set autoUpperCase(value:Boolean):void		
		{
			if (_autoUpperCase != value)
			{
				_autoUpperCase = value;
				_pendingTextChange = true;
				updateTextBuffer();
			}
		}
		
		/** Whether the text should use word wrapping (use it in combination with fixedSize and setWidth()). */
		public function get wordWrap():Boolean 
		{
			return _wordWrap;
		}
		public function set wordWrap(value:Boolean):void		
		{
			if (_wordWrap != value)
			{
				_wordWrap = value;
				_pendingTextChange = true;
				updateTextBuffer();
			}
		}
		
		/** Whether the text field should have a fixed width (use setWidth() afterwards). */
		public function get fixedWidth():Boolean 
		{
			return _fixedWidth;
		}
		public function set fixedWidth(value:Boolean):void		
		{
			if (_fixedWidth != value)
			{
				_fixedWidth = value;
				_pendingTextChange = true;
				updateTextBuffer();
			}
		}
		
		/** Update array of glyphs. */
		protected function updateGlyphs(textGlyphs:Boolean = false, shadowGlyphs:Boolean = false, outlineGlyphs:Boolean = false):void
		{
			if (textGlyphs)
			{
				clearPreparedGlyphs(_preparedTextGlyphs);
				_preparedTextGlyphs = _font.getPreparedGlyphs(_fontScale, _textColor, _useTextColor);
			}
			
			if (shadowGlyphs)
			{
				clearPreparedGlyphs(_preparedShadowGlyphs);
				_preparedShadowGlyphs = _font.getPreparedGlyphs(_fontScale, _shadowColor);
			}
			
			if (outlineGlyphs)
			{
				clearPreparedGlyphs(_preparedOutlineGlyphs);
				_preparedOutlineGlyphs = _font.getPreparedGlyphs(_fontScale, _outlineColor);
			}
		}
		
		/** Dispose of the prepared glyphs BitmapDatas. */
		private function clearPreparedGlyphs(glyphs:Array):void
		{
			if (glyphs != null)
			{
				var bmd:BitmapData;
				
				for (var i:int = 0; i < glyphs.length; i++)
				{
					bmd = glyphs[i];
					
					if (bmd != null)
					{
						bmd.dispose();
					}
				}
				glyphs = null;
			}
		}

		// BitmapText information
		private var _font:BitmapFont;
		private var _text:String = "";
		private var _fieldWidth:int = 0;
		private var _fieldHeight:int = 0;
		private var _textColor:int = 0xFFFFFF;
		private var _useTextColor:Boolean = false;
		private var _outline:Boolean = false;
		private var _outlineColor:int = 0x0;
		private var _shadow:Boolean = false;
		private var _shadowColor:int = 0x0;
		private var _background:Boolean = false;
		private var _backgroundColor:int = 0x0;
		private var _align:String;
		private var _padding:int = 0;
		
		private var _lineSpacing:int = 0;
		private var _letterSpacing:int = 0;
		private var _fontScale:Number = 1;
		private var _autoUpperCase:Boolean = false;
		private var _wordWrap:Boolean = true;
		private var _fixedWidth:Boolean = false;
		
		private var _numSpacesInTab:int = 4;
		private var _tabSpaces:String = "    ";
		
		private var _pendingTextChange:Boolean = false;
		private var _multiLine:Boolean = true;

		private var _preparedTextGlyphs:Array;
		private var _preparedShadowGlyphs:Array;
		private var _preparedOutlineGlyphs:Array;

	}
}