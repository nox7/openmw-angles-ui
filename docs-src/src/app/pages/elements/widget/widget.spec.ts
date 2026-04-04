import { ComponentFixture, TestBed } from '@angular/core/testing';

import { Widget } from './widget';

describe('Widget', () => {
  let component: Widget;
  let fixture: ComponentFixture<Widget>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [Widget]
    })
    .compileComponents();

    fixture = TestBed.createComponent(Widget);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
