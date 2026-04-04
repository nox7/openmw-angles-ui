import { Component, inject, input, OnInit, signal, ViewEncapsulation } from '@angular/core';
import { DomSanitizer, SafeHtml } from '@angular/platform-browser';
import { createHighlighter } from 'shiki';

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
  public Code = input.required<string>();
  public Language = input.required<string>();
  public Content = signal<SafeHtml>("");

  public async ngOnInit(): Promise<void> {
    this.Content.set(this.DomSanitizer.bypassSecurityTrustHtml(
      (await CodeHighlighter.Highlighter).codeToHtml(
        this.Code().trim(), { 
          lang: this.Language(),
          theme: "vitesse-dark",
        }
      )
    ));
  }
}
