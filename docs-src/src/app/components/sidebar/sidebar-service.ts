import { Injectable, inject, signal } from '@angular/core';
import { NavigationEnd, Router } from '@angular/router';
import { filter } from 'rxjs';

@Injectable({
  providedIn: 'root',
})
export class SidebarService {
  public IsOpen = signal<boolean>(false);
  public IsOpening = signal<boolean>(false);
  public IsClosing = signal<boolean>(false);

  public constructor() {
    const router = inject(Router);
    router.events.pipe(filter(e => e instanceof NavigationEnd)).subscribe(() => {
      if (this.IsOpen() || this.IsOpening()) {
        this.IsOpening.set(false);
        this.IsClosing.set(true);
      }
    });
  }
}
