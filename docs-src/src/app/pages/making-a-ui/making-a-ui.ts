import { Component, signal } from '@angular/core';
import { ContentWidthContainer } from "../../components/content-width-container/content-width-container";
import { Card } from "../../components/card/card";
import { CardHeader } from "../../components/card/card-header/card-header";
import { CardBody } from "../../components/card/card-body/card-body";
import { ContentImage } from "../../components/content-image/content-image";
import { CodeHighlighter } from "../../components/code-highlighter/code-highlighter";

@Component({
  selector: 'app-making-a-ui',
  imports: [ContentWidthContainer, Card, CardHeader, CardBody, ContentImage, CodeHighlighter],
  templateUrl: './making-a-ui.html',
  styleUrl: './making-a-ui.scss',
})
export class MakingAUi {
  public Code1 = signal<string>(`
<mw-root
  Layer="Windows"
  [style.width]="'800px'"
  [style.height]="'400px'"
  >
  <mw-window></mw-window>
</mw-root>
  `.trim());

  public Code2 = signal<string>(`
mw-root {
  width: 800px;
  height: 400px;
}
  `.trim());

  public Code3 = signal<string>(`
<mw-root Layer="Windows">
  <mw-window></mw-window>
</mw-root>
  `.trim());

  public LuaRenderCode1 = signal<string>(`
local Renderer = require("scripts.Nox.AnglesUI.Renderer.Renderer")

local renderer = Renderer.FromFile("scripts/Nox/UI/LogisticsUI.html", {})
renderer:Render({})
  `.trim());

    public LuaRenderCode2 = signal<string>(`
local Renderer = require("scripts.Nox.AnglesUI.Renderer.Renderer")

local textSignal = Signal.New("Hello world!")
local onTextClicked = function(mouseEvent, layout)
  textSignal:Set("New text: " .. math.random())
end

local renderer = Renderer.FromFile("scripts/Nox/UI/LogisticsUI.html", {})
renderer:Render({
  Text = textSignal,
  OnTextClicked = onTextClicked,
})
  `.trim());

  public Code4 = signal<string>(`
<mw-root Layer="Windows">
  <mw-window>
    <mw-text (mousePress)="OnTextClicked($event1, $event2)">{{ Text() }}</mw-text>
  </mw-window>
</mw-root>
  `.trim());
}
