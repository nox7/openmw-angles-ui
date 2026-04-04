import { Component, ElementRef, inject, input, signal } from '@angular/core';

/**
 * Use when we want to group buttons into a collapsable section.
 */
@Component({
  selector: 'app-sidebar-button-group',
  imports: [],
  templateUrl: './sidebar-button-group.html',
  styleUrl: './sidebar-button-group.scss',
})
export class SidebarButtonGroup {
  private readonly Element = inject(ElementRef);
  public Label = input.required<string>();
  public IsOpen = signal<boolean>(false);
  public IsOpening = signal<boolean>(false);
  public IsClosing = signal<boolean>(false);
  public ExpandedHeight = signal<string>("0px");

  /**
   * Opens or closes the collapse menu.
   */
  public async Toggle(): Promise<void> {
    if (this.IsOpening() || this.IsClosing()){
      return;
    }

    if (!this.IsOpen()) {
      await this.CalculateContentsExpandedHeight();
      this.IsOpening.set(true);
    } else {
      this.IsClosing.set(true);
    }
  }

  /**
   * Calculates the height of the expandable contents and sets ExpandedHeight.
   * Sets the contents as absolute-positioned and moves it off screen to measure the height.
   */
  public async CalculateContentsExpandedHeight(): Promise<void> {
    const contents = (this.Element.nativeElement as HTMLElement).querySelector('.contents') as HTMLElement;
    contents.style.position = "absolute";
    contents.style.left = "-5000px";
    contents.style.height = "auto";
    await new Promise(resolve => setTimeout(resolve, 5));
    const heightOfContents = contents.getBoundingClientRect().height;
    this.ExpandedHeight.set(`${heightOfContents}px`);
    contents.style.position = "";
    contents.style.left = "";
    contents.style.height = "";
  }

  public OnAnimationEnded(e: AnimationEvent): void {
    if (e.animationName.endsWith("open")) {
      this.IsOpening.set(false);
      this.IsOpen.set(true);
    } else if (e.animationName.endsWith("close")) {
      this.ExpandedHeight.set("0px");
      this.IsClosing.set(false);
      this.IsOpen.set(false);
    }
  }
}
