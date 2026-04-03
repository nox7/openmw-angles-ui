import { ComponentFixture, TestBed } from '@angular/core/testing';

import { SidebarButton } from './sidebar-button';

describe('SidebarButton', () => {
  let component: SidebarButton;
  let fixture: ComponentFixture<SidebarButton>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [SidebarButton]
    })
    .compileComponents();

    fixture = TestBed.createComponent(SidebarButton);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
