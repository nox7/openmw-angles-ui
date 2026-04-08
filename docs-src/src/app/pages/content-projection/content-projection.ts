import { Component, signal } from '@angular/core';
import { ContentWidthContainer } from "../../components/content-width-container/content-width-container";
import { Card } from "../../components/card/card";
import { CardHeader } from "../../components/card/card-header/card-header";
import { CardBody } from "../../components/card/card-body/card-body";
import { RouterLink } from "@angular/router";
import { CodeHighlighter } from "../../components/code-highlighter/code-highlighter";
import { Alert } from "../../components/alert/alert";

@Component({
  selector: 'app-content-projection',
  imports: [ContentWidthContainer, Card, CardHeader, CardBody, RouterLink, CodeHighlighter, Alert],
  templateUrl: './content-projection.html',
  styleUrl: './content-projection.scss',
})
export class ContentProjection {
  public ParentComponent = signal<string>(`
<mw-root Layer="Windows">
  <my-custom-button>Button text 1</my-custom-button>
  <my-custom-button>Button text 2</my-custom-button>
  <my-custom-button>Button text 3</my-custom-button>
</mw-root>
  `)

  public ButtonComponent = signal<string>(`
<mw-widget class="button">
  <mw-text><mw-content></mw-content></mw-text>
</mw-widget>
  `)

  public ParentComponent2 = signal<string>(`
<mw-root Layer="Windows">
  <my-custom-button>
    <mw-image Resource="icons/a/a_shield_breaker.dds"></mw-image>  
    Button text 1
  </my-custom-button>
</mw-root>
  `)

  public ButtonComponent2 = signal<string>(`
<mw-widget class="button">
  <mw-flex>
    <mw-content select="mw-image"></mw-content>
    <mw-text><mw-content></mw-content></mw-text>
  </mw-flex>
</mw-widget>
  `)
}
