import { Component, signal } from '@angular/core';
import { ContentWidthContainer } from "../../components/content-width-container/content-width-container";
import { Card } from "../../components/card/card";
import { CardHeader } from "../../components/card/card-header/card-header";
import { CardBody } from "../../components/card/card-body/card-body";
import { CodeHighlighter } from "../../components/code-highlighter/code-highlighter";
import { RouterLink } from "@angular/router";
import { Alert } from "../../components/alert/alert";

@Component({
  selector: 'app-data-binding',
  imports: [ContentWidthContainer, Card, CardHeader, CardBody, CodeHighlighter, RouterLink, Alert],
  templateUrl: './data-binding.html',
  styleUrl: './data-binding.scss',
})
export class DataBinding {
  public Code1 = signal<string>(`
local Signal = require("scripts.Nox.AnglesUI.Signals.Signal")

local titleSignal = Signal.New("Title of This UI")
local npcNameSignal = Signal.New("Current_NPC_Talking_To")
  `.trim());

  public Code2 = signal<string>(`
local Renderer = require("scripts.Nox.AnglesUI.Renderer.Renderer")

local npcWindowRenderer = Renderer.FromFile("scripts/Nox/UI/NPCWindow.html", {})
npcWindowRenderer:Render({
  Title = titleSignal,
  NPCName = npcNameSignal
})
  `.trim());

  public Code3 = signal<string>(`
npcNameSignal:Set(GetNameOfCurrentNPC())
  `.trim());

  public InterpolationCode = signal<string>(`
<mw-text>{{ NPCName() }}</mw-text>
  `.trim());

  public StyleBindingCode1 = signal<string>(`
<mw-text [style.color]="TextColorInRGB()"></mw-text>
  `.trim());

  public StyleBindingCode2 = signal<string>(`
<mw-text [style.color]="rgb(0,1,0)"></mw-text>
  `.trim());

  public StyleBindingCode3 = signal<string>(`
<mw-text [style.color]="'rgb(0,1,0)'"></mw-text>
  `.trim());

  public ClassBindingCode = signal<string>(`
<mw-text [class.active]="IsActive()"></mw-text>
  `.trim());
}
