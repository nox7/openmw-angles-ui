import{a as I}from"./chunk-4UVQU5FT.js";import{a as v}from"./chunk-XQWTI7VS.js";import{a as w,b as h,c as g}from"./chunk-OI63Y6K5.js";import"./chunk-X23CRHME.js";import{Aa as p,Lb as U,Pa as m,ab as c,ba as r,bb as t,cb as i,db as a,sb as e,xb as o,yb as u}from"./chunk-D3QXKHB2.js";import"./chunk-Q7L6LLAK.js";var b=n=>({TabLabel:"UI.lua",Code:n,Language:"lua"}),y=n=>[n],f=n=>({TabLabel:"AnglesUI.html",Code:n,Language:"angular-html"}),x=n=>({TabLabel:"AnglesUI.css",Code:n,Language:"css"}),z=(n,d)=>[n,d],S=class n{LayoutInHTML1=r(`
<mw-root Layer="Windows">
  <mw-window>
    <mw-grid>
      <mw-window></mw-window>
      <mw-window></mw-window>
      <mw-window></mw-window>
    </mw-grid>
  </mw-window>
</mw-root>
  `);LayoutInCSS1=r(`
mw-root {
  width: 800px;
  height: 200px;
  position: absolute;
  left: calc(50% - 400px);
  top: calc(50% - 100px);

  & > mw-window {
    padding: 10px;
  }
}

mw-grid {
  grid-template-columns: repeat(3, 1fr);
  gap: 10px;
}
  `);LayoutInHTML2=r(`
<mw-root Layer="Windows" Resizable="true">
  <mw-window>
    <mw-grid>
      <mw-window></mw-window>
      <mw-window></mw-window>
      <mw-window></mw-window>
    </mw-grid>
  </mw-window>
</mw-root>
  `);OpenMWLuaCodeForUI1=r(`
local UI = require("openmw.ui")
local Util = require('openmw.util')
local MWUI = require('openmw.interfaces').MWUI

local e = UI.create({
  layer = "Windows",
  props = {
    size = Util.vector2(800, 200),
    relativePosition = Util.vector2(0.5, 0.5),
    anchor = Util.vector2(0.5, 0.5),
  },
  content = UI.content({
    {
      type = UI.TYPE.Image,
      props = {
        resource = UI.texture({
          path = "black"
        }),
        alpha = 0.83,
        relativeSize = Util.vector2(1, 1)
      }
    },
    {
      template = MWUI.templates.bordersThick,
      props = {
        relativeSize = Util.vector2(1,1),
      },
    },
    {
      props = {
        relativeSize = Util.vector2(1, 1),
        size = Util.vector2(-20, -20),
        position = Util.vector2(10, 10),
      },
      content = UI.content({
        {
          type = UI.TYPE.Flex,
          props = {
            relativeSize = Util.vector2(1, 1),
            autoSize = false,
            horizontal = true,
          },
          content = UI.content({
            {
              props = {
                relativeSize = Util.vector2(1/3, 1),
              },
              content = UI.content({
                {
                  props = {
                    relativeSize = Util.vector2(1, 1),
                    size = Util.vector2(-20, -20),
                    position = Util.vector2(10, 10),
                  },
                  content = UI.content({
                    {
                      type = UI.TYPE.Image,
                      props = {
                        resource = UI.texture({
                          path = "black"
                        }),
                        relativeSize = Util.vector2(1,1),
                      }
                    },
                    {
                      template = MWUI.templates.bordersThick,
                      props = {
                        relativeSize = Util.vector2(1,1),
                      },
                    },
                  })
                },
              }),
            },
            {
              props = {
                relativeSize = Util.vector2(1/3, 1),
              },
              content = UI.content({
                {
                  props = {
                    relativeSize = Util.vector2(1, 1),
                    size = Util.vector2(-20, -20),
                    position = Util.vector2(10, 10),
                  },
                  content = UI.content({
                    {
                      type = UI.TYPE.Image,
                      props = {
                        resource = UI.texture({
                          path = "black"
                        }),
                        relativeSize = Util.vector2(1,1),
                      }
                    },
                    {
                      template = MWUI.templates.bordersThick,
                      props = {
                        relativeSize = Util.vector2(1,1),
                      },
                    },
                  })
                },
              }),
            },
            {
              props = {
                relativeSize = Util.vector2(1/3, 1),
              },
              content = UI.content({
                {
                  props = {
                    relativeSize = Util.vector2(1, 1),
                    size = Util.vector2(-20, -20),
                    position = Util.vector2(10, 10),
                  },
                  content = UI.content({
                    {
                      type = UI.TYPE.Image,
                      props = {
                        resource = UI.texture({
                          path = "black"
                        }),
                        relativeSize = Util.vector2(1,1),
                      }
                    },
                    {
                      template = MWUI.templates.bordersThick,
                      props = {
                        relativeSize = Util.vector2(1,1),
                      },
                    },
                  })
                },
              }),
            },
          })
        }
      })
    },
  })
})
  `);static \u0275fac=function(l){return new(l||n)};static \u0275cmp=m({type:n,selectors:[["app-why-use-anglesui"]],decls:44,vars:18,consts:[["Alt","Simple 3 column box layout","Src","/images/why-use/goal.png"],[3,"CodeTabs"]],template:function(l,s){l&1&&(t(0,"app-content-width-container")(1,"app-card")(2,"app-card-header")(3,"h1"),e(4,"Why Use AnglesUI and Not the Plain Lua API?"),i()(),t(5,"app-card-body")(6,"p"),e(7," Simply put, you should spend time making and fleshing out your mod. You shouldn't need to spend excessive time writing boilerplate code or a UI that doesn't respond to natural user-experience actions like scrolling, resizing, or moving. "),i(),t(8,"p"),e(9," Let's demonstrate this with an example. We want to make the following simple layout: "),i(),a(10,"app-content-image",0),t(11,"p"),e(12," This should take no more than 60 seconds and a few lines of design code. However, in the plain OpenMW Lua UI API, this is what it takes (and remember, this "),t(13,"strong"),e(14,"isn't even responsive yet"),i(),e(15," - it's just a static layout): "),i(),a(16,"app-code-highlighter",1),t(17,"p"),e(18," Note that the gapping between elements isn't uniform - this is because there isn't a real sense of padding or gap properties in the Lua API - if we wanted this to be pixel-accurate we would need a more complex solution. "),i(),t(19,"p"),e(20," Now, let's see the same layout in AnglesUI (which is a pixel-perfect rendering system): "),i(),a(21,"app-code-highlighter",1),t(22,"p"),e(23," This is not meant to be a jab or insult at the OpenMW Lua API - it provides all the necessary basic UI elements to create elements we want. However, AnglesUI was created to respect mod development time and allow for stateful, reactive rendering with responsive rendering support - things we've come to expect in UI development. "),i(),t(24,"h2"),e(25,"Adding Resizing Functionality"),i(),t(26,"p"),e(27,"We'll start with the Lua-only version of the UI. We need to do a handful of calculations to determine a reasonable and fluid resize functionality on our UI. Additionally, we need edge-detection to determine if they're resizing from an edge or a corner - and which edge or corner."),i(),t(28,"p"),e(29,"TODO - write this section for Lua"),i(),t(30,"p"),e(31," However, in AnglesUI - this is all done for you. You simply need to add "),t(32,"code"),e(33,"Resizable"),i(),e(34," to your "),t(35,"code"),e(36,"mw-root"),i()(),a(37,"app-code-highlighter",1),t(38,"h2"),e(39,"Making the UI Responsive to Resize and Container Size"),i(),t(40,"p"),e(41," This is where the real power of AnglesUI shines. With the plain Lua API, you would need to write a lot of code to handle resizing and responsiveness. You would need to listen for resize events, calculate the new sizes and positions of each element, and then apply those changes manually. This can quickly become complex and error-prone, especially as your UI grows in complexity. "),i(),t(42,"p"),e(43,"TODO finish writing this"),i()()()()),l&2&&(p(16),c("CodeTabs",o(5,y,o(3,b,s.OpenMWLuaCodeForUI1()))),p(5),c("CodeTabs",u(11,z,o(7,f,s.LayoutInHTML1()),o(9,x,s.LayoutInCSS1()))),p(16),c("CodeTabs",o(16,y,o(14,f,s.LayoutInHTML2()))))},dependencies:[U,w,h,g,I,v],encapsulation:2})};export{S as WhyUseAnglesui};
