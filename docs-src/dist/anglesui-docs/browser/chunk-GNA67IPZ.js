import{a as T}from"./chunk-FCHIL3KZ.js";import{a as v}from"./chunk-4UVQU5FT.js";import{a as L}from"./chunk-XQWTI7VS.js";import{a as S,b as f,c as y}from"./chunk-OI63Y6K5.js";import{f as C}from"./chunk-73NXMPKY.js";import"./chunk-X23CRHME.js";import{Aa as l,Lb as M,Pa as x,ab as m,ba as a,bb as n,cb as t,db as r,sb as e,xb as i,yb as u}from"./chunk-D3QXKHB2.js";import"./chunk-Q7L6LLAK.js";var c=o=>({TabLabel:"MainWindow.html",Code:o,Language:"angular-html"}),F=o=>({TabLabel:"MainWindow.css",Code:o,Language:"css"}),w=(o,g)=>[o,g],h=o=>({TabLabel:"UIManager.lua",Code:o,Language:"lua"}),s=o=>[o],b=o=>({TabLabel:"Button.html",Code:o,Language:"angular-html"}),E=o=>({TabLabel:"Button.css",Code:o,Language:"css"}),k=class o{ParentHTMLCode1=a(`
<mw-root Layer="windows">
  <mw-window></mw-window>
</mw-root>
  `);ParentCSSCode1=a(`
mw-root {
  width: 400px;
  height: 250px;
  position: absolute;
  left: calc(50% - calc(400px / 2));
  top: calc(50% - calc(250px / 2));
}
  `);LuaCode1=a(`
local Renderer = require("scripts.Nox.AnglesUI.Renderer.Renderer")

local renderer = Renderer.FromFile("scripts/Nox/UI/MainWindow.html", {})

renderer:Render({})
  `);LuaCode2=a(`
local Renderer = require("scripts.Nox.AnglesUI.Renderer.Renderer")

local renderer = Renderer.FromFile("scripts/Nox/UI/MainWindow.html", {
  ["nox-button"] = "scripts/Nox/UI/Button.html"
})

renderer:Render({})
  `);ChildHTMLCode1=a(`
<mw-host>
  <mw-window class="button-wrapper">
    <mw-content></mw-content>
  </mw-window>
</mw-host>
  `);ChildCSSCode1=a(`
mw-host {
  width: 125px;
  height: 36px;
  
  & > mw-window {
    padding: 4px;
    background: none;
  }
}
  `);ParentHTMLCode2=a(`
<mw-root Layer="windows">
  <mw-window><nox-button></nox-button></mw-window>
</mw-root>
  `);ParentHTMLCode3=a(`
<mw-root Layer="windows">
  <mw-window>
    <nox-button>
      <mw-text>Click Me</mw-text>
    </nox-button>
  </mw-window>
</mw-root>
  `);ParentHTMLCode4=a(`
<mw-root Layer="windows">
  <mw-window>
    <nox-button>Click me</nox-button>
  </mw-window>
</mw-root>
  `);ChildHTMLCode2=a(`
<mw-host>
  <mw-window class="button-wrapper">
    <mw-text><mw-content></mw-content></mw-text>
  </mw-window>
</mw-host>
  `);ChildHTMLCode3=a(`
<mw-host>
  <mw-window class="button-wrapper">
    <mw-text AutoSize="false"><mw-content></mw-content></mw-text>
  </mw-window>
</mw-host>
  `);ChildCSSCode2=a(`
mw-host {
  width: 125px;
  height: 36px;
  
  & > mw-window {
    background: none;

    mw-text {
      width: 100%;
      height: 100%;
      text-align: center;
      vertical-align: middle;
    }
  }
}
  `);LuaCode3=a(`
local Renderer = require("scripts.Nox.AnglesUI.Renderer.Renderer")

local renderer = Renderer.FromFile("scripts/Nox/UI/MainWindow.html", {
  ["nox-button"] = "scripts/Nox/UI/Button.html"
})

renderer:Render({
  OnButtonClicked = function(somethingToPrint, mouseEvent, layout)
    print(somethingToPrint)
  end
})
  `);ParentHTMLCode5=a(`
<mw-root Layer="windows">
  <mw-window>
    <nox-button (mousePress)="OnButtonClicked('Button clicked!')">Click me</nox-button>
  </mw-window>
</mw-root>
  `);static \u0275fac=function(p){return new(p||o)};static \u0275cmp=x({type:o,selectors:[["app-making-a-button"]],decls:155,vars:62,consts:[[3,"CodeTabs"],["Alt","Rendered main window for our custom button component setup","Src","/images/examples/main-window-1.png"],["routerLink","/content-projection"],["routerLink","/event-bindings"],["Alt","Rendered main window for our custom button component setup","Src","/images/examples/main-window-2.png"],["Alt","Rendered main window for our custom button component setup with content projected into the button","Src","/images/examples/main-window-3.png"],["Alt","Rendered main window for our custom button component setup with content projected into the button","Src","/images/examples/main-window-4.png"],["Alt","OpenMW Lua console viewer","Src","/images/examples/making-button-console-1.png"],["routerLink","/examples/responsive-ui"],["Alt","Responsive grid of buttons","Src","/images/examples/responsive-ui.gif"]],template:function(p,d){p&1&&(n(0,"app-content-width-container")(1,"app-card")(2,"app-card-header")(3,"h1"),e(4,"Making a Button Component"),t()(),n(5,"app-card-body")(6,"p"),e(7," You may find it odd that AnglesUI doesn't include a default button component. This is because buttons are often one of the most customized elements in a UI. Instead of providing a default button component, we will show you how to make your own custom button component that you can reuse throughout your UI. Including event bindings for your button. "),t(),n(8,"p"),e(9," This example will start from the beginning - from making a root element to registering your custom button component to be rendered. While buttons are inherently simple, this guide will be "),n(10,"strong"),e(11,"detailed"),t(),e(12," and serve as a step-by-step. You can deviate should you want different designs or feel you get the hang of things. "),t(),n(13,"h2"),e(14,"Our Basic Window"),t(),n(15,"p"),e(16," First, let's get a basic window element. Make a new HTML file "),n(17,"code"),e(18,"MainWindow.html"),t(),e(19," and a CSS file "),n(20,"code"),e(21,"MainWindow.css"),t(),e(22," somewhere. Preferably, in a directory for all your UIs. "),t(),n(23,"p"),e(24," This will be their code (HTML/CSS) "),t(),r(25,"app-code-highlighter",0),n(26,"p"),e(27," We use the calc() in the CSS so we can center the element on the screen for our example. "),t(),n(28,"p"),e(29," Now, we register that window and render it. This "),n(30,"strong"),e(31,"must be done"),t(),e(32," in a script you registered in your mod's omwscripts file as either a "),n(33,"strong"),e(34,"Player"),t(),e(35," or "),n(36,"strong"),e(37,"Menu"),t(),e(38," script. "),t(),r(39,"app-code-highlighter",0),n(40,"p"),e(41," This will give us the following rendered window: "),t(),r(42,"app-content-image",1),n(43,"h2"),e(44,"Making the Button Component"),t(),n(45,"p"),e(46," Now, add a new HTML file in your UI directory. Call it "),n(47,"code"),e(48,"Button.html"),t(),e(49," and a CSS file "),n(50,"code"),e(51,"Button.css"),t(),e(52,". "),t(),n(53,"p"),e(54," Then, we will register it in our renderer as "),n(55,"code"),e(56,"nox-button"),t(),e(57," so that we can use "),n(58,"code"),e(59,"<nox-button></nox-button>"),t(),e(60," in our HTML to render it. Register it in your Lua code like below (this modifies the existing rendering code from above): "),t(),r(61,"app-code-highlighter",0),n(62,"p"),e(63," Let's add the HTML and CSS for our button. Following the guidelines from "),n(64,"a",2),e(65,"Content Projection"),t(),e(66," and "),n(67,"a",3),e(68,"Event Bindings"),t(),e(69,", we will make sure our component starts with "),n(70,"code"),e(71,"mw-host"),t(),e(72," and has "),n(73,"code"),e(74,"mw-content"),t(),e(75," so we can bind events and project content. "),t(),r(76,"app-code-highlighter",0),n(77,"p"),e(78," Next, we'll go back and modify our "),n(79,"code"),e(80,"MainWindow.html"),t(),e(81," to use the new button component. "),t(),r(82,"app-code-highlighter",0),n(83,"p"),e(84," You can use the "),n(85,"code"),e(86,"reloadlua"),t(),e(87,' command in the OpenMW console (pressing "~" in game) to reload your Lua scripts and re-render the UI. However... '),t(),n(88,"app-alert"),e(89," When creating new files while the game is still running, OpenMW does not recognize them at runtime. Because we created a new button file, you will need to reload your game to get them registered in the game's virtual file system. "),t(),n(90,"p"),e(91," Now, with the button registered and in our HTML, our UI will look like this: "),t(),r(92,"app-content-image",4),n(93,"h2"),e(94,"Adding Content"),t(),n(95,"p"),e(96," This is a boring button, let's project some content into it by modifying our parent element, "),n(97,"code"),e(98,"MainWindow.html"),t(),e(99," where we use our custom element tag and provide some text. "),t(),r(100,"app-code-highlighter",0),n(101,"p"),e(102," Which results in: "),t(),r(103,"app-content-image",5),n(104,"p"),e(105," We can simplify our "),n(106,"code"),e(107,"MainWindow.html"),t(),e(108," by moving the "),n(109,"code"),e(110,"mw-text"),t(),e(111," inside the button and adjusting the "),n(112,"code"),e(113,"mw-content"),t(),e(114," location. See both files now below: "),t(),r(115,"app-code-highlighter",0),n(116,"p"),e(117," Let's, now, center our text by modifying "),n(118,"code"),e(119,"Button.css"),t(),e(120,". There are two ways to do this. One, you can use "),n(121,"code"),e(122,"mw-flex"),t(),e(123," and align-items and justify-content to center the "),n(124,"code"),e(125,"mw-text"),t(),e(126,". This works because, by default, "),n(127,"code"),e(128,"mw-text"),t(),e(129," is auto-sized. For this example, we will disable auto sizing and set the mw-text to be full width and height of its container. The new Button.html and Button.css are below: "),t(),r(130,"app-code-highlighter",0)(131,"app-content-image",6),n(132,"app-alert"),e(133," You may notice the alignment is ever-so-slightly off. This is because, at the time of writing, OpenMW does not provide a way to calculate the bounds of text. So, we have to make an approximation. Literally, by manually trying to guess how wide and tall each letter might be at that font size. "),t(),n(134,"h2"),e(135,"Event Bindings for Click"),t(),n(136,"p"),e(137," Finally, let's dive into hooking a click event on your button. We can't currently implement a hover effect in AnglesUI because OpenMW does not provide a mouseEnter or mouseLeave event. Any other implementation (such as tracking the mouse movement) would simply be bad performance. "),t(),n(138,"p"),e(139," Let's register a context variable that is a function callback in our UIManager.lua to use as a click function. "),t(),r(140,"app-code-highlighter",0),n(141,"p"),e(142," Given the earlier statement about no AnglesUI hover, you are of course welcome to use the callback parameters to try and register your own hover events on the Lua side. "),t(),n(143,"p"),e(144," Next, update your MainWindow.html to hook the event to the button. "),t(),r(145,"app-code-highlighter",0),n(146,"p"),e(147," That's everything. Now, click the button in-game and you'll see your text printed. You can see the Lua output by pressing F10 and opening the Log Viewer. "),t(),r(148,"app-content-image",7),n(149,"p"),e(150," Utilizing more of AnglesUI features and elements, you can quickly (within seconds to minutes) turn static layouts into responsive grids. Read about our "),n(151,"a",8),e(152,"responsive UI design"),t(),e(153,". "),t(),r(154,"app-content-image",9),t()()()),p&2&&(l(25),m("CodeTabs",u(14,w,i(10,c,d.ParentHTMLCode1()),i(12,F,d.ParentCSSCode1()))),l(14),m("CodeTabs",i(19,s,i(17,h,d.LuaCode1()))),l(22),m("CodeTabs",i(23,s,i(21,h,d.LuaCode2()))),l(15),m("CodeTabs",u(29,w,i(25,b,d.ChildHTMLCode1()),i(27,E,d.ChildCSSCode1()))),l(6),m("CodeTabs",i(34,s,i(32,c,d.ParentHTMLCode2()))),l(18),m("CodeTabs",i(38,s,i(36,c,d.ParentHTMLCode3()))),l(15),m("CodeTabs",u(44,w,i(40,c,d.ParentHTMLCode4()),i(42,b,d.ChildHTMLCode2()))),l(15),m("CodeTabs",u(51,w,i(47,b,d.ChildHTMLCode3()),i(49,E,d.ChildCSSCode2()))),l(10),m("CodeTabs",i(56,s,i(54,h,d.LuaCode3()))),l(5),m("CodeTabs",i(60,s,i(58,c,d.ParentHTMLCode5()))))},dependencies:[M,S,f,y,v,L,C,T],encapsulation:2})};export{k as MakingAButton};
