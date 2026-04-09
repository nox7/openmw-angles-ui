import { ComponentFixture, TestBed } from '@angular/core/testing';

import { ResponsiveUiDesign } from './responsive-ui-design';

describe('ResponsiveUiDesign', () => {
  let component: ResponsiveUiDesign;
  let fixture: ComponentFixture<ResponsiveUiDesign>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [ResponsiveUiDesign]
    })
    .compileComponents();

    fixture = TestBed.createComponent(ResponsiveUiDesign);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
