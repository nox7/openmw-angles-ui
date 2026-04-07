import { Component, inject, signal } from '@angular/core';
import { EventType, Router } from '@angular/router';
import { Subscription } from 'rxjs';

@Component({
  selector: 'app-page-loading-bar',
  imports: [],
  templateUrl: './page-loading-bar.html',
  styleUrl: './page-loading-bar.scss',
})
export class PageLoadingBar {
  private readonly Router = inject(Router);

  public NavigationState = signal<undefined | "start" | "end">(undefined);
  public RouterEventSubscriptions: Subscription;

  public constructor(){
    this.RouterEventSubscriptions = this.Router.events.subscribe({
      next: e => {
        if (e.type === EventType.NavigationStart){
          this.NavigationState.set("start");
        } else if (e.type === EventType.NavigationEnd || e.type === EventType.NavigationSkipped || e.type === EventType.NavigationCancel){
          this.NavigationState.set("end");
        }
      }
    });
  }

  public ngOnDestroy(): void {
    this.RouterEventSubscriptions.unsubscribe();
  }

  public PageLoadingBarAnimationEnd(e: AnimationEvent): void{
    if (e.animationName.endsWith("nav-end-bar")){
      this.NavigationState.set(undefined);
    }
  }
}
