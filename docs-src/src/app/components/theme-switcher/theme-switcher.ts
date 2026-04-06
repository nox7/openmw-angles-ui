import { Injectable, signal, effect } from '@angular/core';

type Theme = 'light' | 'dark';

@Injectable({
  providedIn: 'root',
})
export class ThemeSwitcher {
  private static readonly STORAGE_KEY = 'aui_theme_preference';

  public readonly IsDark = signal<boolean>(this.resolveInitialTheme() === 'dark');

  public constructor() {
    effect(() => {
      const dark = this.IsDark();
      document.body.classList.toggle('dark-theme', dark);
      localStorage.setItem(ThemeSwitcher.STORAGE_KEY, dark ? 'dark' : 'light');
    });
  }

  public Toggle(): void {
    this.IsDark.update(v => !v);
  }

  private resolveInitialTheme(): Theme {
    const stored = localStorage.getItem(ThemeSwitcher.STORAGE_KEY) as Theme | null;
    if (stored === 'light' || stored === 'dark') {
      return stored;
    }
    return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  }
}
