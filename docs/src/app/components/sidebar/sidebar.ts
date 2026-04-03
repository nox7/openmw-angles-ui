import { Component } from '@angular/core';
import { SidebarButton } from "./sidebar-button/sidebar-button";
import { RouterLink } from "@angular/router";

@Component({
  selector: 'app-sidebar',
  imports: [SidebarButton, RouterLink],
  templateUrl: './sidebar.html',
  styleUrl: './sidebar.scss',
})
export class Sidebar {

}
