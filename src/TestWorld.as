package  
{
	import flash.system.System;
	import flash.text.TextFormatAlign;
	import net.flashpunk.FP;
	import net.flashpunk.utils.Input;
	import net.flashpunk.utils.Key;
	import net.flashpunk.World;
	import BitmapFont;
	import BitmapText;
	
	/**
	 * World for testing BitmapFont and BitmapText
	 * @author azrafe7
	 */
	public class TestWorld extends World
	{
		[Embed(source="../assets/new_super_mario-littera.png")]
		public var MARIO_FONT_BMD:Class;
		
		[Embed(source="../assets/new_super_mario-littera.fnt", mimeType="application/octet-stream")]
		public var MARIO_FONT_XML:Class;
		
		[Embed(source="../assets/alagard-bmfont.png")]
		public var ALAGARD_FONT_BMD:Class;
		
		[Embed(source="../assets/alagard-bmfont.fnt", mimeType="application/octet-stream")]
		public var ALAGARD_FONT_XML:Class;
		
		[Embed(source="../assets/round_font-pixelizer.png")]
		public var ROUND_FONT_BMD:Class;
		
		
		public var defaultText:BitmapText;
		public var pixelizerText:BitmapText
		public var marioText:BitmapText
		public var alagardText:BitmapText
		
		public var pixelizerFont:BitmapFont;
		public var marioFont:BitmapFont;
		public var alagardFont:BitmapFont;
		
		public function TestWorld() 
		{
			
		}
		
		override public function begin():void 
		{
			super.begin();
			
			// using the default (serialized) font - it's the string stored in BitmapFont.DEFAULT_FONT_DATA
			defaultText = new BitmapText("using Serialized BitmapFont (loaded from a weird string) (:");
			addGraphic(defaultText, 0, 5, 40);
			defaultText.fontScale = 2;
			defaultText.outline = true;
			defaultText.outlineColor = 0;
			
			// using a font (http://www.dafont.com/new-super-mario-font-u.font) exported with Littera (http://kvazars.com/littera/)
			marioFont = new BitmapFont().fromXML(MARIO_FONT_BMD, MARIO_FONT_XML);
			marioText = new BitmapText("SuperMario brooo$ with black\nborders, multiline, etc...!", 0, 0, marioFont);
			addGraphic(marioText, 0, 5, 70);
			marioText.outlineColor = 0x0;
			marioText.outline = true;
			marioText.background = true;
			marioText.backgroundColor = 0xF0D000;
			
			// using a font (http://www.dafont.com/alagard.font) exported with BMFont/AngelCode (http://www.angelcode.com/products/bmfont/)
			alagardFont = new BitmapFont().fromXML(ALAGARD_FONT_BMD, ALAGARD_FONT_XML);
			alagardText = new BitmapText("A' la guaarde\nwith ombregiature!!!", 0, 0, alagardFont)
			addGraphic(alagardText, 0, 275, 360);
			alagardText.shadowColor = 0x0;
			alagardText.shadow = true;
			alagardText.scale = 2;
			alagardText.align = TextFormatAlign.RIGHT;
			trace("This is alagard font serialized:\n" + alagardFont.serialize());
			
			// using a font in the Pixelizer format (https://github.com/johanp/Pixelizer)
			pixelizerFont = new BitmapFont().fromPixelizer(
				ROUND_FONT_BMD, 
				" !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~⌂", 
				0xFF202020);
			pixelizerText = new BitmapText("pixelizedr all wthe waeey!", 0, 0, pixelizerFont);
			pixelizerText.centerOrigin();
			addGraphic(pixelizerText, 0, FP.halfWidth, FP.halfHeight);
			pixelizerText.scale = 2;
		}
		
		override public function update():void 
		{
			super.update();
			
			if (Input.pressed(Key.ESCAPE)) System.exit(0);
		}
	}
}