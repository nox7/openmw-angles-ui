import{a as I}from"./chunk-4UVQU5FT.js";import{a as U}from"./chunk-XQWTI7VS.js";import{a as y,b as g,c as w}from"./chunk-OI63Y6K5.js";import"./chunk-X23CRHME.js";import{Aa as s,Lb as v,Pa as m,ab as p,ba as a,bb as o,cb as t,db as l,sb as e,xb as n,yb as h}from"./chunk-D3QXKHB2.js";import"./chunk-Q7L6LLAK.js";var z=i=>({TabLabel:"UI.lua",Code:i,Language:"lua"}),c=i=>[i],f=i=>({TabLabel:"AnglesUI.html",Code:i,Language:"angular-html"}),b=i=>({TabLabel:"AnglesUI.css",Code:i,Language:"css"}),S=(i,d)=>[i,d],x=class i{LayoutInHTML1=a(`
<mw-root Layer="Windows">
  <mw-window>
    <mw-grid>
      <mw-window></mw-window>
      <mw-window></mw-window>
      <mw-window></mw-window>
    </mw-grid>
  </mw-window>
</mw-root>
  `);LayoutInCSS1=a(`
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
  `);LayoutInHTML2=a(`
<mw-root Layer="Windows" Resizable="true">
  <mw-window Dragger="true">
    <mw-grid>
      <mw-window></mw-window>
      <mw-window></mw-window>
      <mw-window></mw-window>
    </mw-grid>
  </mw-window>
</mw-root>
  `);LayoutInCSS2=a(`
mw-root {
  width: 800px;
  height: 200px;
  position: absolute;
  left: calc(50% - 400px);
  top: calc(50% - 100px);

  & > mw-window {
    padding: 10px;
    container-type: size;
    container-name: main-window;
  }
}

mw-grid {
  grid-template-columns: repeat(3, 1fr);
  gap: 10px;
}

@container main-window (width <= 500px) {
  mw-grid {
    grid-template-columns: repeat(2, 1fr);
  }
}

@container main-window (width <= 350px) {
  mw-grid {
    grid-template-columns: repeat(1, 1fr);
  }
}
  `);OpenMWLuaCodeForUI1=a(`
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
  `);OpenMWLuaCodeForUI2=a(`
local UI = require("openmw.ui")
local Util = require('openmw.util')
local MWUI = require('openmw.interfaces').MWUI
local async = require('openmw.async')

local e;
e = UI.create({
  layer = "Windows",
  props = {
    size = Util.vector2(800, 200),
    relativePosition = Util.vector2(0.5, 0.5),
    anchor = Util.vector2(0.5, 0.5),
  },
  userData = {
    lastMouseDownPosition = nil,
    edgeWhenMouseDown = nil,
  },
  events = {
    mousePress = async:callback(function(mouseEvent, layout)
      e.layout.userData.lastMouseDownPosition = mouseEvent.position

      -- Convert any relativeSize to absolute size
      if (e.layout.props.relativeSize) then
        local widthAbsolute = e.layout.props.relativeSize.x * UI.screenSize().x
        local heightAbsolute = e.layout.props.relativeSize.y * UI.screenSize().y
        e.layout.props.size = Util.vector2(widthAbsolute, heightAbsolute)
        e.layout.props.relativeSize = nil
      end

      -- Convert any relativePosition to absolute position
      if (e.layout.props.relativePosition) then
        local xAbsolute = e.layout.props.relativePosition.x * UI.screenSize().x
        local yAbsolute = e.layout.props.relativePosition.y * UI.screenSize().y
        -- We must now incorporate the anchor property
        if (e.layout.props.anchor) then
          xAbsolute = xAbsolute - e.layout.props.anchor.x * e.layout.props.size.x
          yAbsolute = yAbsolute - e.layout.props.anchor.y * e.layout.props.size.y
          e.layout.props.anchor = nil
        end
        e.layout.props.position = Util.vector2(xAbsolute, yAbsolute)
        e.layout.props.relativePosition = nil
      end

      local elemX, elemY, elemW, elemH = e.layout.props.position.x, e.layout.props.position.y, e.layout.props.size.x, e.layout.props.size.y
      local mx = mouseEvent.position.x
      local my = mouseEvent.position.y
      local edgeMargin = 15 -- How many pixels from the edge counts as clicking the edge

      local onLeft   = mx >= elemX and mx <= elemX + edgeMargin
      local onRight  = mx >= elemX + elemW - edgeMargin and mx <= elemX + elemW
      local onTop    = my >= elemY and my <= elemY + edgeMargin
      local onBottom = my >= elemY + elemH - edgeMargin and my <= elemY + elemH

      local edge = nil
      if (onTop and onLeft) then
        e.layout.userData.edgeWhenMouseDown = "top-left"
      elseif (onTop and onRight) then
        e.layout.userData.edgeWhenMouseDown = "top-right"
      elseif (onBottom and onLeft) then
        e.layout.userData.edgeWhenMouseDown = "bottom-left"
      elseif (onBottom and onRight) then
        e.layout.userData.edgeWhenMouseDown = "bottom-right"
      elseif (onLeft) then
        e.layout.userData.edgeWhenMouseDown = "left"
      elseif (onRight) then
        e.layout.userData.edgeWhenMouseDown = "right"
      elseif (onTop) then
        e.layout.userData.edgeWhenMouseDown = "top"
      elseif (onBottom) then
        e.layout.userData.edgeWhenMouseDown = "bottom"
      else
        e.layout.userData.edgeWhenMouseDown = nil
      end
    end),
    mouseMove = async:callback(function(mouseEvent, layout)
      if (mouseEvent.button == 1) then
        -- Left mouse is down
        if (e.layout.userData.lastMouseDownPosition) then
          local delta = mouseEvent.position - e.layout.userData.lastMouseDownPosition
          e.layout.userData.lastMouseDownPosition = mouseEvent.position

          -- Handle resizing
          if (e.layout.userData.edgeWhenMouseDown ~= nil) then
            if (e.layout.userData.edgeWhenMouseDown == "left") then
              e.layout.props.size = Util.vector2(e.layout.props.size.x - delta.x, e.layout.props.size.y)
              e.layout.props.position = e.layout.props.position + Util.vector2(delta.x, 0)
            elseif (e.layout.userData.edgeWhenMouseDown == "right") then
              e.layout.props.size = Util.vector2(e.layout.props.size.x + delta.x, e.layout.props.size.y)
            elseif (e.layout.userData.edgeWhenMouseDown == "top") then
              e.layout.props.size = Util.vector2(e.layout.props.size.x, e.layout.props.size.y - delta.y)
              e.layout.props.position = e.layout.props.position + Util.vector2(0, delta.y)
            elseif (e.layout.userData.edgeWhenMouseDown == "bottom") then
              e.layout.props.size = Util.vector2(e.layout.props.size.x, e.layout.props.size.y + delta.y)
            elseif (e.layout.userData.edgeWhenMouseDown == "top-left") then
              e.layout.props.size = Util.vector2(e.layout.props.size.x - delta.x, e.layout.props.size.y - delta.y)
              e.layout.props.position = e.layout.props.position + delta
            elseif (e.layout.userData.edgeWhenMouseDown == "top-right") then
              e.layout.props.size = Util.vector2(e.layout.props.size.x + delta.x, e.layout.props.size.y - delta.y)
              e.layout.props.position = e.layout.props.position + Util.vector2(0, delta.y)
            elseif (e.layout.userData.edgeWhenMouseDown == "bottom-left") then
              e.layout.props.size = Util.vector2(e.layout.props.size.x - delta.x, e.layout.props.size.y + delta.y)
              e.layout.props.position = e.layout.props.position + Util.vector2(delta.x, 0)
            elseif (e.layout.userData.edgeWhenMouseDown == "bottom-right") then
              e.layout.props.size = Util.vector2(e.layout.props.size.x + delta.x, e.layout.props.size.y + delta.y)
            end
          else
            -- No resize, so let's move/drag the entire element
            local currentPos = e.layout.props.position or Util.vector2(0, 0)
            e.layout.props.position = currentPos + delta
          end

          e:update()
        end
      end
    end)
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
  `);static \u0275fac=function(u){return new(u||i)};static \u0275cmp=m({type:i,selectors:[["app-why-use-anglesui"]],decls:53,vars:28,consts:[["Alt","Simple 3 column box layout","Src","/images/why-use/goal.png"],[3,"CodeTabs"],["Alt","Resizing the UI","Src","/images/why-use/resizing.gif"],["Alt","Dragging the UI","Src","/images/why-use/dragging.gif"],["Alt","Responsive grid UI","Src","/images/why-use/responsive-ui.gif"]],template:function(u,r){u&1&&(o(0,"app-content-width-container")(1,"app-card")(2,"app-card-header")(3,"h1"),e(4,"Why Use AnglesUI and Not the Plain Lua API?"),t()(),o(5,"app-card-body")(6,"p"),e(7," Simply put, you should spend time making and fleshing out your mod. You shouldn't need to spend excessive time writing boilerplate code or a UI that doesn't respond to natural user-experience actions like scrolling, resizing, or moving. Further, it isn't even feasible to make responsive grid layouts with the plain Lua API - you would need to write an excessive amount of code to handle all the edge cases and calculations for resizing and responsiveness. AnglesUI was created to solve these problems and allow modders to focus on making their mods and not writing boilerplate UI code. "),t(),o(8,"p"),e(9," Let's demonstrate this with an example. We want to make the following simple layout: "),t(),l(10,"app-content-image",0),o(11,"p"),e(12," This should take no more than 60 seconds and a few lines of design code. However, in the plain OpenMW Lua UI API, this is what it takes (and remember, this "),o(13,"strong"),e(14,"isn't even responsive yet"),t(),e(15," - it's just a static layout): "),t(),l(16,"app-code-highlighter",1),o(17,"p"),e(18," Note that the gapping between elements isn't uniform - this is because there isn't a real sense of padding or gap properties in the Lua API - if we wanted this to be pixel-accurate we would need a more complex solution. "),t(),o(19,"p"),e(20," Now, let's see the same layout in AnglesUI (which is a pixel-perfect rendering system): "),t(),l(21,"app-code-highlighter",1),o(22,"p"),e(23," This is not meant to be a jab or insult at the OpenMW Lua API - it provides all the necessary basic UI elements to create elements we want. However, AnglesUI was created to respect mod development time and allow for stateful, reactive rendering with responsive rendering support - things we've come to expect in UI development. "),t(),o(24,"h2"),e(25,"Adding Resizing and Dragging Functionality"),t(),o(26,"p"),e(27," We'll start with the Lua-only version of the UI. We need to do a handful of calculations to determine a reasonable and fluid resize functionality on our UI. Additionally, we need edge-detection to determine if they're resizing from an edge or a corner - and which edge or corner. "),t(),l(28,"app-code-highlighter",1)(29,"app-content-image",2)(30,"app-content-image",3),o(31,"p"),e(32," However, in AnglesUI - this is all done for you. No need to write any Lua code for any of the logic above. You simply need to add "),o(33,"code"),e(34,"Resizable"),t(),e(35," to your "),o(36,"code"),e(37,"mw-root"),t(),e(38,". You can add "),o(39,"code"),e(40,"Dragger"),t(),e(41," to any element to allow the root to be draggable. In our example below, we put it on the containing window. "),t(),l(42,"app-code-highlighter",1),o(43,"h2"),e(44,"Making the UI Responsive to Resize and Container Size"),t(),o(45,"p"),e(46," This is where the real power of AnglesUI shines. With the plain Lua API, you would need to write a lot of code to handle resizing and responsiveness. You would need to listen for resize events, calculate the new sizes and positions of each element, and then apply those changes manually. This can quickly become complex and error-prone, especially as your UI grows in complexity. "),t(),o(47,"p"),e(48," We won't attempt to write this for the Lua API - it would be too much code. We would need to adjust the entire layout of the original UI - each time we want to have a breakpoint that modifies the layout. Instead, we'll just demonstrate this in AnglesUI. "),t(),o(49,"p"),e(50," Assume you want the three column layout to gradually stack to a single column as the user resizes it. All you need to do is modify the CSS slightly to signify a UI container and use a container query to change the grid columns. "),t(),l(51,"app-code-highlighter",1)(52,"app-content-image",4),t()()()),u&2&&(s(16),p("CodeTabs",n(7,c,n(5,z,r.OpenMWLuaCodeForUI1()))),s(5),p("CodeTabs",h(13,S,n(9,f,r.LayoutInHTML1()),n(11,b,r.LayoutInCSS1()))),s(7),p("CodeTabs",n(18,c,n(16,z,r.OpenMWLuaCodeForUI2()))),s(14),p("CodeTabs",n(22,c,n(20,f,r.LayoutInHTML2()))),s(9),p("CodeTabs",n(26,c,n(24,b,r.LayoutInCSS2()))))},dependencies:[v,y,g,w,I,U],encapsulation:2})};export{x as WhyUseAnglesui};
