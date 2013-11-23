package {
	import net.flashpunk.Engine;
	import net.flashpunk.FP;


	/**
	 * ...
	 * @author azrafe7
	 */
	public class Main extends Engine
	{
		
		public function Main() {
			super(640, 480, 60, false);
		}
		
		override public function init():void {
			super.init();
			
			FP.console.enable();
			
			FP.world = new TestWorld;
		}		
		
		public static function main():void { 
			new Main(); 
		}
		
	}
}