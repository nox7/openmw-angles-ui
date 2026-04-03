import { NgTemplateOutlet } from '@angular/common';
import { Component, input } from '@angular/core';
import { RouterLink } from '@angular/router';

@Component({
  selector: 'app-sidebar-button',
  imports: [RouterLink, NgTemplateOutlet],
  templateUrl: './sidebar-button.html',
  styleUrl: './sidebar-button.scss',
})
export class SidebarButton {
  public Href = input.required<string>();
  public IsRouterLink = input<boolean>(true);
}
