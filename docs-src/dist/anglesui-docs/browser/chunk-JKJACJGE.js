import{a as C}from"./chunk-FCHIL3KZ.js";import{a as f}from"./chunk-4G462PBM.js";import{a as g,b as w,c as v}from"./chunk-3UBWY4HP.js";import{f as u}from"./chunk-73NXMPKY.js";import"./chunk-X23CRHME.js";import{Aa as l,Lb as x,Pa as p,ab as d,ba as o,bb as n,cb as t,db as s,sb as e,xb as c,yb as h}from"./chunk-D3QXKHB2.js";import"./chunk-Q7L6LLAK.js";var y=i=>({TabLabel:"Parent.html",Code:i,Language:"angular-html"}),E=i=>({TabLabel:"Child.html",Code:i,Language:"angular-html"}),S=(i,m)=>[i,m],b=class i{LuaCode1=o(`
local Renderer = require("scripts.Nox.AnglesUI.Renderer.Renderer")
local Signal = require("scripts.Nox.AnglesUI.Signals.Signal")

local onWindowClicked = function(e, l)
  print("Window clicked")
end

local renderer = Renderer.FromFile("scripts/Nox/UI/LogisticsUI.html", {})
renderer:Render({
  OnWindowClicked = onWindowClicked
})
  `);HTMLCode1=o(`
<mw-root Layer="Windows" [style.width]="'800px'" [style.height]="'400px'">
  <mw-window (mouseClick)="OnWindowClicked($event1, $event2)"></mw-window>
</mw-root>
  `);CustomComponentEventBinding1=o(`
<mw-root Layer="Windows" [style.width]="'800px'" [style.height]="'400px'">
  <nox-component (mousePress)=SomeFunc($event1, $event2)></nox-component>
</mw-root>
  `);CustomComponentEventBinding2=o(`
<mw-host>
  <mw-widget>
    <mw-text>Child Component</mw-text>
  </mw-widget>
</mw-host>
  `);static \u0275fac=function(a){return new(a||i)};static \u0275cmp=p({type:i,selectors:[["app-event-binding"]],decls:67,vars:10,consts:[["href","https://openmw.readthedocs.io/en/stable/reference/lua-scripting/user_interface.html#layers","target","_blank"],["Language","lua",3,"Code"],["Language","html",3,"Code"],["target","_blank","href","https://openmw.readthedocs.io/en/stable/reference/lua-scripting/widgets/widget.html"],["routerLink","/examples/custom-components"],[3,"CodeTabs"]],template:function(a,r){a&1&&(n(0,"app-content-width-container")(1,"app-card")(2,"app-card-header")(3,"h1"),e(4,"Event Bindings in AnglesUI"),t()(),n(5,"app-card-body")(6,"p"),e(7," Event bindings in AnglesUI are simple and 1-to-1 with OpenMW's Lua event API for UIs. Additionally, that means the layer that you place your "),n(8,"code"),e(9,"mw-root"),t(),e(10," component on will determine if interactive events even fire. Make sure to "),n(11,"a",0),e(12,"read their docs carefully"),t(),e(13," on which layers are interactive. "),t(),n(14,"p"),e(15," Let's say we have the following Lua code to register a renderer on an HTML file: "),t(),s(16,"app-code-highlighter",1),n(17,"p"),e(18," Then, we would use parenthesis on the element we want to bind the event to, and then assign it a function. For example, if we wanted to bind the "),n(19,"code"),e(20,"mouseClick"),t(),e(21," event to our function registered above, then we'd: "),t(),s(22,"app-code-highlighter",2),n(23,"p"),e(24," You may remember that we "),n(25,"strong"),e(26,"only allow"),t(),e(27," functions and signals to be registered in the rendering context. "),t(),n(28,"h2"),e(29,"Arguments Passed to Event Callbacks"),t(),n(30,"p"),e(31," All event callbacks will pass two parameters to the callback function: the first is the event object, and the second is the OpenMW UI element that triggered the event. The data type of the first event object is defined in OpenMW's UI docs for that particular event. "),t(),n(32,"p"),e(33," Use "),n(34,"code"),e(35,"$event1"),t(),e(36," and "),n(37,"code"),e(38,"$event2"),t(),e(39," to access these parameters in your registered callable for events. You can put them in any order you want (in case you need to pass your own custom arguments). "),t(),n(40,"app-alert"),e(41," Only callables you registered in your rendering context can be used for event bindings. Additionally, the syntax dictates that you write it as a function call and not just the function name. "),t(),n(42,"h2"),e(43,"What Are the Events?"),t(),n(44,"p"),e(45," We are 1-to-1 with the OpenMW event implementations. You can find them on the UI section of OpenMW's docs. Check each individual element to see which events they support. "),n(46,"a",3),e(47,"Here is a link"),t(),e(48," to docs on the Widget UI element, which is the base of all UI elements. "),t(),n(49,"h2"),e(50,"Event Bindings on Custom Components"),t(),n(51,"p"),e(52," For "),n(53,"a",4),e(54,"custom components"),t(),e(55,", event binding is slightly more complicated. Because custom components are transposed into the root element, there is no actual element to bind the event to. In Angular, all components get generated with a host element. In AnglesUI, this isn't the case; "),n(56,"strong"),e(57,"but"),t(),e(58," you can opt-in to host elements by placing one yourself. "),t(),n(59,"app-alert"),e(60," Event binding on custom components will not work without the host element. "),t(),n(61,"p"),e(62," Simply, you place a host element in your custom component with "),n(63,"code"),e(64,"<mw-host>"),t(),e(65,". For example, a parent and child component with event binding is displayed below. "),t(),s(66,"app-code-highlighter",5),t()()()),a&2&&(l(16),d("Code",r.LuaCode1()),l(6),d("Code",r.HTMLCode1()),l(44),d("CodeTabs",h(7,S,c(3,y,r.CustomComponentEventBinding1()),c(5,E,r.CustomComponentEventBinding2()))))},dependencies:[x,g,w,v,f,u,C],encapsulation:2})};export{b as EventBinding};
