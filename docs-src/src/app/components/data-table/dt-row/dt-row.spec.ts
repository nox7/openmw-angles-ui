import { ComponentFixture, TestBed } from '@angular/core/testing';

import { DtRow } from './dt-row';

describe('DtRow', () => {
  let component: DtRow;
  let fixture: ComponentFixture<DtRow>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [DtRow]
    })
    .compileComponents();

    fixture = TestBed.createComponent(DtRow);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
