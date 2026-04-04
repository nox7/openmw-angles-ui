import { Component, signal } from '@angular/core';
import { ContentWidthContainer } from "../../components/content-width-container/content-width-container";
import { Card } from "../../components/card/card";
import { CardHeader } from "../../components/card/card-header/card-header";
import { CardBody } from "../../components/card/card-body/card-body";
import { ContentImage } from "../../components/content-image/content-image";
import { Alert } from "../../components/alert/alert";
import { CodeHighlighter } from "../../components/code-highlighter/code-highlighter";

@Component({
  selector: 'app-css',
  imports: [ContentWidthContainer, Card, CardHeader, CardBody, ContentImage, Alert, CodeHighlighter],
  templateUrl: './css.html',
  styleUrl: './css.scss',
})
export class Css {
  public GeneralAndCompoundCode = signal<string>(`
.red-text {
  color: rgb(255, 0, 0);
}

.red-text.hidden {
  visibility: hidden;
}
  `);

  public NestedRuleCode = signal<string>(`
mw-window {
  mw-text {
    color: rgb(255, 0, 0);
  }
}
  `);

  public NotSelectorCode = signal<string>(`
.grid-1:not(.active) {
  visibility: hidden;
}
  `);

  public MediaQueriesCode = signal<string>(`
@media (max-width: 600px) {
  /* Rules applied when the screen width is less than or equal to 600px */
  .grid-1 {
    grid-template-columns: 1fr;
  }
}
  `);

  public ContainerQueriesCode = signal<string>(`
.grid-container {
  container-type: size;
  container-name: grid-container;

  .grid-1 {
    grid-template-columns: 1fr 1fr;
  }
}
  
@container grid-container (width <= 600px) {
  /* Rules applied when the container width is less than or equal to 600px */
  /* This collapses the grid into a single column when it's container is too small. */
  .grid-1 {
    grid-template-columns: 1fr;
  }
}
  `);
}
