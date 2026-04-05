import { Component, inject } from '@angular/core';
import { SidebarService } from '../sidebar/sidebar-service';

@Component({
  selector: 'app-topbar',
  imports: [],
  templateUrl: './topbar.html',
  styleUrl: './topbar.scss',
})
export class Topbar {
  private readonly SidebarService = inject(SidebarService);

  public ToggleSidebar(): void {
    if (!this.SidebarService.IsClosing() && !this.SidebarService.IsOpening()) {
      this.SidebarService.IsOpening.set(true);
    }
  }
}
