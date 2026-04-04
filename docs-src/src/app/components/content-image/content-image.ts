import { Component, input } from '@angular/core';

@Component({
  selector: 'app-content-image',
  imports: [],
  templateUrl: './content-image.html',
  styleUrl: './content-image.scss',
})
export class ContentImage {
  public Alt = input.required<string>();
  public Src = input.required<string>();
}
