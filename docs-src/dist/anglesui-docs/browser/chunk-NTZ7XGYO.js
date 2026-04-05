import{a as u}from"./chunk-RI7MM73A.js";import{a as c,b as p,c as h}from"./chunk-ARCBSOD7.js";import{Aa as r,Ba as t,Ca as n,Da as l,Ra as e,X as a,ea as o,hb as g,na as m}from"./chunk-Z5QWJB5W.js";import"./chunk-Q7L6LLAK.js";var f=class d{LuaCode1=a(`
local Renderer = require("scripts.Nox.AnglesUI.Renderer.Renderer")
local Signal = require("scripts.Nox.AnglesUI.Signals.Signal")

local onWindowClicked = function(e, l)
  print("Window clicked")
end

local renderer = Renderer.FromFile("scripts/Nox/UI/LogisticsUI.html", {})
renderer:Render({
  OnWindowClicked = onWindowClicked
})
    `);HTMLCode1=a(`
<mw-root Layer="Windows" [style.width]="'800px'" [style.height]="'400px'">
  <mw-window (mouseClick)="OnWindowClicked($event1, $event2)"></mw-window>
</mw-root>
    `);static \u0275fac=function(i){return new(i||d)};static \u0275cmp=m({type:d,selectors:[["app-event-binding"]],decls:39,vars:2,consts:[["href","https://openmw.readthedocs.io/en/stable/reference/lua-scripting/user_interface.html#layers","target","_blank"],["Language","lua",3,"Code"],["Language","html",3,"Code"],["target","_blank","href","https://openmw.readthedocs.io/en/stable/reference/lua-scripting/widgets/widget.html"]],template:function(i,s){i&1&&(t(0,"app-content-width-container")(1,"app-card")(2,"app-card-header")(3,"h1"),e(4,"Event Bindings in AnglesUI"),n()(),t(5,"app-card-body")(6,"p"),e(7," Event bindings in AnglesUI are simple and 1-to-1 with OpenMW's Lua event API for UIs. Additionally, that means the layer that you place your "),t(8,"code"),e(9,"mw-root"),n(),e(10," component on will determine if interactive events even fire. Make sure to "),t(11,"a",0),e(12,"read their docs carefully"),n(),e(13," on which layers are interactive. "),n(),t(14,"p"),e(15," Let's say we have the following Lua code to register a renderer on an HTML file: "),n(),l(16,"app-code-highlighter",1),t(17,"p"),e(18," Then, we would use parenthesis on the element we want to bind the event to, and then assign it a function. For example, if we wanted to bind the "),t(19,"code"),e(20,"mouseClick"),n(),e(21," event to our function registered above, then we'd: "),n(),l(22,"app-code-highlighter",2),t(23,"p"),e(24," You may remember that we "),t(25,"strong"),e(26,"only allow"),n(),e(27," functions and signals to be registered in the rendering context. "),n(),t(28,"h2"),e(29,"Arguments Passed to Event Callbacks"),n(),t(30,"p"),e(31," All event callbacks will pass two parameters to the callback function: the first is the event object, and the second is the OpenMW UI element that triggered the event. The data type of the first event object is defined in OpenMW's UI docs for that particular event. "),n(),t(32,"h2"),e(33,"What Are the Events?"),n(),t(34,"p"),e(35," We are 1-to-1 with the OpenMW event implementations. You can find them on the UI section of OpenMW's docs. Check each individual element to see which events they support. "),t(36,"a",3),e(37,"Here is a link"),n(),e(38," to docs on the Widget UI element, which is the base of all UI elements. "),n()()()()),i&2&&(o(16),r("Code",s.LuaCode1()),o(6),r("Code",s.HTMLCode1()))},dependencies:[g,c,p,h,u],encapsulation:2})};export{f as EventBinding};
