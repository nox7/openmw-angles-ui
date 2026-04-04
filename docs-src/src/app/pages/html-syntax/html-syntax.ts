import { Component, signal } from '@angular/core';
import { ContentWidthContainer } from "../../components/content-width-container/content-width-container";
import { Card } from "../../components/card/card";
import { CardHeader } from "../../components/card/card-header/card-header";
import { CardBody } from "../../components/card/card-body/card-body";
import { CodeHighlighter } from "../../components/code-highlighter/code-highlighter";
import { RouterLink } from "@angular/router";

@Component({
  selector: 'app-html-syntax',
  imports: [ContentWidthContainer, Card, CardHeader, CardBody, CodeHighlighter, RouterLink],
  templateUrl: './html-syntax.html',
  styleUrl: './html-syntax.scss',
})
export class HtmlSyntax {
  public Code1 = signal<string>(`
<mw-root Layer="Windows">
  <mw-window>
    <mw-text>Hello world!</mw-text>
  </mw-window>
</mw-root>
  `.trim());

  public Code2 = signal<string>(`
<mw-root
  Layer="Windows"
  [style.width]="InitialWidth()"
  [style.height]="InitialHeight()"
  >
  <mw-window>
    <mw-text>{{ Text() }}</mw-text>
  </mw-window>
</mw-root>
  `.trim());
}
