import{a as x}from"./chunk-GN3ABOUD.js";import{a as w}from"./chunk-EGUWTU4E.js";import{a as c,b as p,c as g}from"./chunk-XFPJAEYH.js";import{f as h}from"./chunk-36MKNQ2T.js";import"./chunk-XST6YTRK.js";import{$ as a,$a as t,Db as u,Ma as s,Za as o,_a as n,ab as i,ob as e,ya as r}from"./chunk-V3XGVJ3S.js";import"./chunk-Q7L6LLAK.js";var y=class m{Code1=a(`
<mw-root
  Layer="Windows"
  [style.width]="'800px'"
  [style.height]="'400px'"
  >
  <mw-window></mw-window>
</mw-root>
  `.trim());Code2=a(`
mw-root {
  width: 800px;
  height: 400px;
}
  `.trim());Code3=a(`
<mw-root Layer="Windows">
  <mw-window></mw-window>
</mw-root>
  `.trim());LuaRenderCode1=a(`
local Renderer = require("scripts.Nox.AnglesUI.Renderer.Renderer")

local renderer = Renderer.FromFile("scripts/Nox/UI/LogisticsUI.html", {})
renderer:Render({})
  `.trim());LuaRenderCode2=a(`
local Renderer = require("scripts.Nox.AnglesUI.Renderer.Renderer")

local textSignal = Signal.New("Hello world!")
local onTextClicked = function(mouseEvent, layout)
  textSignal:Set("New text: " .. math.random())
end

local renderer = Renderer.FromFile("scripts/Nox/UI/LogisticsUI.html", {})
renderer:Render({
  Text = textSignal,
  OnTextClicked = onTextClicked,
})
  `.trim());Code4=a(`
<mw-root Layer="Windows">
  <mw-window>
    <mw-text (mousePress)="OnTextClicked($event1, $event2)">{{ Text() }}</mw-text>
  </mw-window>
</mw-root>
  `.trim());static \u0275fac=function(d){return new(d||m)};static \u0275cmp=s({type:m,selectors:[["app-making-a-ui"]],decls:105,vars:6,consts:[["routerLink","/installation"],["Src","/images/making-a-ui/step-1.png","Alt","Example folder structure"],["Src","/images/making-a-ui/step-2.png","Alt","Example HTML and CSS files"],["Language","angular-html",3,"Code"],["Language","lua",3,"Code"],["Src","/images/making-a-ui/render-1.png","Alt","Basic Morrowind-theme window"],["target","_blank","href","https://openmw.readthedocs.io/en/latest/reference/lua-scripting/openmw_ui.html##(Layout).layer"],["target","_blank","href","https://openmw.readthedocs.io/en/latest/reference/lua-scripting/user_interface.html#layers"],["routerLink","/data-binding"],["Language","css",3,"Code"],["target","_blank","href","https://openmw.readthedocs.io/en/latest/reference/lua-scripting/widgets/widget.html#events"],["Src","/images/making-a-ui/render-2.png","Alt","Basic Morrowind-theme window"],["Src","/images/making-a-ui/render-3.png","Alt","Basic Morrowind-theme window"]],template:function(d,l){d&1&&(n(0,"app-content-width-container")(1,"app-card")(2,"app-card-header")(3,"h1"),e(4,"Making a Basic UI With AnglesUI"),t()(),n(5,"app-card-body")(6,"p"),e(7," Now that you have "),n(8,"a",0),e(9,"installed AnglesUI"),t(),e(10,", you can start making your UIs with enhanced-HTML and CSS. We write "),n(11,"em"),e(12,"enhanced"),t(),e(13," here because the HTML syntax is expaned to be a template language that can support if statements, for loops, and variable output directives. "),t(),n(14,"h2"),e(15,"File and Folder Structure"),t(),n(16,"p"),e(17," We recommend creating a folder dedicated to your UIs in your mod directory. This is where your HTML and CSS files will live for your Lua code to load and render them when you need them. "),t(),i(18,"app-content-image",1)(19,"app-content-image",2),n(20,"h2"),e(21,"Syntax for a Basic Morrowind-Theme Window"),t(),n(22,"p"),e(23," Getting right into it, open up your new HTML file you have created in your UI folder in your editor. All root-level UIs require the first element to be "),n(24,"code"),e(25,"mw-root"),t(),e(26,". More on this later, as you can create child components to better segment and organize your HTML and CSS that do not required this root element. For now, we will just put everything in the root element. This is the basic syntax for a Morrowind-themed window: "),t(),i(27,"app-code-highlighter",3),n(28,"p"),e(29," With this, you will get a basic Morrowind-theme window as shown below. "),n(30,"code"),e(31,"mw-root"),t(),e(32," does not inheritently have any visual styling and serves more as the available canvas for your UI to be drawn on. "),n(33,"code"),e(34,"mw-window"),t(),e(35," is a pre-styled element that has a Morrowind-window appearance. "),t(),n(36,"p"),e(37," However, you will also need to render this in your Lua code somewhere. Currently, only "),n(38,"strong"),e(39,"Player"),t(),e(40," and "),n(41,"strong"),e(42,"Menu"),t(),e(43," scripts allow for UI rendering. A brief, minimal example of a "),n(44,"em"),e(45,"Player"),t(),e(46," script that will render this UI would look like this: "),t(),i(47,"app-code-highlighter",4)(48,"app-content-image",5),n(49,"p"),e(50," The black background will match the user's UI transparency setting. "),t(),n(51,"p"),e(52," The "),n(53,"strong"),e(54,"Layer"),t(),e(55," attribute is directly used for when we create the OpenMW Element object using "),n(56,"code"),e(57,"ui.create()"),t(),e(58,". More information on that OpenMW API property "),n(59,"a",6),e(60,"here"),t(),e(61,". All available options for it "),n(62,"a",7),e(63,"here"),t(),e(64,". "),t(),n(65,"h2"),e(66,"Introducing CSS"),t(),n(67,"p"),e(68," You probably noticed the strange syntax in the "),n(69,"code"),e(70,"mw-root"),t(),e(71," attributes. Those are called style attribute bindings. You can read more about those on the "),n(72,"a",8),e(73,"bindings reference"),t(),e(74," page. For now, they're ugly in our minimal example. We can do all stylings (that don't need variable bindings and are just plain strings) in a separate CSS file. "),t(),n(75,"p"),e(76," AnglesUI enforces that your accompanying CSS file must be in the same directory as your HTML file and named the same, but with a .css extension instead of a .html one. So, create a new file with the same name as your HTML file and make it a .css extension. Then add the following code: "),t(),i(77,"app-code-highlighter",9),n(78,"p"),e(79," Then, we'll remove the style attribute bindings in our HTML file since we can now do those stylings in our CSS file. So, your HTML file should now look like this: "),t(),i(80,"app-code-highlighter",3),n(81,"p"),e(82," You'll get the same result in-game, but the HTML looks cleaner as we've moved the styling out of it. This is the baseline of a basic UI. "),t(),n(83,"h2"),e(84,"More Advanced Techniques: Signal Bindings"),t(),n(85,"p"),e(86," Just like in the web framework, Angular, AnglesUI allows you to pass in signals to the renderer which you can use to bind data to your UI. We'll do an example where we create a window, text, and then change the text by clicking on the text itself (which is a short intro into event bindings). All events in AnglesUI are 1-to-1 with their definitions found in the "),n(87,"a",10),e(88,"OpenMW UI docs"),t(),e(89,". "),t(),n(90,"p"),e(91," We'll re-use the same Lua code, but we'll register a signal and a function to send into our renderer. "),t(),i(92,"app-code-highlighter",4),n(93,"p"),e(94," Now, we'll change our HTML code to use these bindings. Signals get their data fetched by calling the signal like a function. "),t(),i(95,"app-code-highlighter",3),n(96,"p"),e(97," We open the OpenMW terminal in the game (by pressing ~ on the keyboard) and type "),n(98,"code"),e(99,"reloadlua"),t(),e(100," to reload our UI (for this example). "),t(),i(101,"app-content-image",11),n(102,"p"),e(103," Now, clicking on the text we see our event fires and our signal is updated - automatically re-evaluating and re-rendering the necessary portions of the UI for you. "),t(),i(104,"app-content-image",12),t()()()),d&2&&(r(27),o("Code",l.Code1()),r(20),o("Code",l.LuaRenderCode1()),r(30),o("Code",l.Code2()),r(3),o("Code",l.Code3()),r(12),o("Code",l.LuaRenderCode2()),r(3),o("Code",l.Code4()))},dependencies:[u,c,p,g,w,x,h],encapsulation:2})};export{y as MakingAUi};
