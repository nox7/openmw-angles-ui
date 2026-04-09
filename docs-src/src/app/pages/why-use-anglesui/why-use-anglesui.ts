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
  <mw-window>
    <mw-grid>
      <mw-window></mw-window>
      <mw-window></mw-window>
      <mw-window></mw-window>
    </mw-grid>
  </mw-window>
</mw-root>
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
}
