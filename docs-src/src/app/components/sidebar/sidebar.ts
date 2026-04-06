import { Component, ElementRef, inject, OnDestroy } from '@angular/core';
import { SidebarButton } from "./sidebar-button/sidebar-button";
import { RouterLink } from "@angular/router";
import { SidebarButtonGroup } from "./sidebar-button-group/sidebar-button-group";
import { SidebarService } from './sidebar-service';
import { ThemeSwitcher } from '../theme-switcher/theme-switcher';

@Component({
  selector: 'app-sidebar',
  imports: [SidebarButton, RouterLink, SidebarButtonGroup],
  templateUrl: './sidebar.html',
  styleUrl: './sidebar.scss',
  host: {
    "[class.open]": "SidebarService.IsOpen()",
    "[class.opening]": "SidebarService.IsOpening()",
    "[class.closing]": "SidebarService.IsClosing()"
  }
})
export class Sidebar implements OnDestroy {
  private readonly Element = inject(ElementRef).nativeElement as HTMLElement;
  public readonly SidebarService = inject(SidebarService);
  public readonly ThemeSwitcher = inject(ThemeSwitcher);
  public WindowClickCallback: (e: MouseEvent) => void;

  public constructor() {
    this.WindowClickCallback = (e: MouseEvent) => {
      if (this.SidebarService.IsOpen()){
        if (!this.SidebarService.IsClosing() && !this.SidebarService.IsOpening()) {
          if (e.target instanceof HTMLElement && !this.Element.contains(e.target)) {
            this.SidebarService.IsClosing.set(true);
          }
        }
      }
    }
    window.addEventListener('click', this.WindowClickCallback);
  }

  public ngOnDestroy(): void {
    window.removeEventListener('click', this.WindowClickCallback);
  }
}
