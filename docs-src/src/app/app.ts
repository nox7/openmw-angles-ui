import { Component, inject, signal } from '@angular/core';
import { RouterOutlet } from '@angular/router';
import { Topbar } from "./components/topbar/topbar";
import { Sidebar } from "./components/sidebar/sidebar";
import { Footer } from "./components/footer/footer";
import { SidebarService } from './components/sidebar/sidebar-service';

@Component({
  selector: 'app-root',
  imports: [RouterOutlet, Topbar, Sidebar, Footer],
  templateUrl: './app.html',
  styleUrl: './app.scss'
})
export class App {
  public readonly SidebarService = inject(SidebarService);

  public OnAnimationEnd(e: AnimationEvent): void {
    if (e.animationName.endsWith("open-sidebar")) {
      this.SidebarService.IsOpening.set(false);
      this.SidebarService.IsOpen.set(true);
    } else if (e.animationName.endsWith("close-sidebar")) {
      this.SidebarService.IsClosing.set(false);
      this.SidebarService.IsOpen.set(false);
      document.body.style.overflow = "";
    }
  }
}
