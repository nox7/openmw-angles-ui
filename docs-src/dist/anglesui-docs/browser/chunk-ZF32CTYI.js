import{a as v}from"./chunk-4UVQU5FT.js";import{a as C}from"./chunk-XQWTI7VS.js";import{a as f,b,c as y}from"./chunk-OI63Y6K5.js";import{f as x}from"./chunk-73NXMPKY.js";import"./chunk-X23CRHME.js";import{Aa as l,Lb as S,Pa as g,ab as m,ba as a,bb as i,cb as t,db as r,sb as e,xb as s,yb as p,zb as h}from"./chunk-D3QXKHB2.js";import"./chunk-Q7L6LLAK.js";var w=o=>({TabLabel:"Store.html",Code:o,Language:"angular-html"}),u=o=>({TabLabel:"Store.css",Code:o,Language:"css"}),U=o=>({TabLabel:"Button.html",Code:o,Language:"angular-html"}),L=o=>({TabLabel:"Button.css",Code:o,Language:"css"}),E=(o,c,d,n)=>[o,c,d,n],M=o=>({TabLabel:"UI.lua",Code:o,Language:"lua"}),A=o=>[o],I=(o,c)=>[o,c],k=class o{UIHTML1=a(`
<mw-root Layer="Windows" Resizable="true" EdgeMargin="15px">
  <mw-window>
    <mw-flex id="outer-layout">
      <mw-flex id="title" Dragger="true">
        <mw-text AutoSize="false">Castle Armory Store</mw-text>
        <mw-hr></mw-hr>
      </mw-flex>
      <mw-grid id="side-by-side">
        <mw-window>
          <mw-scroll-canvas id="category-buttons">
            <nox-button>Armor</nox-button>
            <nox-button>Weapons</nox-button>
            <nox-button>Potions</nox-button>
            <nox-button>Food</nox-button>
            <nox-button>Relics</nox-button>
            <nox-button>Boats</nox-button>
          </mw-scroll-canvas>
        </mw-window>
        <mw-window>
          
        </mw-window>
      </mw-grid>
    </mw-flex>
</mw-root>
  `);UICSS1=a(`
mw-root {
  width: 1000px;
  height: 500px;
  position: absolute;
  left: calc(50% - 500px);
  top: calc(50% - 250px);

  & > mw-window {
    padding: 10px;
  }
}

#outer-layout {
  flex-direction: column;
}

#title {
  height: 40px;
  flex-direction: column;
  gap: 4px;

  mw-text {
    width: 100%;
    height: 20px;
    font-size: 20px;
  }
}

#side-by-side {
  flex-grow: 1;
  grid-template-columns: 280px 1fr;
  gap: 20px;

  mw-window {
    background: none;
    padding: 10px;
  }
}

#category-buttons {
  padding: 10px;
  height: 100%;
  width: 100%;
  flex-direction: column;
  gap: 20px;

  mw-text {
    font-size: 18px;
  }
}
  `);ButtonHTML1=a(`
<mw-host>
  <mw-window class="button-wrapper">
    <mw-text AutoSize="false"><mw-content></mw-content></mw-text>
  </mw-window>
</mw-host>
  `);ButtonCSS1=a(`
mw-host {
  width: 100%;
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
  `);LuaCode1=a(`
local Renderer = require("scripts.Nox.AnglesUI.Renderer.Renderer")
local Signal = require("scripts.Nox.AnglesUI.Signals.Signal")

local renderer = Renderer.FromFile("scripts/Nox/UI/Store.html", {
  ["nox-button"] = "scripts/Nox/UI/Button.html"
})

local itemsByCategory = Signal.New({
  ["Armor"] = {
    { Name = "Dragonscale Helmet", Quantity = 2, IconPath = "icons/a/tx_dragonscale_helm.dds"},
    { Name = "Glass Helmet", Quantity = 2, IconPath = "icons/a/tx_glass_helmet.dds"},
    { Name = "Dragonscale Helmet", Quantity = 2, IconPath = "icons/a/tx_dragonscale_helm.dds"},
    { Name = "Glass Helmet", Quantity = 2, IconPath = "icons/a/tx_glass_helmet.dds"},
    { Name = "Dragonscale Helmet", Quantity = 2, IconPath = "icons/a/tx_dragonscale_helm.dds"},
    { Name = "Glass Helmet", Quantity = 2, IconPath = "icons/a/tx_glass_helmet.dds"},
    { Name = "Dragonscale Helmet", Quantity = 2, IconPath = "icons/a/tx_dragonscale_helm.dds"},
    { Name = "Glass Helmet", Quantity = 2, IconPath = "icons/a/tx_glass_helmet.dds"},
  }
})

local selectedCategory = Signal.New(nil)

renderer:Render({
  SelectedCategory = selectedCategory,
  ItemsByCategory = itemsByCategory,
  OnStoreCategoryClicked = function(categoryName)
    selectedCategory:Set(categoryName)
  end
})
  `);UIHTML2=a(`
<mw-root Layer="Windows" Resizable="true" EdgeMargin="15px">
  <mw-window>
    <mw-flex id="outer-layout">
      <mw-flex id="title" Dragger="true">
        <mw-text AutoSize="false">Castle Armory Store</mw-text>
        <mw-hr></mw-hr>
      </mw-flex>
      <mw-grid id="side-by-side">
        <mw-window>
          <mw-scroll-canvas id="category-buttons">
            <nox-button (mouseClick)="OnStoreCategoryClicked('Armor')">Armor</nox-button>
            <nox-button (mouseClick)="OnStoreCategoryClicked('Weapons')">Weapons</nox-button>
            <nox-button (mouseClick)="OnStoreCategoryClicked('Potions')">Potions</nox-button>
            <nox-button (mouseClick)="OnStoreCategoryClicked('Food')">Food</nox-button>
            <nox-button (mouseClick)="OnStoreCategoryClicked('Relics')">Relics</nox-button>
            <nox-button (mouseClick)="OnStoreCategoryClicked('Boats')">Boats</nox-button>
          </mw-scroll-canvas>
        </mw-window>
        <mw-window>
          <mw-scroll-canvas id="store-items">
            <mw-grid id="store-grid">
              @if (SelectedCategory() === "Armor") {
                @for (item in ItemsByCategory().Armor) {
                  <mw-flex class="store-item">
                    <mw-window>
                      <mw-image [Resource]="item.IconPath"></mw-image>
                    </mw-window>
                  </mw-flex>
                }
              }
            </mw-grid>
          </mw-scroll-canvas>
        </mw-window>
      </mw-grid>
    </mw-flex>
</mw-root>
  `);UICSS2=a(`
mw-root {
  width: 1000px;
  height: 500px;
  position: absolute;
  left: calc(50% - 500px);
  top: calc(50% - 250px);

  & > mw-window {
    padding: 10px;
  }
}

#outer-layout {
  flex-direction: column;
}

#title {
  height: 40px;
  flex-direction: column;
  gap: 4px;

  mw-text {
    width: 100%;
    height: 20px;
    font-size: 20px;
  }
}

#side-by-side {
  flex-grow: 1;
  grid-template-columns: 280px 1fr;
  gap: 20px;

  mw-window {
    background: none;
    padding: 10px;
  }
}

#category-buttons {
  padding: 10px;
  height: 100%;
  width: 100%;
  flex-direction: column;
  gap: 20px;

  mw-text {
    font-size: 18px;
  }
}

#store-items {
  width: 100%;
  height: 100%;
  #store-grid {
    grid-template-columns: repeat(5, 1fr);
    gap: 10px;
  
    .store-item {
      width: 100%;
      height: 100px;
      justify-content: center;
      mw-window {
        aspect-ratio: 1 / 1;
        mw-image {
          width: 100%;
          height: 100%;
        }
      }
    }
  }
}
  `);CodeSnippetContainer1=a(`
container-type: size;
container-name: main-window;
  `);CodeSnippetContainer2=a(`
@container main-window (width <= 600px) {

}
  `);UIHTML3=a(`
<mw-root Layer="Windows" Resizable="true" EdgeMargin="15px">
  <mw-window>
    <mw-flex id="outer-layout">
      <mw-flex id="title" Dragger="true">
        <mw-text AutoSize="false">Castle Armory Store</mw-text>
        <mw-hr></mw-hr>
      </mw-flex>
      <mw-grid id="side-by-side">
        <mw-window>
          <mw-scroll-canvas id="category-buttons">
            <nox-button (mouseClick)="OnStoreCategoryClicked('Armor')">Armor</nox-button>
            <nox-button (mouseClick)="OnStoreCategoryClicked('Weapons')">Weapons</nox-button>
            <nox-button (mouseClick)="OnStoreCategoryClicked('Potions')">Potions</nox-button>
            <nox-button (mouseClick)="OnStoreCategoryClicked('Food')">Food</nox-button>
            <nox-button (mouseClick)="OnStoreCategoryClicked('Relics')">Relics</nox-button>
            <nox-button (mouseClick)="OnStoreCategoryClicked('Boats')">Boats</nox-button>
          </mw-scroll-canvas>
        </mw-window>
        <mw-window id="store-window">
          <mw-scroll-canvas id="store-items">
            <mw-grid id="store-grid">
              @if (SelectedCategory() === "Armor") {
                @for (item in ItemsByCategory().Armor) {
                  <mw-flex class="store-item">
                    <mw-window>
                      <mw-image [Resource]="item.IconPath"></mw-image>
                    </mw-window>
                  </mw-flex>
                }
              }
            </mw-grid>
          </mw-scroll-canvas>
        </mw-window>
      </mw-grid>
    </mw-flex>
</mw-root>
  `);UICSS3=a(`
mw-root {
  width: 1000px;
  height: 500px;
  position: absolute;
  left: calc(50% - 500px);
  top: calc(50% - 250px);

  & > mw-window {
    padding: 10px;
    container-type: size;
    container-name: main-window;
  }
}

#outer-layout {
  flex-direction: column;
}

#title {
  height: 40px;
  flex-direction: column;
  gap: 4px;

  mw-text {
    width: 100%;
    height: 20px;
    font-size: 20px;
  }
}

#side-by-side {
  flex-grow: 1;
  grid-template-columns: 280px 1fr;
  gap: 20px;

  mw-window {
    background: none;
    padding: 10px;
  }
}

#category-buttons {
  padding: 10px;
  height: 100%;
  width: 100%;
  flex-direction: column;
  gap: 20px;

  mw-text {
    font-size: 18px;
  }
}

#store-window {
  container-type: size;
  container-name: store-window;
}

#store-items {
  width: 100%;
  height: 100%;
  #store-grid {
    grid-template-columns: repeat(5, 1fr);
    justify-content: center;
    gap: 10px;
  
    .store-item {
      width: 100%;
      height: 100px;
      justify-content: center;
      mw-window {
        aspect-ratio: 1 / 1;
        mw-image {
          width: 100%;
          height: 100%;
        }
      }
    }
  }
}

@container main-window (width <= 600px) {
  #side-by-side {
    grid-template-columns: 1fr;
  }
}

@container store-window (width <= 425px) {
  #store-items {
    #store-grid {
      grid-template-columns: repeat(3, 1fr);
    }
  }
}

@container store-window (width <= 325px) {
  #store-items {
    #store-grid {
      grid-template-columns: repeat(1, 1fr);
    }
  }
}
  `);static \u0275fac=function(d){return new(d||o)};static \u0275cmp=g({type:o,selectors:[["app-responsive-ui-design"]],decls:78,vars:37,consts:[["routerLink","/making-a-ui"],["routerLink","/examples/custom-components"],["Alt","Store UI","Src","/images/examples/responsive-ui/finished.png"],["Alt","Step 1: Outer layout of the UI","Src","/images/examples/responsive-ui/step-1.png"],["Alt","Step 2: Outer layout of the UI","Src","/images/examples/responsive-ui/step-2.png"],[3,"CodeTabs"],["Alt","Step 3: Final design of the UI","Src","/images/examples/responsive-ui/step-3.png"],["Language","css",3,"Code"],["Alt","Finished UI with responsive design","Src","/images/examples/responsive-ui/step-4.gif"],["Alt","Stopwatch result time. Reads 19 minutes and 05 seconds.","Src","/images/examples/responsive-ui/stopwatch-result.png"]],template:function(d,n){d&1&&(i(0,"app-content-width-container")(1,"app-card")(2,"app-card-header")(3,"h1"),e(4,"Responsive UI Design in AnglesUI"),t()(),i(5,"app-card-body")(6,"p"),e(7," Before reading, if you're not familiar with registering an HTML component, then read "),i(8,"a",0),e(9,"making a UI"),t(),e(10," first. Further, read "),i(11,"a",1),e(12,"custom components"),t(),e(13," if you're not familiar with registering custom components into your UI. "),t(),i(14,"p"),e(15," By far the most powerful feature of AnglesUI is its responsive design system. It allows you to create interfaces that adapt to different screen (and container) sizes and orientations, providing an optimal user experience across a wide range of devices. Whether you're designing for desktop, tablet, or mobile, AnglesUI's responsive design features ensure that your UI looks great and functions well on any device. "),t(),i(16,"p"),e(17," Further, one of the most natural flows of UI in Morrowind while playing is being able to move and resize the UI (such as dialogue or barter windows). You can cleanly implement your UI to be compatible with however the user wants to resize the UI with this framework - with minimal effort. "),t(),i(18,"h2"),e(19,"Example: Making a Custom Store UI"),t(),i(20,"p"),e(21," Let's go all out with this example. We'll create a custom UI representing some store for a mod. This store UI will have a title at the top, horizontal rule (little bar separator), a left-hand sidebar (scrollable) with item categories, and finally a main window with icon buttons of items to purchase. "),t(),i(22,"p")(23,"strong"),e(24,"For good measures,"),t(),e(25," we'll start a Windows stopwatch to time how long this UI takes us. "),t(),i(26,"p"),e(27," Here is what we will make in this guide (final result GIF at the bottom and source code) "),t(),r(28,"app-content-image",2),i(29,"h2"),e(30,"Outer Layout"),t(),i(31,"p"),e(32," Given the description above, we'll write code to define the outer layout of our store UI. "),t(),r(33,"app-content-image",3),i(34,"p"),e(35," A good first draft, and so far on the clock we're at 1:57 - but it's basic and a bit too big. We'll shrink it, add some buttons in the left-sidebar and increase text size. "),t(),r(36,"app-content-image",4),i(37,"p"),e(38," We're now at 5:42 on the stopwatch. Here is the code for this at this point. "),t(),r(39,"app-code-highlighter",5),i(40,"h2"),e(41,"Button Events and Store Inventory Icons"),t(),i(42,"p"),e(43," Let's finish this design example up (before going to the responsive part) by adding some context to the Lua side of this UI (passing in an array of items to purchase). We haven't shown the Lua registration of this component yet in this example, so we'll show the full code now. Including the passed in loop and click event callback. "),t(),r(44,"app-code-highlighter",5),i(45,"p"),e(46," This will give us our final example result (we won't be adding anymore functionality). The HTML/CSS source for this layout is below the image. In a more realistic and fleshed out example, we may add text or tooltips to the buttons for a better user experience. However, we need to get into the responsive design aspect. "),t(),r(47,"app-content-image",6),i(48,"p"),e(49," Source code: "),t(),r(50,"app-code-highlighter",5),i(51,"h2"),e(52,"Making our Layour Responsive"),t(),i(53,"p"),e(54," Now for the real testament. This layout is resizable - and even if it wasn't we'd want it to fit on any screen size or any window size. All we need to do is make a few adjustments. "),t(),i(55,"p"),e(56,' First, we use container properties in CSS to define a "container" target for any container queries. We use container queries to ask the renderer "What size is this element?" at any given time. We will use our most-outer '),i(57,"code"),e(58,"mw-window"),t(),e(59," as our container. So we'll add "),t(),r(60,"app-code-highlighter",7),i(61,"p"),e(62," to our CSS and target the main window (the full CSS will be at the end of this section). With this, we can now write a container query that changes the styling based on the main window's width (or height, if that had been what we wanted). "),t(),r(63,"app-code-highlighter",7),i(64,"p"),e(65," With something like this, any CSS rules we place inside there will only be applied if the main window's width is less than or equal to 600px. Here's a breakdown of what we want to happen: "),t(),i(66,"ul")(67,"li"),e(68,"Our two-column side-by-side grid collapses into a single column"),t(),i(69,"li"),e(70,"Our store item buttons gradually (over a few container queries) collapse from 5 columns, to 3, then to 1"),t()(),i(71,"p"),e(72," After just a few more lines of code for our media queries, this is what we end up with (source code at the bottom). "),t(),r(73,"app-content-image",8)(74,"app-code-highlighter",5),i(75,"p"),e(76," Total time: 19 minutes and 5 seconds. "),t(),r(77,"app-content-image",9),t()()()),d&2&&(l(39),m("CodeTabs",h(14,E,s(6,w,n.UIHTML1()),s(8,u,n.UICSS1()),s(10,U,n.ButtonHTML1()),s(12,L,n.ButtonCSS1()))),l(5),m("CodeTabs",s(21,A,s(19,M,n.LuaCode1()))),l(6),m("CodeTabs",p(27,I,s(23,w,n.UIHTML2()),s(25,u,n.UICSS2()))),l(10),m("Code",n.CodeSnippetContainer1()),l(3),m("Code",n.CodeSnippetContainer2()),l(11),m("CodeTabs",p(34,I,s(30,w,n.UIHTML3()),s(32,u,n.UICSS3()))))},dependencies:[S,f,b,y,C,v,x],encapsulation:2})};export{k as ResponsiveUiDesign};
