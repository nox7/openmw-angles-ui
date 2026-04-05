import { Component, input } from '@angular/core';
import { SafeHtml } from '@angular/platform-browser';

@Component({
  selector: 'app-dt-cell',
  imports: [],
  templateUrl: './dt-cell.html',
  styleUrl: './dt-cell.scss',
})
export class DtCell {
  public OverrideContent = input<SafeHtml | undefined>(undefined);
}
