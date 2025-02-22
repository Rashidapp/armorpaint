package arm.ui;

import zui.Id;
import zui.Zui;
import iron.data.Data;
import arm.nodes.MaterialParser;
import arm.data.LayerSlot;

class BoxPreferences {

	@:access(zui.Zui)
	public static function show() {
		UIBox.showCustom(function(ui:Zui) {
			var _w = ui._w;
			ui._w = Std.int(_w / 2);
			var htab = Id.handle();

			if (ui.tab(htab, "Interface")) {

				var hscale = Id.handle({value: Config.raw.window_scale});
				ui.slider(hscale, "UI Scale", 0.5, 4.0, true);
				if (!hscale.changed && UITrait.inst.hscaleWasChanged) {
					if (hscale.value == null || Math.isNaN(hscale.value)) hscale.value = 1.0;
					Config.raw.window_scale = hscale.value;
					Config.save();
					setScale();
				}
				UITrait.inst.hscaleWasChanged = hscale.changed;
				var themeHandle = Id.handle({position: 0});
				var themes = ["Dark", "Light"];
				ui.combo(themeHandle, themes, "Theme", true);
				if (themeHandle.changed) {
					var theme = themes[themeHandle.position].toLowerCase();
					if (theme == "dark") { // Built-in default
						App.theme = zui.Themes.dark;
					}
					else {
						Data.getBlob("themes/theme_" + theme + ".arm", function(b:kha.Blob) {
							App.theme = haxe.Json.parse(b.toString());
						});
					}
					ui.t = App.theme;
					UITrait.inst.ui.t = App.theme;
					// UINodes.inst.ui.t = App.theme;
					UITrait.inst.headerHandle.redraws = 2;
					UITrait.inst.toolbarHandle.redraws = 2;
					UITrait.inst.statusHandle.redraws = 2;
					UITrait.inst.workspaceHandle.redraws = 2;
					UITrait.inst.menuHandle.redraws = 2;
					UITrait.inst.hwnd.redraws = 2;
					UITrait.inst.hwnd1.redraws = 2;
					UITrait.inst.hwnd2.redraws = 2;
				}

				UITrait.inst.cacheDraws = ui.check(Id.handle({selected: UITrait.inst.cacheDraws}), "Cache Draws");
				if (ui.isHovered) ui.tooltip("Enabling may reduce GPU usage");

				// ui.text("Node Editor");
				// var gridSnap = ui.check(Id.handle({selected: false}), "Grid Snap");

				ui.endElement();
				ui.row([1/2]);
				if (ui.button("Restore")) {
					// UIMenu.draw(function(ui:Zui) {
					// 	ui.fill(0, 0, ui._w / ui.SCALE, ui.t.ELEMENT_H * 2, ui.t.SEPARATOR_COL);
					// 	ui.text("Restore defaults?", Right);
					// 	if (ui.button("Confirm", Left)) {
							Config.restore();
							setScale();
					// 	}
					// });
				}
			}
			if (ui.tab(htab, "Usage")) {
				UITrait.inst.undoHandle = Id.handle({value: Config.raw.undo_steps});
				Config.raw.undo_steps = Std.int(ui.slider(UITrait.inst.undoHandle, "Undo Steps", 2, 64, false, 1));
				if (UITrait.inst.undoHandle.changed) {
					ui.g.end();
					while (History.undoLayers.length < Config.raw.undo_steps) {
						var l = new LayerSlot("_undo" + History.undoLayers.length);
						l.createMask(0, false);
						History.undoLayers.push(l);
					}
					while (History.undoLayers.length > Config.raw.undo_steps) {
						var l = History.undoLayers.pop();
						l.unload();
					}
					History.reset();
					ui.g.begin(false);
					Config.save();
				}

				UITrait.inst.brushBias = ui.slider(Id.handle({value: UITrait.inst.brushBias}), "Paint Bleed", 0.0, 2.0, true);
				if (ui.isHovered) ui.tooltip("Stretch brush strokes on the uv map to prevent seams");

				var brush3dHandle = Id.handle({selected: UITrait.inst.brush3d});
				UITrait.inst.brush3d = ui.check(brush3dHandle, "3D Cursor");
				if (brush3dHandle.changed) MaterialParser.parsePaintMaterial();

				ui.enabled = UITrait.inst.brush3d;
				var brushDepthRejectHandle = Id.handle({selected: UITrait.inst.brushDepthReject});
				UITrait.inst.brushDepthReject = ui.check(brushDepthRejectHandle, "Depth Reject");
				if (brushDepthRejectHandle.changed) MaterialParser.parsePaintMaterial();

				ui.row([1/2,1/2]);

				var brushAngleRejectHandle = Id.handle({selected: UITrait.inst.brushAngleReject});
				UITrait.inst.brushAngleReject = ui.check(brushAngleRejectHandle, "Angle Reject");
				if (brushAngleRejectHandle.changed) MaterialParser.parsePaintMaterial();

				if (!UITrait.inst.brushAngleReject) ui.enabled = false;
				var angleDotHandle = Id.handle({value: UITrait.inst.brushAngleRejectDot});
				UITrait.inst.brushAngleRejectDot = ui.slider(angleDotHandle, "Angle", 0.0, 1.0, true);
				if (angleDotHandle.changed) {
					MaterialParser.parsePaintMaterial();
				}
				ui.enabled = true;
			}
			if (ui.tab(htab, "Pen")) {
				UITrait.penPressureRadius = ui.check(Id.handle({selected: UITrait.penPressureRadius}), "Brush Radius");
				UITrait.penPressureOpacity = ui.check(Id.handle({selected: UITrait.penPressureOpacity}), "Brush Opacity");
				UITrait.penPressureHardness = ui.check(Id.handle({selected: UITrait.penPressureHardness}), "Brush Hardness");
			}

			UITrait.inst.hssgi = Id.handle({selected: Config.raw.rp_ssgi});
			UITrait.inst.hssr = Id.handle({selected: Config.raw.rp_ssr});
			UITrait.inst.hbloom = Id.handle({selected: Config.raw.rp_bloom});
			UITrait.inst.hsupersample = Id.handle({position: Config.getSuperSampleQuality(Config.raw.rp_supersample)});
			UITrait.inst.hvxao = Id.handle({selected: Config.raw.rp_gi});
			if (ui.tab(htab, "Viewport")) {
				ui.combo(UITrait.inst.hsupersample, ["0.25x", "0.5x", "1.0x", "1.5x", "2.0x", "4.0x"], "Super Sample", true);
				if (UITrait.inst.hsupersample.changed) Config.applyConfig();
				var vsyncHandle = Id.handle({selected: Config.raw.window_vsync});
				Config.raw.window_vsync = ui.check(vsyncHandle, "VSync");
				if (vsyncHandle.changed) Config.save();
				var cullHandle = Id.handle({selected: Config.raw.rp_culling});
				Config.raw.rp_culling = ui.check(cullHandle, "Cull Backfaces");
				if (cullHandle.changed) {
					Config.save();
					MaterialParser.parseMeshMaterial();
				}
				var filterHandle = Id.handle({selected: UITrait.inst.textureFilter});
				UITrait.inst.textureFilter = ui.check(filterHandle, "Filter Textures");
				if (filterHandle.changed) {
					MaterialParser.parseMeshMaterial();
				}
				#if (!kha_direct3d12)
				ui.check(UITrait.inst.hvxao, "Voxel AO");
				if (ui.isHovered) ui.tooltip("Cone-traced AO and shadows");
				if (UITrait.inst.hvxao.changed) {
					Config.applyConfig();
					#if arm_creator
					MaterialParser.parseMeshMaterial();
					#end
				}

				ui.row([1/2, 1/2]);
				ui.enabled = UITrait.inst.hvxao.selected;
				var h = Id.handle({value: UITrait.inst.vxaoOffset});
				UITrait.inst.vxaoOffset = ui.slider(h, "Cone Offset", 1.0, 4.0, true);
				if (h.changed) Context.ddirty = 2;
				var h = Id.handle({value: UITrait.inst.vxaoAperture});
				UITrait.inst.vxaoAperture = ui.slider(h, "Aperture", 1.0, 4.0, true);
				if (h.changed) Context.ddirty = 2;
				ui.enabled = true;
				#end
				ui.check(UITrait.inst.hssgi, "SSAO");
				if (UITrait.inst.hssgi.changed) Config.applyConfig();
				ui.check(UITrait.inst.hbloom, "Bloom");
				if (UITrait.inst.hbloom.changed) Config.applyConfig();
				ui.check(UITrait.inst.hssr, "SSR");
				if (UITrait.inst.hssr.changed) Config.applyConfig();

				#if arm_creator
				var h = Id.handle({value: UITrait.inst.vxaoExt});
				UITrait.inst.vxaoExt = ui.slider(h, "VXAO Ext", 1.0, 10.0);
				if (h.changed) {
					Context.ddirty = 2;
					MaterialParser.parseMeshMaterial();
				}
				#end
			}
			if (ui.tab(htab, "Keymap")) {
				var presetHandle = Id.handle();
				ui.combo(presetHandle, ["Default", "Blender"], "Preset", true);
				if (presetHandle.changed) {
					var preset = presetHandle.position;
					var keymap = Config.keymap;
					if (preset == 0) {
						keymap.action_rotate = "alt+left";
						keymap.action_pan = "alt+middle";
						keymap.action_zoom = "alt+right";
					}
					else if (preset == 1) {
						keymap.action_rotate = "middle";
						keymap.action_pan = "shift+middle";
						keymap.action_zoom = "ctrl+middle";
					}
					Config.applyConfig();
				}
				ui.separator(8, false);

				var i = 0;
				ui.changed = false;
				for (key in Reflect.fields(Config.keymap)) {
					var h = Id.handle().nest(i++);
					h.text = Reflect.field(Config.keymap, key);
					var text = ui.textInput(h, key, Left);
					Reflect.setField(Config.keymap, key, text);
				}
				if (ui.changed) Config.applyConfig();
			}

			ui._w = _w;
		}, 400, 290);
	}

	static function setScale() {
		var scale = Config.raw.window_scale;
		UITrait.inst.ui.setScale(scale);
		UITrait.inst.windowW = Std.int(UITrait.defaultWindowW * scale);
		UITrait.inst.toolbarw = Std.int(UITrait.defaultToolbarW * scale);
		UITrait.inst.headerh = Std.int(UITrait.defaultHeaderH * scale);
		UITrait.inst.menubarw = Std.int(215 * scale);
		UITrait.inst.setIconScale();
		UINodes.inst.ui.setScale(scale);
		UIView2D.inst.ui.setScale(scale);
		App.uibox.setScale(scale);
		App.resize();
	}
}
