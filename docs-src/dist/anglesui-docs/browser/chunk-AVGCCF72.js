import{a as S}from"./chunk-RI7MM73A.js";import{a as w}from"./chunk-3TMNW2FJ.js";import{a as g,b as f,c as h}from"./chunk-ARCBSOD7.js";import{Aa as o,Ba as i,Ca as t,Da as r,Q as m,R as p,Ra as e,X as a,ea as n,hb as u,na as c}from"./chunk-Z5QWJB5W.js";import"./chunk-Q7L6LLAK.js";var x=class s{LuaCode=a(`
local Renderer = require("scripts.Nox.AnglesUI.Renderer.Renderer")
local Signal = require("scripts.Nox.AnglesUI.Signals.Signal")

local castleStaffArraySignal = Signal.New({
  { Name = "Dlarven Hlori", Description = "Steward of the castle's first floor." },
  { Name = "Servia Platios", Description = "Attendant to the head chef." },
  { Name = "Taylorn Vyn", Description = "Chief guard and tired knight's errant of the Imperial Legion." },
})

local renderer = Renderer.FromFile("scripts/Nox/UI/LogisticsUI.html", {})
renderer:Render({
  CastleStaff = castleStaffArraySignal
})
    `);HTMLCode=a(`
<mw-root Layer="Windows" Resizable="true">
  <mw-window>
    <mw-flex>
      @for (staffMember in CastleStaff()) {
        <mw-window>
          <mw-flex>
            <mw-text class="title" AutoSize="false">{{ staffMember.Name }}</mw-text>
            <mw-text class="description">{{ staffMember.Description }}</mw-text>
          </mw-flex>
        </mw-window>
      }
    </mw-flex>
  </mw-window>
</mw-root>
    `);CSSCode=a(`
mw-root {
  width: 800px;
  height: 400px;
}

mw-window {
  padding: 10px;
}

mw-flex {
  width: 100%;
  height: 100%;
  flex-direction: column;
  gap: 20px;

  & > mw-window {
    padding: 10px;
    height: 100px;
    background: none;

    mw-flex {
      width: 100%;
      height: 100%;
      flex-direction: column;

      .title {
        font-size: 24px;
        width: 100%;
        height: 30px;
      }
    }
  }
}
    `);PitfallCode=a(`
table.remove(castleStaffArraySignal(), 1)
castleStaffArraySignal:Set(castleStaffArraySignal())
    `);GoodSignalLuaCode=a(`
local current = castleStaffArraySignal()
local newStaff = {}
for i = 2, #current do
  table.insert(newStaff, current[i])
end
castleStaffArraySignal:Set(newStaff)
    `);static \u0275fac=function(d){return new(d||s)};static \u0275cmp=c({type:s,selectors:[["app-for-loop-directives"]],decls:36,vars:5,consts:[["Language","lua",3,"Code"],["Language","angular-html",3,"Code"],["Alt","Rendered result of a for loop directive","Src","images/examples/for-loop-directive-1.png"],["Language","css",3,"Code"]],template:function(d,l){d&1&&(i(0,"app-content-width-container")(1,"app-card")(2,"app-card-header")(3,"h1"),e(4,"For Loop Directives in AnglesUI"),t()(),i(5,"app-card-body")(6,"p"),e(7," In AnglesUI, you can use "),i(8,"code"),p(),e(9,"for (item in array) {}"),m(),t(),e(10," syntax to iterate over data and render elements dynamically. The data iterated over is data-type agnostic. This allows for complex data structures to be easily rendered in your UI. "),t(),i(11,"p"),e(12,` For this example, we will present Lua code that has an array of "Castle Staff" objects. Then, we'll use a flex container in column direction to generate boxes with their names and job descriptions. `),t(),r(13,"app-code-highlighter",0),i(14,"p"),e(15," Then, our HTML will look like such: "),t(),r(16,"app-code-highlighter",1),i(17,"p"),e(18," We'll be presented with the following rendered result (the CSS styling for this is below the image): "),t(),r(19,"app-content-image",2)(20,"app-code-highlighter",3),i(21,"h2"),e(22,"Common Pitfalls with Loops and Signals"),t(),i(23,"p"),e(24," Because we are dealing with signals and for loops, that means we're dealing with a table of data. There may be a time where you mutate an existing table and expect the UI to update when you set your signal value to the same table. This will not work, as the signal will not detect a change in value since the reference is the same. To get around this, you can create a new table and copy the values over, then set your signal to that new table. This will trigger the UI to update as the reference has changed. "),t(),i(25,"p"),e(26," For example, do "),i(27,"strong"),e(28,"not"),t(),e(29," do this: "),t(),r(30,"app-code-highlighter",0),i(31,"p"),e(32," This will just set the signal to the same table reference - which will not trigger a UI update. "),t(),i(33,"p"),e(34," Instead, you must get a new table reference. This is required because we do not use index tracking in our for loop (currently, we may support this in the future if performance requires it). "),t(),r(35,"app-code-highlighter",0),t()()()),d&2&&(n(13),o("Code",l.LuaCode()),n(3),o("Code",l.HTMLCode()),n(4),o("Code",l.CSSCode()),n(10),o("Code",l.PitfallCode()),n(5),o("Code",l.GoodSignalLuaCode()))},dependencies:[u,g,f,h,S,w],encapsulation:2})};export{x as ForLoopDirectives};
