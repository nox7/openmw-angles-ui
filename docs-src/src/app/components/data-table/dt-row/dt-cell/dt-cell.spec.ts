import { ComponentFixture, TestBed } from '@angular/core/testing';

import { DtCell } from './dt-cell';

describe('DtCell', () => {
  let component: DtCell;
  let fixture: ComponentFixture<DtCell>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [DtCell]
    })
    .compileComponents();

    fixture = TestBed.createComponent(DtCell);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
