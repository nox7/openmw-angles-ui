import { Component, inject, input, OnInit, signal, ViewEncapsulation } from '@angular/core';
import { DomSanitizer, SafeHtml } from '@angular/platform-browser';
import { createHighlighter } from 'shiki';

export interface CodeHighlightDefinition {
  TabLabel: string;
  Code: string;
  Language: string;
}

@Component({
  selector: 'app-code-highlighter',
  imports: [],
  templateUrl: './code-highlighter.html',
  styleUrl: './code-highlighter.scss',
  encapsulation: ViewEncapsulation.None,
})
export class CodeHighlighter implements OnInit {
  public static Highlighter = createHighlighter({ 
    themes: ["vitesse-dark"], 
    langs: ["angular-html", "css", "lua"] 
  });

  private readonly DomSanitizer = inject(DomSanitizer);
  public Code = input<string>();
  public Language = input<string>();
  public CodeTabs = input<CodeHighlightDefinition[] | undefined>(undefined);
  public Content = signal<SafeHtml>("");
  public TabContents = signal<SafeHtml[]>([]);
  public ActiveTab = signal<number>(0);

  public async ngOnInit(): Promise<void> {
    const highlighter = await CodeHighlighter.Highlighter;
    const tabs = this.CodeTabs();

    if (tabs && tabs.length > 0) {
      this.TabContents.set(tabs.map(tab =>
        this.DomSanitizer.bypassSecurityTrustHtml(
          highlighter.codeToHtml(tab.Code.trim(), { lang: tab.Language, theme: "vitesse-dark" })
        )
      ));
    } else {
      const code = this.Code();
      const language = this.Language();
      if (code === undefined || language === undefined) {
        throw "Must provide code and language inputs, or code tabs input.";
      }
      this.Content.set(this.DomSanitizer.bypassSecurityTrustHtml(
        highlighter.codeToHtml(
          code.trim(), { 
            lang: language,
            theme: "vitesse-dark",
          }
        )
      ));
    }
  }

  public SelectTab(index: number): void {
    this.ActiveTab.set(index);
  }
}
