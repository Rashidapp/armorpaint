package arm.ui;

import zui.Zui;
import zui.Id;
import zui.Ext;

class TabBrowser {

	@:access(zui.Zui)
	public static function draw() {
		var ui = UITrait.inst.ui;
		if (ui.tab(UITrait.inst.htab, "Browser")) {
			var h = Id.handle();
			h.text = ui.textInput(h, "Path");
			Ext.fileBrowser(ui, h);
		}
	}
}
