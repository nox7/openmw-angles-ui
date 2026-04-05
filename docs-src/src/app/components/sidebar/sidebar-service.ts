import { Injectable, signal } from '@angular/core';

@Injectable({
  providedIn: 'root',
})
export class SidebarService {
  public IsOpen = signal<boolean>(false);
  public IsOpening = signal<boolean>(false);
  public IsClosing = signal<boolean>(false);
}
