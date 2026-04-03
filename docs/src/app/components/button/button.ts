import { NgTemplateOutlet } from '@angular/common';
import { Component, input } from '@angular/core';
import { RouterLink } from '@angular/router';

@Component({
  selector: 'app-button',
  imports: [RouterLink, RouterLink, NgTemplateOutlet],
  templateUrl: './button.html',
  styleUrl: './button.scss',
})
export class Button {
  public Href = input.required<string>();
  public IsRouterLink = input<boolean>(true);
}
