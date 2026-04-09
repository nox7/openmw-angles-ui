import { Component, signal } from '@angular/core';
import { ContentWidthContainer } from "../../components/content-width-container/content-width-container";
import { Card } from "../../components/card/card";
import { CardHeader } from "../../components/card/card-header/card-header";
import { CardBody } from "../../components/card/card-body/card-body";
import { CodeHighlighter } from "../../components/code-highlighter/code-highlighter";
import { ContentImage } from "../../components/content-image/content-image";

@Component({
  selector: 'app-why-use-anglesui',
  imports: [ContentWidthContainer, Card, CardHeader, CardBody, CodeHighlighter, ContentImage],
  templateUrl: './why-use-anglesui.html',
  styleUrl: './why-use-anglesui.scss',
})
export class WhyUseAnglesui {
  public LayoutInHTML1 = signal<string>(`
<mw-root Layer="Windows">
  <mw-window>
    <mw-grid>
      <mw-window></mw-window>
      <mw-window></mw-window>
      <mw-window></mw-window>
    </mw-grid>
  </mw-window>
</mw-root>
  `);

  public LayoutInCSS1 = signal<string>(`
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
  `);

  public LayoutInHTML2 = signal<string>(`
<mw-root Layer="Windows" Resizable="true">
  <mw-window Dragger="true">
    <mw-grid>
      <mw-window></mw-window>
      <mw-window></mw-window>
      <mw-window></mw-window>
    </mw-grid>
  </mw-window>
</mw-root>
  `);

  public LayoutInCSS2 = signal<string>(`
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
  `);

  public OpenMWLuaCodeForUI1 = signal<string>(`
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
  `);

  public OpenMWLuaCodeForUI2 = signal<string>(`
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
  `);
}
