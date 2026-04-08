import { Component, signal } from '@angular/core';
import { ContentWidthContainer } from "../../../components/content-width-container/content-width-container";
import { Card } from "../../../components/card/card";
import { CardHeader } from "../../../components/card/card-header/card-header";
import { CardBody } from "../../../components/card/card-body/card-body";
import { Alert } from "../../../components/alert/alert";
import { CodeHighlighter } from "../../../components/code-highlighter/code-highlighter";
import { ContentImage } from "../../../components/content-image/content-image";
import { RouterLink } from "@angular/router";

@Component({
  selector: 'app-custom-components',
  imports: [ContentWidthContainer, Card, CardHeader, CardBody, Alert, CodeHighlighter, ContentImage, RouterLink],
  templateUrl: './custom-components.html',
  styleUrl: './custom-components.scss',
})
export class CustomComponents {
  public RegisterLuaCode = signal<string>(`
local Renderer = require("scripts.Nox.AnglesUI.Renderer.Renderer")

local renderer = Renderer.FromFile("scripts/Nox/UI/LogisticsRoot.html", {
  ["nox-product-grid"] = "scripts/Nox/UI/MainGrid.html",
})

renderer:Render({})
  `);

  public MainUIHTML = signal<string>(`
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
  `);

  public MainUICSS = signal<string>(`
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
  `);

  public GridHTML = signal<string>(`
<mw-grid id="grid-1">
  <mw-window></mw-window>
  <mw-window></mw-window>
  <mw-window></mw-window>
</mw-grid>
  `);

  public GridCSS = signal<string>(`
#grid-1 {
  width: 100%;
  flex-grow: 1;
  gap: 20px;
}
  `);
}
