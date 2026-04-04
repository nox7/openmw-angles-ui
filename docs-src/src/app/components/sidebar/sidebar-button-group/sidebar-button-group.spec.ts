import { ComponentFixture, TestBed } from '@angular/core/testing';

import { SidebarButtonGroup } from './sidebar-button-group';

describe('SidebarButtonGroup', () => {
  let component: SidebarButtonGroup;
  let fixture: ComponentFixture<SidebarButtonGroup>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [SidebarButtonGroup]
    })
    .compileComponents();

    fixture = TestBed.createComponent(SidebarButtonGroup);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
