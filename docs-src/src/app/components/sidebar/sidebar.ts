import { Component } from '@angular/core';
import { SidebarButton } from "./sidebar-button/sidebar-button";
import { RouterLink } from "@angular/router";
import { SidebarButtonGroup } from "./sidebar-button-group/sidebar-button-group";

@Component({
  selector: 'app-sidebar',
  imports: [SidebarButton, RouterLink, SidebarButtonGroup],
  templateUrl: './sidebar.html',
  styleUrl: './sidebar.scss',
})
export class Sidebar {

}
