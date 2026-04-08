import { Component, signal } from '@angular/core';
import { ContentWidthContainer } from "../../../components/content-width-container/content-width-container";
import { Card } from "../../../components/card/card";
import { CardHeader } from "../../../components/card/card-header/card-header";
import { CardBody } from "../../../components/card/card-body/card-body";
import { CodeHighlighter } from "../../../components/code-highlighter/code-highlighter";
import { ContentImage } from "../../../components/content-image/content-image";
import { RouterLink } from "@angular/router";
import { Alert } from "../../../components/alert/alert";

@Component({
  selector: 'app-making-a-button',
  imports: [ContentWidthContainer, Card, CardHeader, CardBody, CodeHighlighter, ContentImage, RouterLink, Alert],
  templateUrl: './making-a-button.html',
  styleUrl: './making-a-button.scss',
})
export class MakingAButton {
  public ParentHTMLCode1 = signal<string>(`
<mw-root Layer="windows">
  <mw-window></mw-window>
</mw-root>
  `);

  public ParentCSSCode1 = signal<string>(`
mw-root {
  width: 400px;
  height: 250px;
  position: absolute;
  left: calc(50% - calc(400px / 2));
  top: calc(50% - calc(250px / 2));
}
  `);

  public LuaCode1 = signal<string>(`
local Renderer = require("scripts.Nox.AnglesUI.Renderer.Renderer")

local renderer = Renderer.FromFile("scripts/Nox/UI/MainWindow.html", {})

renderer:Render({})
  `);

  public LuaCode2 = signal<string>(`
local Renderer = require("scripts.Nox.AnglesUI.Renderer.Renderer")

local renderer = Renderer.FromFile("scripts/Nox/UI/MainWindow.html", {
  ["nox-button"] = "scripts/Nox/UI/Button.html"
})

renderer:Render({})
  `);

  public ChildHTMLCode1 = signal<string>(`
<mw-host>
  <mw-window class="button-wrapper">
    <mw-content></mw-content>
  </mw-window>
</mw-host>
  `);

  public ChildCSSCode1 = signal<string>(`
mw-host {
  width: 125px;
  height: 36px;
  
  & > mw-window {
    padding: 4px;
    background: none;
  }
}
  `);

  public ParentHTMLCode2 = signal<string>(`
<mw-root Layer="windows">
  <mw-window><nox-button></nox-button></mw-window>
</mw-root>
  `);

  public ParentHTMLCode3 = signal<string>(`
<mw-root Layer="windows">
  <mw-window>
    <nox-button>
      <mw-text>Click Me</mw-text>
    </nox-button>
  </mw-window>
</mw-root>
  `);

  public ParentHTMLCode4 = signal<string>(`
<mw-root Layer="windows">
  <mw-window>
    <nox-button>Click me</nox-button>
  </mw-window>
</mw-root>
  `);

  public ChildHTMLCode2 = signal<string>(`
<mw-host>
  <mw-window class="button-wrapper">
    <mw-text><mw-content></mw-content></mw-text>
  </mw-window>
</mw-host>
  `);

  public ChildHTMLCode3 = signal<string>(`
<mw-host>
  <mw-window class="button-wrapper">
    <mw-text AutoSize="false"><mw-content></mw-content></mw-text>
  </mw-window>
</mw-host>
  `);

  public ChildCSSCode2 = signal<string>(`
mw-host {
  width: 125px;
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
  `);

  public LuaCode3 = signal<string>(`
local Renderer = require("scripts.Nox.AnglesUI.Renderer.Renderer")

local renderer = Renderer.FromFile("scripts/Nox/UI/MainWindow.html", {
  ["nox-button"] = "scripts/Nox/UI/Button.html"
})

renderer:Render({
  OnButtonClicked = function(somethingToPrint, mouseEvent, layout)
    print(somethingToPrint)
  end
})
  `);

  public ParentHTMLCode5 = signal<string>(`
<mw-root Layer="windows">
  <mw-window>
    <nox-button (mousePress)="OnButtonClicked('Button clicked!')">Click me</nox-button>
  </mw-window>
</mw-root>
  `);
}