import { ComponentFixture, TestBed } from '@angular/core/testing';

import { Installing } from './installing';

describe('Installing', () => {
  let component: Installing;
  let fixture: ComponentFixture<Installing>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [Installing]
    })
    .compileComponents();

    fixture = TestBed.createComponent(Installing);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
