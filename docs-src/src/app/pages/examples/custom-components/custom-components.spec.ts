import { ComponentFixture, TestBed } from '@angular/core/testing';

import { CustomComponents } from './custom-components';

describe('CustomComponents', () => {
  let component: CustomComponents;
  let fixture: ComponentFixture<CustomComponents>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [CustomComponents]
    })
    .compileComponents();

    fixture = TestBed.createComponent(CustomComponents);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
