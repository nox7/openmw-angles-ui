import { Component, inject } from '@angular/core';
import { Router, RouterOutlet, NavigationEnd, ActivatedRoute } from '@angular/router';
import { toSignal } from '@angular/core/rxjs-interop';
import { filter, map } from 'rxjs';
import { Topbar } from "./components/topbar/topbar";
import { Sidebar } from "./components/sidebar/sidebar";
import { Footer } from "./components/footer/footer";
import { SidebarService } from './components/sidebar/sidebar-service';
import { ThemeSwitcher } from './components/theme-switcher/theme-switcher';

@Component({
  selector: 'app-root',
  imports: [RouterOutlet, Topbar, Sidebar, Footer],
  templateUrl: './app.html',
  styleUrl: './app.scss'
})
export class App {
  public readonly SidebarService = inject(SidebarService);
  // Eagerly instantiate so the body class effect runs before first render
  private readonly _themeSwitcher = inject(ThemeSwitcher);

  private readonly router = inject(Router);
  private readonly activatedRoute = inject(ActivatedRoute);

  private getRouteNoPadding(): boolean {
    let route = this.activatedRoute;
    while (route.firstChild) route = route.firstChild;
    return route.snapshot.data?.['noPadding'] === true;
  }

  public readonly HasNoPadding = toSignal(
    this.router.events.pipe(
      filter(e => e instanceof NavigationEnd),
      map(() => this.getRouteNoPadding())
    ),
    { initialValue: this.router.url === '/' || this.router.url === '' }
  );

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
