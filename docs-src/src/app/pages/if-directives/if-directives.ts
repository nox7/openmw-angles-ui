import { Component, signal } from '@angular/core';
import { ContentWidthContainer } from "../../components/content-width-container/content-width-container";
import { Card } from "../../components/card/card";
import { CardHeader } from "../../components/card/card-header/card-header";
import { CardBody } from "../../components/card/card-body/card-body";
import { CodeHighlighter } from "../../components/code-highlighter/code-highlighter";

@Component({
  selector: 'app-if-directives',
  imports: [ContentWidthContainer, Card, CardHeader, CardBody, CodeHighlighter],
  templateUrl: './if-directives.html',
  styleUrl: './if-directives.scss',
})
export class IfDirectives {
  public Code1 = signal<string>(`
<mw-root>
  @if (ShowWindow()) {
    <mw-window></mw-window>
  }
</mw-root>
    `);
}
