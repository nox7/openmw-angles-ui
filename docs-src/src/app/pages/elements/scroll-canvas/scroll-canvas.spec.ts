import { ComponentFixture, TestBed } from '@angular/core/testing';

import { ScrollCanvas } from './scroll-canvas';

describe('ScrollCanvas', () => {
  let component: ScrollCanvas;
  let fixture: ComponentFixture<ScrollCanvas>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [ScrollCanvas]
    })
    .compileComponents();

    fixture = TestBed.createComponent(ScrollCanvas);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
