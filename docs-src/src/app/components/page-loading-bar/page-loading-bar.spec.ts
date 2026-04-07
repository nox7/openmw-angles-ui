import { ComponentFixture, TestBed } from '@angular/core/testing';

import { PageLoadingBar } from './page-loading-bar';

describe('PageLoadingBar', () => {
  let component: PageLoadingBar;
  let fixture: ComponentFixture<PageLoadingBar>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [PageLoadingBar]
    })
    .compileComponents();

    fixture = TestBed.createComponent(PageLoadingBar);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
