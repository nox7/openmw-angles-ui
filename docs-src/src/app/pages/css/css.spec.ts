import { ComponentFixture, TestBed } from '@angular/core/testing';

import { Css } from './css';

describe('Css', () => {
  let component: Css;
  let fixture: ComponentFixture<Css>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [Css]
    })
    .compileComponents();

    fixture = TestBed.createComponent(Css);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
