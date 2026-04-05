import { Component, signal } from '@angular/core';
import { ContentWidthContainer } from "../../components/content-width-container/content-width-container";
import { Card } from "../../components/card/card";
import { CardHeader } from "../../components/card/card-header/card-header";
import { CardBody } from "../../components/card/card-body/card-body";
import { CodeHighlighter } from "../../components/code-highlighter/code-highlighter";

@Component({
  selector: 'app-event-binding',
  imports: [ContentWidthContainer, Card, CardHeader, CardBody, CodeHighlighter],
  templateUrl: './event-binding.html',
  styleUrl: './event-binding.scss',
})
export class EventBinding {
  public LuaCode1 = signal<string>(`
local Renderer = require("scripts.Nox.AnglesUI.Renderer.Renderer")
local Signal = require("scripts.Nox.AnglesUI.Signals.Signal")

local onWindowClicked = function(e, l)
  print("Window clicked")
end

local renderer = Renderer.FromFile("scripts/Nox/UI/LogisticsUI.html", {})
renderer:Render({
  OnWindowClicked = onWindowClicked
})
    `)

  public HTMLCode1 = signal<string>(`
<mw-root Layer="Windows" [style.width]="'800px'" [style.height]="'400px'">
  <mw-window (mouseClick)="OnWindowClicked($event1, $event2)"></mw-window>
</mw-root>
    `)
}
