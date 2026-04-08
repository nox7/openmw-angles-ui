import{a as b}from"./chunk-FCHIL3KZ.js";import{a as S}from"./chunk-4G462PBM.js";import{a as f}from"./chunk-XQWTI7VS.js";import{a as h,b as w,c as x}from"./chunk-3UBWY4HP.js";import{f as g}from"./chunk-73NXMPKY.js";import"./chunk-X23CRHME.js";import{Aa as l,Lb as C,Pa as p,ab as c,ba as a,bb as t,cb as n,db as s,sb as e,xb as m,zb as u}from"./chunk-D3QXKHB2.js";import"./chunk-Q7L6LLAK.js";var L=i=>({TabLabel:"LogisticsRoot.html",Code:i,Language:"angular-html"}),M=i=>({TabLabel:"LogisticsRoot.css",Code:i,Language:"css"}),E=i=>({TabLabel:"MainGrid.html",Code:i,Language:"angular-html"}),v=i=>({TabLabel:"MainGrid.css",Code:i,Language:"css"}),I=(i,d,r,o)=>[i,d,r,o],y=class i{RegisterLuaCode=a(`
local Renderer = require("scripts.Nox.AnglesUI.Renderer.Renderer")

local renderer = Renderer.FromFile("scripts/Nox/UI/LogisticsRoot.html", {
  ["nox-product-grid"] = "scripts/Nox/UI/MainGrid.html",
})

renderer:Render({})
  `);MainUIHTML=a(`
<mw-root Layer="Windows" Resizable="true">
  <mw-window id="main-window">
    <mw-flex>
      <mw-widget id="header-text-container">
        <mw-flex>
          <mw-text>Manage Your Castle's Product Shipping Logistics</mw-text>
          <mw-hr></mw-hr>
        </mw-flex>
      </mw-widget>
      <nox-product-grid></nox-product-grid>
    </mw-flex>
  </mw-window>
</mw-root>
  `);MainUICSS=a(`
mw-root {
  width: 800px;
  height: 400px;
  right: 0;
  right: calc(50% - calc(800px / 2));
  top: calc(50% - calc(400px / 2));
  position: absolute;
}

#main-window {
  padding: 10px;
  container-type: size;
  container-name: main;

  & > mw-flex {
    width: 100%;
    height: 100%;
    flex-direction: column;
  }
}

#header-text-container {
  width: 100%;
  height: 25px;

  & > mw-flex {
    width: 100%;
    height: 100%;
    flex-direction: column;
  }
}
  `);GridHTML=a(`
<mw-grid id="grid-1">
  <mw-window></mw-window>
  <mw-window></mw-window>
  <mw-window></mw-window>
</mw-grid>
  `);GridCSS=a(`
#grid-1 {
  width: 100%;
  flex-grow: 1;
  gap: 20px;
}
  `);static \u0275fac=function(r){return new(r||i)};static \u0275cmp=p({type:i,selectors:[["app-custom-components"]],decls:58,vars:15,consts:[["Language","lua",3,"Code"],[3,"CodeTabs"],["Src","/images/examples/custom-components-1.png","Alt","Rendered custom component UI"],["routerLink","/content-projection"],["href","/event-bindings"]],template:function(r,o){r&1&&(t(0,"app-content-width-container")(1,"app-card")(2,"app-card-header")(3,"h1"),e(4,"Making Custom Components"),n()(),t(5,"app-card-body")(6,"p"),e(7," While there are a handful of existing UI components, you can also create your own custom components to better organize your UI and reuse design code. "),n(),t(8,"app-alert"),e(9," For those familiar with Angular, individual components have their own scopes. In AnglesUI, all components in a single render share the same scope. Custom components are simply transposed into the root component - not matter how deeply they are nested. "),n(),t(10,"h2"),e(11,"What is a Custom Component?"),n(),t(12,"p"),e(13," It's just a regular component, but without mw-root. Additionally, it's in its own file and the CSS can be in its own file as well. As mentioned before, the component is transposed. Your actual HTML tag you use to identify your custom component is replaced with the contents of your component file. The CSS is also transposed "),t(14,"strong"),e(15,"above"),n(),e(16," the root CSS. "),n(),t(17,"h2"),e(18,"Registering a Custom Component"),n(),t(19,"p"),e(20," You register a custom component by providing an key/value to the renderer before rendering. For example: "),n(),s(21,"app-code-highlighter",0),t(22,"p"),e(23," We have now registered a custom component with the HTML tag selector "),t(24,"code"),e(25,"nox-product-grid"),n(),e(26,". When we use this in any of our HTML files, it will have the contents at "),t(27,"code"),e(28,"scripts/Nox/UI/MainGrid.html"),n(),e(29," transposed in - as well as any CSS file in the same directory with the same base name. Such as "),t(30,"code"),e(31,"scripts/Nox/UI/MainGrid.css"),n(),e(32,". "),n(),t(33,"h2"),e(34,"Example of Usage"),n(),t(35,"p"),e(36," Let's use the above and make a primary (root) component and then use our custom component. The code sample is below for reference. "),n(),s(37,"app-code-highlighter",1),t(38,"p"),e(39," With this code, you'll get a UI like below: "),n(),s(40,"app-content-image",2),t(41,"h2"),e(42,"Content Projection"),n(),t(43,"p"),e(44," When you need to pass content from a parent component to a child component, you use content projection. Specifically, your child component will utilize "),t(45,"code"),e(46,"<mw-content>"),n(),e(47," elements to indicate where your project content should go. You can read more on this element here: "),t(48,"a",3),e(49,"Content Projection"),n(),e(50,". "),n(),t(51,"h2"),e(52,"Event Binding"),n(),t(53,"p"),e(54," Custom component event bindings require an extra step compared to regular engine element event bindings. Read the custom component section on "),t(55,"a",4),e(56,"event bindings"),n(),e(57,". "),n()()()()),r&2&&(l(21),c("Code",o.RegisterLuaCode()),l(16),c("CodeTabs",u(10,I,m(2,L,o.MainUIHTML()),m(4,M,o.MainUICSS()),m(6,E,o.GridHTML()),m(8,v,o.GridCSS()))))},dependencies:[C,h,w,x,b,S,f,g],encapsulation:2})};export{y as CustomComponents};
