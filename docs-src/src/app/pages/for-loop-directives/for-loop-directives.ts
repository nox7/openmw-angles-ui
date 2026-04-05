import { Component, signal } from '@angular/core';
import { ContentWidthContainer } from "../../components/content-width-container/content-width-container";
import { Card } from "../../components/card/card";
import { CardHeader } from "../../components/card/card-header/card-header";
import { CardBody } from "../../components/card/card-body/card-body";
import { CodeHighlighter } from "../../components/code-highlighter/code-highlighter";
import { ContentImage } from "../../components/content-image/content-image";

@Component({
  selector: 'app-for-loop-directives',
  imports: [ContentWidthContainer, Card, CardHeader, CardBody, CodeHighlighter, ContentImage],
  templateUrl: './for-loop-directives.html',
  styleUrl: './for-loop-directives.scss',
})
export class ForLoopDirectives {
  public LuaCode = signal<string>(`
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
    `);

  public HTMLCode = signal<string>(`
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
    `);

  public CSSCode = signal<string>(`
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
    `);

  public PitfallCode = signal<string>(`
table.remove(castleStaffArraySignal(), 1)
castleStaffArraySignal:Set(castleStaffArraySignal())
    `);

  public GoodSignalLuaCode = signal<string>(`
local current = castleStaffArraySignal()
local newStaff = {}
for i = 2, #current do
  table.insert(newStaff, current[i])
end
castleStaffArraySignal:Set(newStaff)
    `);
}
